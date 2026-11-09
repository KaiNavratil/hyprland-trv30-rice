#!/usr/bin/env python3
"""
Tokyo 80s TRV30 — Dual-Monitor Desktop Space Radar & Tactical Window Console
東京 80s TRV30 // 双頭作業空間レーダー・タクティカルコンソール

Features:
- Matches Tokyo 80s TRV30 Master Deck palette (vintage amber #d4944c, warm white #e8dfd4, pure black #000000)
- Runs as persistent scratchpad deck (special:radar) with zero white-flash and 0ms reload
- Full window control settings: Focus, Close, Move to Space, Toggle Float, Toggle Pin
- Editable custom workspace names persisted to ~/.config/hypr/workspace_names.json
- Filters out empty spaces: displays ONLY active spaces with open windows
"""

import sys
import os
import json
import time
import subprocess
import threading
import socket

# Allow WebKit web processes direct access without sandbox issues
os.environ["WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS"] = "1"

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('WebKit', '6.0')
from gi.repository import Gtk, WebKit, GLib, Gio, Gdk

SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))
INDEX_URI = f"file://{os.path.join(SCRIPT_DIR, 'index.html')}"
NAMES_FILE = os.path.expanduser("~/.config/hypr/workspace_names.json")
THUMB_DIR = "/tmp/hypr_thumbs"
os.makedirs(THUMB_DIR, exist_ok=True)
LOG_FILE = "/tmp/tokyo-radar.log"

def log(msg):
    try:
        ts = time.strftime("%Y-%m-%d %H:%M:%S")
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(f"[{ts}] {msg}\n")
    except Exception:
        pass

DEFAULT_SPACE_NAMES = {
    1: {"name": "BROWSE", "jp": "探索"},
    2: {"name": "DEV", "jp": "開発"},
    3: {"name": "DOCS", "jp": "記録"},
    4: {"name": "COMMS", "jp": "通信"},
    5: {"name": "MEDIA", "jp": "映像"},
    6: {"name": "SYS", "jp": "計装"},
    7: {"name": "LAB", "jp": "実験"},
    8: {"name": "DATA", "jp": "解析"},
    9: {"name": "CORE", "jp": "防衛"},
}

def load_workspace_names():
    names = dict(DEFAULT_SPACE_NAMES)
    if os.path.exists(NAMES_FILE):
        try:
            with open(NAMES_FILE, "r", encoding="utf-8") as f:
                custom = json.load(f)
                for k, v in custom.items():
                    ik = int(k)
                    if ik in names:
                        names[ik]["name"] = str(v).upper()
        except Exception:
            pass
    return names

def save_workspace_name(space_id, new_name):
    try:
        custom = {}
        if os.path.exists(NAMES_FILE):
            with open(NAMES_FILE, "r", encoding="utf-8") as f:
                custom = json.load(f)
        custom[str(space_id)] = str(new_name).strip().upper()
        with open(NAMES_FILE, "w", encoding="utf-8") as f:
            json.dump(custom, f, indent=2)
    except Exception as e:
        sys.stderr.write(f"Error saving workspace name: {e}\n")

def capture_visible_thumbnails(clients, monitors):
    """Capture live thumbnails for all windows currently visible on any display"""
    active_ws = {m.get("activeWorkspace", {}).get("id") for m in monitors if m.get("activeWorkspace")}
    for m in monitors:
        sp = m.get("specialWorkspace", {})
        if sp and sp.get("id"):
            active_ws.add(sp["id"])

    for c in clients:
        ws_id = c.get("workspace", {}).get("id")
        c_class = c.get("class", "")
        if c_class in ["com.tokyo.radar", "trv30-radar"]:
            continue
        if ws_id in active_ws:
            x, y = c.get("at", [0, 0])
            w, h = c.get("size", [0, 0])
            addr = c.get("address", "")
            if w > 80 and h > 80 and addr:
                thumb_path = f"{THUMB_DIR}/{addr}.jpg"
                cmd = f'grim -g "{x},{y} {w}x{h}" - | magick - -resize 360x225 -quality 75 {thumb_path}'
                try:
                    subprocess.run(cmd, shell=True, stderr=subprocess.DEVNULL, timeout=0.6)
                except Exception:
                    pass

