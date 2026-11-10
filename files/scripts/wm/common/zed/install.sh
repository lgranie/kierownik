#!/usr/bin/env bash

set -euo pipefail

ZED_URL=$(/tmp/files/scripts/common/fetch_gh_latest_tag "zed-industries/zed" "zed-linux-x86_64.tar.gz" --no-pre)
curl --silent --retry 3 -L --output - "${ZED_URL}" |
  tar -xzf - -C /usr/lib/opt/

# Detect extracted app dir (zed.app / zed-preview.app / …)
ZED_APP_DIR=$(find /usr/lib/opt -maxdepth 1 -mindepth 1 -name 'zed*.app' -type d | head -n 1)
[[ -n "${ZED_APP_DIR}" ]] || { echo "zed: no zed*.app dir found under /usr/lib/opt" >&2; exit 1; }

# Link binary
ln -sf "${ZED_APP_DIR}/bin/zed" /usr/bin/zed

# Install .desktop file(s) shipped with the app
for desktop in "${ZED_APP_DIR}"/share/applications/*.desktop; do
  [[ -e "${desktop}" ]] || continue
  install -D "${desktop}" -t /usr/share/applications
  name=$(basename "${desktop}")
  sed -i "s|Icon=zed|Icon=${ZED_APP_DIR}/share/icons/hicolor/512x512/apps/zed.png|g" "/usr/share/applications/${name}"
  sed -i "s|Exec=zed|Exec=${ZED_APP_DIR}/bin/zed|g" "/usr/share/applications/${name}"
done