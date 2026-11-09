#!/bin/bash
# Toggle the Hyprshade VCR CRT effect using native hyprctl
if hyprctl getoption decoration:screen_shader | grep -q "crt-heavy"; then
    hyprctl eval 'hl.config({ decoration = { screen_shader = "" } })'
else
    hyprctl eval 'hl.config({ decoration = { screen_shader = "'"$HOME"'/.config/hypr/shaders/crt-heavy.glsl" } })'
fi
