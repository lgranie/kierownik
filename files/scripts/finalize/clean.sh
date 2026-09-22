#!/usr/bin/env bash
set -oue pipefail

# Clean skel
rm -rf /etc/skel/.{mozilla}*

# Clean dangling services
for dir in /etc/systemd/system /etc/systemd/user /usr/lib/systemd/system /usr/lib/systemd/user; do
  if [[ -d "$dir" ]]; then
    find "$dir" -xtype l -print -delete || true
  fi
done
