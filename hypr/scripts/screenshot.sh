#!/bin/bash
mkdir -p ~/Pictures/Screenshots
FILE="$HOME/Pictures/Screenshots/screenshot-$(date +%Y%m%d-%H%M%S).png"

# Take screenshot of selected area
grim -g "$(slurp)" "$FILE"

# Check if screenshot was actually taken (user didn't cancel slurp)
if [ -f "$FILE" ]; then
    # Write directly to CopyQ clipboard manager
    copyq write image/png - < "$FILE"
    copyq select 0
    
    # Notify user with a preview of the image!
    dunstify -a "osd" -r 9999 "SCREENSHOT" "Saved to Pictures/Screenshots"
fi
