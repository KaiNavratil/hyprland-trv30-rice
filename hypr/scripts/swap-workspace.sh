#!/usr/bin/env bash
# Swaps all windows between the current workspace and the one to its left/right

DIR=$1

ACTIVE_WS=$(hyprctl activeworkspace -j | jq '.id')

if [ "$DIR" == "left" ]; then
    TARGET_WS=$((ACTIVE_WS - 1))
    if [ "$TARGET_WS" -lt 1 ]; then TARGET_WS=9; fi
elif [ "$DIR" == "right" ]; then
    TARGET_WS=$((ACTIVE_WS + 1))
    if [ "$TARGET_WS" -gt 9 ]; then TARGET_WS=1; fi
else
    exit 1
fi

# Get all window addresses for the active and target workspaces
ACTIVE_WINDOWS=$(hyprctl clients -j | jq -r ".[] | select(.workspace.id == $ACTIVE_WS) | .address")
TARGET_WINDOWS=$(hyprctl clients -j | jq -r ".[] | select(.workspace.id == $TARGET_WS) | .address")

# Temp workspace for the swap
TEMP_WS=99

# Move target windows to temp
for addr in $TARGET_WINDOWS; do
    hyprctl dispatch movetoworkspacesilent "$TEMP_WS,address:$addr"
done

# Move active windows to target
for addr in $ACTIVE_WINDOWS; do
    hyprctl dispatch movetoworkspacesilent "$TARGET_WS,address:$addr"
done

# Move temp windows to active
for addr in $TARGET_WINDOWS; do
    hyprctl dispatch movetoworkspacesilent "$ACTIVE_WS,address:$addr"
done

# Follow the target workspace (so you "move" with your desktop)
hyprctl dispatch workspace "$TARGET_WS"

