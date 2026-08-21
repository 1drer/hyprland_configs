#!/usr/bin/env bash
#
# rofi-wifi-menu.sh
# A simple rofi-based Wi-Fi connection menu for NetworkManager.
#
# Requires: nmcli, rofi
#
# Usage: bind this script to your Waybar "network" module's on-click,
#        or to a Hyprland keybind.
THEME="$HOME/.config/rofi/wifi.rasi"
# Rescan for networks (non-blocking-ish, gives nmcli a moment to refresh)
nmcli device wifi rescan >/dev/null 2>&1
sleep 1
# Get current connection name (if any) so we can mark it
current_ssid=$(nmcli -t -f active,ssid dev wifi | awk -F: '$1=="yes"{print $2}')
# Build the network list: SSID, signal %, security
# -t = terse/colon-separated, easy to parse
# We sort by signal strength descending, dedupe by SSID (keep strongest)
mapfile -t networks < <(
  nmcli -t -f SSID,SIGNAL,SECURITY device wifi list |
    awk -F':' '!seen[$1]++' |
    sort -t':' -k2 -n -r
)
menu=""
for line in "${networks[@]}"; do
  ssid="${line%%:*}"
  rest="${line#*:}"
  signal="${rest%%:*}"
  security="${rest#*:}"
  [[ -z "$ssid" ]] && continue
  lock=""
  if [[ -n "$security" && "$security" != "--" ]]; then
    lock=" "
  fi
  marker=""
  if [[ "$ssid" == "$current_ssid" ]]; then
    marker="✓ "
  fi
  menu+="${marker}${ssid} : ${signal}%${lock}\n"
done
# Add utility entries
menu+="\nRescan\nManage Connections"
chosen=$(echo -e "$menu" | rofi -dmenu -i -p "Wi-Fi" -theme "$THEME")
[[ -z "$chosen" ]] && exit 0
if [[ "$chosen" == "Rescan" ]]; then
  nmcli device wifi rescan
  exec "$0"
  exit 0
fi
if [[ "$chosen" == "Manage Connections" ]]; then
  nm-connection-editor &
  exit 0
fi
# Strip the marker and signal/lock suffix to recover the SSID
ssid=$(echo "$chosen" | sed -E 's/^✓ //' | sed -E 's/ : [0-9]+%( )?$//')
# If it's already a saved connection, just bring it up
if nmcli -t -f NAME connection show | grep -Fxq "$ssid"; then
  nmcli connection up "$ssid" ||
    notify-send "Wi-Fi" "Failed to connect to $ssid"
else
  # New network — check if it needs a password
  security=$(nmcli -t -f SSID,SECURITY device wifi list | awk -F':' -v s="$ssid" '$1==s{print $2; exit}')
  if [[ -n "$security" && "$security" != "--" ]]; then
    password=$(rofi -dmenu -password -p "Password for $ssid" -theme "$THEME")
    [[ -z "$password" ]] && exit 0
    nmcli device wifi connect "$ssid" password "$password" ||
      notify-send "Wi-Fi" "Failed to connect to $ssid"
  else
    nmcli device wifi connect "$ssid" ||
      notify-send "Wi-Fi" "Failed to connect to $ssid"
  fi
fi

is there a way to make it so that the saved networks are indicated in some way
