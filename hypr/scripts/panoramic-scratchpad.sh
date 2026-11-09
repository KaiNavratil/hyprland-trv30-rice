#!/usr/bin/env python3
"""
Tokyo 80s TRV30 — Panoramic (Multi-Monitor) Scratchpad Coordinator
パノラマ・マルチモニター・スクラッチパッド展開エンジン

Coordinates dual-screen scratchpad decks simultaneously across:
- Main Monitor (HDMI-A-1 / Left): Primary Deck (Spotify, Discord, Dev, Cockpit)
- Companion Monitor (eDP-1 / Right): Telemetry / Auxiliary Deck (Cava VU, Notion Calendar, Notes/CopyQ, Btop)

Chords:
- Super + Shift + Z: Panoramic Music Studio (Spotify + Cava Spectrum)
- Super + Shift + X: Panoramic Comms Ops (Discord + Calendar)
- Super + Shift + V: Panoramic Research Deck (Dev/IDE + Notes & Clipboard)
- Super + Shift + Escape: Panoramic War Room (Tokyo Cockpit + Btop Telemetry)
"""

import sys
import json
import subprocess
import time
import os

if len(sys.argv) < 2:
    sys.exit(0)

target = sys.argv[1].lower()

# Define Panoramic Deck Pairs: target -> (main_special, comp_special, main_cmd, comp_cmd, main_class, comp_class)
DECKS = {
    "music": {
        "name": "MUSIC STUDIO // 音響機構",
        "main_sp": "music",
        "comp_sp": "cava",
        "main_cmd": "spotify-launcher --skip-update",
        "comp_cmd": "kitty --class trv30-cava -e cava",
        "main_class": "spotify",
        "comp_class": "trv30-cava",
        "main_gaps": "gapsout:60",
        "comp_gaps": "gapsout:60",
    },
    "comms": {
        "name": "COMMS OPS // 通信作戦",
        "main_sp": "discord",
        "comp_sp": "calendar",
        "main_cmd": "vesktop",
        "comp_cmd": "vivaldi-stable --app=https://calendar.notion.so",
        "main_class": "vesktop",
        "comp_class": "calendar",
        "main_gaps": "gapsout:60",
        "comp_gaps": "gapsout:60",
    },
    "discord": {
        "name": "COMMS OPS // 通信作戦",
        "main_sp": "discord",
        "comp_sp": "calendar",
        "main_cmd": "vesktop",
        "comp_cmd": "vivaldi-stable --app=https://calendar.notion.so",
        "main_class": "vesktop",
        "comp_class": "calendar",
        "main_gaps": "gapsout:60",
        "comp_gaps": "gapsout:60",
    },
    "research": {
        "name": "RESEARCH DECK // 開発記録",
        "main_sp": "dev",
        "comp_sp": "notes",
        "main_cmd": "/opt/antigravity-ide/antigravity-ide",
        "comp_cmd": "bash ~/.config/hypr/scripts/launch-notes.sh",
        "main_class": "antigravity",
        "comp_class": "notes-term",
        "main_gaps": "gapsout:0, gapsin:0, border:false",
        "comp_gaps": "gapsout:60, gapsin:4",
    },
    "notes": {
        "name": "RESEARCH DECK // 開発記録",
        "main_sp": "dev",
        "comp_sp": "notes",
        "main_cmd": "/opt/antigravity-ide/antigravity-ide",
        "comp_cmd": "bash ~/.config/hypr/scripts/launch-notes.sh",
        "main_class": "antigravity",
        "comp_class": "notes-term",
        "main_gaps": "gapsout:0, gapsin:0, border:false",
        "comp_gaps": "gapsout:60, gapsin:4",
    },
    "cockpit": {
        "name": "COMMAND CENTER // 司令室",
        "main_sp": "center",
        "comp_sp": "sysmon",
        "main_cmd": "env WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1 python3 ~/.config/hypr/command-center/app.py",
        "comp_cmd": "kitty --class trv30-btop -e btop",
        "main_class": "commandcenter",
        "comp_class": "trv30-btop",
        "main_gaps": "gapsout:0, gapsin:0, border:false",
        "comp_gaps": "gapsout:60",
    },
    "center": {
        "name": "COMMAND CENTER // 司令室",
        "main_sp": "center",
        "comp_sp": "sysmon",
        "main_cmd": "env WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1 python3 ~/.config/hypr/command-center/app.py",
        "comp_cmd": "kitty --class trv30-btop -e btop",
        "main_class": "commandcenter",
        "comp_class": "trv30-btop",
        "main_gaps": "gapsout:0, gapsin:0, border:false",
        "comp_gaps": "gapsout:60",
    }
}

deck = DECKS.get(target)
if not deck:
    # Unknown deck, fallback to standard single scratchpad
    subprocess.run(["bash", os.path.expanduser("~/.config/hypr/scripts/toggle-scratchpad.sh"), target])
    sys.exit(0)

try:
    mon_raw = subprocess.check_output(["hyprctl", "monitors", "-j"], text=True)
    monitors = json.loads(mon_raw)
