"""ai_router: OpenAI-compatible proxy routing prompts to freellmapi profiles via laya."""

# ponytail: single file. ai_router classifies intent (laya) and forwards as
# auto:<chain>; freellmapi owns model choice (quota-aware fallback, key
# rotation). No bench, no probing, no per-model state.
# Config is user-only (~/.config/ai_router/config.yml, seeded by ai_router:init
# from the packaged /usr/lib default). Missing config fails fast, no silent default.

import asyncio
import logging
import os
import sqlite3
import sys
from contextlib import asynccontextmanager

import httpx
import yaml
from fastapi import FastAPI, Request, Response
from fastapi.responses import StreamingResponse

FREELLMAPI_URL = os.environ.get("FREELLMAPI_URL", "http://host.containers.internal:3001")
FREELLMAPI_KEY = os.environ.get("FREELLMAPI_KEY", "")
LAYA_URL = os.environ.get("LAYA_URL", "http://host.containers.internal:8008")
CONFIG_PATH = os.environ.get("CONFIG", "/config/config.yml")
FREEDB_PATH = os.environ.get("FREEDB", "/freedb/freeapi.db")
PORT = int(os.environ.get("PORT", "3003"))

LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO").upper()
logging.basicConfig(level=getattr(logging, LOG_LEVEL, logging.INFO),
                    format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("ai_router")

ALLOWED_REQUIRES = {"tools", "vision"}


def estimate_tokens(text):
    return len(text or "") // 4  # ponytail: char/4 heuristic, real tokenizer if misroutes


def _validate_config(cfg):
    if not isinstance(cfg, dict) or not isinstance(cfg.get("chains"), dict) or not cfg["chains"]:
        raise ValueError("config needs a non-empty 'chains' mapping")
    router = cfg.get("router") or {}
    if "chat" not in cfg["chains"]:
        raise ValueError("config needs a 'chat' chain (mandatory fallback)")
    for name, ch in cfg["chains"].items():
        if not isinstance(ch, dict) or not ch.get("description"):
            raise ValueError("chain %r needs 'description'" % (name,))
        for req in ch.get("requires") or []:
            if req not in ALLOWED_REQUIRES:
                raise ValueError("chain %r: unknown requires %r (allowed: tools, vision)" % (name, req))
        ctx = (ch.get("context") or {}).get("min", 0)
        if not isinstance(ctx, int) or ctx < 0:
            raise ValueError("chain %r: context.min must be a non-negative int" % (name,))
    return {"default_chain": router.get("default_chain", "chat"),
            "large_threshold_tokens": router.get("large_threshold_tokens", 12000),
            "laya_confidence_min": router.get("laya_confidence_min", 0.6)}


def _set_log_level(cfg):
    raw = (cfg.get("log_level") or (cfg.get("router") or {}).get("log_level")
           or os.environ.get("LOG_LEVEL", "INFO")).upper()
    level = getattr(logging, raw, logging.INFO)
    logging.getLogger().setLevel(level)
    for h in logging.getLogger().handlers:
        h.setLevel(level)
    logging.getLogger("ai_router").setLevel(level)
    # httpx/httpcore DEBUG dumps full headers per request — never useful here.
    logging.getLogger("httpx").setLevel(logging.WARNING)
    logging.getLogger("httpcore").setLevel(logging.WARNING)
    return raw


def match_caps(chain, caps):
    reqs = set(chain.get("requires") or [])
    if "tools" in reqs and not caps.get("tools"):
        return False
    if "vision" in reqs and not caps.get("vision"):
        return False
    want = (chain.get("context") or {}).get("min", 0) or 0
    have = caps.get("context")
    if have is not None and have < want:
        return False
    return True


def resolve_route(descriptions, choice, confidence, prompt_tokens, default, large_threshold, conf_min):
    base = choice if choice in descriptions and confidence >= conf_min else default
    if base not in descriptions:
        base = default
    large = base + "-large"
    if prompt_tokens >= large_threshold and large in descriptions:
        return large
    return base


CFG = {}
ROUTER = {}
CHAINS = {}
CAPS = {}  # model_id -> {platform, db_id, context, vision, tools, speed, intel}


def _load_caps_db():
    con = sqlite3.connect("file:%s?mode=ro" % FREEDB_PATH, uri=True, timeout=10)
    try:
        cols = {r[1] for r in con.execute("pragma table_info(models)")}
        need = {"platform", "model_id", "context_window", "supports_vision", "supports_tools", "enabled"}
        if not need <= cols:
            raise RuntimeError("models table lacks %s" % sorted(need - cols))
        out = {}
        for plat, mid, ctx, vis, too, en, spd, itl, db_id in con.execute(
                "select platform, model_id, context_window, supports_vision, supports_tools,"
                " enabled, speed_rank, intelligence_rank, id from models"):
            if not en:
                continue
            cur = out.get(mid)
            row = {"platform": plat, "db_id": db_id, "context": ctx,
                   "vision": bool(vis), "tools": bool(too),
                   "speed": spd if spd is not None else 9999,
                   "intel": itl if itl is not None else 9999}
            if cur is None or (row["intel"], row["speed"]) < (cur["intel"], cur["speed"]):
                if cur is not None:  # merge capability flags across providers
                    row["vision"] = row["vision"] or cur["vision"]
                    row["tools"] = row["tools"] or cur["tools"]
                    row["context"] = max(row["context"] or 0, cur["context"] or 0) or None
                out[mid] = row
        return out
    finally:
        con.close()


async def _load_caps_api(client):
    r = await client.get(FREELLMAPI_URL + "/v1/models",
                         headers={"Authorization": "Bearer " + FREELLMAPI_KEY}, timeout=30)
    r.raise_for_status()
    return {m["id"]: {"platform": m.get("owned_by", ""), "db_id": None, "context": None,
                      "vision": False, "tools": False, "speed": 9999, "intel": 9999}
            for m in r.json().get("data", []) if m.get("id") not in ("auto", "fusion")}


def _chain_pool(name):
    # All capability-eligible models, ranked. freellmapi owns the final pick
    # (quota-aware fallback inside the profile); order seeds profile priority.
    ch = CHAINS[name]
    pool = [dict(mid=mid, **caps) for mid, caps in CAPS.items() if match_caps(ch, caps)]
    pool.sort(key=lambda e: (e["intel"], e["speed"]))
    return pool


def _sync_profiles():
    try:
        con = sqlite3.connect(FREEDB_PATH, timeout=30)
    except Exception as e:  # noqa: BLE001 — dashboard sync is cosmetic, routing works regardless
        logger.warning("profile sync skipped: %s", e)
        return
    try:
        tables = {r[0] for r in con.execute("select name from sqlite_master where type='table'")}
        if not {"profiles", "profile_models"} <= tables:
            return
        for name in CHAINS:
            entries = _chain_pool(name)
            row = con.execute("select id from profiles where name=?", (name,)).fetchone()
            if row is None:
                cur = con.execute(
                    "insert into profiles (name, emoji, color, type, is_favorite,"
                    " sort_order, auto_sort, layout_config, created_at,"
                    " auto_include_new_models) values (?,?,?,?,?,?,?,?,datetime('now'),0)",
                    (name, "", "", "custom", 0, 0, "", ""))
                pid = cur.lastrowid
            else:
                pid = row[0]
            con.execute("delete from profile_models where profile_id=?", (pid,))
            for i, e in enumerate(entries):
                if e.get("db_id") is None:
                    continue
                con.execute("insert into profile_models (profile_id, model_db_id, priority, enabled)"
                            " values (?,?,?,1)", (pid, e["db_id"], i + 1))
        con.commit()
    except Exception as e:  # noqa: BLE001 — see above
        logger.error("profile sync failed: %s", e)
    finally:
        con.close()


async def _laya_route(client, prompt):
    criteria = {n: c["description"] for n, c in CHAINS.items()}
    body = {"state": {"prompt": prompt[:2000]},
            "questions": {"route": {"type": "choice", "criteria": criteria,
              "instructions": "Classify the user prompt by task. Pick exactly one."}}}
    r = None
    for attempt in range(3):  # laya cold-boots on demand (model load >10s)
        try:
            r = await client.post(LAYA_URL + "/predict", json=body, timeout=10)
            break
        except Exception as e:  # noqa: BLE001 — backend waking up, retry
            logger.debug("laya attempt %d/3: %s", attempt + 1, type(e).__name__)
            await asyncio.sleep(5)
    if r is None:
        logger.info("laya unreachable after 3 attempts — default chain")
        return None
    try:
        r.raise_for_status()
        ans = (r.json().get("answers") or {}).get("route") or {}
        choice = ans.get("choice")
        conf = ans.get("confidence", 0)
        try:
            conf = float(conf)
        except (TypeError, ValueError):
            conf = 0
        logger.debug("Laya classification: choice=%r confidence=%.4f (min_confidence=%.2f)", choice, conf, ROUTER["laya_confidence_min"])
        if choice in criteria and conf >= ROUTER["laya_confidence_min"]:
            return choice
        else:
            logger.debug("Laya choice rejected (choice valid? %s, confidence >= min? %s)", choice in criteria, conf >= ROUTER["laya_confidence_min"])
    except Exception as e:  # noqa: BLE001 — fail-open to default chain
        logger.info("laya fallback: %s", type(e).__name__)
    return None


def _prompt_of(body):
    text = ""
    for m in reversed(body.get("messages") or []):
        if m.get("role") != "user":
            continue
        c = m.get("content")
        if isinstance(c, str):
            return c
        for part in c or []:
            if isinstance(part, dict) and part.get("type") == "text":
                text += part.get("text", "")
        return text
    return text


@asynccontextmanager
async def lifespan(app):
    if not os.path.isfile(CONFIG_PATH):
        raise RuntimeError("missing %s — run: mise run ai_router:init" % CONFIG_PATH)
    with open(CONFIG_PATH) as f:
        cfg = yaml.safe_load(f)
    global CFG, ROUTER, CHAINS
    CFG = cfg
    ROUTER = _validate_config(cfg)
    CHAINS = cfg["chains"]
    level_name = _set_log_level(cfg)
    logger.info("log level=%s default_chain=%s chains=%s", level_name,
                ROUTER["default_chain"], sorted(CHAINS))
    if "bench" in cfg:
        logger.warning("ignoring legacy 'bench' section in config (bench removed; freellmapi owns model choice)")
    client = httpx.AsyncClient()
    app.state.client = client
    try:
        CAPS.update(_load_caps_db())
        print("caps: %d models from freellmapi db" % len(CAPS), flush=True)
    except Exception as e:  # noqa: BLE001 — fall back to bare /v1/models ids
        print("db caps failed (%s), using /v1/models" % e, flush=True)
        try:
            CAPS.update(await _load_caps_api(client))
        except Exception as e2:  # noqa: BLE001 — serve with capability-unfiltered pools until caps recover
            print("api caps failed (%s)" % e2, flush=True)
    _sync_profiles()  # profiles must exist before first auto:<chain> request
    yield
    await client.aclose()


app = FastAPI(title="ai_router", version="1.0.0", lifespan=lifespan)


@app.get("/")
def root():
    return {"service": "ai_router", "endpoints": ["/health", "/chains", "/v1/models",
                                                  "/v1/chat/completions", "/v1/embeddings"]}


@app.get("/health")
def health():
    return {"status": "ok",
            "chains": {n: len(_chain_pool(n)) for n in CHAINS}}


@app.get("/chains")
def chains():
    return {"chains": {n: {"description": CHAINS[n]["description"],
                           "models": [e["mid"] for e in _chain_pool(n)]}
                       for n in CHAINS}}


@app.get("/v1/models")
def models():
    data = [{"id": "auto", "object": "model", "created": 0, "owned_by": "ai_router"}]
    for n in CHAINS:
        data.append({"id": "chain-%s" % n, "object": "model", "created": 0, "owned_by": "ai_router"})
    return {"object": "list", "data": data}


def _fwd_headers(request):
    # freellmapi derives client_agent from User-Agent; forwarding the original
    # keeps the dashboard attribution instead of logging "unknown".
    h = {"Authorization": "Bearer " + FREELLMAPI_KEY, "Content-Type": "application/json"}
    ua = request.headers.get("user-agent")
    if ua:
        h["User-Agent"] = ua
    return h


async def _forward(client, body, headers):
    r = await client.send(client.build_request("POST", FREELLMAPI_URL + "/v1/chat/completions",
                                               json=body, headers=headers,
                                               timeout=httpx.Timeout(600.0, connect=10.0)))
    if body.get("stream"):
        h = {"content-type": "text/event-stream", "cache-control": "no-cache"}
        for k in ("x-routed-via", "x-fallback-attempts", "x-fallback-trail"):
            if k in r.headers:
                h[k] = r.headers[k]
        return StreamingResponse(r.aiter_bytes(), status_code=r.status_code, headers=h,
                                 background=r.aclose)
    data = await r.aread()
    return Response(content=data, status_code=r.status_code, media_type="application/json")


@app.post("/v1/chat/completions")
async def chat(body: dict, request: Request):
    client = request.app.state.client
    asked = body.get("model", "auto")
    prompt = _prompt_of(body)
    token_count = estimate_tokens(prompt)
    if isinstance(asked, str) and asked.startswith("chain-") and asked[6:] in CHAINS:
        chain = asked[6:]
        logger.debug("Routed by explicit chain: chain=%s (asked=%r)", chain, asked)
    elif asked in ("auto", None, ""):
        choice = await _laya_route(client, prompt)
        if choice is not None:
            chain = resolve_route(set(CHAINS), choice, 1.0,
                                  token_count, ROUTER["default_chain"],
                                  ROUTER["large_threshold_tokens"], ROUTER["laya_confidence_min"])
            logger.debug("Routed by laya: laya_choice=%r tokens=%d chain=%s", choice, token_count, chain)
        else:
            chain = ROUTER["default_chain"]
            logger.debug("Routed by default chain (laya missed): default=%s tokens=%d", chain, token_count)
    else:  # explicit model id: passthrough untouched
        logger.debug("Routed by explicit model=%r — passthrough to freellmapi", asked)
        return await _forward(client, body, _fwd_headers(request))
    # Delegate model choice to freellmapi: auto:<profile> walks the chain's
    # models with quota-aware fallback + key rotation. Vision/capability gates
    # are enforced router-side there.
    logger.info("Routed: chain=%s profile=auto:%s tokens=%d", chain, chain, token_count)
    body = dict(body, model="auto:" + chain)
    headers = _fwd_headers(request)
    if chain.startswith("coding"):
        headers["X-FreeLLM-Task-Type"] = "code"
    resp = await _forward(client, body, headers)
    resp.headers["X-AI-Router-Chain"] = chain
    return resp


@app.post("/v1/embeddings")
async def embeddings(body: dict, request: Request):
    return await _forward(request.app.state.client, body, _fwd_headers(request))


def _demo():
    assert estimate_tokens("abcd") == 1 and estimate_tokens("") == 0
    caps = {"tools": True, "vision": False, "context": 50000}
    assert match_caps({"requires": ["tools"], "context": {"min": 8000}}, caps)
    assert not match_caps({"requires": ["vision"], "context": {"min": 0}}, caps)
    assert not match_caps({"requires": [], "context": {"min": 100000}}, caps)
    assert match_caps({"requires": [], "context": {"min": 0}}, {"context": None})  # unknown ctx passes
    names = {"coding", "coding-large", "chat"}
    assert resolve_route(names, "coding", 0.9, 500, "chat", 12000, 0.6) == "coding"
    assert resolve_route(names, "coding", 0.9, 50000, "chat", 12000, 0.6) == "coding-large"
    assert resolve_route(names, "coding", 0.1, 500, "chat", 12000, 0.6) == "chat"
    assert resolve_route(names, "nope", 0.9, 500, "chat", 12000, 0.6) == "chat"
    assert _prompt_of({"messages": [{"role": "user", "content": "hi"}]}) == "hi"
    assert _prompt_of({"messages": [{"role": "user", "content": [
        {"type": "text", "text": "ab"}, {"type": "image_url"}]}]}) == "ab"
    r = _validate_config({"chains": {"chat": {"description": "x"}}})  # probe optional now
    assert r["default_chain"] == "chat"
    assert _validate_config({"log_level": "DEBUG", "bench": {"top_n": 3},
                             "chains": {"chat": {"description": "x"}}})["default_chain"] == "chat"  # legacy bench ignored
    try:
        _validate_config({"chains": {"chat": {"description": "x", "requires": ["audio"]}}})
    except ValueError:
        pass
    else:
        raise AssertionError("unknown requires must fail fast")
    print("ai_router demo: all asserts pass")


if __name__ == "__main__" and len(sys.argv) > 1 and sys.argv[1] == "demo":
    _demo()
