alias rpi="ssh server@192.168.1.246"
alias debian="ssh server@192.168.1.247"
alias camera-phone="$HOME/.config/hypr/scripts/camera-phone.sh"
if status is-interactive
    set -g fish_greeting ""
    # Custom colours
    # For jumping between prompts in foot terminal
    #function mark_prompt_start --on-event fish_prompt
    echo -en "\e]133;A\e\\"
    fastfetch
    #end
end
if status is-login; and test -z "$DISPLAY"; and test (tty) = "/dev/tty1"
    exec start-hyprland
end
