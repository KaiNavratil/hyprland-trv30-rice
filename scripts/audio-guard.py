#!/usr/bin/env python3
import os
import re
import subprocess
import threading
import time
import json

import dbus
import dbus.mainloop.glib
from gi.repository import GLib

def run_cmd(cmd):
    try:
        return subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""

def get_sinks():
    out = run_cmd(["pactl", "list", "sinks", "short"])
    sinks = []
    for line in out.splitlines():
        parts = line.split()
        if len(parts) >= 2:
            sinks.append(parts[1])
    return sinks

def get_default_sink():
    return run_cmd(["pactl", "get-default-sink"])

def get_sink_mute(sink):
    out = run_cmd(["pactl", "get-sink-mute", sink])
    if "yes" in out:
        return "1"
    elif "no" in out:
        return "0"
    return None

def sync_mute_state():
    sinks = get_sinks()
    default_sink = get_default_sink()
    if not default_sink or not sinks:
        return

    def_mute = get_sink_mute(default_sink)
    if def_mute is not None:
        for s in sinks:
            if s != default_sink and "alsa_output" in s:
                cur_m = get_sink_mute(s)
                if cur_m is not None and cur_m != def_mute:
                    subprocess.run(["pactl", "set-sink-mute", s, def_mute], stderr=subprocess.DEVNULL)

def handle_device_connected(mac):
    # Wait for the initial incoming connection and potential A2DP collision to settle
    time.sleep(1.2)
    sinks = get_sinks()
    
    # If PipeWire hasn't created a bluez_output sink, the auto-connect hit the A2DP EBUSY bug
    if not any("bluez" in s for s in sinks):
        # Force outgoing connect from PC side to establish the A2DP profile
        subprocess.run(["bluetoothctl", "connect", mac], stderr=subprocess.DEVNULL)
        time.sleep(1.5)
        sinks = get_sinks()
        
        # If still missing, WirePlumber's session manager is hung: restart it
        if not any("bluez" in s for s in sinks):
            subprocess.run(["systemctl", "--user", "restart", "wireplumber"], stderr=subprocess.DEVNULL)
            time.sleep(1.5)
            sinks = get_sinks()

    # Route default sink to the connected Bluetooth headphones
    for s in sinks:
        if "bluez" in s:
            subprocess.run(["pactl", "set-default-sink", s], stderr=subprocess.DEVNULL)
            break
            
    sync_mute_state()

def handle_device_disconnected():
    # Grace period (1.5s): handles single earbud handover (putting one earbud into the case)
    time.sleep(1.5)
    
    # Check if Bluetooth audio is still present or handed over to the other earbud
    sinks = get_sinks()
    if any("bluez" in s for s in sinks):
        sync_mute_state()
        return

    # Check if any bluetooth audio device is still connected in BlueZ
    out = run_cmd(["bluetoothctl", "devices", "Connected"])
    if "70:5A:6F:6B:56:7B" in out:
        sync_mute_state()
        return

    # Genuine full disconnect (both earbuds off/in case): pause media
    subprocess.run(["playerctl", "-a", "pause"], stderr=subprocess.DEVNULL)
    subprocess.run(["dunstify", "-a", "osd", "-r", "9999", "BT DISCONNECT ❚❚", ""], stderr=subprocess.DEVNULL)
    time.sleep(0.2)
    sync_mute_state()

def pactl_listener():
    sync_mute_state()
    while True:
        proc = None
        try:
            proc = subprocess.Popen(
                ["pactl", "subscribe"],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
            )
            for line in proc.stdout:
                if any(k in line for k in ("sink", "server")):
                    sync_mute_state()
            proc.wait()
        except Exception:
            pass
        finally:
            if proc and proc.poll() is None:
                try: proc.terminate()
                except Exception: pass
        time.sleep(1)

def on_dbus_prop_changed(interface, changed, invalidated, path):
    if interface == "org.bluez.Device1" and "Connected" in changed:
        is_connected = bool(changed["Connected"])
        
        # Check if the device is an audio device
        try:
            bus = dbus.SystemBus()
            dev_obj = bus.get_object("org.bluez", path)
            dev_iface = dbus.Interface(dev_obj, "org.bluez.Device1")
            props = dbus.Interface(dev_obj, "org.freedesktop.DBus.Properties")
            uuids = props.Get("org.bluez.Device1", "UUIDs")
            icon = props.Get("org.bluez.Device1", "Icon") if "Icon" in props.GetAll("org.bluez.Device1") else ""
            
            # Check for A2DP / Headset / Audio Sink UUIDs
            is_audio = any("110b" in u.lower() or "110d" in u.lower() or "1108" in u.lower() for u in uuids) or "audio" in icon
            if not is_audio:
                return
                
            mac_match = re.search(r"dev_([0-9A-Fa-f_]+)", path)
            if not mac_match:
                return
            mac = mac_match.group(1).replace("_", ":")
            
            if is_connected:
                threading.Thread(target=handle_device_connected, args=(mac,), daemon=True).start()
            else:
                threading.Thread(target=handle_device_disconnected, daemon=True).start()
        except Exception:
            pass

