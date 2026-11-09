#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
#  TOKYO 80s TRV30 — SCREENSHOT OCR (TEXT EXTRACTION)
#  Snips area, extracts text via Tesseract, copies text to clipboard & CopyQ
# ══════════════════════════════════════════════════════════════════════════════

mkdir -p ~/Pictures/Screenshots
FILE="$HOME/Pictures/Screenshots/ocr-$(date +%Y%m%d-%H%M%S).png"

# Take screenshot of selected area
GEOM=$(slurp 2>/dev/null)
if [ -z "$GEOM" ]; then
    exit 0
fi

grim -g "$GEOM" "$FILE"

if [ -f "$FILE" ]; then
    # 1. Save image to CopyQ
    if command -v copyq >/dev/null 2>&1; then
        copyq write image/png - < "$FILE" 2>/dev/null || true
    fi
    
    # 2. Extract text with Tesseract OCR
    TEXT=$(tesseract "$FILE" stdout -l eng 2>/dev/null | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    
    if [ -n "$TEXT" ]; then
        # 3. Copy extracted text directly to Wayland clipboard for instant Ctrl+V
        wl-copy "$TEXT"

        # Also add to CopyQ history
        if command -v copyq >/dev/null 2>&1; then
            copyq add "$TEXT" 2>/dev/null || true
            copyq select 0 2>/dev/null || true
        fi
        
        # 4. Show extracted text in HUD notification
        PREVIEW=$(echo "$TEXT" | head -n 3 | cut -c 1-60)
        dunstify -a "osd" -r 9999 -i "$FILE" "📝 OCR TEXT COPIED" "$PREVIEW"
    else
        # Fallback: copy image to clipboard if no text was detected
        wl-copy --type image/png < "$FILE"
        dunstify -a "osd" -r 9999 -i "$FILE" "📷 NO TEXT DETECTED" "Copied screenshot image to clipboard."
    fi
fi
