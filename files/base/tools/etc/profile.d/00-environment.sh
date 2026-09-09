# bash twin of conf.d/00-environment.fish (sourced from /etc/profile.d)
# shellcheck shell=bash

# Env
export EDITOR=nvim
export VISUAL=nvim

# Wayland
export XDG_SESSION_TYPE=wayland
export QT_QPA_PLATFORM=wayland
export QT_QPA_PLATFORMTHEME=gtk3
export QT_QPA_PLATFORMTHEME_QT6=gtk3
export ELECTRON_OZONE_PLATFORM_HINT=auto
