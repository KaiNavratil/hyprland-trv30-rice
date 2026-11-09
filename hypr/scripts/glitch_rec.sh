#!/bin/bash
LOCK_FILE="/tmp/glitch_start"
if [ ! -f "$LOCK_FILE" ]; then
    date +%s%3N > "$LOCK_FILE"
fi
START_TIME=$(cat "$LOCK_FILE" 2>/dev/null || date +%s%3N)
NOW=$(date +%s%3N)
ELAPSED=$((NOW - START_TIME))

# Glitch Phase (1.0 seconds)
if [ "$ELAPSED" -lt 1000 ]; then
    if [ $(( RANDOM % 100 )) -gt 40 ]; then
        echo "<span foreground='#ff0000'>●</span> REC"
    else
        echo ""
    fi
else
    # Standard blinking REC behavior
    if [ $(( (NOW / 1000) % 2 )) -eq 0 ]; then
        echo "<span foreground='#ff0000'>●</span> REC"
    else
        echo "  REC"
    fi
fi
