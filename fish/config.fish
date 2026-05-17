alias windows="sudo umount /mnt/window && sudo ntfs-3g -o remove_hiberfile /dev/nvme0n1p3 /mnt/window/"
alias vencord='sh -c "$(curl -sS https://raw.githubusercontent.com/Vendicated/VencordInstaller/main/install.sh)"'
alias rpi="ssh server@192.168.1.246"
alias debian="ssh server@192.168.1.247"
if status is-interactive
    set -g fish_greeting ""
    # Custom colours
    source ~/.local/state/caelestia/sequences.txt
    # For jumping between prompts in foot terminal
    #function mark_prompt_start --on-event fish_prompt
    echo -en "\e]133;A\e\\"
    fastfetch
    #end
end
