#!/bin/bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# Script for changing blurs on the fly

notif="$HOME/.config/swaync/images/bell.png"

STATE=$(hyprctl -j getoption decoration:blur:enabled | jq ".int")

if [ "${STATE}" == "1" ]; then
  hyprctl keyword decoration:blur:enabled 0
  notify-send -e -u critical -i "$notif" "No blur"
else
  hyprctl keyword decoration:blur:enabled 1
  notify-send -e -u critical -i "$notif" "Normal blur"
fi
