#!/bin/bash
if ! hyprctl clients -j | grep -qi '"class": "antigravity"'; then
    antigravity &
    sleep 0.5
fi
~/.config/hypr/scripts/toggle-scratchpad.sh antigravity
