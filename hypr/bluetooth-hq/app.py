#!/usr/bin/env python3
"""
Tokyo 80s TRV30 — Bluetooth Tactical Headquarters & Audio Command Deck
東京 80s TRV30 // 無線統御司令部 (com.tokyo.bluetoothhq)
"""

import sys
import os
os.environ["WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS"] = "1"
import json
import time
import subprocess
import threading
import re

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('WebKit', '6.0')
from gi.repository import Gtk, WebKit, GLib, Gio, Gdk

SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))
INDEX_URI = f"file://{os.path.join(SCRIPT_DIR, 'index.html')}"
USUAL_MAC = "70:5A:6F:6B:56:7B"
USUAL_NAME = "EarFun Air Pro 4"

def run_cmd(args):
    try:
        return subprocess.check_output(args, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""

def get_bluetooth_state():
    # 1. Controller / Power status
    show_out = run_cmd(["bluetoothctl", "show"])
    is_powered = "Powered: yes" in show_out
    is_discovering = "Discovering: yes" in show_out
    controller_mac = ""
    m = re.search(r"Controller ([0-9A-Fa-f:]+)", show_out)
    if m:
        controller_mac = m.group(1)

    # Check rfkill
    rf_out = run_cmd(["rfkill", "list", "bluetooth"])
    is_rf_blocked = "Soft blocked: yes" in rf_out or "Hard blocked: yes" in rf_out

    # 2. Paired Devices
    dev_out = run_cmd(["bluetoothctl", "devices"])
    devices = []
    seen_macs = set()

    for line in dev_out.splitlines():
        parts = line.strip().split()
        if len(parts) >= 3 and parts[0] == "Device":
            mac = parts[1]
            name = " ".join(parts[2:])
            seen_macs.add(mac)

            info = run_cmd(["bluetoothctl", "info", mac])
            connected = "Connected: yes" in info
            paired = "Paired: yes" in info
            trusted = "Trusted: yes" in info

            bat = None
            bat_m = re.search(r"Battery Percentage:.*\((.+)\)", info)
            if bat_m:
                try:
                    bat = int(bat_m.group(1))
                except Exception:
                    pass

            icon = "headphones"
            if any(k in name.lower() for k in ("phone", "iphone", "galaxy", "pixel")):
                icon = "phone"
            elif any(k in name.lower() for k in ("mouse", "keyboard", "controller", "gamepad")):
                icon = "input"

            devices.append({
                "mac": mac,
                "name": name,
                "connected": connected,
                "paired": paired,
                "trusted": trusted,
                "battery": bat,
                "icon": icon,
                "is_usual": (mac.upper() == USUAL_MAC.upper())
            })

    # Always ensure Usual device is represented even if powered off
    if not any(d["is_usual"] for d in devices):
        info = run_cmd(["bluetoothctl", "info", USUAL_MAC])
        devices.insert(0, {
            "mac": USUAL_MAC,
            "name": USUAL_NAME,
            "connected": "Connected: yes" in info,
            "paired": True,
            "trusted": True,
            "battery": None,
            "icon": "headphones",
            "is_usual": True
        })

    # 3. Audio Pipeline Status
    cards_out = run_cmd(["pactl", "list", "cards"])
    bluez_profile = "none"
    active_codec = "None"

    if "bluez_card" in cards_out:
        card_m = re.search(r"Name: (bluez_card\.[^\n]+)", cards_out)
        if card_m:
            prof_m = re.search(r"Active Profile: ([^\n]+)", cards_out)
            if prof_m:
                bluez_profile = prof_m.group(1).strip()
                if "a2dp" in bluez_profile:
                    if "aptx" in bluez_profile or "a2dp-sink" == bluez_profile:
                        active_codec = "aptX High-Res Stereo (48kHz)"
                    elif "aac" in bluez_profile:
                        active_codec = "AAC 48kHz Stereo"
                    elif "sbc_xq" in bluez_profile:
                        active_codec = "SBC-XQ High-Bitrate Stereo"
                    else:
                        active_codec = "A2DP Hi-Fi Stereo"
                elif "headset" in bluez_profile:
                    active_codec = "mSBC Call / Voice Mode (Mono)"

    # Default sink and source
    default_sink = run_cmd(["pactl", "get-default-sink"])
    default_source = run_cmd(["pactl", "get-default-source"])

    sink_label = "Laptop Speakers"
    if "bluez" in default_sink:
        sink_label = f"{USUAL_NAME} (Bluetooth)"
    elif "HDMI" in default_sink or "hdmi" in default_sink:
        sink_label = "HDMI / Projector Audio"

    source_label = "Laptop Digital Mic (Armed)"
    if "bluez" in default_source:
        source_label = f"{USUAL_NAME} Mic (Call Mode)"

    return {
        "powered": is_powered and not is_rf_blocked,
        "rf_blocked": is_rf_blocked,
        "discovering": is_discovering,
        "controller_mac": controller_mac,
        "devices": devices,
        "audio": {
            "profile": bluez_profile,
            "codec": active_codec,
            "is_hifi": "a2dp" in bluez_profile,
            "is_call": "headset" in bluez_profile,
            "default_sink": sink_label,
            "default_source": source_label,
        },
        "timestamp": time.strftime("%H:%M:%S")
    }

class BluetoothHQWindow(Gtk.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title="TRV30 Bluetooth Headquarters")
        self.set_default_size(920, 620)
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
        content_mgr.register_script_message_handler("bthq")
        content_mgr.connect("script-message-received::bthq", self.on_script_message)

        # WebKit WebView
        self.webview = WebKit.WebView(user_content_manager=content_mgr, settings=settings)
        rgba = Gdk.RGBA()
        rgba.parse("#0e0d0c")
        self.webview.set_background_color(rgba)
        self.webview.connect("load-changed", self.on_load_changed)
        self.webview.load_uri(INDEX_URI)

        # Key controller (CAPTURE phase ensures Escape/Q works even when WebKit has focus)
        ev_ctrl = Gtk.EventControllerKey.new()
        ev_ctrl.set_propagation_phase(Gtk.PropagationPhase.CAPTURE)
        ev_ctrl.connect("key-pressed", self.on_key_pressed)
        self.add_controller(ev_ctrl)

        self.set_child(self.webview)

        # Auto poller every 1.8 seconds to keep UI responsive to connects/disconnects
        GLib.timeout_add(1800, self.periodic_poll)

    def on_load_changed(self, webview, event):
        if event == WebKit.LoadEvent.FINISHED:
            self.send_state_to_js()

    def on_key_pressed(self, controller, keyval, keycode, state):
        if keyval in (Gdk.KEY_Escape, Gdk.KEY_q, Gdk.KEY_Q):
            self.close_hq()
            return True
        return False

    def close_hq(self):
        subprocess.run(["hyprctl", "eval", "require('scratchpads').toggle('bluetooth')"], stdout=subprocess.DEVNULL)

    def periodic_poll(self):
        if not self.running:
            return False
        # Only poll if window is mapped / visible
        if self.is_visible():
            threading.Thread(target=self._async_poll, daemon=True).start()
        return True

    def _async_poll(self):
        state = get_bluetooth_state()
        GLib.idle_add(lambda: self._push_state(state))

    def _push_state(self, state):
        js = f"if (window.updateBluetoothHQ) {{ window.updateBluetoothHQ({json.dumps(state)}); }}"
        self.webview.evaluate_javascript(js, -1, None, None, None, None, None)

    def send_state_to_js(self):
        threading.Thread(target=self._async_poll, daemon=True).start()

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
                self.close_hq()

            elif action == "toggle_power":
                threading.Thread(target=self._action_toggle_power, daemon=True).start()

            elif action == "toggle_scan":
                scan_on = msg.get("scan", True)
                threading.Thread(target=self._action_toggle_scan, args=(scan_on,), daemon=True).start()

            elif action == "connect":
                mac = msg.get("mac", USUAL_MAC)
                threading.Thread(target=self._action_connect, args=(mac,), daemon=True).start()

            elif action == "disconnect":
                mac = msg.get("mac", USUAL_MAC)
                threading.Thread(target=self._action_disconnect, args=(mac,), daemon=True).start()

            elif action == "toggle_audio_mode":
                threading.Thread(target=self._action_toggle_audio, daemon=True).start()

            elif action == "remove":
                mac = msg.get("mac")
                if mac:
                    threading.Thread(target=self._action_remove, args=(mac,), daemon=True).start()

            elif action == "restart_pipeline":
                threading.Thread(target=self._action_restart_pipeline, daemon=True).start()

        except Exception as e:
            print(f"[BluetoothHQ Error] on_script_message: {e}", file=sys.stderr)

    def _action_toggle_power(self):
        st = get_bluetooth_state()
        if st["powered"]:
            subprocess.run(["bluetoothctl", "power", "off"], stdout=subprocess.DEVNULL)
        else:
            subprocess.run(["rfkill", "unblock", "bluetooth"], stdout=subprocess.DEVNULL)
            time.sleep(0.3)
            subprocess.run(["bluetoothctl", "power", "on"], stdout=subprocess.DEVNULL)
        time.sleep(0.5)
        self.send_state_to_js()

    def _action_toggle_scan(self, scan_on):
        cmd = "scan on" if scan_on else "scan off"
        subprocess.run(["bluetoothctl", cmd.split()[0], cmd.split()[1]], stdout=subprocess.DEVNULL)
        time.sleep(0.5)
        self.send_state_to_js()

    def _action_connect(self, mac):
        subprocess.run(["rfkill", "unblock", "bluetooth"], stdout=subprocess.DEVNULL)
        subprocess.run(["bluetoothctl", "power", "on"], stdout=subprocess.DEVNULL)
        time.sleep(0.3)
        subprocess.run(["bluetoothctl", "connect", mac], stdout=subprocess.DEVNULL)
        time.sleep(1.0)
        # Ensure Hi-Fi profile if it's the usual
        if mac.upper() == USUAL_MAC.upper():
            subprocess.run(["bash", os.path.expanduser("~/.config/hypr/scripts/toggle-usual-bluetooth.sh")], stdout=subprocess.DEVNULL)
        self.send_state_to_js()

    def _action_disconnect(self, mac):
        subprocess.run(["bluetoothctl", "disconnect", mac], stdout=subprocess.DEVNULL)
        time.sleep(0.5)
        self.send_state_to_js()

    def _action_toggle_audio(self):
        script = os.path.expanduser("~/.config/hypr/scripts/toggle-audio-quality.sh")
        subprocess.run(["bash", script], stdout=subprocess.DEVNULL)
        time.sleep(0.5)
        self.send_state_to_js()

    def _action_remove(self, mac):
        subprocess.run(["bluetoothctl", "remove", mac], stdout=subprocess.DEVNULL)
        time.sleep(0.5)
        self.send_state_to_js()

    def _action_restart_pipeline(self):
        subprocess.run(["systemctl", "--user", "restart", "wireplumber"], stdout=subprocess.DEVNULL)
        time.sleep(1.5)
        self.send_state_to_js()


class BluetoothHQApp(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="com.tokyo.bluetoothhq",
                         flags=Gio.ApplicationFlags.FLAGS_NONE)

    def do_activate(self):
        win = self.props.active_window
        if not win:
            win = BluetoothHQWindow(self)
        win.present()

if __name__ == "__main__":
    app = BluetoothHQApp()
    sys.exit(app.run(sys.argv))
