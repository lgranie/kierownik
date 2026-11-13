#!/usr/bin/env bash

set -euo pipefail

# Install tar.gz github latest releases
declare -A tgz_bins=(
  ["usage"]=https://github.com/jdx/usage/releases/latest/download/usage-x86_64-unknown-linux-gnu.tar.gz
  # tomlq archive contains binary named "tq"
  ["tomlq"]=https://github.com/cryptaliagy/tomlq/releases/latest/download/tomlq.amd64.tgz
)
for bin in "${!tgz_bins[@]}"; do
  if [[ "$bin" == "tomlq" ]]; then
    # Archive contains binary named "tq", extract and rename
    curl --silent --retry 3 -L --output - "${tgz_bins[$bin]}" | tar -xzf - -C /usr/bin/ tq
    chmod +x /usr/bin/tq
  else
    curl --silent --retry 3 -L --output - "${tgz_bins[$bin]}" | tar -xzf - -C /usr/bin/ "${bin}"
    chmod +x "/usr/bin/${bin}"
  fi
done

# Install binaries github releases
declare -A bins=(
  # ["bluetui"]=https://github.com/pythops/bluetui/releases/latest/download/bluetui-x86_64-linux-musl
  ["herdr"]=https://github.com/herdrdev/herdr/releases/latest/download/herdr-linux-x86_64
  ["cliamp"]=https://github.com/bjarneo/cliamp/releases/latest/download/cliamp-linux-amd64
  ["systemd-manager-tui"]=https://github.com/matheus-git/systemd-manager-tui/releases/latest/download/systemd-manager-tui
  # ["impala"]=https://github.com/pythops/impala/releases/latest/download/impala-x86_64-unknown-linux-musl
)
for bin in "${!bins[@]}"; do
  curl --silent --retry 3 -L --output "/usr/bin/${bin}" "${bins[$bin]}"
  chmod +x "/usr/bin/${bin}"
done

# Install lazygit
LAZYGIT_URL=$(/tmp/files/scripts/common/fetch_gh_latest_tag "jesseduffield/lazygit" "linux_x86_64.tar.gz")
if [[ -n "$LAZYGIT_URL" ]]; then
  curl --silent --retry 3 -L --output - "${LAZYGIT_URL}" |
    tar -xzf - -C /usr/bin/ lazygit
fi

# Install mise
MISE_URL=$(/tmp/files/scripts/common/fetch_gh_latest_tag "jdx/mise" "linux-x64.tar.gz")
if [[ -n "$MISE_URL" ]]; then
  curl --silent --retry 3 -L --output - "${MISE_URL}" |
    tar -xzf - --strip-components=2 \
      -C /usr/bin/ mise/bin/mise
fi

# Install Flyline
FLYLINE_URL=$(/tmp/files/scripts/common/fetch_gh_latest_tag "HalFrgrd/flyline" "x86_64-unknown-linux-gnu.tar.gz")
if [[ -n "$FLYLINE_URL" ]]; then
  FLYLINE_TAG="$(basename "${FLYLINE_URL}" | sed -E 's/libflyline-(v[0-9.]+)-x86_64.*/\1/')"
  curl --silent --retry 3 -L --output - "${FLYLINE_URL}" |
    tar -xzf - -C /usr/lib64/
  ln -sf "/usr/lib64/libflyline.so.${FLYLINE_TAG#v}" /usr/lib64/libflyline.so
fi

# Install flycomp (flyline completion synthesis)
FLYCOMP_URL=$(/tmp/files/scripts/common/fetch_gh_latest_tag "HalFrgrd/flycomp" "x86_64-unknown-linux-gnu.tar.gz")
if [[ -n "$FLYCOMP_URL" ]]; then
  curl --silent --retry 3 -L --output - "${FLYCOMP_URL}" |
    tar -xzf - -C /usr/bin/ flycomp
fi
