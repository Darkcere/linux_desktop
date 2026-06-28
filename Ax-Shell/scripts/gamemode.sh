#!/usr/bin/env sh

# Check if animations are disabled (game mode is active)
check_gamemode() {
    HYPRGAMEMODE=$(hyprctl getoption animations:enabled | awk 'NR==1{print $2}')
    if [ "$HYPRGAMEMODE" = 0 ] ; then 
        echo "t"
        return 0
    else
        echo "f"
        return 1
    fi
}

# Toggle game mode state
toggle_gamemode() {
    HYPRGAMEMODE=$(hyprctl getoption animations:enabled | awk 'NR==1{print $2}')
    if [ "$HYPRGAMEMODE" = 1 ] ; then
        hyprctl --batch "\
            keyword animations:enabled 0;\
            keyword animation borderangle,0;\
            keyword decoration:shadow:enabled 0;\
            keyword decoration:blur:enabled 0;\
            keyword general:border_size 1;\
            keyword decoration:rounding 0;\
            "
        swaync-client -dn
        powerprofilesctl set performance
        exit
    fi
    hyprctl reload
    swaync-client -df
    powerprofilesctl set balanced
}

# Main script logic
case "$1" in
    check)
        check_gamemode
        ;;
    *)
        toggle_gamemode
        ;;
esac
