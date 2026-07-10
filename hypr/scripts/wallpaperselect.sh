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

# 1. Write the absolute path to a file that QML can read
echo "$CHOICE" > "$HOME/.current_wall_path"
ln -sf "$CHOICE" "$HOME/.current.wall"

# 2. Trigger the animation in QML instantly
hyprctl dispatch global quickshell:updateWallpaper

# 3. Push the heavy UI/Color tasks to the background. 
# We add a 1-second sleep so the crossfade finishes BEFORE your system reloads its colors.
(
  matugen --source-color-index 0 image "$CHOICE" -t scheme-content
  sh "$HOME/.config/hypr/scripts/colors_mqtt.sh"
) & disown


