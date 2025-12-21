#!/bin/bash

OPTIONS="\uf186  Suspend System\n\
\uf011  Power Off System\n\
\uf021  Reboot System\n\
\uf023  Lock Session\n\
\uf08b  Log Out"

CHOICE=$(echo -e "$OPTIONS" | vicinae dmenu -p 'Power Menu:' | cut -d ' ' -f3-)

# --- Execute the selected command ---
case "$CHOICE" in
"Suspend System")
  echo "Suspending system..."
  systemctl suspend
  ;;
"Power Off System")
  echo "Shutting down system..."
  systemctl poweroff
  ;;
"Reboot System")
  echo "Rebooting system..."
  systemctl reboot
  ;;
"Lock Session")
  echo "Locking session..."
  # Replace 'loginctl lock-session' with your preferred locker
  # (e.g., 'i3lock', 'kscreenlocker_command', 'betterlockscreen -l', etc.)
  loginctl lock-session
  ;;
"Log Out")
  echo "Logging out..."
  # Replace 'pkill -KILL -u "$USER"' with the proper logout command for your WM/DE.
  # e.g., 'loginctl terminate-session $XDG_SESSION_ID' for SystemD-based logouts.
  pkill -KILL -u "$USER"
  ;;
*)
  echo "Menu closed or no action selected: $CHOICE"
  ;;
esac