def is_discord_in_call():
    # 1. Check Hyprland idle-inhibition on vesktop (Wayland voice/video call indicator)
    try:
        out = subprocess.check_output(["hyprctl", "clients", "-j"], text=True, stderr=subprocess.DEVNULL)
        clients = json.loads(out)
        for c in clients:
            if c.get("class") == "vesktop" and c.get("inhibitingIdle") is True:
                return True
    except Exception:
        pass

    # 2. Check established UDP voice sockets (with -n for instant non-blocking check)
    try:
        out = subprocess.check_output(["ss", "-u", "-a", "-p", "-n"], text=True, stderr=subprocess.DEVNULL)
        for line in out.splitlines():
            if any(p in line for p in ("vesktop", "discord")) and "ESTAB" in line:
                return True
    except Exception:
        pass

    return False

def discord_call_watcher():
    in_call_state = is_discord_in_call()
    no_call_counter = 0

    # Ensure profile matches current state on start
    card_out = run_cmd(["pactl", "list", "cards", "short"])
    if "bluez_card" in card_out and in_call_state:
        card = ""
        for line in card_out.splitlines():
            if "bluez_card" in line:
                card = line.split()[1]
                break
        if card:
            subprocess.run(["pactl", "set-card-profile", card, "headset-head-unit"], stderr=subprocess.DEVNULL)
            time.sleep(0.5)
            sources = run_cmd(["pactl", "list", "sources", "short"])
            for s in sources.splitlines():
                if "bluez_input" in s:
                    subprocess.run(["pactl", "set-default-source", s.split()[1]], stderr=subprocess.DEVNULL)
                    break

    while True:
        try:
            time.sleep(2)
            card_out = run_cmd(["pactl", "list", "cards", "short"])
            if "bluez_card" not in card_out:
                continue

            card = ""
            for line in card_out.splitlines():
                if "bluez_card" in line:
                    card = line.split()[1]
                    break
            if not card:
                continue

            current_check = is_discord_in_call()

            if current_check:
                # Active in call
                no_call_counter = 0
                if not in_call_state:
                    in_call_state = True
                    subprocess.run(["pactl", "set-card-profile", card, "headset-head-unit"], stderr=subprocess.DEVNULL)
                    time.sleep(0.5)
                    sources = run_cmd(["pactl", "list", "sources", "short"])
                    for s in sources.splitlines():
                        if "bluez_input" in s:
                            subprocess.run(["pactl", "set-default-source", s.split()[1]], stderr=subprocess.DEVNULL)
                            break
                    subprocess.run(["dunstify", "-a", "osd", "-r", "9998", "🎙️ DISCORD CALL", "EarFun Mic Active"], stderr=subprocess.DEVNULL)
            else:
                # Negative check: require 5 consecutive checks (~10 seconds) of no call before disconnecting
                if in_call_state:
                    no_call_counter += 1
                    if no_call_counter >= 5:
                        in_call_state = False
                        no_call_counter = 0
                        subprocess.run(["pactl", "set-card-profile", card, "a2dp-sink"], stderr=subprocess.DEVNULL)
                        time.sleep(0.5)
                        sinks = get_sinks()
                        for s in sinks:
                            if "bluez" in s:
                                subprocess.run(["pactl", "set-default-sink", s], stderr=subprocess.DEVNULL)
                                break
                        sources = run_cmd(["pactl", "list", "sources", "short"])
                        for s in sources.splitlines():
                            if "alsa_input" in s and "Mic1" in s:
                                subprocess.run(["pactl", "set-default-source", s.split()[1]], stderr=subprocess.DEVNULL)
                                break
                        subprocess.run(["dunstify", "-a", "osd", "-r", "9998", "🎧 DISCORD DISCONNECT", "EarFun Hi-Fi Active"], stderr=subprocess.DEVNULL)
        except Exception:
            pass

def main():
    threading.Thread(target=pactl_listener, daemon=True).start()
    threading.Thread(target=discord_call_watcher, daemon=True).start()

    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SystemBus()
    bus.add_signal_receiver(
        on_dbus_prop_changed,
        signal_name="PropertiesChanged",
        dbus_interface="org.freedesktop.DBus.Properties",
        path_keyword="path"
    )

    loop = GLib.MainLoop()
    loop.run()

if __name__ == "__main__":
    main()

