#!/usr/bin/env bash
# Tokyo TRV30 Smart Launcher Runner
# Intercepts all rofi execution commands to eliminate "Failed to execute" error popups

CMD="$*"
[ -z "$CMD" ] && exit 0

# Check if first word is an executable in PATH
FIRST_WORD=$(echo "$CMD" | awk '{print $1}')
if command -v "$FIRST_WORD" >/dev/null 2>&1; then
    exec "$@" >/dev/null 2>&1 &
    exit 0
fi

# Fallback to python smart handler
exec python3 /home/kaijnav/.config/rofi/scripts/smart-fallback.py "$CMD"
