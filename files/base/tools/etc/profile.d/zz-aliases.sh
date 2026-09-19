# aliases (sourced from /etc/profile.d)
# shellcheck shell=bash

# shellcheck source=00-interactive-only.sh disable=SC1091
. /etc/profile.d/00-interactive-only.sh 2>/dev/null || return 0 2>/dev/null || exit 0
krw_require_interactive || return 0 2>/dev/null || exit 0

# Delete dead links in current dir
alias rmdl='find . -xtype l -delete'

# lsd
alias ls=lsd
alias l='lsd -l'
alias ll='lsd -la'

# nvim
alias v=nvim
alias vi=nvim
alias vim=nvim

# mise
alias mup='mise up'
alias mr='mise run'

# Utils
alias env='env | sort'
alias df='df -h'
alias du='du -h -d 1'

# run0
alias dmesg='run0 dmesg'

# bash cannot place cursor like `run0 bash -c '%'` template; function wraps instead
sudo() { run0 bash -c "$*"; }
