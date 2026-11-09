#!/bin/bash
# Records the start time on first run, glitches for 1.2 seconds, then stabilizes.

LOCK_FILE="/tmp/glitch_start"

# If hyprlock was just launched, reset the timer
if [ ! -f "$LOCK_FILE" ]; then
    date +%s%3N > "$LOCK_FILE"
fi

START_TIME=$(cat "$LOCK_FILE" 2>/dev/null || date +%s%3N)
NOW=$(date +%s%3N)
ELAPSED=$((NOW - START_TIME))

# Glitch Phase (0.5 seconds)
if [ "$ELAPSED" -lt 500 ]; then
    # The glitch gets slower as time goes on.
    MOD=$(( (ELAPSED / 100) + 1 )) 
    if [ $(( (NOW / 50) % MOD )) -eq 0 ]; then
        head -c 100 /dev/urandom | tr -dc '0-9A-F:<>?!*#' | fold -w 8 | head -n 1 > /tmp/glitch_text_cache
    fi
    cat /tmp/glitch_text_cache 2>/dev/null || echo "88:88:88"
else
    # Stabilize into the real time
    date '+%I:%M:%S %p'
fi
