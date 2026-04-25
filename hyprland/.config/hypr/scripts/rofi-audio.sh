#!/usr/bin/env bash

# 1. Fetch Sink IDs and Descriptions, then clean up the text
# We remove the long hardware controller prefix and redundant "sink" suffix
devices=$(pactl list sinks | awk '/^Sink #/ {id=$2; sub("#", "", id)} /Description:/ {sub(/Description: /, ""); print id " : " $0}' | \
    sed 's/Meteor Lake-P HD Audio Controller //g' | \
    sed 's/alsa_output.*.HiFi__//g; s/__sink//g' | \
    sed 's/HDMI \/ DisplayPort /HDMI /g')

# 2. Open Rofi
selected=$(echo "$devices" | rofi -dmenu -i -p "󰓃 Select Output:" -config ~/.config/rofi/config.rasi)

# 3. Exit if nothing selected
if [ -z "$selected" ]; then
    exit 0
fi

# 4. Extract the ID (everything before the first colon)
device_id=$(echo "$selected" | cut -d' ' -f1)

# 5. Set the default sink
pactl set-default-sink "$device_id"

# 6. Force move all currently playing streams to the new sink
# This ensures Spotify/Chrome switch immediately without pausing
for stream in $(pactl list short sink-inputs | awk '{print $1}'); do
    pactl move-sink-input "$stream" "$device_id"
done

# 7. Notification
friendly_name=$(echo "$selected" | cut -d':' -f2- | xargs)
notify-send "Audio Switcher" "Output: $friendly_name" -i audio-speakers -t 2000