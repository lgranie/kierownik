-- Animations preset: Material 3 (Android style, clean & precise)
-- Material 3 decel curves. Crisp, fast, no spring.

-- Curves
hl.curve("md3_decel",  { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1.0 } } })
hl.curve("md3_accel",  { type = "bezier", points = { { 0.3, 0 }, { 0.8, 0.15 } } })
hl.curve("menu_decel", { type = "bezier", points = { { 0.1, 1 }, { 0, 1 } } })

-- Windows & Workspaces
hl.animation({ leaf = "windows",    enabled = true, speed = 3, bezier = "md3_decel", style = "popin 80%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2, bezier = "md3_accel", style = "popin 80%" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 3.5, bezier = "md3_decel", style = "slidefade 15%" })

-- Fade & Layers
hl.animation({ leaf = "fade",   enabled = true, speed = 2, bezier = "menu_decel" })
hl.animation({ leaf = "layers", enabled = true, speed = 2.5, bezier = "md3_decel" })
