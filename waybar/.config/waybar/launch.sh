#!/bin/bash

killall waybar
hyprctl reload
sleep 1
waybar & waybar -c ~/.config/waybar/external.jsonc & waybar -c ~/.config/waybar/external2.jsonc