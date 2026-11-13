#!/usr/bin/env bash

set -euo pipefail

VOXTYPE_URL=$(/tmp/files/scripts/common/fetch_gh_latest_tag "peteonrails/voxtype" "linux-x86_64-vulkan")

# curl --silent --retry 3 -L --output /usr/bin/voxtype https://github.com/peteonrails/voxtype/releases/latest/download/voxtype-${VOXTYPE_VER}-linux-x86_64-vulkan
curl --silent --retry 3 -L --output /usr/bin/voxtype "${VOXTYPE_URL}"
chmod +x /usr/bin/voxtype

# OSD ( depends on gtk4-layer-shell )
# curl --silent --retry 3 -L --output /usr/bin/voxtype-osd https://github.com/peteonrails/voxtype/releases/latest/download/voxtype-${VOXTYPE_VER}-linux-x86_64-osd
# chmod +x /usr/bin/voxtype-osd
# curl --silent --retry 3 -L --output /usr/bin/voxtype-osd-gtk4 https://github.com/peteonrails/voxtype/releases/latest/download/voxtype-${VOXTYPE_VER}-linux-x86_64-osd-gtk4
# chmod +x /usr/bin/voxtype-osd-gtk4

# voxtype setup gpu --enable --backend vulkan

# Shell completion (upstream ships bash under packaging/completions)
mkdir -p /usr/share/bash-completion/completions
curl --silent --retry 3 -L \
  --output /usr/share/bash-completion/completions/voxtype \
  https://raw.githubusercontent.com/peteonrails/voxtype/main/packaging/completions/voxtype.bash
