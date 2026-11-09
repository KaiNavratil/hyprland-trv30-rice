#!/bin/bash
mkdir -p ~/Pictures/Screenshots
FILE="$HOME/Pictures/Screenshots/screenshot-$(date +%Y%m%d-%H%M%S).png"

# Take screenshot of selected area
GEOM=$(slurp 2>/dev/null)
if [ -z "$GEOM" ]; then
    exit 0
fi

grim -g "$GEOM" "$FILE"

# Check if screenshot was actually taken
if [ -f "$FILE" ]; then
    # 1. Primary Wayland clipboard copy (image/png) for instant Ctrl+V
    wl-copy --type image/png < "$FILE"

    # 2. Add to CopyQ clipboard manager if available
    if command -v copyq >/dev/null 2>&1; then
        copyq write image/png - < "$FILE" 2>/dev/null || true
        copyq select 0 2>/dev/null || true
    fi
    
    # 3. Notify user with thumbnail preview
    dunstify -a "osd" -r 9999 -i "$FILE" "📷 SCREENSHOT COPIED" "Copied to clipboard & saved to Pictures/Screenshots"
fi
