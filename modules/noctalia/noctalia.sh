#!/usr/bin/env bash
#
# BlueBuild module: enable Noctalia plugins and templates at build time.
#
# Use in recipes as:
#   - type: noctalia
#     source: local
#     plugins: [kierownik/nightlight]
#     templates: [brave]
#     builtin_templates: [foot]
#
# Keys: plugins (author/name) appends to `enabled = [...]` in plugins.toml;
# templates + builtin_templates (lowercase [a-z0-9_-]) append to
# `community_ids` / `builtin_ids` in templates.toml. Files are created when
# the noctalia recipe has not run yet, so recipe order never matters.
# Idempotent: re-runs are no-ops.
#
# Test: KIEROWNIK_ROOT=/tmp/test-root ./modules/noctalia/noctalia.sh '{"plugins":[...]}'

set -euo pipefail

CONFIG="${1:?usage: noctalia.sh '<json config>'}"
ROOT="${KIEROWNIK_ROOT:-/}"
PLUGINS_TOML="${NOCTALIA_SYSTEM_PLUGINS_TOML:-${ROOT}/usr/lib/kierownik/noctalia/config/plugins.toml}"
TEMPLATES_TOML="${NOCTALIA_SYSTEM_TEMPLATES_TOML:-${ROOT}/usr/lib/kierownik/noctalia/config/templates.toml}"

command -v jq >/dev/null || {
  echo "noctalia: missing required tool 'jq'" >&2
  exit 1
}

toml_append() { # file key id
  local file="${1}" key="${2}" id="${3}" section
  case "${file}" in
    "${PLUGINS_TOML}") section="plugins" ;;
    *) section="theme.templates" ;;
  esac

  if grep -qF "\"${id}\"" "${file}"; then
    echo "noctalia: ${id} already enabled"
    return 0
  fi

  grep -Eq "^${key} = \[.*\]$" "${file}" || {
    echo "noctalia: no single-line '${key} = [...]' in ${file}" >&2
    exit 1
  }

  local tmp
  tmp="$(mktemp)"
  awk -v key="${key}" -v id="${id}" '
$0 ~ "^" key " = \\[.*\\]$" && !done {
    sub(/\]$/, ", \"" id "\"]")
    sub("^" key " = \\[, ", key " = [")
    done = 1
}
{ print }
' "${file}" >"${tmp}"
  cat "${tmp}" >"${file}"
  rm -f "${tmp}"

  grep -qF "\"${id}\"" "${file}" || {
    echo "noctalia: append failed for ${id}" >&2
    exit 1
  }

  if command -v python3 >/dev/null; then
    FILE="${file}" KEY="${key}" ID="${id}" SECTION="${section}" python3 -c "
import os, tomllib
d = tomllib.load(open(os.environ['FILE'], 'rb'))
node = d
for part in os.environ['SECTION'].split('.'):
    node = node[part]
assert os.environ['ID'] in node[os.environ['KEY']], 'id missing after edit'
" || {
      echo "noctalia: ${file} invalid TOML after edit" >&2
      exit 1
    }
  fi

  echo "noctalia: ${id} enabled (${key})"
}

ensure_plugins_toml() {
  if [[ ! -f "${PLUGINS_TOML}" ]]; then
    mkdir -p "$(dirname "${PLUGINS_TOML}")"
    cat >"${PLUGINS_TOML}" <<'EOF'
[plugins]
enabled = []
EOF
  fi
}

ensure_templates_toml() {
  if [[ ! -f "${TEMPLATES_TOML}" ]]; then
    mkdir -p "$(dirname "${TEMPLATES_TOML}")"
    cat >"${TEMPLATES_TOML}" <<'EOF'
[theme.templates]
builtin_ids = []
community_ids = []
EOF
  fi
}

# --- plugins ---
if jq -e '.plugins | length > 0' <<<"${CONFIG}" >/dev/null; then
  ensure_plugins_toml
  while IFS= read -r id; do
    [[ -n "${id}" ]] || continue
    [[ "${id}" =~ ^[^/[:space:]]+/[^/[:space:]]+$ ]] || {
      echo "noctalia: invalid plugin id '${id}' (want author/name)" >&2
      exit 1
    }
    toml_append "${PLUGINS_TOML}" "enabled" "${id}"
  done < <(jq -r '.plugins[]' <<<"${CONFIG}")
fi

# --- templates ---
if jq -e '(.templates // [] | length > 0) or (.builtin_templates // [] | length > 0)' <<<"${CONFIG}" >/dev/null; then
  ensure_templates_toml
  while IFS= read -r id; do
    [[ -n "${id}" ]] || continue
    [[ "${id}" =~ ^[a-z0-9][a-z0-9_-]*$ ]] || {
      echo "noctalia: invalid template id '${id}' (want lowercase [a-z0-9_-])" >&2
      exit 1
    }
    toml_append "${TEMPLATES_TOML}" "community_ids" "${id}"
  done < <(jq -r '.templates // [] | .[]' <<<"${CONFIG}")
  while IFS= read -r id; do
    [[ -n "${id}" ]] || continue
    [[ "${id}" =~ ^[a-z0-9][a-z0-9_-]*$ ]] || {
      echo "noctalia: invalid template id '${id}' (want lowercase [a-z0-9_-])" >&2
      exit 1
    }
    toml_append "${TEMPLATES_TOML}" "builtin_ids" "${id}"
  done < <(jq -r '.builtin_templates // [] | .[]' <<<"${CONFIG}")
fi