def get_window_metrics(clients):
    try:
        ps_out = subprocess.check_output(['ps', '-eo', 'pid,ppid,%cpu,%mem,rss'], text=True, stderr=subprocess.DEVNULL)
    except Exception:
        return {}

    procs = {}
    children = {}
    for line in ps_out.strip().splitlines()[1:]:
        p = line.strip().split()
        if len(p) >= 5:
            try:
                pid = int(p[0])
                ppid = int(p[1])
                procs[pid] = {
                    'cpu': float(p[2]),
                    'mem': float(p[3]),
                    'rss_mb': int(p[4]) / 1024.0
                }
                children.setdefault(ppid, []).append(pid)
            except ValueError:
                continue

    pid_window_counts = {}
    for c in clients:
        pid = c.get('pid')
        if pid:
            pid_window_counts[pid] = pid_window_counts.get(pid, 0) + 1

    tree_metrics_cache = {}
    def calc_tree(root_pid):
        if root_pid in tree_metrics_cache:
            return tree_metrics_cache[root_pid]
        tot_cpu = 0.0
        tot_mem = 0.0
        tot_rss = 0.0
        stack = [root_pid]
        seen = set()
        while stack:
            cur = stack.pop()
            if cur in seen:
                continue
            seen.add(cur)
            if cur in procs:
                tot_cpu += procs[cur]['cpu']
                tot_mem += procs[cur]['mem']
                tot_rss += procs[cur]['rss_mb']
            stack.extend(children.get(cur, []))
        res = {'cpu': tot_cpu, 'mem': tot_mem, 'rss_mb': tot_rss}
        tree_metrics_cache[root_pid] = res
        return res

    metrics_by_addr = {}
    for c in clients:
        addr = c.get('address', '')
        pid = c.get('pid')
        if not addr or not pid:
            continue
        tree = calc_tree(pid)
        win_count = pid_window_counts.get(pid, 1)

        if win_count > 1:
            win_cpu = round(tree['cpu'] / win_count, 1)
            win_mem = round(tree['mem'] / win_count, 1)
            win_rss = round(tree['rss_mb'] / win_count, 1)
            is_shared = True
        else:
            win_cpu = round(tree['cpu'], 1)
            win_mem = round(tree['mem'], 1)
            win_rss = round(tree['rss_mb'], 1)
            is_shared = False

        metrics_by_addr[addr] = {
            'pid': pid,
            'cpu': win_cpu,
            'mem': win_mem,
            'rss_mb': win_rss,
            'total_cpu': round(tree['cpu'], 1),
            'total_rss_mb': round(tree['rss_mb'], 1),
            'is_shared': is_shared
        }

    return metrics_by_addr

