#!/usr/bin/env bash

set -euo pipefail

ZED_URL=$(/tmp/files/scripts/common/fetch_gh_latest_tag "zed-industries/zed" "zed-linux-x86_64.tar.gz")
curl --silent --retry 3 -L --output - "${ZED_URL}" |
  tar -xzf - -C /usr/lib/opt/

# Link binary
ln -sf /usr/lib/opt/zed.app/bin/zed /usr/bin/zed

# Install .desktop
install -D /usr/lib/opt/zed.app/share/applications/dev.zed.Zed.desktop -t /usr/share/applications
sed -i "s|Icon=zed|Icon=/usr/lib/opt/zed.app/share/icons/hicolor/512x512/apps/zed.png|g" /usr/share/applications/dev.zed.Zed.desktop
sed -i "s|Exec=zed|Exec=/usr/lib/opt/zed.app/bin/zed|g" /usr/share/applications/dev.zed.Zed.desktop
