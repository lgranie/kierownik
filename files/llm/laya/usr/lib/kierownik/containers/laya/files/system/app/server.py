"""Laya English-only decision microservice (inferenceprince/laya-onnx, ONNX Runtime)."""
# ponytail: prompt math vendored from laya common.py, zero torch dep; add Router when multilingual needed.

import json
import os

from fastapi import FastAPI, HTTPException

import numpy as np
import onnxruntime as ort
from huggingface_hub import snapshot_download
from transformers import AutoTokenizer

ONNX_REPO = os.environ.get("LAYA_ONNX_MODEL", "inferenceprince/laya-onnx")
CACHE = os.environ.get("HF_HUB_CACHE", "/cache")

QTYPES = {"choice": 0, "score": 1, "noul": 2}
QTYPE_NAMES = {v: k for k, v in QTYPES.items()}
TEMP_MIN, TEMP_MAX = 0.5, 5.0


def _clamp_temp(t):
    try:
        t = float(t)
    except (TypeError, ValueError):
        return 1.0
    if t != t or t in (float("inf"), float("-inf")):
        return 1.0
    return min(TEMP_MAX, max(TEMP_MIN, t))


def _serialize_state(state):
    if isinstance(state, str):
        return state
    return json.dumps(state, ensure_ascii=False)


def _render_criterion(value):
    if isinstance(value, str):
        return value
    return json.dumps(value, ensure_ascii=False, separators=(", ", ": "), default=str)


def _noul_labels(labels=None):
    if labels is None:
        labels = {"false": "false", "true": "true"}
    if not isinstance(labels, dict) or set(labels) != {"false", "true"}:
        raise ValueError("noul labels must map exactly 'false' and 'true'")
    false_label, true_label = labels["false"], labels["true"]
    if not isinstance(false_label, str) or not isinstance(true_label, str):
        raise ValueError("noul labels must map exactly 'false' and 'true'")
    false_label, true_label = false_label.strip(), true_label.strip()
    if not false_label or not true_label or false_label == true_label:
        raise ValueError("noul labels must map exactly 'false' and 'true'")
    return false_label, true_label


def _render_options(q):
    t, crit = q["t"], q.get("crit")
    if t != "noul" and "labels" in q:
        raise ValueError("labels is only supported for noul questions")
    if t == "choice":
        return [str(k) if v is None or v == "" else "%s: %s" % (k, _render_criterion(v)) for k, v in crit.items()]
    if t == "score":
        return ["level %d: %s" % (i, _render_criterion(c)) for i, c in enumerate(crit)]
    crit = crit or {}
    false_label, true_label = _noul_labels(q.get("labels"))
    false_crit, true_crit = crit.get("false"), crit.get("true")
    return [
        false_label + ": " + (_render_criterion(false_crit) if false_crit not in (None, "") else "no, the statement does not hold"),
        true_label + ": " + (_render_criterion(true_crit) if true_crit not in (None, "") else "yes, the statement holds"),
    ]


