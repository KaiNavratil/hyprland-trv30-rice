#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
#  LID SWITCH EVENT HANDLER FOR HYPRLAND
#  Handles lid open/close events based on Clamshell / Insomnia mode state
# ══════════════════════════════════════════════════════════════════════════════

EVENT="$1" # "close" or "open"
STATE_FILE="$HOME/.cache/insomnia_mode"
INTERNAL_MONITOR="eDP-1"
NUM_MONITORS=$(hyprctl monitors -j 2>/dev/null | jq '. | length')

is_insomnia_active() {
    [ -f "$STATE_FILE" ] && pgrep -f "systemd-inhibit.*Clamshell" >/dev/null
}

if [ "$EVENT" = "close" ]; then
    if is_insomnia_active; then
        # Insomnia / Clamshell mode is EXPLICITLY active (Super+O)
        # Keep laptop awake. If external display is connected, disable internal screen
        if [ "$NUM_MONITORS" -gt 1 ]; then
            hyprctl eval "hl.monitor({ output = '$INTERNAL_MONITOR', disabled = true })"
        else
            hyprctl dispatch dpms off "$INTERNAL_MONITOR"
        fi
    else
        # Normal behavior: Always suspend on lid close, even when external monitor is connected!
        systemctl suspend
    fi
elif [ "$EVENT" = "open" ]; then
    # Re-enable internal laptop monitor if it was disabled
    if [ "$NUM_MONITORS" -gt 1 ]; then
        hyprctl eval "hl.monitor({ output = '$INTERNAL_MONITOR', mode = 'preferred', position = 'auto-right', scale = 1.30, disabled = false })"
    else
        hyprctl eval "hl.monitor({ output = '$INTERNAL_MONITOR', mode = 'preferred', position = 'auto', scale = 1.20, disabled = false })"
    fi
    # Wake up screen immediately
    hyprctl dispatch dpms on "$INTERNAL_MONITOR"
fi
