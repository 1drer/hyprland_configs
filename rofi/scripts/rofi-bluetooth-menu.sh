#!/usr/bin/env bash
#
# rofi-bluetooth-menu.sh
# A simple rofi-based Bluetooth menu for BlueZ (bluetoothctl).
#
# Requires: bluetoothctl, rofi
#
# Usage: bind this script to your Waybar "bluetooth" module's on-click,
#        or to a Hyprland keybind.

THEME="$HOME/.config/rofi/wifi.rasi"

power_status=$(bluetoothctl show | awk '/Powered:/{print $2}')

# If Bluetooth is off, offer to turn it on and stop here
if [[ "$power_status" == "no" ]]; then
    chosen=$(echo -e "Bluetooth is off\nTurn on Bluetooth" | rofi -dmenu -i -p "Bluetooth" -theme "$THEME")
    if [[ "$chosen" == "Turn on Bluetooth" ]]; then
        bluetoothctl power on
        notify-send "Bluetooth" "Powered on"
    fi
    exit 0
fi

# Get paired devices with connection state
# bluetoothctl devices gives: Device <MAC> <Name>
mapfile -t devices < <(bluetoothctl devices)

menu=""
declare -A mac_for_name

for line in "${devices[@]}"; do
    mac=$(echo "$line" | awk '{print $2}')
    name=$(echo "$line" | cut -d' ' -f3-)

    [[ -z "$mac" ]] && continue

    info=$(bluetoothctl info "$mac")
    connected=$(echo "$info" | awk '/Connected:/{print $2}')
    paired=$(echo "$info" | awk '/Paired:/{print $2}')

    marker=""
    if [[ "$connected" == "yes" ]]; then
        marker="✓ "
    elif [[ "$paired" == "yes" ]]; then
        marker=" "
    fi

    menu+="${marker}${name}\n"
    mac_for_name["${marker}${name}"]="$mac"
done

menu+="\nScan for devices\nTurn off Bluetooth"

chosen=$(echo -e "$menu" | rofi -dmenu -i -p "Bluetooth" -theme "$THEME")

[[ -z "$chosen" ]] && exit 0

if [[ "$chosen" == "Scan for devices" ]]; then
    notify-send "Bluetooth" "Scanning for 8 seconds..."
    bluetoothctl --timeout 8 scan on
    exec "$0"
    exit 0
fi

if [[ "$chosen" == "Turn off Bluetooth" ]]; then
    bluetoothctl power off
    notify-send "Bluetooth" "Powered off"
    exit 0
fi

mac="${mac_for_name[$chosen]}"

if [[ -z "$mac" ]]; then
    notify-send "Bluetooth" "Could not resolve device"
    exit 1
fi

info=$(bluetoothctl info "$mac")
connected=$(echo "$info" | awk '/Connected:/{print $2}')
paired=$(echo "$info" | awk '/Paired:/{print $2}')

if [[ "$connected" == "yes" ]]; then
    # Already connected -> offer disconnect
    action=$(echo -e "Disconnect\nRemove device" | rofi -dmenu -i -p "$chosen" -theme "$THEME")
    case "$action" in
        "Disconnect")
            bluetoothctl disconnect "$mac"
            notify-send "Bluetooth" "Disconnected"
            ;;
        "Remove device")
            bluetoothctl remove "$mac"
            notify-send "Bluetooth" "Device removed"
            ;;
    esac
elif [[ "$paired" == "yes" ]]; then
    bluetoothctl connect "$mac" && \
        notify-send "Bluetooth" "Connected" || \
        notify-send "Bluetooth" "Failed to connect"
else
    # Not paired yet
    bluetoothctl pair "$mac" && bluetoothctl trust "$mac" && bluetoothctl connect "$mac" && \
        notify-send "Bluetooth" "Paired and connected" || \
        notify-send "Bluetooth" "Failed to pair"
fi
