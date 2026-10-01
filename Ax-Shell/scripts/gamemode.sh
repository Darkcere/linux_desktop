#!/usr/bin/env sh

check_gamemode() {
    HYPRGAMEMODE=$(hyprctl getoption animations:enabled | awk 'NR==1{print $2}')
    if [ "$HYPRGAMEMODE" = 'false' ] ; then 
        echo "t"
        return 0
    else
        echo "f"
        return 1
    fi
}

toggle_gamemode() {
    HYPRGAMEMODE=$(hyprctl getoption animations:enabled | awk 'NR==1{print $2}')
    if [ "$HYPRGAMEMODE" = 'true' ] ; then
        hyprctl eval "hl.config({
            animations = { 
                enabled = false, 
                animation = { 'borderangle,0' } 
            },
            decoration = { 
                shadow = { enabled = false }, 
                blur = { enabled = false }, 
                rounding = 0 
            },
            general = { 
                border_size = 1 
            }
        })"
        powerprofilesctl set performance
        
        # Tell Quickshell to enter Game Mode (destroys UI, clears RAM, enables DND)
        qs ipc call gamemode set true
        
        exit
    fi
    
    hyprctl reload
    powerprofilesctl set balanced
    
    # Tell Quickshell to exit Game Mode (recreates UI, disables DND)
    qs ipc call gamemode set false
}

case "$1" in
    check)
        check_gamemode
        ;;
    *)
        toggle_gamemode
        ;;
esac
