#!/usr/bin/env fish

# No agent there, avoids tty/systemctl
# noise and writes under greetd's HOME. Non-interactive shells need nothing here.
status is-interactive; or return

# Env
set -gx EDITOR nvim
set -gx VISUAL nvim

# Wayland
set -gx XDG_SESSION_TYPE wayland
set -gx QT_QPA_PLATFORM wayland
set -gx QT_QPA_PLATFORMTHEME gtk3
set -gx QT_QPA_PLATFORMTHEME_QT6 gtk3
set -gx ELECTRON_OZONE_PLATFORM_HINT auto
