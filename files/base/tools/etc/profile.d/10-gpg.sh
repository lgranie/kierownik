# bash twin of conf.d/10-gpg.fish (sourced from /etc/profile.d)
# shellcheck shell=bash

GPG_TTY="$(tty)"
export GPG_TTY
SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
export SSH_AUTH_SOCK
systemctl --user set-environment "SSH_AUTH_SOCK=$SSH_AUTH_SOCK"

gpg-connect-agent updatestartuptty /bye >/dev/null || true
