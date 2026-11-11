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
