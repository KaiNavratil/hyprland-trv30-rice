#!/bin/bash
# Kill any lingering or orphaned hyprlock instances before taking fresh screenshot
pkill -9 hyprlock 2>/dev/null
sleep 0.1

rm -f /tmp/glitch_start

# Generate CRT scanline pattern, fullscreen overlay, and vignette mask ONCE (caches them for instant use)
if [ ! -f /tmp/scanline_fullscreen.png ]; then
    # Generate incredibly fast by caching a single 1920x4 row first, then tiling vertically
    magick -size 2x4 xc:transparent -fill "rgba(0,0,0,0.15)" -draw "rectangle 0,0 2,1" /tmp/scanline.png
    magick -size 1920x4 tile:/tmp/scanline.png /tmp/scanline_row.png
    magick -size 1920x1920 tile:/tmp/scanline_row.png /tmp/scanline_fullscreen.png
    
    # Create a completely harsh, solid black square CRT bezel outline for 1920x1200
    magick -size 1920x1200 xc:transparent -stroke "black" -strokewidth 300 -fill none -draw "rectangle 0,0 1920,1200" /tmp/vignette.png
fi

# Pipe a raw screenshot directly from memory into ImageMagick to bake the CRT effects instantly
grim - | magick - /tmp/vignette.png -compose over -composite \
       -color-matrix "0.95 0 0 0, 0 0.65 0 0, 0 0 0.2 0, 0 0 0 1" \
       -distort Barrel "0.0 0.0 -0.15 1.15" \
       /tmp/lock_fisheye.png

# Summon hyprlock using the pre-rendered fisheye image
hyprlock
