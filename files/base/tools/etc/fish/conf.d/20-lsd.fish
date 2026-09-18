#!/usr/bin/env fish

# No agent there, avoids tty/systemctl
# noise and writes under greetd's HOME. Non-interactive shells need nothing here.
status is-interactive; or return

alias ls lsd
alias l 'lsd -l'
alias ll 'lsd -la'
