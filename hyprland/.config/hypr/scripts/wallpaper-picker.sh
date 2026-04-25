#!/bin/bash

# Path to your wallpapers
WALLPAPER_DIR="$HOME/.config/assets"

# Transition settings (swww)
TRANSITION_TYPE="wipe"
TRANSITION_ANGLE=30
TRANSITION_FPS=60
TRANSITION_STEP=50

# Get list of wallpapers and show in Rofi
# Using -dmenu allows Rofi to act as a selector
selected=$(ls "$WALLPAPER_DIR" | rofi -dmenu -i -p "Select Wallpaper:" -config ~/.config/rofi/config.rasi)

# If a selection was made
if [ -n "$selected" ]; then
    awww img "$WALLPAPER_DIR/$selected" \
        --transition-type "$TRANSITION_TYPE" \
        --transition-fps "$TRANSITION_FPS" \
        --transition-step "$TRANSITION_STEP"\
        --transition-angle "$TRANSITION_ANGLE"
fi