def get_radar_state():
    space_names = load_workspace_names()

    try:
        clients_raw = subprocess.check_output(["hyprctl", "clients", "-j"], text=True)
        clients = json.loads(clients_raw)
    except Exception:
        clients = []

    win_metrics = get_window_metrics(clients)

    try:
        mons_raw = subprocess.check_output(["hyprctl", "monitors", "-j"], text=True)
        monitors = [m for m in json.loads(mons_raw) if not m.get("disabled", False)]
    except Exception:
        monitors = []

    if not monitors:
        monitors = [{"id": 0, "name": "eDP-1", "x": 0, "y": 0, "focused": True, "activeWorkspace": {"id": 1, "name": "1"}}]

    # Sort monitors left-to-right spatially
    sorted_monitors = sorted(monitors, key=lambda m: (m.get("x", 0), m.get("y", 0)))

    try:
        active_win_raw = subprocess.check_output(["hyprctl", "activewindow", "-j"], text=True)
        active_win = json.loads(active_win_raw)
    except Exception:
        active_win = {}

    active_addr = active_win.get("address", "")
    
    current_space = 1
    focused_mon = sorted_monitors[0]["name"]

    for m in sorted_monitors:
        if m.get("focused"):
            focused_mon = m["name"]
            aws = m.get("activeWorkspace", {}).get("name", "")
            if aws.isdigit():
                num = int(aws)
                current_space = ((num - 1) % 10) + 1

    spaces = {}
    for i in range(1, 10):
        columns = []
        for idx, m in enumerate(sorted_monitors):
            ws_id = i + idx * 10
            columns.append({
                "monitor_name": m["name"],
                "monitor_desc": m.get("description", m.get("model", m["name"])),
                "monitor_index": idx,
                "workspace_id": ws_id,
                "is_primary": (idx == 0),
                "is_focused_mon": (m["name"] == focused_mon),
                "windows": []
            })
        spaces[i] = {
            "id": i,
            "name": space_names[i]["name"],
            "jp": space_names[i]["jp"],
            "columns": columns,
            "main": columns[0]["windows"] if len(columns) > 0 else [],
            "comp": columns[1]["windows"] if len(columns) > 1 else [],
            "is_current": (i == current_space)
        }

    scratchpads = {}
    total_windows = 0

    for c in clients:
        c_class = c.get("class", "Unknown") or "Unknown"
        if c_class in ["com.tokyo.radar", "trv30-radar"]:
            continue

        ws_name = c.get("workspace", {}).get("name", "")
        c_addr = c.get("address", "")
        c_pid = c.get("pid", 0)
        c_title = c.get("title", "Untitled") or "Untitled"
        is_active = (c_addr == active_addr)
        total_windows += 1

        thumb_file = f"{THUMB_DIR}/{c_addr}.jpg"
        thumb_uri = f"file://{thumb_file}" if os.path.exists(thumb_file) else None

        m = win_metrics.get(c_addr, {'cpu': 0.0, 'mem': 0.0, 'rss_mb': 0.0, 'is_shared': False})

        win_info = {
            "address": c_addr,
            "class": c_class,
            "title": c_title,
            "pid": c_pid,
            "cpu": m["cpu"],
            "mem": m["mem"],
            "rss_mb": m["rss_mb"],
            "is_shared": m.get("is_shared", False),
            "floating": c.get("floating", False),
            "pinned": c.get("pinned", False),
            "active": is_active,
            "workspace": ws_name,
            "monitor": c.get("monitor", 0),
            "thumb": thumb_uri
        }

        if ws_name.startswith("special:"):
            sp_name = ws_name.replace("special:", "")
            scratchpads.setdefault(sp_name, []).append(win_info)
        elif ws_name.isdigit():
            num = int(ws_name)
            space = ((num - 1) % 10) + 1
            tier = (num - 1) // 10
            if 1 <= space <= 9:
                if tier < len(sorted_monitors):
                    spaces[space]["columns"][tier]["windows"].append(win_info)
                else:
                    spaces[space]["columns"][0]["windows"].append(win_info)

    # Filter spaces: ONLY show spaces with open windows OR the currently active space!
    active_spaces = {}
    for i in range(1, 10):
        sp = spaces[i]
        total_space_wins = sum(len(col["windows"]) for col in sp["columns"])
        if total_space_wins > 0 or sp["is_current"]:
            active_spaces[i] = sp

    # Check anchor locks
    anchors = {}
    for sp in ["music", "discord", "calendar", "notes", "center", "dev", "display", "antigravity", "sysmon", "cava"]:
        anchors[sp] = os.path.exists(f"/tmp/scratchpad_anchored_{sp}")

    # Check visible special workspaces
    active_specials = {}
    for m in sorted_monitors:
        sp = m.get("specialWorkspace", {}).get("name", "").replace("special:", "")
        if sp:
            active_specials[sp] = m["name"]

    monitors_data = [
        {
            "id": m.get("id", idx),
            "name": m["name"],
            "model": m.get("model", ""),
            "description": m.get("description", m.get("model", m["name"])),
            "width": m.get("width", 1920),
            "height": m.get("height", 1080),
            "scale": m.get("scale", 1.0),
            "x": m.get("x", 0),
            "y": m.get("y", 0),
            "focused": m.get("focused", False),
            "index": idx
        }
        for idx, m in enumerate(sorted_monitors)
    ]

    state = {
        "current_space": current_space,
        "focused_mon": focused_mon,
        "spaces": active_spaces,
        "all_spaces": {i: spaces[i]["name"] for i in range(1, 10)},
        "scratchpads": scratchpads,
        "anchors": anchors,
        "active_specials": active_specials,
        "total_windows": total_windows,
        "monitor_count": len(sorted_monitors),
        "monitors": monitors_data,
        "timestamp": time.strftime("%H:%M:%S")
    }
    return state, clients, sorted_monitors

