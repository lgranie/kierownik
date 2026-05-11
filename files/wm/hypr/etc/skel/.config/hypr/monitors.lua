------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
hl.monitor({
	output = "eDP-1",
	mode = "preferred",
	position = "auto",
	scale = "1.25",
})

hl.monitor({
	output = "DP-2",
	mode = "preferred",
	position = "1920x0",
	scale = "1.33",
	transform = 2,
})
