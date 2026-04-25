#!/bin/bash

POSITION=$1

# Get internal display
INTERNAL=$(hyprctl monitors -j | jq -r '.[] | select(.name | startswith("eDP") or startswith("LVDS") or startswith("DSI")) | .name' | head -1)

# Get internal display dimensions
INTERNAL_INFO=$(hyprctl monitors -j | jq -r ".[] | select(.name == \"$INTERNAL\")")
INTERNAL_WIDTH=$(echo "$INTERNAL_INFO" | jq -r '.width')
INTERNAL_HEIGHT=$(echo "$INTERNAL_INFO" | jq -r '.height')
INTERNAL_SCALE=$(echo "$INTERNAL_INFO" | jq -r '.scale // 1')

# divide by scale (round to nearest integer)
INTERNAL_WIDTH=$(awk -v w="$INTERNAL_WIDTH" -v s="$INTERNAL_SCALE" 'BEGIN {printf "%d", (w/s + 0.5)}')
INTERNAL_HEIGHT=$(awk -v h="$INTERNAL_HEIGHT" -v s="$INTERNAL_SCALE" 'BEGIN {printf "%d", (h/s + 0.5)}')

# Get ALL connected displays
ALL_DISPLAYS=$(hyprctl monitors all -j | jq -r '.[].name')

# Get external monitor
EXTERNAL=""
for display in $ALL_DISPLAYS; do
    if [[ ! "$display" =~ ^(eDP|LVDS|DSI) ]]; then
        EXTERNAL="$display"
        break
    fi
done



# Check if external monitor exists
if [ -z "$EXTERNAL" ]; then
    exit 0
fi

# Get external display dimensions
EXTERNAL_INFO=$(hyprctl monitors -j | jq -r ".[] | select(.name == \"$EXTERNAL\")")
EXTERNAL_WIDTH=$(echo "$EXTERNAL_INFO" | jq -r '.width')
EXTERNAL_HEIGHT=$(echo "$EXTERNAL_INFO" | jq -r '.height')

# Calculate position coordinates
case "$POSITION" in
    left)
        POSITION_ARG="-${EXTERNAL_WIDTH}x0"
        ;;
    right)
        POSITION_ARG="${INTERNAL_WIDTH}x0"
        ;;
    top)
        POSITION_ARG="0x-${EXTERNAL_HEIGHT}"
        ;;
    bottom)
        POSITION_ARG="0x${INTERNAL_HEIGHT}"
        ;;
    *)
        POSITION_ARG="${INTERNAL_WIDTH}x0"  # default to right
        ;;
esac

# Apply the monitor configuration
hyprctl keyword monitor "$EXTERNAL,preferred,${POSITION_ARG},1"

# Give it a moment to reconfigure
sleep 0.2

# Re-run workspace setup
~/.config/hypr/scripts/monitor-setup.sh