def _build_sequence(tok, state, q, max_len=512, head_max_len=192, state_ids=None):
    mask_tok = tok.mask_token
    opts = _render_options(q)
    ins = str(q["ins"]).replace(mask_tok, " ")
    head_ids = tok("%s question: %s" % (q["t"], ins), add_special_tokens=False)["input_ids"]
    opt_ids = []
    for text in opts:
        toks = tok(" " + text.replace(mask_tok, " "), add_special_tokens=False, truncation=True, max_length=48)["input_ids"]
        opt_ids.append([tok.mask_token_id] + toks)
    opt_budget = head_max_len - sum(len(o) for o in opt_ids)
    if opt_budget < 16:
        per = max(4, (head_max_len - 16) // max(1, len(opt_ids)))
        opt_ids = [o[:per] for o in opt_ids]
        opt_budget = head_max_len - sum(len(o) for o in opt_ids)
    head_ids = head_ids[: max(8, opt_budget)]
    ids = [tok.cls_token_id] + head_ids + [tok.sep_token_id]
    markers = []
    for o in opt_ids:
        markers.append(len(ids))
        ids.extend(o)
    ids.append(tok.sep_token_id)
    room = max(0, max_len - len(ids) - 1)
    if state_ids is None:
        state_ids = tok(_serialize_state(state).replace(mask_tok, " "), add_special_tokens=False)["input_ids"]
    st = state_ids[:room]
    ids = ids + st + [tok.sep_token_id]
    return ids[:max_len], [m for m in markers if m < max_len]


def _temp_bucket(qtype, k):
    size = "2" if k <= 2 else "3-5" if k <= 5 else "6-10" if k <= 10 else "11+"
    return "%s:%s" % (QTYPE_NAMES[int(qtype)], size)


def _confidence(p, k):
    if k < 2:
        return 1.0
    ent = -(p[:k] * np.log(np.clip(p[:k], 1e-12, 1.0))).sum()
    return float(np.clip(1.0 - ent / np.log(k), 0.0, 1.0))


def _to_internal(qid, qdef):
    if not isinstance(qdef, dict):
        raise ValueError("question %r: must be an object" % (qid,))
    t = qdef.get("type")
    if t not in QTYPES:
        raise ValueError("question %r: unknown type %r" % (qid, t))
    crit = qdef.get("criteria")
    if t == "choice":
        if isinstance(crit, list):
            crit = {c: None for c in crit}
        if not isinstance(crit, dict) or not crit:
            raise ValueError("question %r: choice needs criteria object" % (qid,))
    elif t == "score":
        if not isinstance(crit, list) or not crit:
            raise ValueError("question %r: score needs criteria list" % (qid,))
    elif isinstance(crit, dict):
        crit = {str(k).lower(): v for k, v in crit.items()}
    elif crit is not None:
        raise ValueError("question %r: noul needs criteria object or nothing" % (qid,))
    ins = qdef.get("instructions")
    if not isinstance(ins, str):
        ins = json.dumps(ins, ensure_ascii=False)
    q = {"t": t, "ins": ins, "crit": crit}
    if "labels" in qdef:
        q["labels"] = qdef["labels"]
    return q


def _download_bundle():
    return snapshot_download(
        ONNX_REPO,
        cache_dir=CACHE,
        allow_patterns=["model.onnx", "model.onnx.data", "tokenizer/*", "rl_agent_config.json"],
    )


bundle = _download_bundle()
with open(os.path.join(bundle, "rl_agent_config.json")) as f:
    cfg = json.load(f)
tok = AutoTokenizer.from_pretrained(os.path.join(bundle, "tokenizer"))
_so = ort.SessionOptions()
_so.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
session = ort.InferenceSession(os.path.join(bundle, "model.onnx"), sess_options=_so, providers=["CPUExecutionProvider"])
_temperature = [_clamp_temp(t) for t in cfg.get("temperature", [1.0, 1.0, 1.0])]
_temp_by_options = {k: _clamp_temp(v) for k, v in cfg.get("temperature_by_options", {}).items()}
_max_len = cfg.get("max_len", 512)
_head_max_len = cfg.get("head_max_len", 192)

app = FastAPI(title="laya-decision", version="2.0.0")


def _infer(state, questions):
    ids = list(questions.keys())
    if not ids:
        return {"model": "laya-rl-agent-onnx", "answers": {}, "usage": {"input_tokens": 0, "output_tokens": 0}}
    internal = {qid: _to_internal(qid, questions[qid]) for qid in ids}
    state_ids = tok(_serialize_state(state).replace(tok.mask_token, " "), add_special_tokens=False)["input_ids"]
    seqs, markers, qtypes = [], [], []
    for qid in ids:
        seq, marks = _build_sequence(tok, state, internal[qid], _max_len, _head_max_len, state_ids=state_ids)
        if len(marks) != len(_render_options(internal[qid])):
            raise ValueError("question %r options exceed head_max_len=%d" % (qid, _head_max_len))
        seqs.append(seq)
        markers.append(marks)
        qtypes.append(QTYPES[internal[qid]["t"]])
    n = len(seqs)
    width = max(len(s) for s in seqs)
    kmax = max(len(m) for m in markers)
    input_ids = np.full((n, width), tok.pad_token_id, dtype=np.int64)
    attention_mask = np.zeros((n, width), dtype=np.int64)
    marker_pos = np.zeros((n, kmax), dtype=np.int64)
    marker_mask = np.zeros((n, kmax), dtype=bool)
    for i, seq in enumerate(seqs):
        input_ids[i, : len(seq)] = seq
        attention_mask[i, : len(seq)] = 1
        marker_pos[i, : len(markers[i])] = markers[i]
        marker_mask[i, : len(markers[i])] = True
    logits, act_logits = session.run(
        ["logits", "act_logits"],
        {
            "input_ids": input_ids,
            "attention_mask": attention_mask,
            "marker_pos": marker_pos,
            "marker_mask": marker_mask,
            "qtype": np.array(qtypes, dtype=np.int64),
        },
    )
    act = np.exp(act_logits - act_logits.max(axis=-1, keepdims=True))
    act = act / act.sum(axis=-1, keepdims=True)
    answers = {}
    for r, qid in enumerate(ids):
        q = internal[qid]
        k = len(markers[r])
        qt = qtypes[r]
        scale = _temp_by_options.get(_temp_bucket(qt, k), _temperature[qt])
        z = logits[r, :k] / scale
        p = np.exp(z - z.max())
        p = p / p.sum()
        conf = round(_confidence(p, k), 4)
        ans_conf = round(float(np.clip(p[:k].max(), 0.0, 1.0)), 4)
        ext = {"act_probability": round(float(act[r, 0]), 4)}
        if q["t"] == "choice":
            keys = list(q["crit"].keys())
            answers[qid] = {
                "type": "choice",
                "choice": keys[int(p.argmax())],
                "probabilities": {kk: round(float(v), 4) for kk, v in zip(keys, p)},
                "confidence": conf,
                "answer_confidence": ans_conf,
                "action": ext,
            }
        elif q["t"] == "score":
            exp_score = float((np.arange(k) * p).sum())
            answers[qid] = {
                "type": "score",
                "score": round(exp_score, 4),
                "legend": {str(i): c for i, c in enumerate(q["crit"])},
                "probabilities": {str(i): round(float(v), 4) for i, v in enumerate(p)},
                "confidence": conf,
                "answer_confidence": ans_conf,
                "action": ext,
            }
        else:
            answers[qid] = {
                "type": "noul",
                "noul": round(float(p[1]), 4),
                "confidence": round(max(float(p[1]), 1.0 - float(p[1])), 4),
                "answer_confidence": ans_conf,
                "action": ext,
            }
    return {"model": "laya-rl-agent-onnx", "answers": answers, "usage": {"input_tokens": int(attention_mask.sum()), "output_tokens": 0}}


@app.get("/")
def root():
    return {"service": "laya-decision", "model": ONNX_REPO, "backend": "onnx", "endpoints": ["/health", "/predict"]}


@app.get("/health")
def health():
    return {"status": "ok", "model": ONNX_REPO, "backend": "onnx"}


@app.post("/predict")
def predict(payload: dict):
    state = payload.get("state")
    questions = payload.get("questions")
    if not isinstance(state, dict) or not isinstance(questions, dict):
        raise HTTPException(status_code=400, detail="body needs {state: {}, questions: {}}")
    try:
        return _infer(state, questions)
    except Exception as e:  # noqa: BLE001 — surface model errors as 500
        raise HTTPException(status_code=500, detail=str(e)) from e
