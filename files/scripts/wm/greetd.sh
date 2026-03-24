#!/usr/bin/env bash

set -euo pipefail

mkdir -p /var/cache/tuigreet
chown -R greetd:greetd /var/cache/tuigreet
mkdir -p /var/lib/greetd
chown -R greetd:greetd /var/lib/greet
