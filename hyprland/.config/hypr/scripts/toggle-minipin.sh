#!/bin/bash

WINDOW=$(hyprctl activewindow -j)
ADDR=$(echo "$WINDOW" | jq -r '.address')
IS_FLOATING=$(echo "$WINDOW" | jq -r '.floating')
IS_PINNED=$(echo "$WINDOW" | jq -r '.pinned')

if [ "$IS_FLOATING" = "true" ] && [ "$IS_PINNED" = "true" ]; then
    hyprctl dispatch pin address:$ADDR
    hyprctl dispatch settiled address:$ADDR
else
    MONITOR=$(hyprctl monitors -j | jq '.[] | select(.focused == true)')
    MON_W=$(echo "$MONITOR" | jq -r '.width')
    MON_SCALE=$(echo "$MONITOR" | jq -r '.scale')
    RESERVED_TOP=$(echo "$MONITOR" | jq -r '.reserved[1]')

    LOGICAL_W=$(echo "$MON_W $MON_SCALE" | awk '{printf "%d", $1 / $2}')

    MINI_W=600
    MINI_H=400
    MARGIN=20

    POS_X=$(( LOGICAL_W - MINI_W - MARGIN ))
    POS_Y=$(( RESERVED_TOP + MARGIN ))

    # Use setfloating instead of togglefloating to avoid tiling flash
    hyprctl dispatch setfloating address:$ADDR
    hyprctl dispatch focuswindow address:$ADDR
    sleep 0.1

    hyprctl dispatch resizewindowpixel exact $MINI_W $MINI_H,address:$ADDR
    # hyprctl dispatch movewindowpixel exact $POS_X $POS_Y,address:$ADDR

    hyprctl dispatch pin
fi