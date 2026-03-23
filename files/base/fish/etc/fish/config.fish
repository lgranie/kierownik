#!/usr/bin/env fish

# Env
set -gx EDITOR nvim
set -gx VISUAL nvim

# Remove greeting
set -U fish_greeting ""

# Activate tools
fzf --fish | source
mise activate fish | source
zoxide init --cmd cd fish | source
