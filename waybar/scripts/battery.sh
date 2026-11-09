#!/bin/bash
BAT=$(ls /sys/class/power_supply | grep BAT | head -n 1)
if [ -z "$BAT" ]; then exit 0; fi

STATUS=$(cat /sys/class/power_supply/$BAT/status 2>/dev/null)
CAPACITY=$(cat /sys/class/power_supply/$BAT/capacity 2>/dev/null)

# Calculate camcorder blocks
if [ "$CAPACITY" -ge 80 ]; then ICON="[█████]"
elif [ "$CAPACITY" -ge 60 ]; then ICON="[████░]"
elif [ "$CAPACITY" -ge 40 ]; then ICON="[███░░]"
elif [ "$CAPACITY" -ge 20 ]; then ICON="[██░░░]"
elif [ "$CAPACITY" -ge 5 ]; then ICON="[█░░░░]"
else ICON="[░░░░░]"
fi

# Determine CSS Class based on capacity
CLASS="normal"
if [ "$CAPACITY" -le 15 ]; then CLASS="critical"
elif [ "$CAPACITY" -le 30 ]; then CLASS="warning"
fi

# Handle Charging Flashing State
if [ "$STATUS" = "Charging" ]; then
    CLASS="charging"
    if [ $(( $(date +%s) % 2 )) -eq 0 ]; then
        TEXT="$ICON $CAPACITY+"
    else
        # Ensure width doesn't shift wildly if capacity string is shorter
        TEXT="$ICON $CAPACITY%"
    fi
else
    TEXT="$ICON $CAPACITY%"
fi

# Time remaining calculation
TOOLTIP="Battery: $CAPACITY%"
if [ -f /sys/class/power_supply/$BAT/power_now ]; then
    POWER=$(cat /sys/class/power_supply/$BAT/power_now 2>/dev/null)
    ENERGY=$(cat /sys/class/power_supply/$BAT/energy_now 2>/dev/null)
    if [ -n "$POWER" ] && [ "$POWER" -gt 0 ]; then
        if [ "$STATUS" = "Charging" ]; then
            ENERGY_FULL=$(cat /sys/class/power_supply/$BAT/energy_full 2>/dev/null)
            REMAINING_HOURS=$(awk "BEGIN {print ($ENERGY_FULL - $ENERGY) / $POWER}")
        else
            REMAINING_HOURS=$(awk "BEGIN {print $ENERGY / $POWER}")
        fi
        TIME_EST=$(awk -v h="$REMAINING_HOURS" 'BEGIN { printf "%02d:%02d", int(h), int((h-int(h))*60) }')
        TOOLTIP="Battery: $CAPACITY% - ${TIME_EST} remaining"
    fi
fi

# Output JSON for Waybar
jq -n -c --arg text "$TEXT" --arg class "$CLASS" --arg tooltip "$TOOLTIP" '{"text": $text, "class": $class, "tooltip": $tooltip}'
