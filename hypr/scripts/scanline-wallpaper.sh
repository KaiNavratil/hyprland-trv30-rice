#!/bin/bash
# ═══════════════════════════════════════════════════════════
#  スキャンライン壁紙ジェネレータ (Scanline Wallpaper Generator)
#  Bakes subtle CRT scanlines INTO a wallpaper image so they
#  appear only on the desktop background — not over windows.
#
#  Usage:  ./scanline-wallpaper.sh /path/to/wallpaper.jpg
#  Output: ~/.config/hypr/wallpaper-crt.png
#
#  Requires: imagemagick (convert)
# ═══════════════════════════════════════════════════════════

set -e

INPUT="$1"
OUTPUT="$HOME/.config/hypr/wallpaper-crt.png"

if [ -z "$INPUT" ]; then
    echo "Usage: $0 <input-wallpaper>"
    echo "  Bakes CRT scanlines into the wallpaper."
    echo "  Output: $OUTPUT"
    exit 1
fi

if ! command -v convert &> /dev/null; then
    echo "Error: imagemagick is required (provides 'convert')"
    echo "  Install: sudo pacman -S imagemagick"
    exit 1
fi

# Get input image dimensions
DIMS=$(identify -format "%wx%h" "$INPUT" 2>/dev/null)
WIDTH=$(echo "$DIMS" | cut -dx -f1)
HEIGHT=$(echo "$DIMS" | cut -dx -f2)

echo "Processing: $INPUT (${WIDTH}x${HEIGHT})"
echo "Applying CRT scanlines..."

# Generate a scanline overlay:
# - Create alternating transparent/dark-transparent horizontal lines
# - Every other row is darkened by ~6% (subtle but visible on wallpaper)
# - Tile to match input dimensions, then composite over the original
convert "$INPUT" \
    \( -size "${WIDTH}x2" xc:"rgba(0,0,0,0)" \
       -size "${WIDTH}x2" xc:"rgba(0,0,0,0.06)" \
       -append -write mpr:scanline +delete \
       -size "${WIDTH}x${HEIGHT}" tile:mpr:scanline \) \
    -composite \
    "$OUTPUT"

echo "Done: $OUTPUT"
echo ""
echo "To use, add to hyprland.conf autostart:"
echo "  exec-once = swaybg -i $OUTPUT -m fill"
echo ""
echo "Or with hyprpaper, set in hyprpaper.conf:"
echo "  preload = $OUTPUT"
echo "  wallpaper = ,$OUTPUT"