except Exception:
    subprocess.run(["bash", os.path.expanduser("~/.config/hypr/scripts/toggle-scratchpad.sh"), target])
    sys.exit(0)

# Single monitor fallback: just open the main tool
if len(monitors) <= 1:
    subprocess.run(["bash", os.path.expanduser("~/.config/hypr/scripts/toggle-scratchpad.sh"), deck["main_sp"]])
    sys.exit(0)

# Identify monitors
main_mon = None
comp_mon = None
focused_mon = None

for m in monitors:
    if m.get("focused"):
        focused_mon = m["name"]
    if m["name"] == "HDMI-A-1" or (not m["name"].startswith("eDP") and main_mon is None):
        main_mon = m
    else:
        comp_mon = m

if not main_mon:
    main_mon = monitors[0]
if not comp_mon:
    comp_mon = monitors[1]

main_name = main_mon["name"]
comp_name = comp_mon["name"]

main_active_sp = (main_mon.get("specialWorkspace", {}) or {}).get("name", "").replace("special:", "")
comp_active_sp = (comp_mon.get("specialWorkspace", {}) or {}).get("name", "").replace("special:", "")

main_target_sp = deck["main_sp"]
comp_target_sp = deck["comp_sp"]

# Check if both are currently open
if main_active_sp == main_target_sp and comp_active_sp == comp_target_sp:
    # Both are open: Dismiss both simultaneously!
    batch = [
        f"dispatch focusmonitor {main_name}",
        f"dispatch togglespecialworkspace {main_target_sp}",
        f"dispatch focusmonitor {comp_name}",
        f"dispatch togglespecialworkspace {comp_target_sp}",
        f"dispatch focusmonitor {focused_mon or main_name}"
    ]
    subprocess.run(["hyprctl", "--batch", " ; ".join(batch)], stdout=subprocess.DEVNULL)
    subprocess.run(["dunstify", "-a", "osd", "-r", "9997", "-u", "normal",
                    "[ ❖ PANORAMIC STOWED / パノラマ格納 ]",
                    f"{deck['name']} DISMISSED ACROSS ALL DISPLAYS"])
    # Clean up anchors
    for sp in [main_target_sp, comp_target_sp]:
        try:
            os.remove(f"/tmp/scratchpad_anchored_{sp}")
        except Exception:
            pass
    sys.exit(0)

# Otherwise, summon both!
# 1. Check if companion windows exist or launch them
try:
    clients_raw = subprocess.check_output(["hyprctl", "clients", "-j"], text=True)
    clients = json.loads(clients_raw)
except Exception:
    clients = []

def has_window(sp_name, class_sub):
    for c in clients:
        ws_name = c.get("workspace", {}).get("name", "")
        c_class = c.get("class", "").lower()
        if ws_name == f"special:{sp_name}":
            return True
        if class_sub and class_sub.lower() in c_class:
            return True
    return False

# Launch primary if missing
if not has_window(main_target_sp, deck["main_class"]):
    subprocess.run(["hyprctl", "dispatch", "exec", f"[workspace special:{main_target_sp} silent] {deck['main_cmd']}"])

# Launch companion if missing
if not has_window(comp_target_sp, deck["comp_class"]):
    subprocess.run(["hyprctl", "dispatch", "exec", f"[workspace special:{comp_target_sp} silent] {deck['comp_cmd']}"])

# Configure workspace rules & monitor locks
subprocess.run(["hyprctl", "keyword", "workspace", f"special:{main_target_sp}, {deck['main_gaps']}, monitor:{main_name}"], stdout=subprocess.DEVNULL)
subprocess.run(["hyprctl", "keyword", "workspace", f"special:{comp_target_sp}, {deck['comp_gaps']}, monitor:{comp_name}"], stdout=subprocess.DEVNULL)

batch = []

# If main monitor has a different scratchpad open, stow it
if main_active_sp and main_active_sp != main_target_sp:
    batch.append(f"dispatch focusmonitor {main_name}")
    batch.append(f"dispatch togglespecialworkspace {main_active_sp}")

# If companion monitor has a different scratchpad open, stow it
if comp_active_sp and comp_active_sp != comp_target_sp:
    batch.append(f"dispatch focusmonitor {comp_name}")
    batch.append(f"dispatch togglespecialworkspace {comp_active_sp}")

# Open main deck if not already open
if main_active_sp != main_target_sp:
    batch.append(f"dispatch focusmonitor {main_name}")
    batch.append(f"dispatch togglespecialworkspace {main_target_sp}")

# Open companion deck if not already open
if comp_active_sp != comp_target_sp:
    batch.append(f"dispatch focusmonitor {comp_name}")
    batch.append(f"dispatch togglespecialworkspace {comp_target_sp}")

# Restore user focus
batch.append(f"dispatch focusmonitor {focused_mon or main_name}")

if batch:
    subprocess.run(["hyprctl", "--batch", " ; ".join(batch)], stdout=subprocess.DEVNULL)

subprocess.run(["dunstify", "-a", "osd", "-r", "9997", "-u", "normal",
                "[ ❖ PANORAMIC ENGAGED / パノラマ展開 ]",
                f"{deck['name']} ONLINE ACROSS DUAL SCREENS"])
