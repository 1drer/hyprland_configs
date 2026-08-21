#!/usr/bin/env bash
# rofi + hyprshutdown power menu

theme="$HOME/.config/rofi/power-menu.rasi"

shutdown=" Shutdown"
restart=" Restart"
logout=" Log out"
#hibernate=" Hibernate"
suspend=" Suspend"
lock=" Lock"

options="$shutdown\n$restart\n$logout\n$suspend\n$lock"

chosen=$(echo -e "$options" | rofi -dmenu -p "Power" -theme "$theme")

case "$chosen" in
"$shutdown")
  hyprshutdown -t 'Shutting down...' --post-cmd 'shutdown -P 0'
  ;;
"$restart")
  hyprshutdown -t 'Restarting...' --post-cmd 'reboot'
  ;;
"$logout")
  hyprshutdown -t 'Logging out...'
  ;;
  #	"$hibernate")
  #		systemctl hibernate
  #		;;
"$suspend")
  systemctl suspend
  ;;
"$lock")
  hyprlock
  ;;
*)
  exit 0
  ;;
esac
