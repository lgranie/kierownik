hl.config({
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
