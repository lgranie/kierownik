---------------------------
---- BRAVE WINDOW RULES ----
---------------------------

-- Brave file dialogs
hl.window_rule({
	name = "brave-dialogs",
	match = {
		class = "^brave-.*-Default$"
	},
	float = true,
	center = true,
})
