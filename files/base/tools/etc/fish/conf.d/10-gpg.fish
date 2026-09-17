#!/usr/bin/env fish

# No agent there, avoids tty/systemctl
# noise and writes under greetd's HOME. Non-interactive shells need nothing here.
status is-interactive; or return

set -gx GPG_TTY (tty)
set -gx SSH_AUTH_SOCK (gpgconf --list-dirs agent-ssh-socket)
systemctl --user set-environment SSH_AUTH_SOCK=$SSH_AUTH_SOCK

gpg-connect-agent updatestartuptty /bye >/dev/null
