#!/usr/bin/env fish

# No agent there, avoids tty/systemctl
# noise and writes under greetd's HOME. Non-interactive shells need nothing here.
status is-interactive; or return

# Delete dead links in current dir
alias rmdl 'find . -xtype l -delete'

# nvim
alias v nvim
alias vi nvim
alias vim nvim

# mise
alias mup 'mise up'
alias mr 'mise run'

# Utils
alias env 'env | sort'
abbr df 'df -h'
abbr du 'du -h -d 1'

# run0
abbr --add dmesg 'run0 dmesg'
abbr --add sudo --set-cursor 'run0 bash -c \'%\''
