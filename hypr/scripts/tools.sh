#!/usr/bin/env bash

# --- Configuration ---

# Path to the helper scripts
SCRIPTS_DIR="/home/duarte/.config/Ax-Shell/scripts"

SCREENSHOT_SCRIPT="$SCRIPTS_DIR/screenshot.sh"
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

# Function to forcefully close the current menu
close_menu() {
  pkill -f "vicinae dmenu"
}

# --- Tool Functions ---

# Screenshare Privacy Toggle
do_screenshare_privacy() {
  close_menu
  hyprctl dispatch setprop active no_screen_share toggle
}

# HDR
do_hdr() {
  close_menu

  local preset
  preset=$(hyprctl monitors all | awk -F': ' '/colorManagementPreset/ {print $2; exit}')

  if [[ "$preset" == "hdr" ]]; then
    hyprctl keyword monitor ",highrr,auto,1"
  else
    hyprctl keyword monitor ",highrr,auto,1,bitdepth,10,cm,hdr,sdrbrightness,5"
  fi
}

# Layout submenu
do_layouts() {
  close_menu
  
  local current_layout
  current_layout=$(hyprctl activeworkspace | awk '/tiledLayout:/ {print $2}')
  local current_layout_general
  current_layout_general=$(hyprctl getoption general:layout -j | jq -r '.str')

  local options=$(echo -e "Dwindle\nScrolling\nMaster\nMonocle\nSet Current to General\nGo back")
  local choice=$($DMENU_CMD -p "Workspace Layout: [$current_layout]:" -n "General Layout: [$current_layout_general]" <<<"$options")

  case "$choice" in
    "Dwindle")
      hyprctl keyword workspace "$(hyprctl -j activeworkspace | jq '.id')", layout:dwindle
      ;;
    
    "Scrolling")
      hyprctl keyword workspace "$(hyprctl -j activeworkspace | jq '.id')", layout:scrolling
      ;;

    "Master")
      hyprctl keyword workspace "$(hyprctl -j activeworkspace | jq '.id')", layout:master
      ;;

    "Monocle")
      hyprctl keyword workspace "$(hyprctl -j activeworkspace | jq '.id')", layout:monocle
      ;;

    "Set Current to General")
      hyprctl keyword general:layout "$current_layout"
      ;;

    "Go back")
      bash "/home/duarte/.config/hypr/scripts/tools.sh" &
      ;;
  esac
}

# Screenshot submenu
do_screenshot() {
  close_menu

  local options=$(echo -e "Open Folder\nRegion\nWindow\nFullscreen\nGo back")
  local choice=$($DMENU_CMD -p "Screenshot Mode:" <<<"$options")

  case "$choice" in
    "Open Folder")
      local pictures_dir="${XDG_PICTURES_DIR:-$HOME/Pictures}"
      local screenshots_dir="$pictures_dir/Screenshots"
      xdg-open "$screenshots_dir" &
      ;;

    "Region")
      sleep 0.2
      bash "$SCREENSHOT_SCRIPT" s &
      ;;

    "Window")
      bash "$SCREENSHOT_SCRIPT" w &
      ;;

    "Fullscreen")
      bash "$SCREENSHOT_SCRIPT" p &
      ;;

    "Go back")
      bash "/home/duarte/.config/hypr/scripts/tools.sh" &
      ;;

    *)
      return 1
      ;;
  esac
}

# Screen Recorder
do_screenrecord() {
  close_menu
  bash -c "nohup bash $SCREENRECORD_SCRIPT > /dev/null 2>&1 & disown"
}

# Pomodoro
do_pomodoro() {
  close_menu
  bash -c "nohup bash $POMODORO_SCRIPT > /dev/null 2>&1 & disown"
}

# OCR
do_ocr() {
  close_menu
  sleep 0.2
  bash "$OCR_SCRIPT" &
}

# Gamemode
do_gamemode() {
  close_menu
  bash "$GAMEMODE_SCRIPT" &
}

# Color Picker submenu
do_colorpicker() {
  close_menu

  local options=$(echo -e "HEX\nRGB\nHSV\nGo back")
  local choice=$($DMENU_CMD -p "Color Picker Format:" <<<"$options")

  local cmd=""

  case "$choice" in
    "HEX") cmd="-hex" ;;
    "RGB") cmd="-rgb" ;;
    "HSV") cmd="-hsv" ;;

    "Go back")
      bash "/home/duarte/.config/hypr/scripts/tools.sh" &
      return
      ;;

    *)
      return 1
      ;;
  esac

  sleep 0.2
  bash "$HYPRPICKER_SCRIPT" "$cmd"
}

# Open Recordings Folder
open_recordings_folder() {
  close_menu

  local videos_dir="${XDG_VIDEOS_DIR:-$HOME/Videos}"
  local recordings_dir="$videos_dir/Recordings"

  xdg-open "$recordings_dir" &
}

# --- Main Menu Logic ---

build_menu() {
  local current_layout
  current_layout=$(hyprctl activeworkspace | awk '/tiledLayout:/ {print $2}')
  local current_layout_general
  current_layout_general=$(hyprctl getoption general:layout -j | jq -r '.str')

  local status_screenrecord="[REC]"
  is_running "gpu-screen-recorder" && status_screenrecord="[LIVE]"

  local status_pomodoro="[Timer Off]"
  is_running "pomodoro.sh" && status_pomodoro="[Timer On]"

  local gamemode_status_char=$("$GAMEMODE_SCRIPT" check 2>/dev/null)
  local status_gamemode="[Disabled]"

  if [[ "$gamemode_status_char" == "t" ]]; then
    status_gamemode="[Enabled]"
  fi

  # Detect screenshare privacy status of the active window using getprop
  local status_privacy="[VISIBLE]"
  local prop_status
  prop_status=$(hyprctl getprop active no_screen_share 2>/dev/null)
  
  if [[ "$prop_status" == *"int: 1"* || "$prop_status" == *"true"* ]]; then
    status_privacy="[HIDDEN]"
  fi

  local left="Layouts"
  local center="Workspace: [$current_layout]"
  local right="General: [$current_layout_general]"

  # fixed column widths
  local L=45
  local R=75

  local layout_line
  printf -v layout_line "%-${L}s%*s%-${R}s%s" \
    "$left" \
    $(( (80 - L - R) / 2 )) "" \
    "$center" \
    "$right"

  cat <<EOF
Game Mode $status_gamemode
Toggle HDR
$layout_line
Screenshare Privacy $status_privacy
Screenshot Menu
Recorder $status_screenrecord
Open Recordings Folder
OCR
Color Picker
Pomodoro $status_pomodoro
EOF
}

main() {
  local menu_output=$(build_menu)

  local choice=$($DMENU_CMD -p "Toolbox:" <<<"$menu_output")

  case "$choice" in
    *"Game Mode"*)
      do_gamemode
      ;;
    *"Toggle HDR"*)
      do_hdr
      ;;
    *"Layouts"*)
      do_layouts
      ;;
    *"Screenshare Privacy"*)
      do_screenshare_privacy
      ;;
    *"Screenshot"*)
      do_screenshot
      ;;
    *"Recorder"*)
      do_screenrecord
      ;;
    *"Open Recordings Folder"*)
      open_recordings_folder
      ;;
    *"OCR"*)
      do_ocr
      ;;
    *"Color Picker"*)
      do_colorpicker
      ;;
    *"Pomodoro"*)
      do_pomodoro
      ;;
    *)
      exit 0
      ;;
  esac
}

main "$@"
