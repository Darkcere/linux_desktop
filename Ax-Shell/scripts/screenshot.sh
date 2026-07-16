#!/usr/bin/env sh

if [ -z "$XDG_PICTURES_DIR" ]; then
    XDG_PICTURES_DIR="$HOME/Pictures"
fi

save_dir="${3:-$XDG_PICTURES_DIR/Screenshots}"
save_file=$(date +'%y%m%d_%Hh%Mm%Ss_screenshot.png')
full_path="$save_dir/$save_file"
mkdir -p "$save_dir"

mockup_mode="$2"

print_error() {
    cat <<EOF
    ./screenshot.sh <action> [mockup]
    ...valid actions are...
        p  : print selected screen
        s  : snip selected region
        w  : snip focused window
EOF
}

case $1 in
    p)
        hyprshot -s -m output -m active -o "$save_dir" -f "$save_file"
        ;;
    s)
        hyprshot -s -z -m region -o "$save_dir" -f "$save_file"
        ;;
    w)
        hyprshot -s -m window -m active -o "$save_dir" -f "$save_file";
        ;;
    *)
        print_error
        exit 1
        ;;
esac

# 💡 THE FIX: Give hyprshot half a second to finish writing large files to the disk
sleep 0.5

if [ -f "$full_path" ]; then
    
    # 💡 THE FIX: Create a tiny thumbnail in a dedicated /tmp folder for the notification
    # This prevents DBus/Qt from choking on massive 4K PNGs
    thumb_dir="/tmp/ax_shell_thumbs"
    mkdir -p "$thumb_dir"
    thumb_path="$thumb_dir/$save_file"
    
    # Check if ImageMagick is installed and create a fast 256x256 thumbnail
    if command -v magick &> /dev/null; then
        magick "$full_path" -resize 256x256\> "$thumb_path"
    elif command -v convert &> /dev/null; then
        convert "$full_path" -resize 256x256\> "$thumb_path"
    else
        # Fallback if ImageMagick isn't installed
        thumb_path="$full_path"
    fi

    # Send the tiny thumbnail to Quickshell instead of the giant original
    ACTION=$(notify-send -a "Ax-Shell" -i "$thumb_path" "Screenshot saved" "in $full_path" \
        -A "view=View" -A "edit=Edit" -A "open=Open Folder" -A "delete=Delete")

    case "$ACTION" in
        view) xdg-open "$full_path" ;;
        edit) swappy -f "$full_path" ;;
        open) xdg-open "$save_dir" ;;
        delete) rm -r "$full_path" ;;
    esac
fi