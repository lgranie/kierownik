------------------
---- TABLET ----
------------------
-- SW_TABLET_MODE from the EC ("Intel Virtual Switches" in hyprctl devices).
-- On the 5290 this switch does not move when the base is unclipped; krw-tablet
-- watches the base's USB keyboard/touchpad for that. The binds stay because a
-- fold or another 2-in-1 still reports through them, and a signal that never
-- fires only costs one trigger, not the whole mode.
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
