#!/usr/bin/env sh

sleep 0.25

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

if [ -f "$full_path" ]; then
   \

    ACTION=$(notify-send -a "Ax-Shell" -i "$full_path" "Screenshot saved" "in $full_path" \
        -A "view=View" -A "edit=Edit" -A "open=Open Folder" -A "delete=Delete")\

    case "$ACTION" in
        view) xdg-open "$full_path" ;;
        edit) swappy -f "$full_path" ;;
        open) xdg-open "$save_dir" ;;
        delete) rm -r "$full_path" ;;
    esac
fi
