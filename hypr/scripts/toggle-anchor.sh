#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
#  TOKYO 80s TRV30 — SCRATCHPAD ANCHOR & HUD PIN MANAGER
#  常駐ピン留め・HUD固定スクリプト
# ═══════════════════════════════════════════════════════════════════════════════

# Detect currently focused monitor and active special workspace
FOCUSED_MON_INFO=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true)')
FOCUSED_MON=$(echo "$FOCUSED_MON_INFO" | jq -r '.name')
SPECIAL_WS=$(echo "$FOCUSED_MON_INFO" | jq -r '.specialWorkspace.name' | sed 's/special://')

if [ -n "$SPECIAL_WS" ] && [ "$SPECIAL_WS" != "null" ] && [ "$SPECIAL_WS" != "" ]; then
    # We are on a monitor with an active scratchpad!
    ANCHOR_FILE="/tmp/scratchpad_anchored_${SPECIAL_WS}"
    if [ -f "$ANCHOR_FILE" ]; then
        rm -f "$ANCHOR_FILE"
        dunstify -a "osd" -r 9998 -u normal \
            "[ 🔓 ANCHOR RELEASED / 通常解除 ]" \
            "DECK [${SPECIAL_WS^^}] WILL HIDE ON DESKTOP SWITCH"
    else
        touch "$ANCHOR_FILE"
        dunstify -a "osd" -r 9998 -u normal \
            "[ 📌 ANCHOR ENGAGED / 常駐ピン留め ]" \
            "DECK [${SPECIAL_WS^^}] PINNED ACROSS ALL 1-9 DESKTOP SPACES"
    fi
else
    # No scratchpad is active on this monitor. Toggle Hyprland PIN on the active floating window!
    ACTIVE_WIN=$(hyprctl activewindow -j)
    IS_FLOATING=$(echo "$ACTIVE_WIN" | jq -r '.floating')
    WIN_TITLE=$(echo "$ACTIVE_WIN" | jq -r '.title' | cut -c 1-30)
    
    if [ "$IS_FLOATING" = "true" ]; then
        hyprctl dispatch pin active >/dev/null 2>&1
        IS_PINNED=$(hyprctl activewindow -j | jq -r '.pinned')
        if [ "$IS_PINNED" = "true" ]; then
            dunstify -a "osd" -r 9998 -u normal \
                "[ 📌 WINDOW PINNED / ウィンドウ固定 ]" \
                "${WIN_TITLE:-WINDOW} PINNED ACROSS ALL WORKSPACES"
        else
            dunstify -a "osd" -r 9998 -u normal \
                "[ 🔓 PIN RELEASED / 固定解除 ]" \
                "${WIN_TITLE:-WINDOW} UNPINNED"
        fi
    else
        # Window is tiled; notify user
        dunstify -a "osd" -r 9998 -u low \
            "[ ℹ ANCHOR HUD / 常駐情報 ]" \
            "OPEN A SCRATCHPAD OR FLOAT A WINDOW (Super+Ctrl+T) TO PIN"
    fi
fi
