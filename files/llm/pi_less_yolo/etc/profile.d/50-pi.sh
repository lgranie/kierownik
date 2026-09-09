# bash twin of conf.d/50-pi.fish (sourced from /etc/profile.d)
# shellcheck shell=bash

# Env
export PI_NO_CONTAINER_PROMPT=1
export PI_LOCAL_MODELS=1
export PI_SKIP_VERSION_CHECK=1
export PI_MEMORY=4g
export PI_CPUS=2
export PI_PIDS_LIMIT=512

# Alias
alias pi='mise run pi'
