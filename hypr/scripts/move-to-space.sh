#!/usr/bin/env python3
"""
Tokyo 80s TRV30 — Move Window to Desktop Space (1-9)
Moves the active window to the correct workspace for the monitor it's on:
- Main Monitor (HDMI-A-1 / Left): Workspace 1-9
- Companion Monitor (eDP-1 / Right): Workspace 11-19
"""

import sys
import json
import subprocess

if len(sys.argv) < 2:
    sys.exit(0)

try:
    target_space = int(sys.argv[1])
except ValueError:
    sys.exit(1)

try:
    mon_raw = subprocess.check_output(["hyprctl", "monitors", "-j"], text=True)
    monitors = json.loads(mon_raw)
    win_raw = subprocess.check_output(["hyprctl", "activewindow", "-j"], text=True)
    active_win = json.loads(win_raw)
except Exception:
    subprocess.run(["hyprctl", "dispatch", "movetoworkspace", str(target_space)])
    sys.exit(0)

if len(monitors) <= 1 or not active_win:
    subprocess.run(["hyprctl", "dispatch", "movetoworkspace", str(target_space)])
    sys.exit(0)

win_mon_id = active_win.get("monitor", -1)
win_mon = next((m for m in monitors if m.get("id") == win_mon_id), None)

# If window is on the laptop companion monitor (eDP-1), route to 11-19
if win_mon and win_mon.get("name", "").startswith("eDP"):
    dest = target_space + 10
else:
    dest = target_space

subprocess.run(["hyprctl", "dispatch", "movetoworkspace", str(dest)])
