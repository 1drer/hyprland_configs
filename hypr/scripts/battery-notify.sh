#!/usr/bin/env bash

# Configuration
LOW_THRESHOLD=20
CRIT_THRESHOLD=10
SLEEP_INTERVAL=30 # Check every 30 seconds for better responsiveness at low percentages

# 1. Auto-detect battery path (handles BAT0, BAT1, etc. automatically)
BAT_PATH=$(find /sys/class/power_supply/ -name "BAT*" -print -quit)
if [[ -z "$BAT_PATH" ]]; then
  echo "No battery found!" >&2
  exit 1
fi

# Track what state we last alerted the user about
# Choices: "none", "low", "critical"
LAST_STATE="none"

while true; do
  # 2. Prevent script crash if battery is temporarily registering weirdly
  if [[ -f "$BAT_PATH/capacity" && -f "$BAT_PATH/status" ]]; then
    LEVEL=$(cat "$BAT_PATH/capacity")
    STATUS=$(cat "$BAT_PATH/status")
  else
    sleep "$SLEEP_INTERVAL"
    continue
  fi

  # 3. Dynamic logic based on state tracking
  if [[ "$STATUS" == "Discharging" ]]; then

    # CRITICAL ZONE
    if [[ "$LEVEL" -le "$CRIT_THRESHOLD" && "$LAST_STATE" != "critical" ]]; then
      notify-send -u critical \
        -h string:x-dunst-stack-tag:battery \
        "󰂃 CRITICAL Battery" "${LEVEL}% remaining — PLUG IN NOW!"
      LAST_STATE="critical"

    # LOW ZONE
    elif [[ "$LEVEL" -le "$LOW_THRESHOLD" && "$LEVEL" -gt "$CRIT_THRESHOLD" && "$LAST_STATE" != "low" ]]; then
      notify-send -u normal \
        -h string:x-dunst-stack-tag:battery \
        "󰁻 Low Battery" "${LEVEL}% remaining — plug in soon."
      LAST_STATE="low"
    fi

  elif [[ "$STATUS" == "Charging" || "$STATUS" == "Full" ]]; then
    # 4. Smart reset: Reset tracking state when power is connected
    LAST_STATE="none"
  fi

  sleep "$SLEEP_INTERVAL"
done
