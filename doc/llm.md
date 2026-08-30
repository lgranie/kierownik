# Local LLM on 8745HS (32GB shared RAM)

Reference for running local LLMs with ramalama on the Ryzen AI HX (Radeon 860M iGPU,
32GB unified/shared memory) machines in this repo.

## Quick start

Interactive model picker (turns hugepages on, serves, then turns them off):

```bash
mise run llm:serve
```

Serve a specific model with default tuning:

```bash
mise run llm:serve qwen3-coder:q3_k_m
```

Override context size and GPU offload layers:

```bash
LLM_CONTEXT=16384 LLM_GPU_LAYERS=60 mise run llm:serve qwen3-coder:q3_k_m
```

Manage hugepages manually:

```bash
mise run llm:hugepages status   # show THP + static hugepage state
mise run llm:hugepages on       # allocate half of free RAM as static hugepages
mise run llm:hugepages off      # revert to transparent hugepages
```

Clean up downloaded models:

```bash
mise run llm:clean              # pick which models to remove
mise run llm:clean --all        # remove everything
```

## Models / shortnames

Configured in `files/llm/ramalama/usr/share/ramalama/shortnames.conf`.
All are GGUF on Hugging Face, sorted newest first. Verified working URLs.

| Alias | Model | Note |
|-------|-------|------|
| `qwen3.8` | Qwen3.8 27B | Dense, highest accuracy, but heavier for 32GB |
| `gemma4` | Gemma 4 26B | MoE (4B active), Apache 2.0, fast on shared RAM |
| `bigcodemax` | BigCodeMax 8B | MXFP4 ~7.8GB, easiest fit, quick/light coding |
| `devstral` | Devstral Small 24B | Dense, best for agentic/multi-file workflows, SLOW on 32GB |
| `qwen3-coder` | Qwen3-Coder 30B | MoE (3.3B active), best all-round coding on this HW |

### Quant aliases (fit for 32GB shared RAM)

| Alias | Quant | Size | Use |
|-------|-------|------|-----|
| `qwen3-coder:q4_k_m` | Q4_K_M | 18.6GB | default, balance |
| `qwen3-coder:q4_k_s` | Q4_K_S | 17.5GB | more headroom |
| `qwen3-coder:q3_k_m` | Q3_K_M | 14.7GB | **recommended** tightest good fit |
| `gemma4:q4_k_s` | Q4_K_S | 15.8GB | more headroom |
| `gemma4:iq4_xs` | IQ4_XS | 14.2GB | imatrix, quality/size |
| `gemma4:q3_k_m` | Q3_K_M | 13GB | tightest good fit |

Recommended default for interactive coding on 8745HS:
**`qwen3-coder:q3_k_m`** (MoE keeps it responsive on the 860M).

## Advice for 32GB shared memory

- **There is no discrete VRAM.** The iGPU borrows from the same 32GB pool as the
  CPU/OS. Realistic model+context budget is ~20–24GB.
- **Prefer MoE models** (Qwen3-Coder 30B, Gemma 4) — only their active experts run
  per token, so they stay responsive even mostly on CPU.
- **Dense models that don't fit** (Devstral 24B, Qwen3.8 27B at high quants) will be
  slow on shared RAM — only use if you need their specific strengths.
- **Context is RAM.** Native context is 256K but it won't fit. Use
  `LLM_CONTEXT=8192` (default) to `16384` unless you genuinely need long context.
- **GPU offload trades compute, not memory.** `--ngl` moves work to the iGPU but the
  weights still live in the same 32GB. A partial offload (`LLM_GPU_LAYERS=40`) is a
  good starting point.
- **Hugepages:** the serve task allocates ~half of *free* RAM as static hugepages for
  the duration. Don't run two models at once (they'd fight over the pool).

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
