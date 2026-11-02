#!/usr/bin/env bash

set -euo pipefail

# Install herdr-core
core_url=$(curl --silent --show-error --fail --retry 3 --location "https://releases.herdr.dev/core/latest.json" |
  jq -er --arg component "core" '.targets["linux-x86_64"].url | select(startswith("https://releases.herdr.dev/core/"))')
curl --silent --retry 3 -L --output - "$core_url" |
  tar -xzf - -C /usr/bin/ "herdr-core"
chmod 0755 "/usr/bin/herdr-core"
ln -s /usr/bin/herdr-core /usr/bin/hc

# Install herdr-app
app_url=$(curl --silent --show-error --fail --retry 3 --location "https://releases.herdr.dev/app/latest.json" |
  jq -er --arg component "app" '.targets["linux-x86_64"].url | select(startswith("https://releases.herdr.dev/app/"))')
curl --silent --retry 3 -L --output - "$app_url" |
  tar -xzf - --strip-components=1 -C /usr/bin/ "herdr-app/herdr-app"
chmod 0755 "/usr/bin/herdr-app"
