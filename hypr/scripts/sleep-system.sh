#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
#  TOKYO 80s TRV30 — SLEEP & SCREEN OFF SYSTEM
#  Locks screen, silences audio, turns off all displays, and enters sleep
#  Wakes up ONLY on keyboard keypress — ignores all mouse movement / bumps
# ══════════════════════════════════════════════════════════════════════════════

# 1. Pause any playing music/videos
playerctl -a pause 2>/dev/null

# 2. Ensure mouse movement does NOT wake DPMS monitors in Hyprland
hyprctl eval 'hl.config({ misc = { mouse_move_enables_dpms = false, key_press_enables_dpms = true } })' >/dev/null 2>&1

# 3. Mode check: full system suspend or screen-off only
MODE="${1:-suspend}"

if [ "$MODE" = "screen" ]; then
    # Screen-off only (laptop stays running in background, but both screens black)
    dunstify -a "osd" -r 9998 -u normal "💤 TURNING OFF SCREENS" "Press any key on keyboard to wake"
    sleep 0.5
    # Lock session and turn off DPMS
    loginctl lock-session
    sleep 0.5
    hyprctl dispatch dpms off
    exit 0
fi

# Full Sleep / Suspend mode
dunstify -a "osd" -r 9998 -u normal "💤 GOING TO SLEEP" "Press any keyboard key or power button to wake"
sleep 0.5

# Suspend system with -i to ignore any inhibitors (hypridle will trigger lock)
systemctl suspend -i
