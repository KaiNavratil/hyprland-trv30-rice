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

# Identify monitors
main_mon = None
comp_mon = None
focused_mon = None

for m in monitors:
    if m.get("focused"):
        focused_mon = m["name"]
    # Big external monitor on left is Main; eDP laptop on right is Companion
    if m["name"] == "HDMI-A-1" or (not m["name"].startswith("eDP") and main_mon is None):
        main_mon = m
    else:
        comp_mon = m

if not main_mon:
    main_mon = monitors[0]
if not comp_mon and len(monitors) > 1:
    comp_mon = monitors[1]

# Check special workspaces (scratchpads) on each monitor
main_special = main_mon.get("specialWorkspace", {}).get("name", "")
comp_special = comp_mon.get("specialWorkspace", {}).get("name", "") if comp_mon else ""

main_target_ws = str(target_space)
comp_target_ws = str(target_space + 10)

batch = []

# If the focused monitor currently has a scratchpad open, close it UNLESS it's anchored!
# Scratchpad on the OTHER monitor is kept open so you can reference it.
import os

if focused_mon == main_mon["name"]:
    if main_special and main_special.startswith("special:"):
        sp_name = main_special.replace("special:", "")
        if not os.path.exists(f"/tmp/scratchpad_anchored_{sp_name}"):
            batch.append(f"dispatch togglespecialworkspace {sp_name}")
elif comp_mon and focused_mon == comp_mon["name"]:
    if comp_special and comp_special.startswith("special:"):
        sp_name = comp_special.replace("special:", "")
        if not os.path.exists(f"/tmp/scratchpad_anchored_{sp_name}"):
            batch.append(f"dispatch togglespecialworkspace {sp_name}")

# Order the batch so that the non-focused monitor switches first,
# and the currently focused monitor switches last (retaining user focus seamlessly).
if focused_mon == comp_mon["name"]:
    batch.append(f"dispatch focusmonitor {main_mon['name']}")
    batch.append(f"dispatch workspace {main_target_ws}")
    batch.append(f"dispatch focusmonitor {comp_mon['name']}")
    batch.append(f"dispatch workspace {comp_target_ws}")
else:
    if comp_mon:
        batch.append(f"dispatch focusmonitor {comp_mon['name']}")
        batch.append(f"dispatch workspace {comp_target_ws}")
    batch.append(f"dispatch focusmonitor {main_mon['name']}")
    batch.append(f"dispatch workspace {main_target_ws}")

if focused_mon:
    batch.append(f"dispatch focusmonitor {focused_mon}")

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
