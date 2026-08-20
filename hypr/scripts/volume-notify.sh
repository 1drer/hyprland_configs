#!/bin/bash
VOL=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)
MUTED=$(echo "$VOL" | grep -c MUTED)
LEVEL=$(echo "$VOL" | awk '{print int($2*100)}')

if [[ "$MUTED" -gt 0 ]]; then
  ICON="󰝟"
  MSG="Muted"
elif [[ "$LEVEL" -ge 67 ]]; then
  ICON="󰕾"
  MSG="${LEVEL}%"
elif [[ "$LEVEL" -ge 34 ]]; then
  ICON="󰖀"
  MSG="${LEVEL}%"
else
  ICON="󰕿"
  MSG="${LEVEL}%"
fi

notify-send -a "dunst" -h string:x-dunst-stack-tag:volume \
  -h int:value:"$LEVEL" \
  "Volume $ICON" "$MSG"
