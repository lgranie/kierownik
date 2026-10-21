# gpg/ssh agent env (sourced from /etc/profile.d)
# shellcheck shell=bash

# Skip system users (e.g. greetd UID 967) and non-interactive shells.
# shellcheck source=00-interactive-only.sh disable=SC1091
. /etc/profile.d/00-interactive-only.sh 2>/dev/null || return 0 2>/dev/null || exit 0
krw_require_interactive || return 0 2>/dev/null || exit 0

GPG_TTY="$(tty)"
export GPG_TTY

# environment.d/99-ssh-gpg.conf and uwsm/env already export this; only fall
# back to gpgconf when the socket path is missing from the session.
if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
  SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
  export SSH_AUTH_SOCK
fi

gpg-connect-agent updatestartuptty /bye >/dev/null || true
