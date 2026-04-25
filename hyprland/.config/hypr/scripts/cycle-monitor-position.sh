#!/bin/bash

STATE_FILE="/tmp/hyprland-display-mode"
POSITION_FILE="/tmp/hyprland-monitor-position"

# Check if we're in mirror mode
CURRENT_MODE="expand"
if [ -f "$STATE_FILE" ]; then
    CURRENT_MODE=$(cat "$STATE_FILE")
fi

if [ "$CURRENT_MODE" = "mirror" ]; then
    notify-send "Monitor Position" "⚠️ Switch to expand mode first (Mod+Shift+M)"
    exit 0
fi

# Get current position (default to right)
CURRENT_POSITION="right"
if [ -f "$POSITION_FILE" ]; then
    CURRENT_POSITION=$(cat "$POSITION_FILE")
fi

# Cycle to next position: right -> left -> top -> bottom -> right
case "$CURRENT_POSITION" in
    right)
        NEW_POSITION="left"
        ICON="⬅️"
        ;;
    left)
        NEW_POSITION="top"
        ICON="⬆️"
        ;;
    top)
        NEW_POSITION="bottom"
        ICON="⬇️"
        ;;
    bottom)
        NEW_POSITION="right"
        ICON="➡️"
        ;;
    *)
        NEW_POSITION="right"
        ICON="➡️"
        ;;
esac

# Save the new position
echo "$NEW_POSITION" > "$POSITION_FILE"

# Apply the position
~/.config/hypr/scripts/apply-monitor-position.sh "$NEW_POSITION"

# Show notification
notify-send "Monitor Position" "$ICON External monitor: $NEW_POSITION"