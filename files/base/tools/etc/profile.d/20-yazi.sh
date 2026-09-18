# yazi wrapper: interactive shells only.

# shellcheck source=00-interactive-only.sh disable=SC1091
. /etc/profile.d/00-interactive-only.sh 2>/dev/null || return 0 2>/dev/null || exit 0
krw_require_interactive || return 0 2>/dev/null || exit 0

if [ -n "${BASH_VERSION:-}" ]; then
  y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
    yazi "$@" --cwd-file="$tmp"
    if cwd=$(command cat -- "$tmp") && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
      builtin cd -- "$cwd"
    fi
    rm -f -- "$tmp"
  }
fi
