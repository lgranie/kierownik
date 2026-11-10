-- Animations preset: Playful / Bouncy (overshoot)
-- Slight overshoot on window open and workspace change.

-- Curves
hl.curve("overshoot", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.curve("bouncy",    { type = "spring", mass = 1, stiffness = 140, damping = 15 })

-- Windows
hl.animation({ leaf = "windowsIn",  enabled = true, speed = 4, spring = "bouncy", style = "popin 80%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2, bezier = "overshoot" })

-- Workspaces
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "overshoot", style = "slide" })
