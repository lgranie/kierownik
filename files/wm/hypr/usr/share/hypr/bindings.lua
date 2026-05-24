-- Keybindings
-- https://wiki.hypr.land/Configuring/Basics/Binds/

local exec = hl.dsp.exec_cmd
local layout = hl.dsp.layout
local window = hl.dsp.window
local worksp = hl.dsp.workspace

-- 0. Keybind Cheatsheet
hl.bind("SUPER + slash", exec("qs -c noctalia-shell ipc call plugin:keybind-cheatsheet toggle"), { description = "Keybind Cheatsheet" })

-- Unified clipboard (Super+C/V/X works everywhere)
hl.bind("SUPER + C", exec("wl-copy"))
hl.bind("SUPER + X", function()
    hl.dispatch(exec("wl-copy"))
    hl.dispatch(window.close())
end)
hl.bind("SUPER + V", exec("wl-paste"))
hl.bind("SUPER + CTRL + V", exec("cliphist decode | wl-paste"))

-- 1. Applications
hl.bind("SUPER + RETURN", exec("footclient"), { description = "Open a Terminal: foot client" })
hl.bind("SUPER + ALT + RETURN", exec("footclient tmux"), { description = "Open a Terminal: foot client tmux" })
hl.bind("SUPER + SHIFT + RETURN", exec("foot"), { description = "Open a Terminal: foot" })
hl.bind("SUPER + SPACE", exec("qs -c noctalia-shell ipc call launcher toggle"), { description = "Run an Application: Menu" })
hl.bind("SUPER + SHIFT + SPACE", exec("footclient --title fsel fsel"), { description = "Run an Application via fsel" })
hl.bind("SUPER + B", exec("qs -c noctalia-shell ipc call plugin:bookmarks toggle"), { description = "Open Bookmark" })
hl.bind("SUPER + ALT + L", exec("swaylock"), { description = "Lock the Screen: swaylock" })

-- 2. Window Management
hl.bind("SUPER + W", window.close(), { description = "Close window" })
hl.bind("SUPER + F", window.fullscreen({ mode = 1 }), { description = "Full width" })
hl.bind("SUPER + ALT + F", window.fullscreen({ mode = 0 }), { description = "Full screen" })
hl.bind("SUPER + T", window.float({ action = "toggle" }), { description = "Toggle window floating/tiling" })
hl.bind("SUPER + CTRL + F", window.fullscreen_state({ internal = 0, client = 2, action = "toggle" }), { description = "Tiled full screen" })

-- 3. Workspace Navigation
hl.bind("SUPER + LEFT", layout("focus l"), { description = "Move window focus left" })
hl.bind("SUPER + RIGHT", layout("focus r"), { description = "Move window focus right" })
hl.bind("SUPER + SHIFT + LEFT", layout("swapcol l"), { description = "Swap window to the left" })
hl.bind("SUPER + SHIFT + RIGHT", layout("swapcol r"), { description = "Swap window to the right" })
hl.bind("SUPER + SHIFT + M", window.move({ workspace = "m+1"}), { description = "Swap window to the right" })

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind("SUPER + mouse:272", window.drag(),   { mouse = true })
hl.bind("SUPER + mouse:273", window.resize(), { mouse = true })

-- 9. Hyprland Specific
hl.bind("SUPER + R", layout("colresize +conf"))
hl.bind("SUPER + S", function()
    hl.dispatch(worksp.toggle_special("scratchpad"))
end, { description = "Toggle scratchpad" })
hl.bind("SUPER + ALT + S", window.move({ workspace = "special:scratchpad", silent = true }), { description = "Move window to scratchpad" })
