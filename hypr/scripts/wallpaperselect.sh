#!/bin/bash
pkill -x vicinae 2>/dev/null

WALL_DIR="$HOME/Pictures/Wallpapers"

CURRENT=$(basename "$(readlink "$HOME/.current.wall" 2>/dev/null)")

CHOICE=$(
  (
    find "$WALL_DIR" -name ".git" -prune -o -type f -print | shuf -n 1
    find "$WALL_DIR" -name ".git" -prune -o -type f -print
  ) | vicinae dmenu -p "Pick a wallpaper..." -n "Current: $CURRENT"
)

[ -z "$CHOICE" ] && exit 0

matugen --source-color-index 0 image "$CHOICE" -t scheme-content
pkill waybar && waybar
ln -sf "$CHOICE" "$HOME/.current.wall"
sh "$HOME/.config/hypr/scripts/colors_mqtt.sh"

