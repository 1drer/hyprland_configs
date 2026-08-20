-- curves
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("snap", { type = "bezier", points = { { 0.15, 0.85 }, { 0.25, 1 } } })
hl.curve("smoothOut", { type = "bezier", points = { { 0.2, 0.9 }, { 0.3, 1 } } })

-- global
hl.animation({ leaf = "global", enabled = true, speed = 1.2, bezier = "snap" })

-- borders (near-instant, borders shouldn't drag)
hl.animation({ leaf = "border", enabled = true, speed = 1, bezier = "snap" })

-- windows (clean open/close, no recoil)
hl.animation({ leaf = "windows", enabled = true, speed = 2.2, bezier = "snap" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 1.4, bezier = "snap" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.1, bezier = "smoothOut" })

-- fades (fast, this is what makes it feel snappy)
hl.animation({ leaf = "fadeIn", enabled = true, speed = 0.15, bezier = "snap" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 0.12, bezier = "snap" })
hl.animation({ leaf = "fade", enabled = true, speed = 0.35, bezier = "snap" })

-- layers (menus, rofi, dunst, etc — should feel immediate)
hl.animation({ leaf = "layers", enabled = true, speed = 0.3, bezier = "snap" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 0.3, bezier = "snap", style = "slide" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.2, bezier = "snap", style = "slide" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 0.1, bezier = "snap" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 0.08, bezier = "snap" })

-- workspaces (fast slide, no overshoot)
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.3, bezier = "snap", style = "slide" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 1.3, bezier = "snap", style = "slide" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.1, bezier = "snap", style = "slide" })

-- zoom
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 1.2, bezier = "snap" })
