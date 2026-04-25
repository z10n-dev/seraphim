#!/bin/bash

CONFIG_DIR="$HOME/.config/hypr/monitors"
CONFIG_FILE="$HOME/.config/hypr/monitors.conf"

set_layout() {
    local layout_file="$CONFIG_DIR/$1.conf"

    if [ ! -f "$layout_file" ]; then
        notify-send "Error changing display Mode: Layout file not found: $layout_file"
        exit 1
    fi

    ln -sf "$layout_file" "$CONFIG_FILE"
    hyprctl reload
    sh "$HOME/.config/hypr/scripts/restart-bar.sh"
    awww
    notify-send "Display Mode" "Display Mode changed to: $1" -i dialog-information
}

case "$1" in
    portable|1)
        set_layout "portable"
        ;;
    home|2)
        set_layout "home"
        ;;
    docking|3)
        set_layout "docking"
        ;;
    presentation|4)
        set_layout "presentation"
        ;;
    laptop|0)
        set_layout "laptop"
        ;;
    menu)
        # For use with rofi/wofi
        choice=$(echo -e "Laptop Only\nPortable Monitor\nHome Monitor\nDocking Station\nPresentation" | rofi -dmenu -p "Monitor Layout")
        case "$choice" in
            "Laptop Only") set_layout "laptop" ;;
            "Portable Monitor") set_layout "portable" ;;
            "Home Monitor") set_layout "home" ;;
            "Docking Station") set_layout "docking" ;;
            "Presentation") set_layout "presentation" ;;
        esac
        ;;
    *)
        echo "Usage: $0 {portable|home|docking|laptop|menu}"
        echo "  portable (1) - Laptop + Portable Monitor on DP-1"
        echo "  home (2)     - Laptop + HDMI Monitor"
        echo "  docking (3)  - Laptop + Docking Station (2 monitors)"
        echo "  laptop (0)   - Laptop only"
        echo "  menu         - Show rofi/wofi menu"
        exit 1
        ;;
esac