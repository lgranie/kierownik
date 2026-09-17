# Local LLM on 8745HS (32GB shared RAM)

Reference for running local LLMs with ramalama on the Ryzen 7 8745HS (Radeon 780M iGPU,
32GB unified/shared memory) machines in this repo.

## Quick start

Interactive model picker (per-model tuning auto-applied from the table below):

```bash
mise run llm:serve
```

Serve a specific model with default tuning:

```bash
mise run llm:serve qwen3.8:ud-iq4_xs
```

Override context size and GPU offload layers:

```bash
LLM_CONTEXT=16384 LLM_GPU_LAYERS=60 mise run llm:serve qwen3.8:ud-iq4_xs
```

Check hugepage state:

```bash
mise run llm:hugepages status   # show THP mode + AnonHugePages
```

THP is pinned to `madvise` at boot via the `transparent_hugepage=madvise` karg in
`recipes/llm/ramalama.yml` (takes effect after rebuild + reboot). No runtime toggle:
llama.cpp marks its buffers `MADV_HUGEPAGE`, so it gets hugepages automatically with
zero RAM reservation. Static HugeTLB pools stay at 0 — llama.cpp doesn't use them.

Clean up downloaded models:

```bash
mise run llm:clean              # pick which models to remove
mise run llm:clean --all        # remove everything
```

## Models / shortnames

Configured in `files/llm/ramalama/usr/share/ramalama/shortnames.conf`.
All are GGUF on Hugging Face. URLs verified 2026-09-17 via HF API + `curl -I`
(`x-linked-size`). Sizes are exact file bytes converted to GB.

Memory = weights + KV cache (f16) + ~1.5GB compute/buffers. Budget ~20–24GB
(model+ctx); rest stays for OS. Green fits easy, yellow tight but OK.

| Name | Release | Shortname | URL (verified) | Size | Mem 8k | Mem 16k | Mem 32k | MTP draft (speculative) | Ramalama args |
|------|---------|-----------|----------------|------|--------|---------|---------|-------------------------|---------------|
| Qwen3.6 35B-A3B MoE, 262K, thinking+vision | 2026-04-16 | `qwen3.6:iq3_xxs` | `hf://bartowski/Qwen_Qwen3.6-35B-A3B-GGUF/Qwen_Qwen3.6-35B-A3B-IQ3_XXS.gguf` | 15.8GB | 18.1GB | 19.0GB | 20.7GB | `hf://bartowski/Qwen_Qwen3.6-35B-A3B-GGUF/mtp-Qwen_Qwen3.6-35B-A3B-Q4_0.gguf` | `-c 16384 --ngl 40 --temp 0.7 --runtime-args "--top-p 0.95 --repeat-penalty 1.1"` |
| Qwen3.8 27B newest dense, 262K (ext. 1M), vision | 2026-08-13 | `qwen3.8:ud-iq4_xs` | `hf://unsloth/Qwen3.8-27B-GGUF/Qwen3.8-27B-UD-IQ4_XS.gguf` | 14.3GB | 16.9GB | 18.1GB | 20.4GB | `hf://unsloth/Qwen3.8-27B-GGUF/MTP/mtp-Qwen3.8-27B-Q4_0.gguf` | `-c 16384 --ngl 30 --temp 1.0 --top-k 20 --runtime-args "--top-p 0.95 --repeat-penalty 1.0"` |
| Muse Glimmer 30B dense, 131K, Apache-2.0, agentic coding 76% SWE-bench | 2026-08-10 | `muse-glimmer:iq4_xs` | `hf://bartowski/Muse-Glimmer-30B-GGUF/Muse-Glimmer-30B-IQ4_XS.gguf` | 15.4GB | 18.1GB | 19.3GB | 21.7GB | `hf://bartowski/Muse-Glimmer-30B-GGUF/dflash-Muse-Glimmer-30B-Q4_0.gguf` (DFlash draft) | `-c 16384 --ngl 30 --temp 0.7 --runtime-args "--top-p 0.95 --repeat-penalty 1.1"` (reasoning_strength high, ATEM tool template) |
| Gemma 4 26B-A4B MoE, 262K, Apache-2.0, best general tool-call | 2026-03-31 | `gemma4:ud-iq4_xs` | `hf://unsloth/gemma-4-26B-A4B-it-GGUF/gemma-4-26B-A4B-it-UD-IQ4_XS.gguf` | 13.6GB | 16.0GB | 16.8GB | 18.5GB | `hf://unsloth/gemma-4-26B-A4B-it-GGUF/mtp-gemma-4-26B-A4B-it-Q8_0.gguf` | `-c 16384 --ngl 40 --temp 0.7 --runtime-args "--top-p 0.95 --repeat-penalty 1.1"` |
| Gemma 4 26B-A4B MoE, higher-quality quant | 2026-03-31 | `gemma4:ud-q4_k_xl` | `hf://unsloth/gemma-4-26B-A4B-it-GGUF/gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf` | 17.0GB | 19.4GB | 20.2GB | 21.9GB | same as above | `-c 16384 --ngl 40 --temp 0.7 --runtime-args "--top-p 0.95 --repeat-penalty 1.1"` |
| GLM-4.7-Flash, 128K, long-ctx agent pick | 2026-01-20 | `glm-flash:q3_k_s` | `hf://bartowski/zai-org_GLM-4.7-Flash-GGUF/zai-org_GLM-4.7-Flash-Q3_K_S.gguf` | 13.5GB | 15.9GB | 16.9GB | 18.7GB | — | `-c 32768 --ngl 30 --temp 0.7 --runtime-args "--top-p 0.95 --repeat-penalty 1.1"` |

