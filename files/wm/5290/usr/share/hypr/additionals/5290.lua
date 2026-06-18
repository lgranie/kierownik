hl.config({
	input = {
		touchpad = {
			natural_scroll = true,
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

-- hl.gesture({
--     action = function()
--         hl.exec_cmd("killall -34 wvkbd-mobintl")
--     end,
--     direction = "up",
--     fingers = 2
-- })

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

