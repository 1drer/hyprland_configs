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
-- Layer-shell surfaces manifest "from thin air" (fade + popin). Enabled
-- globally, but every quickshell surface shares the namespace
-- "quickshell" (bar, control center, tray menu, theme switcher, power
-- menu) and is pinned to no-anim below — the power menu's own manifest
-- is done in PowerMenu.qml. This leaves the animation for non-quickshell
-- layers such as dunst's "notifications" surface.
hl.animation({ leaf = "layers", enabled = true, speed = 1, bezier = "md3_decel" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 1, bezier = "md3_decel", style = "popin" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1, bezier = "md3_decel", style = "popin" })
hl.animation({ leaf = "fadeLayers", enabled = true, speed = 1, bezier = "md3_decel" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1, bezier = "md3_decel" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1, bezier = "md3_decel" })

hl.layer_rule({
    name = "no-anim-quickshell-layers",
    match = { namespace = "^quickshell$" },
    no_anim = true,
})

-- FOR HORIZONTAL FAST:
hl.animation({ leaf = "workspaces", enabled = true, speed = 2.5, bezier = "md3_decel", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2.5, bezier = "md3_decel", style = "slidevert" })

-- FOR VERTICAL FAST (Replace the two lines above with these):
-- hl.animation({ leaf = "workspaces", enabled = true, speed = 2.5, bezier = "md3_decel", style = "slidevert" })
-- hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2.5, bezier = "md3_decel", style = "slide" })
