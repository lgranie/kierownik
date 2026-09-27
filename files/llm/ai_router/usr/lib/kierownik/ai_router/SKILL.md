---
name: ai-router-chains
description: Inspect, tune, or add ai_router routing chains (probes, requires, context, bench knobs). Use when routing misclassifies, a chain is empty/slow, or a new capability needs its own chain.
---

# ai-router-chains

ai_router routes prompts to freellmapi models via per-intent **chains**, classified by laya. Chain membership is re-benched against live models; config is user-owned, bench state is incremental.

## Facts

- Config: `~/.config/ai_router/config.yml` (seeded once by `ai_router:init` from `/usr/lib/kierownik/ai_router/config.default.yml`, never overwritten).
- Bench state: `~/.local/share/ai_router/state.json` — per-chain top models. Deleted only for a full re-bench.
- Bench is **incremental**: only new `(platform, model)` pairs get probed; cached results survive. Pool capped (`bench.pool_cap`), keeps `bench.top_n` by latency.
- Validation (server fails fast, container crashes): `chat` chain mandatory; every chain needs `description` + `probe`; `requires` ⊆ `{tools, vision}`; `context.min` non-negative int; `{chain}-large` suffix auto-wins past `router.large_threshold_tokens`.
- Full re-bench burns free-tier quota — confirm with the user first.
- Debug logging: set `log_level: DEBUG` in `config.yml` to trace per-request routing (Laya choice, confidence, chain/model pick). View with `mise run ai_router:logs`.
- Laya stays warm (no idle-stop): ai_router dials the container directly, host loopback is unreachable from pasta guests, so stopping it would strand routing.

## Flows (prefer the CLI; same logic as the krw tasks)

- Read: `ai-chains status` (or `mise run ai_router:chains`) — bench state + top models per chain. Empty pool or all-failing = weak chain.
- Tune: `ai-chains tune` (or `mise run ai_router:tune`) — pick chain + field, validates, restarts router, waits for bench idle, syncs freellmapi profiles.
- Add: `ai-chains add [name]` (or `mise run ai_router:add`) — scaffolds description/probe/requires/context.min, then same validate/bench path.
- Full re-bench: `mise run ai_router:bench` — wipes state, probes every live model per chain (~25 min max poll).

## Rules

- Never hand-edit `state.json`; change `config.yml` and let bench merge.
- Never remove/rename `chat`.
- Probes must be small and capability-specific (one tool call, one reasoning step, one exact-reply).
- After any chain change, wait for bench `idle` before declaring done; restart `freellmapi.service` last so dashboard profiles sync.
