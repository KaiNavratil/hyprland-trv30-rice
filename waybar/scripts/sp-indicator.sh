#!/bin/bash
WORKSPACE="special:$1"
LABEL="$2"

# Check if the special workspace is currently active on any monitor
if hyprctl monitors -j | jq -e ".[] | select(.specialWorkspace.name == \"$WORKSPACE\")" > /dev/null; then
    echo "<span foreground='#ff0000'>● $LABEL</span>"
else
    echo "  $LABEL"
fi
