-- Animations preset: Smooth & Responsive Spring (Apple-like)
-- Springs for windows, slidefade for workspaces. Fast, smooth, no harsh stops.

-- Curves
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("quick",        { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })
hl.curve("smoothSpring", { type = "spring", mass = 1, stiffness = 180, damping = 22 })

-- Windows
hl.animation({ leaf = "windows",     enabled = true, speed = 4, spring = "smoothSpring" })
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 4, spring = "smoothSpring", style = "popin 85%" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 2, bezier = "quick", style = "popin 85%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 3, spring = "smoothSpring" })

-- Workspaces (slide + subtle fade)
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "easeOutQuint", style = "slidefade 20%" })

-- Fade & Layers
hl.animation({ leaf = "fade",   enabled = true, speed = 2, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 3, bezier = "easeOutQuint", style = "popin 80%" })
