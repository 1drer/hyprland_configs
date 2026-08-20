-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

hl.env("XCURSOR_SIZE", "28")
hl.env("XCURSOR_THEME", "Vimix-cursors")
hl.env("HYPRCURSOR_SIZE", "28")
hl.env("HYPRCURSOR_THEME", "Vimix-cursors")
hl.env("HYPRSHOT_DIR", os.getenv("HOME") .. "/Pictures/Screenshots")

-- Nvidia --
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
