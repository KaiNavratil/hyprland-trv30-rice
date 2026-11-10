#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
#  TOKYO 80s TRV30 — SCREENSHOT OCR (TEXT EXTRACTION)
#  Snips area, extracts text via Tesseract, copies text to clipboard & CopyQ
#  Keybind: Super + Shift + S
# ══════════════════════════════════════════════════════════════════════════════

mkdir -p ~/Pictures/Screenshots
FILE="$HOME/Pictures/Screenshots/ocr-$(date +%Y%m%d-%H%M%S).png"

# Kill any stale slurp instance to avoid frozen crosshairs
pkill -x slurp 2>/dev/null || true

# Snip selection with Tokyo amber border
GEOM=$(slurp -b '#0d0d0caa' -c '#f2a533' -w 2 -s '#f2a53322' 2>/dev/null)
if [ -z "$GEOM" ]; then
    exit 0
fi

# Capture the selected region
grim -g "$GEOM" "$FILE"

if [ -f "$FILE" ]; then
    # 1. Save original capture image to CopyQ
    if command -v copyq >/dev/null 2>&1; then
        copyq write image/png - < "$FILE" 2>/dev/null || true
    fi
    
    # 2. Extract text with Tesseract OCR (clean whitespace trim)
    TEXT=$(tesseract "$FILE" stdout -l eng 2>/dev/null | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    
    if [ -n "$TEXT" ]; then
        # 3. Copy extracted text directly to Wayland clipboard for instant Ctrl+V
        printf "%s" "$TEXT" | wl-copy

        # Also register in CopyQ clipboard history
        if command -v copyq >/dev/null 2>&1; then
            copyq add "$TEXT" 2>/dev/null || true
            copyq select 0 2>/dev/null || true
        fi
        
        # 4. Display extracted text snippet in Tokyo HUD notification
        PREVIEW=$(echo "$TEXT" | head -n 3 | cut -c 1-80)
        dunstify -a "TRV30_OSD" -r 9999 -i "$FILE" "📝 OCR TEXT EXTRACTED" "$PREVIEW\n(Copied to clipboard)" -t 3500
    else
        # Fallback: copy image to clipboard if no legible text was found
        wl-copy --type image/png < "$FILE"
        dunstify -a "TRV30_OSD" -r 9999 -i "$FILE" "📷 NO TEXT DETECTED" "Copied screenshot image to clipboard." -t 2500
    fi
fi
