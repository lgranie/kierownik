hl.config({
	scrolling = {
		column_width = 1.0, -- Sets new windows to 100% of screen width
	},
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
})

hl.gesture({
    action = function()
        hl.exec_cmd("killall -34 wvkbd-mobintl")
    end,
    direction = "up",
    fingers = 3,
    workspace_swipe_touch = true
})