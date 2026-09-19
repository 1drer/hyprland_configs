-- -----------------------------------------------------
-- FAST PRESET: High Performance / Low Latency
-- -----------------------------------------------------

hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("md3_decel", { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1 } } })
hl.curve("instant", { type = "bezier", points = { { 0, 1 }, { 0, 1 } } })

hl.animation({ leaf = "windows", enabled = true, speed = 2, bezier = "md3_decel", style = "slide" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 2, bezier = "md3_decel", style = "slide" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2, bezier = "md3_decel", style = "slide" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 2, bezier = "md3_decel", style = "slide" })

hl.animation({ leaf = "border", enabled = true, speed = 1, bezier = "linear" })
hl.animation({ leaf = "fade", enabled = true, speed = 2, bezier = "md3_decel" })
-- Layer-shell surfaces (quickshell power menu, bars, popups) should
-- appear and disappear instantly, no slide or fade.
hl.animation({ leaf = "layers", enabled = false, speed = 0 })
hl.animation({ leaf = "layersIn", enabled = false, speed = 0 })
hl.animation({ leaf = "layersOut", enabled = false, speed = 0 })
hl.animation({ leaf = "fadeLayers", enabled = false, speed = 0 })
hl.animation({ leaf = "fadeLayersIn", enabled = false, speed = 0 })
hl.animation({ leaf = "fadeLayersOut", enabled = false, speed = 0 })

-- FOR HORIZONTAL FAST:
hl.animation({ leaf = "workspaces", enabled = true, speed = 2.5, bezier = "md3_decel", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2.5, bezier = "md3_decel", style = "slidevert" })

-- FOR VERTICAL FAST (Replace the two lines above with these):
-- hl.animation({ leaf = "workspaces", enabled = true, speed = 2.5, bezier = "md3_decel", style = "slidevert" })
-- hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2.5, bezier = "md3_decel", style = "slide" })
