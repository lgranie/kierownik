#!/usr/bin/env bash
#
# BlueBuild module: install tools from GitHub releases at build time.
#
# Use in recipes as:
#   - type: github-releases
#     source: local
#     releases:
#       - repo: herdrdev/herdr
#         asset: herdr-linux-x86_64
#         dest: /usr/bin/herdr
#
# Entry keys:
#   repo (owner/name, required), asset (required; {tag} is the latest
#   version with leading v stripped, write v{tag} where upstream keeps it;
#   placeholders or release:true resolve the latest tag via the GitHub API
#   and use releases/download, otherwise releases/latest/download), dest
#   (bin file path, or dir for tarballs), type (bin|tgz, default by asset
#   suffix), member + strip (single tar member extraction), chmod (default
#   true for bin, false for tgz), links ({link: target} symlinks),
#   fetch ([{url, dest}] extra files), desktop ({src} installed to
#   /usr/share/applications), post ([shell]).
#
# Test: KIEROWNIK_ROOT=/tmp/test-root ./modules/github-releases/github-releases.sh '{"releases":[...]}'

set -euo pipefail

CONFIG="${1:?usage: github-releases.sh '<json config>'}"
ROOT="${KIEROWNIK_ROOT:-/}"

command -v jq >/dev/null || {
  echo "github-releases: missing required tool 'jq'" >&2
  exit 1
}
command -v curl >/dev/null || {
  echo "github-releases: missing required tool 'curl'" >&2
  exit 1
}
command -v tar >/dev/null || {
  echo "github-releases: missing required tool 'tar'" >&2
  exit 1
}

# Prefix an absolute image path with the test root (no-op at build, ROOT=/).
prefix() {
  echo "${ROOT}${1}"
}

gh_tag() { # owner/repo -> latest tag (empty when API unreachable)
  curl --silent --retry 3 "https://api.github.com/repos/${1}/releases/latest" | jq -r '.tag_name // empty' 2>/dev/null || true
}

# Expand the {tag} placeholder (bare version, no leading v).
resolve() { # template tag -> expanded
  local s="${1}" tag="${2}"
  s="${s//\{tag\}/${tag}}"
  echo "${s}"
}

install_entry() { # entry-json
  local entry="${1}"
  local repo asset dest type member strip chmod release
  repo="$(jq -r '.repo' <<<"${entry}")"
  asset="$(jq -r '.asset' <<<"${entry}")"
  dest="$(jq -r '.dest' <<<"${entry}")"
  type="$(jq -r '.type // empty' <<<"${entry}")"
  member="$(jq -r '.member // empty' <<<"${entry}")"
  strip="$(jq -r '.strip // 0' <<<"${entry}")"
  chmod="$(jq -r '.chmod // empty' <<<"${entry}")"
  release="$(jq -r '.release // false' <<<"${entry}")"

  [[ "${repo}" =~ ^[^/[:space:]]+/[^/[:space:]]+$ ]] || {
    echo "github-releases: invalid repo '${repo}' (want owner/name)" >&2
    exit 1
  }

  if [[ -z "${type}" ]]; then
    if [[ "${asset}" == *.tar.gz || "${asset}" == *.tgz ]]; then
      type="tgz"
    else
      type="bin"
    fi
  fi
  if [[ -z "${chmod}" ]]; then
    if [[ "${type}" == "bin" ]]; then chmod="true"; else chmod="false"; fi
  fi

  local tag="" url
  if [[ "${asset}" == *"{tag}"* || "${release}" == "true" ]]; then
    local full_tag
    full_tag="$(gh_tag "${repo}")"
    [[ -n "${full_tag}" ]] || {
      echo "github-releases: could not resolve latest tag for ${repo}" >&2
      exit 1
    }
    tag="${full_tag#v}"
    url="https://github.com/${repo}/releases/download/${full_tag}/$(resolve "${asset}" "${tag}")"
  else
    url="https://github.com/${repo}/releases/latest/download/${asset}"
  fi

  if [[ "${type}" == "bin" ]]; then
    mkdir -p "$(dirname "$(prefix "${dest}")")"
    curl --silent --retry 3 -L --output "$(prefix "${dest}")" "${url}"
  else
    mkdir -p "$(prefix "${dest}")"
    if [[ -n "${member}" ]]; then
      curl --silent --retry 3 -L --output - "${url}" |
        tar -xzf - --strip-components="${strip}" -C "$(prefix "${dest}")" "${member}"
      if [[ "${chmod}" == "true" ]]; then
        chmod +x "$(prefix "${dest}")/$(basename "${member}")"
      fi
    else
      curl --silent --retry 3 -L --output - "${url}" |
        tar -xzf - -C "$(prefix "${dest}")"
    fi
  fi
  if [[ "${type}" == "bin" && "${chmod}" == "true" ]]; then
    chmod +x "$(prefix "${dest}")"
  fi
  echo "github-releases: installed ${repo} -> ${dest}"

  local link target
  while IFS=$'\t' read -r link target; do
    [[ -n "${link}" ]] || continue
    mkdir -p "$(dirname "$(prefix "${link}")")"
    ln -sf "$(prefix "$(resolve "${target}" "${tag}")")" "$(prefix "${link}")"
  done < <(jq -r '.links // {} | to_entries[] | "\(.key)\t\(.value)"' <<<"${entry}")

  local furl fdest
  while IFS=$'\t' read -r furl fdest; do
    [[ -n "${furl}" ]] || continue
    mkdir -p "$(dirname "$(prefix "${fdest}")")"
    curl --silent --retry 3 -L --output "$(prefix "${fdest}")" "$(resolve "${furl}" "${tag}")"
  done < <(jq -r '.fetch // [] | .[] | "\(.url)\t\(.dest)"' <<<"${entry}")

  local dsrc
  dsrc="$(jq -r '.desktop.src // empty' <<<"${entry}")"
  if [[ -n "${dsrc}" ]]; then
    install -D "$(prefix "${dsrc}")" "$(prefix "/usr/share/applications/$(basename "${dsrc}")")"
  fi

  local line
  while IFS= read -r line; do
    [[ -n "${line}" ]] || continue
    bash -c "$(resolve "${line}" "${tag}")"
  done < <(jq -r '.post // [] | .[]' <<<"${entry}")
}

while IFS= read -r entry; do
  [[ -n "${entry}" ]] || continue
  install_entry "${entry}"
done < <(jq -c '.releases // [] | .[]' <<<"${CONFIG}")
