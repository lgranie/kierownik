# flyline: interactive bash only

# shellcheck source=00-interactive-only.sh disable=SC1091
. /etc/profile.d/00-interactive-only.sh 2>/dev/null || return 0 2>/dev/null || exit 0
krw_require_interactive || return 0 2>/dev/null || exit 0

if [ -n "${BASH_VERSION:-}" ]; then
  enable flyline 2>/dev/null || enable -f /usr/lib64/libflyline.so flyline
fi
