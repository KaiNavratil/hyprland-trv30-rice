#!/usr/bin/env python3
"""
Tokyo 80s TRV30 — Reopen Last Closed Window (Super + T / Super + Shift + T)
- Pops the most recently closed window from ~/.cache/recently_closed.json (or fallback).
- Places it into ~/.cache/pending_reopen.json so window-router immediately catches and routes it.
- Dispatches exec into the exact Desktop Space it came from.
- Displays a retro HUD notification showing which app and space are being restored.
"""

import os
import json
import subprocess
import time
import sys

RECENTLY_CLOSED_FILE = os.path.expanduser("~/.cache/recently_closed.json")
PENDING_REOPEN_FILE = os.path.expanduser("~/.cache/pending_reopen.json")
LEGACY_FILE = os.path.expanduser("~/.cache/last_closed_app")

target = None
history = []

if os.path.exists(RECENTLY_CLOSED_FILE):
    try:
        with open(RECENTLY_CLOSED_FILE, "r", encoding="utf-8") as f:
            history = json.load(f)
        if history:
            target = history.pop(0)
            with open(RECENTLY_CLOSED_FILE, "w", encoding="utf-8") as f:
                json.dump(history, f, indent=2)
    except Exception:
        pass

# Fallback to legacy file if history was empty
if not target and os.path.exists(LEGACY_FILE):
    try:
        with open(LEGACY_FILE, "r", encoding="utf-8") as f:
            line = f.read().strip()
        if line.startswith("[workspace "):
            parts = line.split("] ", 1)
            ws = parts[0].replace("[workspace ", "")
            cmd = parts[1]
            target = {
                "class": cmd.split()[0],
                "title": "",
                "workspace": ws,
                "exec_cmd": cmd
            }
            # Remove legacy file once consumed
            try:
                os.remove(LEGACY_FILE)
            except Exception:
                pass
    except Exception:
        pass

if not target:
    subprocess.run(["dunstify", "-u", "low", "-t", "1500", "REOPEN", "No recently closed windows in history"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    sys.exit(0)

ws = target.get("workspace", "1")
cmd = target.get("exec_cmd", "")
title = target.get("title", "")
c_class = target.get("class", "")

# Save to pending_reopen so window-router catches it as soon as it appears
pending_data = {
    "class": c_class,
    "title": title,
    "workspace": ws,
    "time": time.time()
}
try:
    with open(PENDING_REOPEN_FILE, "w", encoding="utf-8") as f:
        json.dump(pending_data, f)
except Exception:
    pass

# Launch the app
if cmd:
    subprocess.run(["hyprctl", "dispatch", "exec", f"[workspace {ws}] {cmd}"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

# Calculate user-facing Space number
try:
    ws_int = int(ws)
    if ws_int > 10:
        space_num = ws_int - 10
        space_str = f"Space {space_num} (Companion Monitor)"
    else:
        space_num = ws_int
        space_str = f"Space {space_num} (Main Monitor)"
except Exception:
    space_str = f"Workspace {ws}"

display_name = title if (title and " - " in title) else (c_class if c_class else cmd)
if len(display_name) > 42:
    display_name = display_name[:39] + "..."

subprocess.run(["dunstify", "-u", "low", "-t", "2000", "● REOPEN", f"Restoring to {space_str}:\n{display_name}"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
