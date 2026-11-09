#!/usr/bin/env python3
"""
Tokyo 80s TRV30 — Dual-Monitor Desktop Space Switcher
- Spaces 1-9 span across BOTH monitors synchronously:
    Main Monitor (HDMI-A-1 / Left): Workspaces 1-9
    Companion Monitor (eDP-1 / Right): Workspaces 11-19
- Scratchpad Persistence:
    If a monitor currently has a scratchpad (special workspace) open,
    that scratchpad is NOT closed. It stays open on that monitor while you work
    on the other monitor in any space!
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
except Exception:
    subprocess.run(["hyprctl", "dispatch", "workspace", str(target_space)])
    sys.exit(0)

# Single monitor fallback (e.g. laptop alone on the go)
if len(monitors) <= 1:
    m = monitors[0]
    special = m.get("specialWorkspace", {}).get("name", "")
    if special and special.startswith("special:"):
        sp_name = special.replace("special:", "")
        import os
        if not os.path.exists(f"/tmp/scratchpad_anchored_{sp_name}"):
            subprocess.run(["hyprctl", "--batch", f"dispatch togglespecialworkspace {sp_name} ; dispatch workspace {target_space}"])
        else:
            subprocess.run(["hyprctl", "dispatch", "workspace", str(target_space)])
    else:
        subprocess.run(["hyprctl", "dispatch", "workspace", str(target_space)])
    sys.exit(0)

# Dynamic monitor sorting (spatially left-to-right by X, then Y)
active_monitors = [m for m in monitors if not m.get("disabled", False)]
if not active_monitors:
    active_monitors = monitors

active_monitors.sort(key=lambda m: (m.get("x", 0), m.get("y", 0)))

# Identify focused monitor
focused_mon = None
for m in active_monitors:
    if m.get("focused"):
        focused_mon = m["name"]
if not focused_mon and active_monitors:
    focused_mon = active_monitors[0]["name"]

batch = []
import os

# If the focused monitor currently has a scratchpad open, close it UNLESS it's anchored!
# Scratchpads on OTHER monitors are kept open so you can reference them seamlessly.
for m in active_monitors:
    if m["name"] == focused_mon:
        special = m.get("specialWorkspace", {}).get("name", "")
        if special and special.startswith("special:"):
            sp_name = special.replace("special:", "")
            if not os.path.exists(f"/tmp/scratchpad_anchored_{sp_name}"):
                batch.append(f"dispatch togglespecialworkspace {sp_name}")

# Switch workspaces across ALL monitors dynamically!
# Monitor index idx is assigned target workspace: target_space + idx * 10
# (Index 0 = target_space, Index 1 = target_space + 10, Index 2 = target_space + 20, ...)
# We order the batch so that all non-focused monitors switch first,
# and the currently focused monitor switches last (retaining user input focus seamlessly).
non_focused_mons = [m for m in active_monitors if m["name"] != focused_mon]
focused_mon_obj = next((m for m in active_monitors if m["name"] == focused_mon), active_monitors[0])

for m in non_focused_mons:
    idx = active_monitors.index(m)
    target_ws = str(target_space + idx * 10)
    batch.append(f"dispatch focusmonitor {m['name']}")
    batch.append(f"dispatch workspace {target_ws}")

# Now switch the focused monitor last
focused_idx = active_monitors.index(focused_mon_obj)
target_ws_focused = str(target_space + focused_idx * 10)
batch.append(f"dispatch focusmonitor {focused_mon_obj['name']}")
batch.append(f"dispatch workspace {target_ws_focused}")

import time, os

LOCK_FILE = "/tmp/workspace_switching"
try:
    with open(LOCK_FILE, "w") as f:
        f.write(str(time.time()))
except Exception:
    pass

if batch:
    cmd_str = " ; ".join(batch)
    subprocess.run(["hyprctl", "--batch", cmd_str])

time.sleep(0.15)
try:
    if os.path.exists(LOCK_FILE):
        os.remove(LOCK_FILE)
except Exception:
    pass

# Synchronize desktop spaces immediately so empty spaces vanish with 0 latency
try:
    subprocess.Popen(["python3", "-c", """
import json, subprocess
clients = json.loads(subprocess.check_output(['hyprctl', 'clients', '-j']))
mons = json.loads(subprocess.check_output(['hyprctl', 'monitors', '-j']))
occupied = {int(c['workspace']['name'])-10 if int(c['workspace']['name'])>10 else int(c['workspace']['name']) for c in clients if c.get('workspace',{}).get('name','').isdigit() and 1 <= (int(c['workspace']['name'])-10 if int(c['workspace']['name'])>10 else int(c['workspace']['name'])) <= 9}
for m in mons:
    aws = m.get('activeWorkspace',{}).get('name','')
    if aws.isdigit():
        num = int(aws)
        sp = num-10 if num>10 else num
        if 1 <= sp <= 9: occupied.add(sp)
batch = []
for s in range(1, 10):
    if s in occupied:
        batch.append(f'keyword workspace {s},persistent:true')
        if len(mons) > 1: batch.append(f'keyword workspace {s+10},persistent:true')
    else:
        batch.append(f'keyword workspace {s},persistent:false')
        batch.append(f'keyword workspace {s+10},persistent:false')
if batch: subprocess.run(['hyprctl', '--batch', ' ; '.join(batch)], stdout=subprocess.DEVNULL)
"""])
except Exception:
    pass
