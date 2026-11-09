#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
#  TOKYO 80s TRV30 — SCREENSHOT OCR (TEXT EXTRACTION)
#  Snips area, extracts text via Tesseract, adds both image & text to CopyQ
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
    # 1. Save image directly to CopyQ clipboard history
    copyq write image/png - < "$FILE"
    
    # 2. Extract text with Tesseract OCR
    TEXT=$(tesseract "$FILE" stdout -l eng 2>/dev/null | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    
    if [ -n "$TEXT" ]; then
        # 3. Add extracted text to CopyQ and set as primary clipboard
        copyq add "$TEXT"
        copyq select 0
        
        # 4. Show extracted text in HUD notification
        PREVIEW=$(echo "$TEXT" | head -n 3 | cut -c 1-60)
        dunstify -a "osd" -r 9999 "📝 OCR TEXT EXTRACTED" "$PREVIEW"
    else
        dunstify -a "osd" -r 9999 "⚠️ OCR: NO TEXT DETECTED" "Screenshot saved to Super+V, but no readable text found."
    fi
fi
