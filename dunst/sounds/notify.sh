#!/bin/bash

# Silence volume, brightness and low urgency
[[ "$DUNST_SUMMARY" == Volume* ]] && exit 0
[[ "$DUNST_SUMMARY" == Brightness* ]] && exit 0
[[ "$DUNST_URGENCY" == "LOW" ]] && exit 0

# Critical = warning sound
if [[ "$DUNST_URGENCY" == "CRITICAL" ]]; then
  paplay /usr/share/sounds/freedesktop/stereo/dialog-warning.oga
  exit 0
fi

# Everything else = normal sound
paplay /usr/share/sounds/freedesktop/stereo/message.oga