Notes:

- Release = base model launch (GLM-4.7-Flash GGUF 2026-01-20,
  Gemma 4 2026-03-31, Qwen3.6 2026-04-16, Muse Glimmer 2026-08-10,
  Qwen3.8 GGUF 2026-08-13).
  2026 models only; older releases (Qwen3-Coder, gpt-oss, Devstral Small 2)
  dropped per policy.
- `mise run llm:serve <alias>` auto-applies that row's Ramalama args (ctx, ngl,
  temp, top-p, top-k, repeat-penalty) from the `shortnames.conf` comment.
  Env overrides win: `LLM_CONTEXT=8192 LLM_GPU_LAYERS=20 mise run llm:serve ...`.
- Qwen3-Coder-Next (80B-A3B) excluded: only Q8_0 GGUF published (~84GB), no fit.
- NVIDIA Nemotron 3.5 Lightning 30B excluded: smallest quants ~18.9GB + KV = tight
  with no coding advantage over Qwen3-Coder on this HW.
- MTP = multi-token-prediction draft for speculative decoding (ggml-org preset style:
  `--spec-type draft-mtp`). Ramalama may not expose MTP flags yet; column lists the
  matching draft file when the publisher ships one. `—` = none published.
- Qwen3.8 thinking model uses `temperature=1.0, top_k=20` per Unsloth guide;
  coders use `temperature=0.7`. Muse Glimmer uses `reasoning_strength` high.

Recommended default for interactive coding on 8745HS:
**`qwen3.8:ud-iq4_xs`** (newest 2026 coding gains, fits 16.9/18.1GB at 8k/16k).
MoE alternative for max responsiveness: **`gemma4:ud-iq4_xs`**.

## Advice for 32GB shared memory

- **There is no discrete VRAM.** The iGPU borrows from the same 32GB pool as the
  CPU/OS. Realistic model+context budget is ~20–24GB.
- **Prefer MoE models** (Qwen3.6 35B, Gemma 4) — only their active experts run
  per token, so they stay responsive even mostly on CPU.
- **Dense models need headroom** (Qwen3.8 27B, Muse Glimmer 30B at 32k ctx reach ~21–22GB) —
  fine at 8–16k ctx, tight at 32k. Only use 32k if you need repo-scale context.
- **Context is RAM.** Native context is 128–262K but it won't fit. Use
  `LLM_CONTEXT=8192` (default) to `16384` unless you genuinely need long context.
  32k fits the table above but leaves little headroom; measure with `mise run llm:serve`.
- **GPU offload trades compute, not memory.** `--ngl` moves work to the iGPU but the
  weights still live in the same 32GB. A partial offload (`LLM_GPU_LAYERS=40` MoE,
  `20–30` dense) is a good starting point.
- **Hugepages:** THP pinned to `madvise` at boot (karg, zero RAM carve).
  llama.cpp gets hugepages via `MADV_HUGEPAGE` automatically. Don't run two models
  at once (they'd fight over RAM).

## BIOS configuration for shared memory

Exact menu labels vary by OEM (Framework, Minisforum, Lenovo, ASUS...).

1. **UMA Frame Buffer Size / iGPU Memory / DVMT**
   - Purpose: RAM reserved for the iGPU.
   - For LLM on CPU (no/low offload): set **Auto** (or 512MB–1GB). This maximizes
     the RAM available to the model + OS. Avoid large fixed carve-outs (e.g. 8GB),
     which permanently shrink your 32GB budget.
   - For GPU offload (`--ngl > 0`): a fixed **2–4GB** buffer gives the Vulkan/ROCm
     runtime reliable allocation. Still shared — size it to the KV cache + offloaded
     layers, not the whole model.
   - Always reboot after changing.

2. **Resizable BAR / Above 4G Decoding**
   - Purpose: lets the iGPU address the full shared pool.
   - Set **Enabled** if you offload to the iGPU; improves Vulkan performance.

3. **Memory / SVM (Secure Virtual Machine)**
   - Leave **Auto**.

> Note: with UMA set to Auto, `/proc/meminfo` (used by the hugepage script) still
> sees ~full 32GB, since the iGPU borrows dynamically rather than reserving up-front.

Max model headroom = UMA **Auto**. Better GPU-offload perf = UMA fixed **2–4GB**.
