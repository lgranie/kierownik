# Keep bash history across panes and servers.
# shellcheck shell=bash
#
# Bash writes HISTFILE only on a clean exit, and interactive bash ignores
# SIGTERM. herdr SIGKILLs its pane shells on every server shutdown/restart
# (see event="app.shutdown" in herdr-server.log), so without an incremental
# flush the whole in-memory history of a long-lived pane is lost.
# Flushing on each prompt makes a killed pane lose at most the running command.

# shellcheck source=00-interactive-only.sh disable=SC1091
. /etc/profile.d/00-interactive-only.sh 2>/dev/null || return 0 2>/dev/null || exit 0
krw_require_interactive || return 0 2>/dev/null || exit 0

shopt -s histappend
# Fedora defaults to 1000 lines; many concurrent panes fill that quickly.
HISTSIZE=20000
HISTFILESIZE=100000
export HISTSIZE HISTFILESIZE

# PROMPT_COMMAND is an array on bash >= 5.1 (zoxide/mise hooks prepend to it).
if [[ $(declare -p PROMPT_COMMAND 2>/dev/null) == "declare -a"* ]]; then
  [[ " ${PROMPT_COMMAND[*]} " == *" history -a "* ]] || PROMPT_COMMAND=("history -a" "${PROMPT_COMMAND[@]}")
else
  case ";${PROMPT_COMMAND-};" in
    *";history -a;"*) ;;
    *) PROMPT_COMMAND="history -a${PROMPT_COMMAND:+;$PROMPT_COMMAND}" ;;
  esac
fi
