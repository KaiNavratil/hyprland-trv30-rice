#!/usr/bin/env python3
"""
Cinema Cursor Guard for Hyprland
Automatically manages cursor:inactive_timeout:
- Sets timeout to 3s when watching movies / fullscreen video (cursor auto-hides after timescroller fades)
- Sets timeout to 0 (never hide) during normal desktop usage (coding, browsing, terminal)
- Keeps hide_on_key_press = false permanently so pressing Control never hides cursor
"""

import os
import sys
import json
import socket
import subprocess
import time

STATE_FILE = os.path.expanduser("~/.cache/cinema_cursor_mode.json")

MEDIA_CLASSES = {
    "mpv", "vlc", "celluloid", "totem", "kodi", "plexmediaplayer",
    "stremio", "popcorntime", "netflix", "jellyfinmediaplayer"
}

VIDEO_TITLE_HINTS = [
    "youtube", "netflix", "crunchyroll", "twitch", "prime video",
    "disney+", "hulu", "bilibili", "movie", "watch", "video", "stream",
    "player", "anime", "cinema"
]

current_applied_timeout = None

def get_user_mode():
    try:
        if os.path.exists(STATE_FILE):
            with open(STATE_FILE, "r") as f:
                data = json.load(f)
                return data.get("mode", "auto")
    except Exception:
        pass
    return "auto"

def set_hypr_timeout(val):
    global current_applied_timeout
    if current_applied_timeout == val:
        return
    try:
        subprocess.run(["hyprctl", "keyword", "cursor:inactive_timeout", str(val)],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        current_applied_timeout = val
    except Exception:
        pass

def is_watching_media(client_data):
    if not client_data:
        return False
    
    # 1. Fullscreen is active on the window (Movies, YouTube, Netflix in fullscreen)
    fullscreen = client_data.get("fullscreen", 0)
    if fullscreen:
        return True
    
    # 2. Dedicated media player focused
    c_class = str(client_data.get("class", "")).lower()
    c_init_class = str(client_data.get("initialClass", "")).lower()
    if any(m in c_class or m in c_init_class for m in MEDIA_CLASSES):
        return True
    
    # 3. Active idle inhibition + video keywords in title
    inhibiting = client_data.get("inhibitingIdle", False)
    title = str(client_data.get("title", "")).lower()
    if inhibiting:
        if any(h in title for h in VIDEO_TITLE_HINTS):
            return True
            
    return False

def check_and_update():
    mode = get_user_mode()
    if mode == "never":
        set_hypr_timeout(0)
        return
    elif mode == "always_3":
        set_hypr_timeout(3)
        return

    # In "auto" (default) mode:
    try:
        out = subprocess.check_output(["hyprctl", "activewindow", "-j"],
                                      text=True, stderr=subprocess.DEVNULL)
        data = json.loads(out)
    except Exception:
        data = None

    if is_watching_media(data):
        set_hypr_timeout(3)
    else:
        set_hypr_timeout(0)

def daemon():
    his = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    xdg = os.environ.get("XDG_RUNTIME_DIR", "/run/user/1000")
    if not his:
        sys.exit(1)
        
    sock_path = f"{xdg}/hypr/{his}/.socket2.sock"

    # Always ensure hide_on_key_press is false and warps are disabled
    subprocess.run(["hyprctl", "keyword", "cursor:hide_on_key_press", "false"],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(["hyprctl", "keyword", "cursor:no_warps", "true"],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(["hyprctl", "keyword", "cursor:warp_on_change_workspace", "0"],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    # Initial evaluation
    check_and_update()

    while True:
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.connect(sock_path)
            f = s.makefile('r', encoding='utf-8')

            while True:
                line = f.readline()
                if not line:
                    break
                
                event_name = line.split(">>")[0].strip()
                if event_name in ("fullscreen", "activewindow", "workspace", "closewindow", "changefloatingmode"):
                    check_and_update()
                    
            f.close()
            s.close()
        except Exception:
            time.sleep(2)
            check_and_update()

if __name__ == "__main__":
    daemon()
