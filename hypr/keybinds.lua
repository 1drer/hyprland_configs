local terminal = "kitty"
local fileManager = "nautilus"
local menu = "rofi -show drun"
local browser = "zen-browser"
local mod = "SUPER"

hl.bind(mod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mod .. " + C", hl.dsp.window.close())
hl.bind(mod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(mod .. " + SHIFT + B", hl.dsp.exec_cmd("zen-browser --private-window"))
hl.bind(mod .. " + R", hl.dsp.exec_cmd(menu))
hl.bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }))
--hl.bind(mod .. " + V", function()
--	hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
--	hl.dispatch(hl.dsp.window.resize({ x = 800, y = 800 }))
--end)
hl.bind(mod .. " + P", hl.dsp.window.pseudo())
hl.bind(mod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mod .. " + L", hl.dsp.exec_cmd("~/.local/bin/hyprlock-awww"))

-- Screenshot
local ts = "Screenshot-$(date +%Y-%m-%d_%H%M%S).png"
hl.bind("PRINT", hl.dsp.exec_cmd("hyprshot -m output -f Screenshot-$(date +%Y-%m-%d_%H%M%S).png"))
hl.bind(mod .. " + PRINT", hl.dsp.exec_cmd("hyprshot -m region -f Screenshot-$(date +%Y-%m-%d_%H%M%S).png"))
hl.bind("ALT + PRINT", hl.dsp.exec_cmd("hyprshot -m window -f Screenshot-$(date +%Y-%m-%d_%H%M%S).png"))

-- Clipboard
hl.bind(
	mod .. "+ SHIFT + V",
	hl.dsp.exec_cmd([[
  sel=$(cliphist list | (echo "Clear History"; cat) | rofi -dmenu)
  if [ "$sel" = "Clear History" ]; then
    cliphist wipe && notify-send "Clipboard" "History cleared"
  else
    echo "$sel" | cliphist decode | wl-copy
  fi
]])
)
-- Focus
hl.bind(mod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + down", hl.dsp.focus({ direction = "down" }))

-- Move active window inside the layout (Tiling Position)
hl.bind(mod .. " + SHIFT + left", hl.dsp.window.move({ direction = "left" }))
hl.bind(mod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mod .. " + SHIFT + up", hl.dsp.window.move({ direction = "up" }))
hl.bind(mod .. " + SHIFT + down", hl.dsp.window.move({ direction = "down" }))

-- rofi power menu (Lock / Logout / Suspend / Hibernate / Reboot / Shutdown)
hl.bind(mod .. " + SHIFT + M", hl.dsp.exec_cmd("~/.config/rofi/scripts/power-menu.sh"))

-- wallpaper menu
hl.bind(mod .. " + SHIFT + W", hl.dsp.exec_cmd("qs ipc call wallpaper toggle"))
hl.bind(mod .. " + SHIFT + T", hl.dsp.exec_cmd("qs ipc call theme toggle"))

-- Reload
--hl.bind("SUPER + W", hl.dsp.exec_cmd("pkill quickshell"))

-- Trackpad Gesture
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- Workspaces
for i = 1, 10 do
	local key = i % 10
	hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = i }))
	hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Scroll workspaces
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize with mouse
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Scratchpad
hl.bind(mod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Volume
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+ && ~/.config/hypr/scripts/volume-notify.sh"),
	{ locked = true, repeating = true }
)

hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- && ~/.config/hypr/scripts/volume-notify.sh"),
	{ locked = true, repeating = true }
)

hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle && ~/.config/hypr/scripts/volume-notify.sh"),
	{ locked = true }
)

hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })

-- Brightness
hl.bind(
	"XF86MonBrightnessUp",
	hl.dsp.exec_cmd("brightnessctl -e2 -n2 set 5%+ && ~/.config/hypr/scripts/brightness-notify.sh"),
	{ locked = true, repeating = true }
)

hl.bind(
	"XF86MonBrightnessDown",
	hl.dsp.exec_cmd("brightnessctl -e2 -n2 set 5%- && ~/.config/hypr/scripts/brightness-notify.sh"),
	{ locked = true, repeating = true }
)

-- Requires playerctl
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
