#!/usr/bin/env fish

# Env
set -gx PI_NO_CONTAINER_PROMPT 1
set -gx PI_LOCAL_MODELS 1
set -gx PI_SKIP_VERSION_CHECK 1
set -gx PI_MEMORY "4g"
set -gx PI_CPUS 2
set -gx PI_PIDS_LIMIT 512

# Alias
alias pi "mise run pi"
