#!/usr/bin/env bash
# ~/.config/hypr/scripts/idle-check.sh
# Guards hypridle listeners — skips the command if:
#   1. A fullscreen window is active on the current workspace
#   2. Any media is currently playing (catches windowed YouTube on Zen/Firefox)

# Check fullscreen
hyprctl activeworkspace -j | jq -e '.hasfullscreen' >/dev/null 2>&1 && exit 0

# Check playing media via MPRIS (playerctl)
playerctl status 2>/dev/null | grep -q "Playing" && exit 0

# All clear — run the actual command
exec "$@"
