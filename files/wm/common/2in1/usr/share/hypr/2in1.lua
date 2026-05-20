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
    fingers = 3,
    direction = "down",
    action = function()
        hl.exec_cmd("maliit-keyboard")
    end
})

hl.gesture({
    fingers = 3,
    direction = "up",
    action = function()
        hl.exec_cmd("pkill maliit-keyboard")
    end
})