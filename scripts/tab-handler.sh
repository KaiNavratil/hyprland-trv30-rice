#!/bin/bash
ACTIVE=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .specialWorkspace.name' | sed 's/special://')

if [ -z "$ACTIVE" ] || [ "$ACTIVE" == "null" ] || [ "$ACTIVE" == "" ]; then
    hyprctl dispatch workspace previous
else
    hyprctl dispatch togglespecialworkspace "$ACTIVE"
fi

# Force Waybar to update the red light indicators immediately
( sleep 0.1 ; pkill -RTMIN+1 waybar ) &
