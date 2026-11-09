#!/usr/bin/env python3
"""
Tokyo 80s TRV30 — Intelligent Window Router & Session Manager
- Continuously tracks all open windows and their Desktop Spaces (1-9 across both displays).
- Persists window titles to workspaces in ~/.cache/window_workspaces.json and ~/.config/hypr/session.json.
- When multi-window apps like Vivaldi restart or everything closes and reopens,
  automatically sorts newly opened windows back into their respective Desktop Spaces.
- Maintains a recently closed window stack in ~/.cache/recently_closed.json for Super+T / Super+Shift+T.
- Coordinates with pending reopen requests to immediately route restored windows.
"""

import os
import socket
import json
import subprocess
import time
import threading

WORKSPACES_FILE = os.path.expanduser("~/.cache/window_workspaces.json")
SESSION_FILE = os.path.expanduser("~/.config/hypr/session.json")
RECENTLY_CLOSED_FILE = os.path.expanduser("~/.cache/recently_closed.json")
PENDING_REOPEN_FILE = os.path.expanduser("~/.cache/pending_reopen.json")
LEGACY_CLOSED_FILE = os.path.expanduser("~/.cache/last_closed_app")

GENERIC_TITLES = {
    "vivaldi - vivaldi", "vivaldi", "settings - vivaldi",
    "start page - vivaldi", "new tab - vivaldi", "new tab",
    "", "null"
}

def is_generic_title(title):
    if not title:
        return True
    return title.strip().lower() in GENERIC_TITLES

def is_switching():
    if os.path.exists("/tmp/workspace_switching"):
        try:
            with open("/tmp/workspace_switching", "r") as f:
                t = float(f.read().strip())
                if time.time() - t < 1.0:
                    return True
        except Exception:
            return True
    return False

def load_json(path, default=None):
    if default is None:
        default = {}
    if not os.path.exists(path):
        return default
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return default

def save_json_atomic(path, data):
    tmp = path + f".tmp.{os.getpid()}"
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
        os.rename(tmp, path)
    except Exception:
        try:
            if os.path.exists(tmp):
                os.remove(tmp)
        except Exception:
            pass

def get_exec_cmd(class_name, title=""):
    c = class_name.lower() if class_name else ""
    t = title.lower() if title else ""

    if "vivaldi" in c:
        if "calendar.notion.so" in t or "notion calendar" in t:
            return "vivaldi-stable --app=https://calendar.notion.so"
        return "vivaldi-stable"
    elif "kitty" in c:
        return "kitty"
    elif "code" in c:
        return "code"
    elif "vesktop" in c or "discord" in c:
        return "vesktop"
    elif "spotify" in c:
        return "spotify-launcher --skip-update"
    elif "pavucontrol" in c:
        return "pavucontrol"
    elif "github desktop" in c or "github-desktop" in c:
        return "github-desktop"
    elif "antigravity-ide" in c:
        return "/opt/antigravity-ide/antigravity-ide"
    elif "antigravity" in c:
        return "antigravity"
    elif "copyq" in c:
        return "copyq show"
    else:
        return class_name.lower() if class_name else "kitty"

# Global state
active_windows = {}     # addr -> dict(class, title, workspace, monitor, time)
newly_opened = {}       # addr -> timestamp
routed_windows = set()  # set of addrs already routed on creation
lock = threading.Lock()

def get_clients_from_hypr():
    try:
        out = subprocess.check_output(["hyprctl", "clients", "-j"], text=True)
        return json.loads(out)
    except Exception:
        return []

def push_recently_closed(win_info):
    ws = win_info.get("workspace", "")
    if not ws or ws.startswith("special:"):
        return
    c_class = win_info.get("class", "")
    title = win_info.get("title", "")
    if not c_class and is_generic_title(title):
        return

    cmd = get_exec_cmd(c_class, title)
    entry = {
        "class": c_class,
        "title": title,
        "workspace": ws,
        "monitor": win_info.get("monitor", 0),
        "exec_cmd": cmd,
        "timestamp": time.time()
    }

    try:
        history = load_json(RECENTLY_CLOSED_FILE, default=[])
        if history and history[0].get("title") == title and history[0].get("class") == c_class:
            return
        history.insert(0, entry)
        save_json_atomic(RECENTLY_CLOSED_FILE, history[:30])

        with open(LEGACY_CLOSED_FILE, "w", encoding="utf-8") as f:
            f.write(f"[workspace {ws}] {cmd}")
    except Exception:
        pass

