#!/usr/bin/env python3
"""
Tokyo 80s TRV30 — Notification Action Router Daemon
Monitors D-Bus ActionInvoked signals from Dunst and routes notification clicks.
Clicking Discord/Vesktop notifications activates and focuses the Discord chat.
"""
import os
import re
import sys
import time
import json
import subprocess

NOTIF_DIR = "/tmp/dunst_active_notifs"

def cleanup_stale():
    try:
        if not os.path.exists(NOTIF_DIR):
            os.makedirs(NOTIF_DIR, exist_ok=True)
            return
        now = time.time()
        for f in os.listdir(NOTIF_DIR):
            p = os.path.join(NOTIF_DIR, f)
            if os.path.isfile(p) and (now - os.path.getmtime(p) > 120):
                try:
                    os.remove(p)
                except Exception:
                    pass
    except Exception:
        pass

def get_app_for_notification(nid):
    # 1. Check tracked files from dunst-track-app.sh
    fpath = os.path.join(NOTIF_DIR, str(nid))
    if os.path.exists(fpath):
        try:
            with open(fpath, "r") as f:
                app = f.read().strip().lower()
            os.remove(fpath)
            return app
        except Exception:
            pass

    # 2. Fallback: check dunstctl history
    try:
        out = subprocess.check_output(["dunstctl", "history"], text=True, stderr=subprocess.DEVNULL)
        data = json.loads(out)
        for group in data.get("data", []):
            for item in group:
                item_id = item.get("id", {}).get("data")
                if item_id == nid:
                    return str(item.get("appname", {}).get("data", "")).lower()
    except Exception:
        pass
    return ""

def handle_action(nid, action):
    app = get_app_for_notification(nid)
    if not app:
        return

    if "discord" in app or "vesktop" in app:
        # User clicked Discord notification: open and focus Discord chat scratchpad
        subprocess.run(
            ["/home/kaijnav/.config/hypr/scripts/toggle-scratchpad.sh", "discord", "--show"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )

def main():
    cleanup_stale()

    cmd = ["dbus-monitor", "interface='org.freedesktop.Notifications',member='ActionInvoked'"]

    while True:
        try:
            proc = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
                bufsize=1
            )

            for line in proc.stdout:
                line = line.strip()
                m = re.search(r"uint32\s+(\d+)", line)
                if m:
                    nid = int(m.group(1))
                    handle_action(nid, "default")
                    cleanup_stale()
        except Exception:
            time.sleep(1)

if __name__ == "__main__":
    main()
