#!/usr/bin/env fish

set -gx GPG_TTY (tty)
set -U -x SSH_AUTH_SOCK (gpgconf --list-dirs agent-ssh-socket)
systemctl --user set-environment SSH_AUTH_SOCK=$SSH_AUTH_SOCK

gpg-connect-agent updatestartuptty /bye > /dev/null