def check_pending_reopen(c_class, title):
    if not os.path.exists(PENDING_REOPEN_FILE):
        return None
    try:
        data = load_json(PENDING_REOPEN_FILE, default={})
        if not data:
            return None
        # Check if expired (> 20s)
        if time.time() - data.get("time", 0) > 20:
            os.remove(PENDING_REOPEN_FILE)
            return None
        
        p_class = data.get("class", "").lower()
        if p_class and (p_class in c_class.lower() or c_class.lower() in p_class):
            target_ws = data.get("workspace")
            try:
                os.remove(PENDING_REOPEN_FILE)
            except Exception:
                pass
            return target_ws
    except Exception:
        pass
    return None

prev_monitor_count = 2

def collapse_companion_windows():
    try:
        clients_raw = subprocess.check_output(["hyprctl", "clients", "-j"], text=True)
        clients = json.loads(clients_raw)
        batch = []
        for c in clients:
            ws_name = c.get("workspace", {}).get("name", "")
            addr = c.get("address", "")
            if ws_name.isdigit():
                ws_num = int(ws_name)
                if ws_num > 9:
                    target_ws = ((ws_num - 1) % 10) + 1
                    batch.append(f"dispatch movetoworkspacesilent {target_ws},address:{addr}")
        if batch:
            subprocess.run(["hyprctl", "--batch", " ; ".join(batch)], stdout=subprocess.DEVNULL)
            subprocess.run(["dunstify", "-u", "low", "-t", "2500", "🖥️ SINGLE DISPLAY", "Migrated companion windows to Spaces 1-9"], stdout=subprocess.DEVNULL)
    except Exception:
        pass

def sync_desktop_spaces():
    try:
        clients_raw = subprocess.check_output(["hyprctl", "clients", "-j"], text=True)
        clients = json.loads(clients_raw)
        mons_raw = subprocess.check_output(["hyprctl", "monitors", "-j"], text=True)
        mons = [m for m in json.loads(mons_raw) if not m.get("disabled", False)]
        mon_count = max(1, len(mons))

        occupied_spaces = set()
        for c in clients:
            ws = c.get("workspace", {}).get("name", "")
            if ws.isdigit():
                num = int(ws)
                space = ((num - 1) % 10) + 1
                if 1 <= space <= 9:
                    occupied_spaces.add(space)

        for m in mons:
            aws = m.get("activeWorkspace", {}).get("name", "")
            if aws.isdigit():
                num = int(aws)
                space = ((num - 1) % 10) + 1
                if 1 <= space <= 9:
                    occupied_spaces.add(space)

        batch = []
        for s in range(1, 10):
            is_occupied = (s in occupied_spaces)
            for tier in range(max(2, mon_count)):
                ws_id = s + tier * 10
                if tier < mon_count and is_occupied:
                    batch.append(f"keyword workspace {ws_id},persistent:true")
                else:
                    batch.append(f"keyword workspace {ws_id},persistent:false")

        if batch:
            subprocess.run(["hyprctl", "--batch", " ; ".join(batch)], stdout=subprocess.DEVNULL)
    except Exception:
        pass

def poller():
    """Periodic background sync every 3 seconds."""
    global prev_monitor_count
    while True:
        try:
            mons_raw = subprocess.check_output(["hyprctl", "monitors", "-j"], text=True)
            mons = json.loads(mons_raw)
            current_count = len(mons)
            if prev_monitor_count > 1 and current_count == 1:
                collapse_companion_windows()
            prev_monitor_count = current_count

            sync_desktop_spaces()

            clients = get_clients_from_hypr()
            ws_map = load_json(WORKSPACES_FILE, default={})
            session_state = []
            now = time.time()

            with lock:
                current_addrs = set()
                for c in clients:
                    raw_addr = c.get("address", "")
                    addr = raw_addr.replace("0x", "")
                    current_addrs.add(addr)
                    c_class = c.get("class", "")
                    title = c.get("title", "")
                    ws = c.get("workspace", {}).get("name", "")
                    mon = c.get("monitor", 0)

                    active_windows[addr] = {
                        "class": c_class,
                        "title": title,
                        "workspace": ws,
                        "monitor": mon,
                        "time": active_windows.get(addr, {}).get("time", now)
                    }

                    if ws and not ws.startswith("special:"):
                        session_state.append({
                            "class": c_class,
                            "title": title,
                            "workspace": ws,
                            "monitor": mon
                        })

                        if title and not is_generic_title(title):
                            ws_map[title] = ws

                # Cleanup old newly_opened entries (> 45s)
                expired_opened = [a for a, t in newly_opened.items() if now - t > 45]
                for a in expired_opened:
                    newly_opened.pop(a, None)

                # Cleanup routed_windows that no longer exist
                routed_windows.intersection_update(current_addrs)

            save_json_atomic(WORKSPACES_FILE, ws_map)
            save_json_atomic(SESSION_FILE, session_state)

        except Exception:
            pass

        time.sleep(3)

