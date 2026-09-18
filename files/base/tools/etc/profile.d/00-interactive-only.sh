# Shared guard for interactive-only profile.d scripts.
# shellcheck shell=sh
#
# Usage at top of script (after shellcheck header):
#   # shellcheck source=00-interactive-only.sh disable=SC1091
#   . /etc/profile.d/00-interactive-only.sh 2>/dev/null || return 0 2>/dev/null || exit 0
#   krw_require_interactive || return 0 2>/dev/null || exit 0
#
# Skips system users (e.g. greetd UID 967: no agent there, avoids
# tty/systemctl noise and writes under the service HOME),
# non-interactive shells, and shells without a controlling terminal.
krw_require_interactive() {
  [ "$(id -u)" -lt 1000 ] && [ "$(id -un)" != "root" ] && return 1
  case $- in
    *i*) ;;
    *) return 1 ;;
  esac
  tty -s || return 1
}
