---
name: ai-router-chains
description: Inspect, tune, or add ai_router routing chains (descriptions, requires, context). Use when routing misclassifies, a chain is empty, or a new capability needs its own chain.
---

# ai-router-chains

ai_router classifies prompts by intent (laya) and forwards to freellmapi as `auto:<chain>`; freellmapi owns model choice (quota-aware fallback, key rotation). Chain membership = capability filter over live models; config is user-owned.

## Facts

- Config: `~/.config/ai_router/config.yml` (seeded once by `ai_router:init` from `/usr/lib/kierownik/ai_router/config.default.yml`, never overwritten).
- No bench, no probing, no per-model state. Eligibility per chain: `requires` ⊆ `{tools, vision}` + `context.min`, evaluated against freellmapi's live model DB at startup; profiles resynced on every router start.
- Validation (server fails fast, container crashes): `chat` chain mandatory; every chain needs `description`; `requires` ⊆ `{tools, vision}`; `context.min` non-negative int; `{chain}-large` suffix auto-wins past `router.large_threshold_tokens`. Legacy `bench:` section is ignored (warns in log).
- Debug logging: set `log_level: DEBUG` in `config.yml` to trace per-request routing (Laya choice, confidence, chain/profile pick). View with `mise run ai_router:logs`.
- Laya stays warm (no idle-stop): ai_router dials the container directly, host loopback is unreachable from pasta guests, so stopping it would strand routing.

## Flows (prefer the CLI; same logic as the krw tasks)

- Read: `ai-chains status` (or `mise run ai_router:chains`) — eligible models per chain. Empty pool = requirements too strict for the live catalog.
- Tune: `ai-chains tune` (or `mise run ai_router:tune`) — pick chain + field, validates, restarts router (startup resyncs freellmapi profiles).
- Add: `ai-chains add [name]` (or `mise run ai_router:add`) — scaffolds description/requires/context.min, then same validate/apply path.

## Rules

- Never remove/rename `chat`.
- Descriptions are the laya classification signal — one line, task-focused, distinct per chain.
- After any chain change, restart `freellmapi.service` last so dashboard profiles sync.