def daemon():
    his = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    xdg = os.environ.get("XDG_RUNTIME_DIR", "/run/user/1000")
    if not his:
        time.sleep(2)
        return
    sock_path = f"{xdg}/hypr/{his}/.socket2.sock"

    # Start poller thread
    t = threading.Thread(target=poller, daemon=True)
    t.start()

    # Initial scan of clients
    clients = get_clients_from_hypr()
    now = time.time()
    with lock:
        for c in clients:
            addr = c.get("address", "").replace("0x", "")
            active_windows[addr] = {
                "class": c.get("class", ""),
                "title": c.get("title", ""),
                "workspace": c.get("workspace", {}).get("name", ""),
                "monitor": c.get("monitor", 0),
                "time": now
            }

    while True:
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.connect(sock_path)
            f = s.makefile("r", encoding="utf-8")

            while True:
                line = f.readline()
                if not line:
                    break
                line = line.strip()

                # openwindow>>ADDR,WORKSPACE,CLASS,TITLE
                if line.startswith("openwindow>>"):
                    try:
                        raw = line.split(">>")[1]
                        parts = raw.split(",", 3)
                        if len(parts) >= 3:
                            addr = parts[0].replace("0x", "")
                            ws = parts[1]
                            c_class = parts[2]
                            title = parts[3] if len(parts) > 3 else ""

                            with lock:
                                newly_opened[addr] = time.time()
                                active_windows[addr] = {
                                    "class": c_class,
                                    "title": title,
                                    "workspace": ws,
                                    "time": time.time()
                                }

                            # 1. Check if this is a pending reopen request (Super+T)
                            target_ws = check_pending_reopen(c_class, title)
                            if target_ws and ws != target_ws and not target_ws.startswith("special:"):
                                subprocess.run(["hyprctl", "dispatch", "movetoworkspacesilent", f"{target_ws},address:0x{addr}"], stdout=subprocess.DEVNULL)
                                with lock:
                                    routed_windows.add(addr)
                                    newly_opened.pop(addr, None)
                                continue

                            # 2. For non-Vivaldi windows with known title/class at launch
                            if c_class != "vivaldi-stable" and not ws.startswith("special:"):
                                ws_map = load_json(WORKSPACES_FILE, default={})
                                saved_ws = ws_map.get(title)
                                if saved_ws and ws != saved_ws and not saved_ws.startswith("special:"):
                                    subprocess.run(["hyprctl", "dispatch", "movetoworkspacesilent", f"{saved_ws},address:0x{addr}"], stdout=subprocess.DEVNULL)
                                    with lock:
                                        routed_windows.add(addr)
                                        newly_opened.pop(addr, None)
                    except Exception:
                        pass

                # windowtitle>>ADDR
                elif line.startswith("windowtitle>>"):
                    try:
                        addr = line.split(">>")[1].replace("0x", "")
                        is_new = False
                        with lock:
                            is_new = addr in newly_opened and addr not in routed_windows

                        # Query window details
                        out = subprocess.check_output(["hyprctl", "clients", "-j"], text=True)
                        clients = json.loads(out)
                        for c in clients:
                            c_addr = c.get("address", "").replace("0x", "")
                            if c_addr == addr:
                                title = c.get("title", "")
                                ws = c.get("workspace", {}).get("name", "")
                                c_class = c.get("class", "")

                                with lock:
                                    if addr in active_windows:
                                        active_windows[addr]["title"] = title
                                        active_windows[addr]["workspace"] = ws

                                if is_new and title and not is_generic_title(title):
                                    # 1. Pending reopen check
                                    target_ws = check_pending_reopen(c_class, title)
                                    # 2. Saved workspace check
                                    if not target_ws:
                                        ws_map = load_json(WORKSPACES_FILE, default={})
                                        target_ws = ws_map.get(title)

                                    if target_ws and ws != target_ws and not target_ws.startswith("special:"):
                                        subprocess.run(["hyprctl", "dispatch", "movetoworkspacesilent", f"{target_ws},address:0x{addr}"], stdout=subprocess.DEVNULL)

                                    with lock:
                                        routed_windows.add(addr)
                                        newly_opened.pop(addr, None)

                                elif not is_new and title and not is_generic_title(title) and ws and not ws.startswith("special:"):
                                    # Normal browsing: update workspace memory
                                    ws_map = load_json(WORKSPACES_FILE, default={})
                                    if ws_map.get(title) != ws:
                                        ws_map[title] = ws
                                        save_json_atomic(WORKSPACES_FILE, ws_map)

                                break
                    except Exception:
                        pass

                # closewindow>>ADDR
                elif line.startswith("closewindow>>"):
                    try:
                        addr = line.split(">>")[1].replace("0x", "")
                        win_info = None
                        with lock:
                            win_info = active_windows.pop(addr, None)
                            newly_opened.pop(addr, None)
                            routed_windows.discard(addr)

                        if win_info:
                            push_recently_closed(win_info)
                    except Exception:
                        pass

                # movewindow>>ADDR,WORKSPACE
                elif line.startswith("movewindow>>"):
                    try:
                        raw = line.split(">>")[1]
                        parts = raw.split(",")
                        if len(parts) >= 2:
                            addr = parts[0].replace("0x", "")
                            ws = parts[1]
                            with lock:
                                if addr in active_windows:
                                    active_windows[addr]["workspace"] = ws
                                    title = active_windows[addr].get("title", "")
                                    if title and not is_generic_title(title) and not ws.startswith("special:"):
                                        ws_map = load_json(WORKSPACES_FILE, default={})
                                        ws_map[title] = ws
                                        save_json_atomic(WORKSPACES_FILE, ws_map)
                    except Exception:
                        pass

                # workspace>>WORKSPACE
                elif line.startswith("workspace>>"):
                    try:
                        if is_switching():
                            continue
                        ws_name = line.split(">>")[1].strip()
                        if ws_name.isdigit():
                            ws_num = int(ws_name)
                            m_out = subprocess.check_output(["hyprctl", "monitors", "-j"], text=True)
                            mons = [m for m in json.loads(m_out) if not m.get("disabled", False)]
                            if len(mons) > 1:
                                mons.sort(key=lambda m: (m.get("x", 0), m.get("y", 0)))
                                space = ((ws_num - 1) % 10) + 1
                                source_tier = (ws_num - 1) // 10
                                source_mon = mons[source_tier] if source_tier < len(mons) else None

                                batch = []
                                for idx, m in enumerate(mons):
                                    if idx == source_tier:
                                        continue
                                    target_tier_ws = str(space + idx * 10)
                                    if m.get("activeWorkspace", {}).get("name") != target_tier_ws:
                                        batch.append(f"dispatch focusmonitor {m['name']}")
                                        batch.append(f"dispatch workspace {target_tier_ws}")
                                if source_mon:
                                    batch.append(f"dispatch focusmonitor {source_mon['name']}")
                                if batch:
                                    subprocess.run(["hyprctl", "--batch", " ; ".join(batch)], stdout=subprocess.DEVNULL)
                    except Exception:
                        pass

                # activewindowv2>>ADDR
                elif line.startswith("activewindowv2>>"):
                    try:
                        if is_switching():
                            continue
                        raw_addr = line.split(">>")[1].strip()
                        if raw_addr:
                            aw_raw = subprocess.check_output(["hyprctl", "activewindow", "-j"], text=True)
                            aw = json.loads(aw_raw)
                            aw_ws = aw.get("workspace", {}).get("name", "")
                            aw_mon = aw.get("monitor", -1)
                            if aw_ws and not aw_ws.startswith("special:") and aw_mon >= 0:
                                m_out = subprocess.check_output(["hyprctl", "monitors", "-j"], text=True)
                                mons = json.loads(m_out)
                                for m in mons:
                                    if m.get("id") == aw_mon:
                                        sp = m.get("specialWorkspace", {}).get("name", "")
                                        if sp and sp.startswith("special:"):
                                            subprocess.run(["hyprctl", "dispatch", "togglespecialworkspace", sp.replace("special:", "")], stdout=subprocess.DEVNULL)
                    except Exception:
                        pass

                # monitorremoved>>MONITOR or monitoradded>>MONITOR
                elif line.startswith("monitorremoved>>") or line.startswith("monitoradded>>"):
                    try:
                        time.sleep(0.3)
                        m_out = subprocess.check_output(["hyprctl", "monitors", "-j"], text=True)
                        mons = [m for m in json.loads(m_out) if not m.get("disabled", False)]
                        if len(mons) == 1:
                            collapse_companion_windows()
                        sync_desktop_spaces()
                    except Exception:
                        pass

        except Exception:
            time.sleep(2)
        finally:
            try:
                s.close()
            except Exception:
                pass

if __name__ == "__main__":
    while True:
        try:
            daemon()
        except Exception:
            time.sleep(2)
