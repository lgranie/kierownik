# compress/compdir/decompress helpers.
# shellcheck shell=bash

# shellcheck source=00-interactive-only.sh disable=SC1091
. /etc/profile.d/00-interactive-only.sh 2>/dev/null || return 0 2>/dev/null || exit 0
krw_require_interactive || return 0 2>/dev/null || exit 0

compress() { tar -czvf "$1.tar.gz" "$1"; }
comparedir() { diff -rq "$1" "$2"; }
decompress() {
  local file
  for file in "$@"; do
    if [ -f "$file" ]; then
      gum log -sl info "Extracting $file"
      case "$file" in
        *.tar) tar -xvf "$file" ;;
        *.tar.bz2 | *.tbz2) tar -jxvf "$file" ;;
        *.tar.gz | *.tgz) tar -zxvf "$file" ;;
        *.bz2) bunzip2 "$file" ;;
        *.gz) gunzip "$file" ;;
        *.rar) unrar x "$file" ;;
        *.zip | *.ZIP) unzip "$file" ;;
        *) gum log -sl warn "Extension not recognized, cannot extract $file" ;;
      esac
    else
      gum log -sl error "$file is not a valid file"
    fi
  done
}
