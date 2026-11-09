#!/usr/bin/env python3
"""
Tokyo 80s TRV30 — Dual-Monitor Display & Power Command Deck
東京 80s TRV30 // 画面構成・電源統御マトリクス (com.tokyo.displaydeck)
"""

import sys
import os
os.environ["WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS"] = "1"
import json
import time
import subprocess
import threading
import socket
import shutil

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('WebKit', '6.0')
from gi.repository import Gtk, WebKit, GLib, Gio, Gdk

SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))
INDEX_URI = f"file://{os.path.join(SCRIPT_DIR, 'index.html')}"
MONITORS_CONF = os.path.expanduser("~/.config/hypr/monitors.conf")
BACKUP_CONF = os.path.expanduser("~/.config/hypr/monitors.conf.bak")

DEFAULT_MONITOR_CONF = """# ═══════════════════════════════════════════════════════════════════════════════
#  TOKYO 80s TRV30 — DYNAMIC MONITOR CONFIGURATION
#  東京 80s TRV30 // ディスプレイ構成設定
# ═══════════════════════════════════════════════════════════════════════════════

# External Big Monitor (Left): native 1080p crisp 1:1 scale
monitor = HDMI-A-1, preferred, 0x0, 1.00

# Laptop Screen (Right): positioned to the right, scaled at 1.30 for easy reading from a distance
monitor = eDP-1, preferred, auto-right, 1.30

# Fallback for other displays or standalone laptop
monitor = , preferred, auto, 1.20
"""

def get_brightness_info():
    try:
        out = subprocess.check_output(["brightnessctl", "-m"], text=True, stderr=subprocess.DEVNULL).strip()
        # format: amdgpu_bl1,backlight,53087,81%,65535
        parts = out.split(",")
        if len(parts) >= 4:
            device = parts[0]
            pct_str = parts[3].replace("%", "").strip()
            return int(pct_str), device
    except Exception:
        pass
    return 80, "backlight"

def get_battery_info():
    info = {"percent": 100, "status": "AC", "charging": True}
    bat_path = "/sys/class/power_supply/BAT0"
    if os.path.exists(bat_path):
        try:
            with open(os.path.join(bat_path, "capacity"), "r") as f:
                info["percent"] = int(f.read().strip())
            with open(os.path.join(bat_path, "status"), "r") as f:
                info["status"] = f.read().strip()
                info["charging"] = (info["status"] in ["Charging", "Full"])
        except Exception:
            pass
    return info

