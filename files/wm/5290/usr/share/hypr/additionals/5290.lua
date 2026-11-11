hl.config({
	input = {
		touchpad = {
			natural_scroll = true,
			tap_to_click = true,
			drag_lock = true,
        },

		touchdevice = {
			output = "eDP-1",
			transform = 0,
		},

		tablet = {
			output = "eDP-1",
			transform = 0,
		},
	},

	scrolling = {
		column_width = 1.0, -- Sets new windows to 100% of screen width
	},
})

hl.gesture({
    action = "workspace",
    direction = "horizontal",
    fingers = 3,
})

------------------
---- MONITORS ----
------------------
-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
hl.monitor({
	output = "eDP-1",
	mode = "preferred",
	position = "auto",
	scale = "1.33",
})

hl.monitor({
	output = "DP-1",
	mode = "preferred",
	position = "1920x0",
	scale = "1.33",
	transform = 2,
})

------------------
---- TABLET ----
------------------
-- SW_TABLET_MODE from the EC ("Intel Virtual Switches" in hyprctl devices).
-- krw-tablet also polls the keyboard base, so a bind that never fires on some
-- build only costs one signal, not the whole mode.
pcall(function()
	hl.bind("switch:on:Intel Virtual Switches", function()
		hl.exec_cmd("/usr/bin/krw-tablet switch on")
	end, { locked = true })
	hl.bind("switch:off:Intel Virtual Switches", function()
		hl.exec_cmd("/usr/bin/krw-tablet switch off")
	end, { locked = true })
end)

------------------
---- ROTATION ----
------------------
-- Written by krw-tablet while the panel is turned (accelerometer, or a manual
-- `krw-tablet rotate`). Loaded last so it overrides the monitor rule above and
-- survives `hyprctl reload`; absent while the panel is upright.
local tablet_rotation = os.getenv("HOME") and (os.getenv("HOME") .. "/.local/state/kierownik/tablet/rotation.lua")
if tablet_rotation then
	pcall(dofile, tablet_rotation)
end
