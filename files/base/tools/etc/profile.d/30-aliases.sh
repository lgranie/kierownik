# bash twin of conf.d/30-aliases.fish (sourced from /etc/profile.d)
# shellcheck shell=bash

# shellcheck source=00-interactive-only.sh disable=SC1091
. /etc/profile.d/00-interactive-only.sh 2>/dev/null || return 0 2>/dev/null || exit 0
krw_require_interactive || return 0 2>/dev/null || exit 0

# Delete dead links in current dir
alias rmdl='find . -xtype l -delete'

# nvim
alias v=nvim
alias vi=nvim
alias vim=nvim

# mise
alias mup='mise up'
alias mr='mise run'

# Utils (fish abbrs become plain aliases; no recursive expansion in bash)
alias env='env | sort'
alias df='df -h'
alias du='du -h -d 1'

# run0 (fish `abbr dmesg` equivalent)
alias dmesg='run0 dmesg'

# fish `abbr sudo --set-cursor "run0 bash -c '%'"` has no alias equivalent;
# a function wraps the command the same way (bash cannot place the cursor)
sudo() { run0 bash -c "$*"; }
