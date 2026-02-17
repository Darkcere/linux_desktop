#!/usr/bin/env bash

# --- Configuration ---

# Path to the helper scripts, as specified
SCRIPTS_DIR="/home/duarte/.config/Ax-Shell/scripts"

SCREENSHOT_SCRIPT="$SCRIPTS_DIR/screenshot.sh"
POMODORO_SCRIPT="$SCRIPTS_DIR/pomodoro.sh"
OCR_SCRIPT="$SCRIPTS_DIR/ocr.sh"
GAMEMODE_SCRIPT="$SCRIPTS_DIR/gamemode.sh"
SCREENRECORD_SCRIPT="$SCRIPTS_DIR/screenrecord.sh"
HYPRPICKER_SCRIPT="$SCRIPTS_DIR/hyprpicker.sh"

# Define your dmenu/rofi command
DMENU_CMD="vicinae dmenu"

# --- Functions ---

# Helper function to check if a process is running
is_running() {
  pgrep -f "$1" >/dev/null
}

# NEW: Function to forcefully close the current menu
close_menu() {
  # Find and terminate the process started by the DMENU_CMD
  # We use pkill -f to match the full command line "vicinae dmenu"
  pkill -f "vicinae dmenu"
}

# --- Tool Functions ---

# Screenshot functions (submenu is required as it has multiple options)
do_screenshot() {
  close_menu # Close the parent menu
  local options=$(echo -e "Region\nWindow\nFullscreen\nGo back")
  local choice=$($DMENU_CMD -p "Screenshot Mode:" <<<"$options")

  case "$choice" in
  "Region")
    sleep 0.2
    bash "$SCREENSHOT_SCRIPT" s &
    ;;
  "Window") bash "$SCREENSHOT_SCRIPT" w & ;;
  "Fullscreen") bash "$SCREENSHOT_SCRIPT" p & ;;
  "Go back")
    bash "/home/duarte/.config/hypr/scripts/tools.sh" &
    ;;
  *) return 1 ;;
  esac
}

# Screen Recorder (direct action)
do_screenrecord() {
  close_menu # Close the parent menu
  bash -c "nohup bash $SCREENRECORD_SCRIPT > /dev/null 2>&1 & disown"
}

# Pomodoro (direct action)
do_pomodoro() {
  close_menu # Close the parent menu
  bash -c "nohup bash $POMODORO_SCRIPT > /dev/null 2>&1 & disown"
}

# OCR (direct action)
do_ocr() {
  close_menu # Close the parent menu
  sleep 0.2
  bash "$OCR_SCRIPT" &
}

# Gamemode (direct action)
do_gamemode() {
  close_menu # Close the parent menu
  bash "$GAMEMODE_SCRIPT" &
}

# Color Picker (submenu is required as it has multiple formats)
do_colorpicker() {
  close_menu # Close the parent menu
  local options=$(echo -e "HEX\nRGB\nHSV\nGo back")
  local choice=$($DMENU_CMD -p "Color Picker Format:" <<<"$options")

  local cmd=""
  case "$choice" in
  "HEX") cmd="-hex" ;;
  "RGB") cmd="-rgb" ;;
  "HSV") cmd="-hsv" ;;
  "Go back")
    bash "/home/duarte/.config/hypr/scripts/tools.sh" &
    ;;
  *) return 1 ;;
  esac
  sleep 0.2
  bash "/home/duarte/.config/Ax-Shell/scripts/hyprpicker.sh" "$cmd"
}

# Emoji Picker (direct action)
do_emoji() {
  close_menu # Close the parent menu before launching the new vicinae command
  # The vicinae command to open the picker is executed directly
  bash -c "vicinae vicinae://extensions/vicinae/vicinae/search-emojis"
}

# Open Screenshots Folder (direct action)
open_screenshots_folder() {
  close_menu # Close the parent menu
  local pictures_dir="${XDG_PICTURES_DIR:-$HOME/Pictures}"
  local screenshots_dir="$pictures_dir/Screenshots"
  xdg-open "$screenshots_dir" &
}

# Open Recordings Folder (direct action)
open_recordings_folder() {
  close_menu # Close the parent menu
  local videos_dir="${XDG_VIDEOS_DIR:-$HOME/Videos}"
  local recordings_dir="$videos_dir/Recordings"
  xdg-open "$recordings_dir" &
}

# --- Main Menu Logic ---

# Build the main menu options, including dynamic status indicators
build_menu() {
  local status_screenrecord="[REC]"
  is_running "gpu-screen-recorder" && status_screenrecord="[LIVE]"

  local status_pomodoro="[Timer Off]"
  is_running "pomodoro.sh" && status_pomodoro="[Timer On]"

  # NEW: Check gamemode status by running the script and capturing its output (t or f)
  local gamemode_status_char=$("$GAMEMODE_SCRIPT" check 2>/dev/null)
  local status_gamemode="[Disabled]"

  # Set status based on the script's output
  if [[ "$gamemode_status_char" == "t" ]]; then
    status_gamemode="[Enabled]"
  fi

  # Format: Tool Name | Status
  cat <<-EOF
Screenshot
Open Screenshots Folder
Recorder $status_screenrecord
Open Recordings Folder
OCR
Color Picker
Game Mode $status_gamemode
Pomodoro $status_pomodoro
Emoji Picker
EOF
}
# Run the main menu and execute the selected action
main() {
  local menu_output=$(build_menu)
  # Get the full selected line from the menu
  local choice=$($DMENU_CMD -p "Toolbox:" <<<"$menu_output")

  # The case statement matches the menu item based on its name, ignoring the dynamic status.
  case "$choice" in
  *"Screenshot") do_screenshot ;;
  *"Open Screenshots Folder") open_screenshots_folder ;;
  *"Screen Recorder"*) do_screenrecord ;;
  *"Open Recordings Folder") open_recordings_folder ;;
  *"OCR") do_ocr ;;
  *"Color Picker") do_colorpicker ;;
  *"Game Mode"*) do_gamemode ;;
  *"Pomodoro"*) do_pomodoro ;;
  *"Emoji Picker") do_emoji ;;
  *)
    # No selection or C-g escape
    exit 0
    ;;
  esac
}

main "$@"
