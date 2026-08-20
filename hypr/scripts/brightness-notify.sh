#!/bin/bash
LEVEL=$(brightnessctl get)
MAX=$(brightnessctl max)
PCT=$((LEVEL * 100 / MAX))

if [[ "$PCT" -ge 67 ]]; then
  ICON="󰃠"
elif [[ "$PCT" -ge 34 ]]; then
  ICON="󰃟"
else
  ICON="󰃞"
fi

notify-send -a "dunst" -h string:x-dunst-stack-tag:brightness \
  -h int:value:"$PCT" \
  "Brightness $ICON" "${PCT}%"
