#!/usr/bin/env python3
"""
Tokyo 80s Sony TRV30 Camcorder CRT Wallpaper Generator
Generates high-definition scanline CRT standby displays with safe-title brackets,
crosshair reticles, and authentic Japanese 80s camcorder OSD markings.
"""
import cairo
import math
import os

def render_crt_display(width, height, outfile, is_companion=False):
    surface = cairo.ImageSurface(cairo.FORMAT_ARGB32, width, height)
    ctx = cairo.Context(surface)

    # 1. Base dark background (Tokyo CRT deep charcoal)
    ctx.set_source_rgb(0.045, 0.038, 0.032) # #0b0a08
    ctx.paint()

    # 2. CRT Glass Curvature Vignette (Radial phosphor falloff)
    rad = cairo.RadialGradient(width/2, height/2, width*0.12, width/2, height/2, width*0.68)
    rad.add_color_stop_rgba(0.0, 0.10, 0.075, 0.04, 0.35) # Warm phosphor center glow
    rad.add_color_stop_rgba(0.65, 0.02, 0.015, 0.01, 0.15)
    rad.add_color_stop_rgba(1.0, 0.00, 0.000, 0.00, 0.88) # Outer glass bezel
    ctx.set_source(rad)
    ctx.paint()

    # 3. Horizontal Scanlines (alternating 1px dark raster lines)
    ctx.set_source_rgba(0.0, 0.0, 0.0, 0.38)
    for y in range(0, height, 2):
        ctx.rectangle(0, y, width, 1)
    ctx.fill()

    # 4. Subtle phosphor mesh lines (vertical micro-stripes)
    ctx.set_source_rgba(0.95, 0.65, 0.2, 0.018)
    for x in range(0, width, 3):
        ctx.rectangle(x, 0, 1, height)
    ctx.fill()

    # 5. 4:3 CRT Safe Title Frame
    h_43 = height * 0.76
    w_43 = h_43 * (4.0 / 3.0)
    x0 = (width - w_43) / 2
    y0 = (height - h_43) / 2

    # Draw safe frame box (dashed faint amber)
    ctx.set_source_rgba(0.95, 0.65, 0.2, 0.15)
    ctx.set_line_width(1.0)
    ctx.set_dash([6.0, 6.0])
    ctx.rectangle(x0, y0, w_43, h_43)
    ctx.stroke()
    ctx.set_dash([])

    # Corner brackets (solid phosphor amber)
    bracket_len = 28.0
    ctx.set_source_rgba(0.95, 0.65, 0.2, 0.45)
    ctx.set_line_width(1.5)

    corners = [
        (x0, y0, 1, 1),
        (x0 + w_43, y0, -1, 1),
        (x0, y0 + h_43, 1, -1),
        (x0 + w_43, y0 + h_43, -1, -1)
    ]
    for cx, cy, dx, dy in corners:
        ctx.move_to(cx + dx * bracket_len, cy)
        ctx.line_to(cx, cy)
        ctx.line_to(cx, cy + dy * bracket_len)
        ctx.stroke()

    # Center Reticle (+)
    cx, cy = width / 2, height / 2
    ctx.set_source_rgba(0.95, 0.65, 0.2, 0.28)
    ctx.set_line_width(1.0)
    # Horizontal crosshair
    ctx.move_to(cx - 24, cy)
    ctx.line_to(cx - 6, cy)
    ctx.move_to(cx + 6, cy)
    ctx.line_to(cx + 24, cy)
    # Vertical crosshair
    ctx.move_to(cx, cy - 24)
    ctx.line_to(cx, cy - 6)
    ctx.move_to(cx, cy + 6)
    ctx.line_to(cx, cy + 24)
    ctx.stroke()
    # Center circle
    ctx.arc(cx, cy, 4, 0, 2 * math.pi)
    ctx.stroke()

    # 6. OSD Text (TRV30 Camcorder Standby)
    # Top Left: Mode & Timecode
    ctx.select_font_face('JetBrainsMono Nerd Font', cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
    ctx.set_font_size(16.0)
    ctx.set_source_rgba(0.95, 0.65, 0.2, 0.60)
    ctx.move_to(x0 + 10, y0 + 30)
    ctx.show_text('STANDBY' if not is_companion else 'MONITOR')

    ctx.set_font_size(12.0)
    ctx.set_source_rgba(0.90, 0.85, 0.80, 0.35)
    ctx.move_to(x0 + 10, y0 + 52)
    ctx.show_text('SP  0:00:00:00' if not is_companion else 'CH-2  DECK BUS')

    # Top Right: Tape & Battery
    ctx.set_font_size(13.0)
    ctx.set_source_rgba(0.95, 0.65, 0.2, 0.50)
    ctx.move_to(x0 + w_43 - 150, y0 + 30)
    ctx.show_text('DVC [■■■■]')

    ctx.set_font_size(11.0)
    ctx.set_source_rgba(0.90, 0.85, 0.80, 0.30)
    ctx.move_to(x0 + w_43 - 150, y0 + 52)
    ctx.show_text('16BIT 48kHz' if not is_companion else 'AUDIO L/R AUX')

    # Bottom Left: Channel & Japanese OSD
    ctx.select_font_face('DotGothic16', cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
    ctx.set_font_size(16.0)
    ctx.set_source_rgba(0.95, 0.65, 0.2, 0.55)
    ctx.move_to(x0 + 10, y0 + h_43 - 32)
    ctx.show_text('ビデオ 1 (VIDEO-1)' if not is_companion else 'サブモニター (DECK-2)')

    ctx.select_font_face('JetBrainsMono Nerd Font', cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_NORMAL)
    ctx.set_font_size(11.0)
    ctx.set_source_rgba(0.90, 0.85, 0.80, 0.30)
    ctx.move_to(x0 + 10, y0 + h_43 - 12)
    ctx.show_text('CH 1/2 STEREO MONITOR' if not is_companion else 'COMPANION DUAL DISPLAY')

    # Bottom Right: Camcorder Model & Spec
    ctx.set_font_size(13.0)
    ctx.set_source_rgba(0.95, 0.65, 0.2, 0.45)
    ctx.move_to(x0 + w_43 - 170, y0 + h_43 - 32)
    ctx.show_text('SONY DCR-TRV30')

    ctx.set_font_size(10.5)
    ctx.set_source_rgba(0.90, 0.85, 0.80, 0.30)
    ctx.move_to(x0 + w_43 - 170, y0 + h_43 - 12)
    ctx.show_text('NTSC 60Hz EIAJ' if not is_companion else '1200p 60Hz 16:10')

    os.makedirs(os.path.dirname(outfile), exist_ok=True)
    surface.write_to_png(outfile)
    print(f'Rendered: {outfile} ({width}x{height})')

if __name__ == '__main__':
    hdmi_path = os.path.expanduser('~/.config/hypr/assets/wallpaper-hdmi.png')
    edp_path = os.path.expanduser('~/.config/hypr/assets/wallpaper-edp.png')
    render_crt_display(1920, 1080, hdmi_path, is_companion=False)
    render_crt_display(1920, 1200, edp_path, is_companion=True)