class RadarWindow(Gtk.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title="Tokyo Space Radar")
        self.set_default_size(1500, 920)
        self.running = True
        self.is_visible = False
        self.dirty = True
        self._last_send_time = 0.0
        self._update_pending = False
        self._update_lock = threading.Lock()

        try:
            state, clients, monitors = get_radar_state()
            threading.Thread(target=capture_visible_thumbnails, args=(clients, monitors), daemon=True).start()
        except Exception as e:
            log(f"Init state error: {e}")

        # WebKit Settings with Hardware Acceleration
        settings = WebKit.Settings()
        settings.set_enable_developer_extras(False)
        settings.set_javascript_can_access_clipboard(True)
        settings.set_allow_file_access_from_file_urls(True)
        settings.set_allow_universal_access_from_file_urls(True)
        settings.set_hardware_acceleration_policy(WebKit.HardwareAccelerationPolicy.ALWAYS)

        # Content Manager & Script Message Handler
        content_mgr = WebKit.UserContentManager()
        content_mgr.register_script_message_handler("radar")
        content_mgr.connect("script-message-received::radar", self.on_script_message)

        # WebKit WebView with pure black background (prevents white-screen flash!)
        self.webview = WebKit.WebView(user_content_manager=content_mgr, settings=settings)
        rgba = Gdk.RGBA()
        rgba.parse("#000000")
        self.webview.set_background_color(rgba)

        self.webview.connect("load-changed", self.on_load_changed)
        try:
            self.webview.connect("web-process-terminated", self.on_web_process_terminated)
        except Exception as e:
            log(f"web-process-terminated hook notice: {e}")

        self.webview.load_uri(INDEX_URI)

        # Key controller for ESC, Q, and 1-9
        key_ctrl = Gtk.EventControllerKey()
        key_ctrl.connect("key-pressed", self.on_key_pressed)
        self.add_controller(key_ctrl)

        self.set_child(self.webview)

        # Start Hyprland Socket2 listener with persistent reconnect
        self.socket_thread = threading.Thread(target=self.listen_socket2, daemon=True)
        self.socket_thread.start()

        # Start background metrics worker
        self.metrics_thread = threading.Thread(target=self._metrics_worker, daemon=True)
        self.metrics_thread.start()

    def check_is_visible(self):
        try:
            out = subprocess.check_output(["hyprctl", "monitors", "-j"], text=True, stderr=subprocess.DEVNULL, timeout=0.8)
            return any(m.get("specialWorkspace", {}).get("name") == "special:radar" for m in json.loads(out))
        except Exception:
            return False

    def on_web_process_terminated(self, webview, reason):
        log(f"WebKit WebProcess terminated (reason={reason}). Reloading URI...")
        GLib.timeout_add(200, self._reload_ui)

    def _reload_ui(self):
        try:
            if self.webview and self.running:
                self.webview.load_uri(INDEX_URI)
                self.dirty = True
        except Exception as e:
            log(f"Error reloading webview: {e}")
        return False

    def on_load_changed(self, webview, event):
        if event == WebKit.LoadEvent.FINISHED:
            self.request_update(force=True)

    def request_update(self, force=False):
        """Thread-safe debounced update request to GTK main loop"""
        now = time.time()
        if not force and not self.is_visible:
            self.dirty = True
            return

        with self._update_lock:
            if self._update_pending and not force:
                return
            self._update_pending = True

        def _do_update():
            with self._update_lock:
                self._update_pending = False
            self.send_state_to_js()
            return False

        elapsed = now - self._last_send_time
        if elapsed < 0.12 and not force:
            GLib.timeout_add(int((0.12 - elapsed) * 1000), _do_update)
        else:
            GLib.idle_add(_do_update)

    def send_state_to_js(self):
        if not self.webview or not self.running:
            return
        self._last_send_time = time.time()
        try:
            state, _, _ = get_radar_state()
            raw_json = json.dumps(state)
            js = f"""
            if (window.renderRadar) {{
                try {{
                    window.renderRadar({raw_json});
                }} catch(e) {{
                    console.error("renderRadar JS error:", e);
                }}
            }}
            """
            self.webview.evaluate_javascript(js, -1, None, None, None, None, None)
            self.dirty = False
        except Exception as e:
            log(f"Error in send_state_to_js: {e}")

    def _metrics_worker(self):
        while self.running:
            try:
                now_vis = self.check_is_visible()
                was_vis = self.is_visible
                self.is_visible = now_vis

                if now_vis:
                    if not was_vis or self.dirty:
                        self.request_update(force=True)
                    else:
                        self.request_update()
            except Exception as e:
                log(f"Metrics worker error: {e}")
            time.sleep(2.0)

    def on_script_message(self, content_mgr, js_result):
        try:
            val_str = ""
            try:
                if hasattr(js_result, "is_string") and js_result.is_string():
                    val_str = js_result.to_string()
                else:
                    val_str = js_result.to_json(0)
            except Exception:
                val_str = js_result.to_string()

            try:
                msg = json.loads(val_str)
                while isinstance(msg, str):
                    msg = json.loads(msg)
            except Exception:
                msg = {"action": val_str}

            action = msg.get("action")

            if action == "focus":
                space = msg.get("space")
                addr = msg.get("address")
                # Close/stow special workspace
                subprocess.run(["hyprctl", "dispatch", "togglespecialworkspace", "radar"], stdout=subprocess.DEVNULL)
                if space:
                    subprocess.run(["hyprctl", "eval", f"require('spaces').switch_desktop_space({space})"], stdout=subprocess.DEVNULL)
                if addr:
                    subprocess.run(["hyprctl", "dispatch", "focuswindow", f"address:{addr}"], stdout=subprocess.DEVNULL)

            elif action == "close_window":
                addr = msg.get("address")
                if addr:
                    subprocess.run(["hyprctl", "dispatch", "closewindow", f"address:{addr}"], stdout=subprocess.DEVNULL)
                    time.sleep(0.08)
                    self.send_state_to_js()

            elif action == "move_window":
                addr = msg.get("address")
                target_ws = msg.get("target_ws")
                if addr and target_ws:
                    subprocess.run(["hyprctl", "dispatch", "movetoworkspacesilent", f"{target_ws},address:{addr}"], stdout=subprocess.DEVNULL)
                    time.sleep(0.08)
                    self.send_state_to_js()

            elif action == "move_window_to_space":
                addr = msg.get("address")
                target_space = msg.get("target_space")
                current_ws = msg.get("current_ws", "")
                if addr and target_space:
                    tier = 0
                    if str(current_ws).isdigit():
                        ws_num = int(current_ws)
                        tier = (ws_num - 1) // 10
                    target_ws = int(target_space) + tier * 10
                    subprocess.run(["hyprctl", "dispatch", "movetoworkspacesilent", f"{target_ws},address:{addr}"], stdout=subprocess.DEVNULL)
                    time.sleep(0.08)
                    self.send_state_to_js()

            elif action == "swap_window_monitor":
                addr = msg.get("address")
                current_ws = msg.get("current_ws", "")
                if addr and str(current_ws).isdigit():
                    ws_num = int(current_ws)
                    space = ((ws_num - 1) % 10) + 1
                    curr_tier = (ws_num - 1) // 10
                    try:
                        mons_raw = subprocess.check_output(["hyprctl", "monitors", "-j"], text=True)
                        mons = [m for m in json.loads(mons_raw) if not m.get("disabled", False)]
                        mon_count = len(mons)
                    except Exception:
                        mon_count = 2

                    if mon_count > 1:
                        next_tier = (curr_tier + 1) % mon_count
                        target_ws = space + next_tier * 10
                        subprocess.run(["hyprctl", "dispatch", "movetoworkspacesilent", f"{target_ws},address:{addr}"], stdout=subprocess.DEVNULL)
                        time.sleep(0.08)
                        self.send_state_to_js()

            elif action == "toggle_floating":
                addr = msg.get("address")
                if addr:
                    subprocess.run(["hyprctl", "--batch", f"dispatch focuswindow address:{addr} ; dispatch togglefloating"], stdout=subprocess.DEVNULL)
                    time.sleep(0.08)
                    self.send_state_to_js()

            elif action == "toggle_pin":
                addr = msg.get("address")
                if addr:
                    subprocess.run(["hyprctl", "dispatch", "pin", f"address:{addr}"], stdout=subprocess.DEVNULL)
                    time.sleep(0.08)
                    self.send_state_to_js()

            elif action == "rename_space":
                space = msg.get("space")
                name = msg.get("name")
                if space and name:
                    save_workspace_name(space, name)
                    self.send_state_to_js()

            elif action == "switch_space":
                space = msg.get("space")
                subprocess.run(["hyprctl", "dispatch", "togglespecialworkspace", "radar"], stdout=subprocess.DEVNULL)
                if space:
                    subprocess.run(["hyprctl", "eval", f"require('spaces').switch_desktop_space({space})"], stdout=subprocess.DEVNULL)

            elif action == "toggle_scratchpad":
                target = msg.get("target")
                subprocess.run(["hyprctl", "dispatch", "togglespecialworkspace", "radar"], stdout=subprocess.DEVNULL)
                if target:
                    subprocess.run(["hyprctl", "eval", f"require('scratchpads').toggle('{target}')"], stdout=subprocess.DEVNULL)

            elif action == "close":
                subprocess.run(["hyprctl", "dispatch", "togglespecialworkspace", "radar"], stdout=subprocess.DEVNULL)

        except Exception as e:
            sys.stderr.write(f"on_script_message error: {e}\n")

    def on_key_pressed(self, controller, keyval, keycode, state):
        keyname = Gdk.keyval_name(keyval)
        if not keyname:
            return False

        if keyname in ["Escape", "q", "Q"]:
            subprocess.run(["hyprctl", "dispatch", "togglespecialworkspace", "radar"], stdout=subprocess.DEVNULL)
            return True
        elif keyname in ["1", "2", "3", "4", "5", "6", "7", "8", "9"]:
            space = int(keyname)
            subprocess.run(["hyprctl", "dispatch", "togglespecialworkspace", "radar"], stdout=subprocess.DEVNULL)
            subprocess.run(["hyprctl", "eval", f"require('spaces').switch_desktop_space({space})"], stdout=subprocess.DEVNULL)
            return True
        return False

    def listen_socket2(self):
        while self.running:
            his = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
            if not his:
                time.sleep(1.0)
                continue
            runtime_dir = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
            sock_path = f"{runtime_dir}/hypr/{his}/.socket2.sock"

            if not os.path.exists(sock_path):
                time.sleep(0.5)
                continue

            try:
                log(f"Connecting to Hyprland socket2: {sock_path}")
                with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
                    s.connect(sock_path)
                    s_file = s.makefile("r", encoding="utf-8", errors="replace")
                    log("Socket2 connected successfully.")
                    while self.running:
                        line = s_file.readline()
                        if not line:
                            break
                        line = line.strip()

                        if line.startswith("specialworkspace>>"):
                            now_vis = ("special:radar" in line or "radar" in line) or self.check_is_visible()
                            was_vis = self.is_visible
                            self.is_visible = now_vis
                            if now_vis and (not was_vis or self.dirty):
                                self.request_update(force=True)
                            elif not now_vis:
                                self.dirty = True

                        elif any(line.startswith(prefix) for prefix in [
                            "openwindow>>", "closewindow>>", "movewindow>>",
                            "workspace>>", "focusedmon>>", "activewindow>>",
                            "monitoradded>>", "monitorremoved>>"
                        ]):
                            if self.is_visible:
                                self.request_update()
                            else:
                                self.dirty = True
            except Exception as e:
                log(f"Socket2 disconnected: {e}. Reconnecting in 1s...")
                time.sleep(1.0)

class RadarApp(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="com.tokyo.radar", flags=Gio.ApplicationFlags.FLAGS_NONE)
        self.win = None

    def do_activate(self):
        if not self.win:
            self.win = RadarWindow(self)
        self.win.present()

def main():
    app = RadarApp()
    app.run(sys.argv)

if __name__ == "__main__":
    main()
