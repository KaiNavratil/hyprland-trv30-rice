#!/bin/bash
# Blinking REC indicator
if [ $(( $(date +%s) % 2 )) -eq 0 ]; then
    echo "<span foreground='#ff0000'>●</span> REC"
else
    echo "  REC"
fi
