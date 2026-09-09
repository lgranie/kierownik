#!/usr/bin/env bash

set -euo pipefail

VOXTYPE_TAG=$(/tmp/files/scripts/common/fetch_gh_latest_tag "peteonrails/voxtype")
VOXTYPE_VER=${VOXTYPE_TAG:1}

# curl --silent --retry 3 -L --output /usr/bin/voxtype https://github.com/peteonrails/voxtype/releases/latest/download/voxtype-${VOXTYPE_VER}-linux-x86_64-vulkan
curl --silent --retry 3 -L --output /usr/bin/voxtype "https://github.com/peteonrails/voxtype/releases/download/${VOXTYPE_TAG}/voxtype-${VOXTYPE_VER}-linux-x86_64-vulkan"
chmod +x /usr/bin/voxtype

# OSD ( depends on gtk4-layer-shell )
# curl --silent --retry 3 -L --output /usr/bin/voxtype-osd https://github.com/peteonrails/voxtype/releases/latest/download/voxtype-${VOXTYPE_VER}-linux-x86_64-osd
# chmod +x /usr/bin/voxtype-osd
# curl --silent --retry 3 -L --output /usr/bin/voxtype-osd-gtk4 https://github.com/peteonrails/voxtype/releases/latest/download/voxtype-${VOXTYPE_VER}-linux-x86_64-osd-gtk4
# chmod +x /usr/bin/voxtype-osd-gtk4

# voxtype setup gpu --enable --backend vulkan

# Shell completions (upstream ships bash/fish/zsh under packaging/completions)
mkdir -p /usr/share/bash-completion/completions
curl --silent --retry 3 -L \
  --output /usr/share/bash-completion/completions/voxtype \
  https://raw.githubusercontent.com/peteonrails/voxtype/main/packaging/completions/voxtype.bash
curl --silent --retry 3 -L \
  --output /etc/fish/completions/voxtype.fish \
  https://raw.githubusercontent.com/peteonrails/voxtype/main/packaging/completions/voxtype.fish