def get_uptime_str():
    try:
        with open("/proc/uptime", "r") as f:
            secs = float(f.readline().split()[0])
            hrs = int(secs // 3600)
            mins = int((secs % 3600) // 60)
            return f"{hrs}h {mins:02d}m"
    except Exception:
        return "--"

def get_system_state():
    # 1. Query monitors
    monitors = []
    try:
        out = subprocess.check_output(["hyprctl", "monitors", "-j"], text=True, stderr=subprocess.DEVNULL)
        monitors = json.loads(out)
    except Exception:
        pass

    # 2. Query workspaces
    workspaces = []
    try:
        out = subprocess.check_output(["hyprctl", "workspaces", "-j"], text=True, stderr=subprocess.DEVNULL)
        workspaces = json.loads(out)
    except Exception:
        pass

    # 3. Brightness
    brightness, br_dev = get_brightness_info()

    # 4. Battery
    battery = get_battery_info()

    # 5. Uptime
    uptime = get_uptime_str()

    return {
        "monitors": monitors,
        "workspaces": workspaces,
        "brightness": brightness,
        "brightness_device": br_dev,
        "battery": battery,
        "uptime": uptime,
        "timestamp": time.strftime("%H:%M:%S")
    }

class DisplayDeckWindow(Gtk.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title="TRV30 Display & Power Deck")
        self.set_default_size(1360, 840)
        self.running = True

        # WebKit Settings
        settings = WebKit.Settings()
        settings.set_enable_developer_extras(False)
        settings.set_javascript_can_access_clipboard(True)
        settings.set_allow_file_access_from_file_urls(True)
        settings.set_allow_universal_access_from_file_urls(True)
        settings.set_hardware_acceleration_policy(WebKit.HardwareAccelerationPolicy.ALWAYS)

        # Content Manager
        content_mgr = WebKit.UserContentManager()
        content_mgr.register_script_message_handler("deck")
        content_mgr.connect("script-message-received::deck", self.on_script_message)

        # WebKit WebView
        self.webview = WebKit.WebView(user_content_manager=content_mgr, settings=settings)
        rgba = Gdk.RGBA()
        rgba.parse("#0a0b0e")
        self.webview.set_background_color(rgba)
        self.webview.connect("load-changed", self.on_load_changed)
        self.webview.load_uri(INDEX_URI)

        # Key controller for ESC and Super+G
        key_ctrl = Gtk.EventControllerKey()
        key_ctrl.connect("key-pressed", self.on_key_pressed)
        self.add_controller(key_ctrl)

        self.set_child(self.webview)

        # Start Hyprland Socket2 listener
        self.socket_thread = threading.Thread(target=self.listen_socket2, daemon=True)
        self.socket_thread.start()

        # Start 2-second background heartbeat
        self.heartbeat_thread = threading.Thread(target=self._heartbeat_worker, daemon=True)
        self.heartbeat_thread.start()

    def _heartbeat_worker(self):
        while self.running:
            try:
                if os.path.exists("/tmp/open_display_modal"):
                    try: os.remove("/tmp/open_display_modal")
                    except Exception: pass
                    GLib.idle_add(lambda: self.webview.evaluate_javascript("if (window.openDisplaySettings) { window.openDisplaySettings(); }", -1, None, None, None, None, None))

                out = subprocess.check_output(["hyprctl", "monitors", "-j"], text=True, stderr=subprocess.DEVNULL)
                is_vis = any(m.get("specialWorkspace", {}).get("name") == "special:display" for m in json.loads(out))
                if is_vis:
                    GLib.idle_add(self.send_state_to_js)
            except Exception:
                pass
            time.sleep(1.0)

    def on_load_changed(self, webview, event):
        if event == WebKit.LoadEvent.FINISHED:
            self.send_state_to_js()

    def on_key_pressed(self, controller, keyval, keycode, state):
        if keyval in [Gdk.KEY_q, Gdk.KEY_Q]:
            subprocess.run(["hyprctl", "dispatch", "togglespecialworkspace", "display"], stdout=subprocess.DEVNULL)
            return True
        elif keyval in [Gdk.KEY_s, Gdk.KEY_S, Gdk.KEY_d, Gdk.KEY_D]:
            self.webview.evaluate_javascript("if (window.openDisplaySettings) { window.openDisplaySettings(); }", -1, None, None, None, None, None)
            return True
        elif keyval in [Gdk.KEY_Escape]:
            self.webview.evaluate_javascript("if (window.handleEscape && window.handleEscape()) {} else { closeDeck(); }", -1, None, None, None, None, None)
            return True
        return False

    def send_state_to_js(self):
        state = get_system_state()
        js = f"if (window.updateDisplayDeck) {{ window.updateDisplayDeck({json.dumps(state)}); }}"
        self.webview.evaluate_javascript(js, -1, None, None, None, None, None)

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

            if action == "get_state":
                self.send_state_to_js()

            elif action == "close":
                subprocess.run(["hyprctl", "dispatch", "togglespecialworkspace", "display"], stdout=subprocess.DEVNULL)

            elif action == "power":
                mode = msg.get("mode", "sleep")
                self.execute_power_action(mode)

            elif action == "set_brightness":
                pct = int(msg.get("percent", 80))
                pct = max(5, min(100, pct))
                subprocess.run(["brightnessctl", "s", f"{pct}%"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                GLib.idle_add(self.send_state_to_js)

            elif action == "set_dpms":
                target = msg.get("target", "all")
                state = msg.get("state", "toggle")
                if target == "all":
                    subprocess.run(["hyprctl", "dispatch", "dpms", state], stdout=subprocess.DEVNULL)
                else:
                    subprocess.run(["hyprctl", "dispatch", "dpms", state, target], stdout=subprocess.DEVNULL)
                GLib.idle_add(self.send_state_to_js)

            elif action == "apply_display_config":
                configs = msg.get("monitors", [])
                self.apply_display_configurations(configs)
                GLib.idle_add(self.send_state_to_js)

            elif action == "apply_preset":
                preset = msg.get("preset")
                self.apply_preset_topology(preset)
                GLib.idle_add(self.send_state_to_js)

            elif action == "revert_config":
                if os.path.exists(BACKUP_CONF):
                    shutil.copy2(BACKUP_CONF, MONITORS_CONF)
                    subprocess.run(["hyprctl", "reload"], stdout=subprocess.DEVNULL)
                    time.sleep(0.3)
                    GLib.idle_add(self.send_state_to_js)

            elif action == "reset_defaults":
                with open(MONITORS_CONF, "w") as f:
                    f.write(DEFAULT_MONITOR_CONF)
                subprocess.run(["hyprctl", "reload"], stdout=subprocess.DEVNULL)
                time.sleep(0.3)
                GLib.idle_add(self.send_state_to_js)

        except Exception as e:
            sys.stderr.write(f"Script message error: {e}\n")

    def execute_power_action(self, mode):
        # Close the special workspace first so screen is clear
        subprocess.run(["hyprctl", "dispatch", "togglespecialworkspace", "display"], stdout=subprocess.DEVNULL)

        if mode == "sleep":
            # Sleep / Suspend (S3)
            subprocess.run(["playerctl", "-a", "pause"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.run(["hyprctl", "eval", 'hl.config({ misc = { mouse_move_enables_dpms = false, key_press_enables_dpms = true } })'], stdout=subprocess.DEVNULL)
            subprocess.run(["loginctl", "lock-session"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            time.sleep(0.3)
            subprocess.run(["systemctl", "suspend"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        elif mode == "screen":
            # Screen Off (DPMS)
            subprocess.run(["playerctl", "-a", "pause"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.run(["hyprctl", "eval", 'hl.config({ misc = { mouse_move_enables_dpms = false, key_press_enables_dpms = true } })'], stdout=subprocess.DEVNULL)
            subprocess.run(["loginctl", "lock-session"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            time.sleep(0.3)
            subprocess.run(["hyprctl", "dispatch", "dpms", "off"], stdout=subprocess.DEVNULL)

        elif mode == "lock":
            # Lock Session
            subprocess.run(["loginctl", "lock-session"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        elif mode == "poweroff":
            # Power Off
            subprocess.run(["systemctl", "poweroff"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        elif mode == "reboot":
            # Reboot
            subprocess.run(["systemctl", "reboot"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        elif mode == "hibernate":
            # Hibernate (S4)
            subprocess.run(["playerctl", "-a", "pause"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.run(["systemctl", "hibernate"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    def apply_display_configurations(self, configs):
        if not configs:
            return

        # 1. Backup current monitors.conf
        if os.path.exists(MONITORS_CONF):
            try:
                shutil.copy2(MONITORS_CONF, BACKUP_CONF)
            except Exception:
                pass

        # 2. Build configuration lines
        conf_lines = [
            "# ═══════════════════════════════════════════════════════════════════════════════",
            "#  TOKYO 80s TRV30 — DYNAMIC MONITOR CONFIGURATION",
            f"#  Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}",
            "# ═══════════════════════════════════════════════════════════════════════════════\n"
        ]

        for m in configs:
            name = m.get("name")
            if not name:
                continue

            disabled = m.get("disabled", False)
            if disabled:
                conf_lines.append(f"monitor = {name}, disable")
                subprocess.run(["hyprctl", "eval", f'hl.monitor({{ output = "{name}", disabled = true }})'], stdout=subprocess.DEVNULL)
                continue

            mode = m.get("mode", "preferred")
            pos_x = m.get("x", 0)
            pos_y = m.get("y", 0)
            scale = m.get("scale", 1.0)
            transform = m.get("transform", 0)
            vrr = m.get("vrr", False)
            mirror = m.get("mirrorOf", "none")

            pos_str = f"{pos_x}x{pos_y}"
            if mirror and mirror != "none":
                rule = f"monitor = {name}, preferred, auto, {scale}, mirror, {mirror}"
                subprocess.run(["hyprctl", "eval", f'hl.monitor({{ output = "{name}", mode = "preferred", position = "auto", scale = {scale}, mirror = "{mirror}", disabled = false }})'], stdout=subprocess.DEVNULL)
            elif transform and int(transform) > 0:
                rule = f"monitor = {name}, {mode}, {pos_str}, {scale}, transform, {transform}"
                subprocess.run(["hyprctl", "eval", f'hl.monitor({{ output = "{name}", mode = "{mode}", position = "{pos_str}", scale = {scale}, disabled = false }})'], stdout=subprocess.DEVNULL)
            else:
                rule = f"monitor = {name}, {mode}, {pos_str}, {scale}"
                subprocess.run(["hyprctl", "eval", f'hl.monitor({{ output = "{name}", mode = "{mode}", position = "{pos_str}", scale = {scale}, disabled = false }})'], stdout=subprocess.DEVNULL)

            if vrr:
                rule += ", vrr, 1"

            conf_lines.append(rule)

        conf_lines.append("\n# Fallback wildcard\nmonitor = , preferred, auto, 1.20\n")

        # 3. Write out to ~/.config/hypr/monitors.conf and monitors.lua
        try:
            with open(MONITORS_CONF, "w") as f:
                f.write("\n".join(conf_lines))
            lua_lines = ["-- Dynamic monitors generated by display-deck"]
            for m in configurations:
                name = m.get("name")
                if not name: continue
                if m.get("disabled", False):
                    lua_lines.append(f'hl.monitor({{ output = "{name}", disabled = true }})')
                else:
                    mode = m.get("mode", "preferred")
                    pos_str = f"{m.get('x', 0)}x{m.get('y', 0)}"
                    scale = m.get("scale", 1.0)
                    lua_lines.append(f'hl.monitor({{ output = "{name}", mode = "{mode}", position = "{pos_str}", scale = {scale}, disabled = false }})')
            lua_lines.append('hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1.20 })\n')
            with open(os.path.expanduser("~/.config/hypr/monitors.lua"), "w") as f:
                f.write("\n".join(lua_lines))
        except Exception as e:
            sys.stderr.write(f"Error saving monitors: {e}\n")
        except Exception as e:
            sys.stderr.write(f"Error saving monitors.conf: {e}\n")

    def apply_preset_topology(self, preset):
        if preset == "extend_default":
            # HDMI Left (0x0, 1.00), eDP Right (auto-right, 1.30)
            configs = [
                {"name": "HDMI-A-1", "mode": "1920x1080@60.00Hz", "x": 0, "y": 0, "scale": 1.00, "transform": 0},
                {"name": "eDP-1", "mode": "1920x1200@60.00Hz", "x": 1920, "y": 0, "scale": 1.30, "transform": 0}
            ]
            self.apply_display_configurations(configs)

        elif preset == "extend_reverse":
            # eDP Left (0x0, 1.30), HDMI Right (1920x0, 1.00)
            configs = [
                {"name": "eDP-1", "mode": "1920x1200@60.00Hz", "x": 0, "y": 0, "scale": 1.30, "transform": 0},
                {"name": "HDMI-A-1", "mode": "1920x1080@60.00Hz", "x": 1920, "y": 0, "scale": 1.00, "transform": 0}
            ]
            self.apply_display_configurations(configs)

        elif preset == "mirror":
            # Mirror HDMI-A-1 onto eDP-1
            configs = [
                {"name": "HDMI-A-1", "mode": "1920x1080@60.00Hz", "x": 0, "y": 0, "scale": 1.00, "transform": 0},
                {"name": "eDP-1", "mode": "preferred", "x": 0, "y": 0, "scale": 1.00, "mirrorOf": "HDMI-A-1"}
            ]
            self.apply_display_configurations(configs)

        elif preset == "laptop_only":
            # Disable HDMI, keep eDP-1 at native 1.30
            configs = [
                {"name": "eDP-1", "mode": "1920x1200@60.00Hz", "x": 0, "y": 0, "scale": 1.30, "transform": 0},
                {"name": "HDMI-A-1", "disabled": True}
            ]
            self.apply_display_configurations(configs)

        elif preset == "external_only":
            # Disable eDP-1, keep HDMI at native 1.00
            configs = [
                {"name": "HDMI-A-1", "mode": "1920x1080@60.00Hz", "x": 0, "y": 0, "scale": 1.00, "transform": 0},
                {"name": "eDP-1", "disabled": True}
            ]
            self.apply_display_configurations(configs)

    def listen_socket2(self):
        his = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
        xdg = os.environ.get("XDG_RUNTIME_DIR", "/run/user/1000")
        if not his:
            return
        sock_path = f"{xdg}/hypr/{his}/.socket2.sock"

        while self.running:
            try:
                s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                s.connect(sock_path)
                s_file = s.makefile("r", encoding="utf-8")
                while self.running:
                    line = s_file.readline()
                    if not line:
                        break
                    line = line.strip()
                    if any(line.startswith(prefix) for prefix in [
                        "monitoradded>>", "monitorremoved>>", "focusedmon>>", "dpms>>"
                    ]):
                        GLib.idle_add(self.send_state_to_js)
            except Exception:
                time.sleep(1.0)

class DisplayDeckApp(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="com.tokyo.displaydeck", flags=Gio.ApplicationFlags.FLAGS_NONE)
        self.win = None

    def do_activate(self):
        if not self.win:
            self.win = DisplayDeckWindow(self)
        self.win.present()

def main():
    app = DisplayDeckApp()
    app.run(sys.argv)

if __name__ == "__main__":
    main()
