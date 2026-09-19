# bash prompt with abbreviated pwd: /v/h/lgranie
# shellcheck shell=bash

# shellcheck source=00-interactive-only.sh disable=SC1091
. /etc/profile.d/00-interactive-only.sh 2>/dev/null || return 0 2>/dev/null || exit 0
krw_require_interactive || return 0 2>/dev/null || exit 0

# abbreviated pwd: /v/h/lgranie
pwdshort() {
  local p="$PWD"
  case "$p" in "$HOME"*) p="~${p#$HOME}" ;; esac
  local IFS=/
  read -ra parts <<<"$p"
  local out="" n=${#parts[@]} i c
  for ((i = 0; i < n; i++)); do
    c="${parts[i]}"
    if [ -z "$c" ]; then
      out+="/"
      continue
    fi
    if [ $i -eq $((n - 1)) ] || [ "$c" = "~" ]; then
      out+="$c"
    else
      out+="${c:0:1}"
    fi
    [ $i -lt $((n - 1)) ] && out+="/"
  done
  printf "%s" "$out"
}
PS1='[\u@\h $(pwdshort)]\$ '
