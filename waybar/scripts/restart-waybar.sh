#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════
#  WAYBAR RESTART SCRIPT (TRV30 Phosphor Theme)
#  Kills any stuck Waybar instances and cleanly reloads
# ═══════════════════════════════════════════════════════════

set -euo pipefail

# Gracefully terminate waybar
pkill -x waybar 2>/dev/null || killall -q waybar 2>/dev/null || true
sleep 0.2

# Force kill if still lingering
if pgrep -x waybar >/dev/null 2>&1; then
    pkill -9 -x waybar 2>/dev/null || true
    sleep 0.1
fi

# Relaunch waybar with top configuration
nohup waybar -c "$HOME/.config/waybar/config-top" -s "$HOME/.config/waybar/style.css" >/dev/null 2>&1 &
disown

# Notify user of successful restart
if command -v dunstify >/dev/null 2>&1; then
    dunstify -u normal -t 2000 -r 8888 "⚡ WAYBAR RESET" "システムバー再起動 — Waybar reloaded cleanly"
elif command -v notify-send >/dev/null 2>&1; then
    notify-send -t 2000 "⚡ WAYBAR RESET" "システムバー再起動 — Waybar reloaded cleanly"
fi
