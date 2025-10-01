if status is-interactive
    set -g fish_greeting ""
    # Custom colours
    cat ~/.local/state/caelestia/sequences.txt 2>/dev/null

    # For jumping between prompts in foot terminal
    #function mark_prompt_start --on-event fish_prompt
    echo -en "\e]133;A\e\\"
    fastfetch
    #end
end
