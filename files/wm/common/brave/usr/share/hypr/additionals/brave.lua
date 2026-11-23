---------------------------
---- BRAVE WINDOW RULES ----
---------------------------

-- Brave file dialogs
hl.window_rule({
	name = "brave-dialogs",
	match = {
		class = "^Brave.*$",
		modal = true,
	},
	float = true,
	center = true,
})
