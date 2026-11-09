#!/bin/bash
# Simulates a hard visual CRT glitch by rapidly dropping the text signal
LOCK_FILE="/tmp/glitch_start"
if [ ! -f "$LOCK_FILE" ]; then
    date +%s%3N > "$LOCK_FILE"
fi
START_TIME=$(cat "$LOCK_FILE" 2>/dev/null || date +%s%3N)
NOW=$(date +%s%3N)
ELAPSED=$((NOW - START_TIME))

TEXT="$*"

# Glitch Phase (1.0 seconds)
if [ "$ELAPSED" -lt 1000 ]; then
    # Create an erratic on/off flashing pattern
    # 50% chance the text vanishes completely on this frame
    if [ $(( RANDOM % 100 )) -gt 40 ]; then
        echo "$TEXT"
    else
        echo ""
    fi
else
    # Stabilize
    echo "$TEXT"
fi
