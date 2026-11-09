#!/usr/bin/env python3
"""
Tokyo 80s TRV30 Master Deck — GTK4 + WebKit6 Host Application
Provides hardware-accelerated retro UI with bi-directional native IPC
"""

import sys
import os
# Allow WebKit web processes direct access to webcam and PipeWire without bubblewrap sandbox restrictions
os.environ["WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS"] = "1"
import json
import time
import subprocess
import glob
import shutil
import threading
import socket

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('WebKit', '6.0')
from gi.repository import Gtk, WebKit, GLib, Gio

SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))
INDEX_URI = f"file://{os.path.join(SCRIPT_DIR, 'index.html')}"
LOG_FILE = "/tmp/command-center.log"

def log(msg):
    ts = time.strftime("%Y-%m-%d %H:%M:%S")
    entry = f"[{ts}] {msg}\n"
    sys.stderr.write(entry)
    try:
        with open(LOG_FILE, "a") as f:
            f.write(entry)
    except Exception:
        pass

# Global state for CPU delta calculation
prev_cpu_total = 0
prev_cpu_idle = 0
prev_core_stats = {}

def get_cpu_info():
    global prev_cpu_total, prev_cpu_idle, prev_core_stats
    total_usage = 0
    cores_usage = []
    try:
        with open('/proc/stat', 'r') as f:
            lines = f.readlines()
        
        # Line 0: overall cpu
        fields = [float(x) for x in lines[0].strip().split()[1:]]
        idle = fields[3] + fields[4] # idle + iowait
        total = sum(fields)
        diff_total = total - prev_cpu_total
        diff_idle = idle - prev_cpu_idle
        prev_cpu_total = total
        prev_cpu_idle = idle
        if diff_total > 0:
            total_usage = max(0, min(100, int(round(100.0 * (1.0 - (diff_idle / diff_total))))))
        
        for line in lines[1:]:
            parts = line.strip().split()
            if not parts: continue
            name = parts[0]
            if name.startswith('cpu') and name != 'cpu':
                c_fields = [float(x) for x in parts[1:]]
                c_idle = c_fields[3] + c_fields[4]
                c_total = sum(c_fields)
                
                prev = prev_core_stats.get(name)
                prev_core_stats[name] = (c_total, c_idle)
                
                if prev:
                    d_tot = c_total - prev[0]
                    d_idl = c_idle - prev[1]
                    if d_tot > 0:
                        c_pct = max(0, min(100, int(round(100.0 * (1.0 - (d_idl / d_tot))))))
                        cores_usage.append(c_pct)
                    else:
                        cores_usage.append(0)
                else:
                    cores_usage.append(0)
            else:
                break
    except Exception:
        pass
    
    return {"total": total_usage, "cores": cores_usage}

def get_cpu_usage():
    return get_cpu_info()["total"]

def get_memory_info():
    try:
        mem = {}
        with open('/proc/meminfo', 'r') as f:
            for line in f:
                parts = line.split(':')
                if len(parts) == 2:
                    mem[parts[0].strip()] = int(parts[1].split()[0])
        total_kb = mem.get('MemTotal', 1)
        avail_kb = mem.get('MemAvailable', 0)
        free_kb = mem.get('MemFree', 0)
        cached_kb = mem.get('Cached', 0) + mem.get('Buffers', 0)
        used_kb = total_kb - avail_kb
        
        total_gb = round(total_kb / (1024 * 1024), 1)
        used_gb = round(used_kb / (1024 * 1024), 1)
        avail_gb = round(avail_kb / (1024 * 1024), 1)
        cached_gb = round(cached_kb / (1024 * 1024), 1)
        pct = int(round((used_kb / total_kb) * 100))
        return {
            "total_gb": total_gb,
            "used_gb": used_gb,
            "avail_gb": avail_gb,
            "cached_gb": cached_gb,
            "pct": pct
        }
    except Exception:
        return {"total_gb": 14.3, "used_gb": 0.0, "avail_gb": 14.3, "cached_gb": 0.0, "pct": 0}

def get_zram_info():
    try:
        with open('/sys/block/zram0/disksize', 'r') as f:
            disksize_b = int(f.read().strip())
        with open('/sys/block/zram0/mm_stat', 'r') as f:
            mm = f.read().split()
            orig_b = int(mm[0])
            compr_b = int(mm[1])
            mem_used_b = int(mm[2])
            
        disk_gb = round(disksize_b / (1024**3), 1)
        orig_gb = round(orig_b / (1024**3), 2)
        compr_gb = round(compr_b / (1024**3), 2)
        ratio = round(orig_b / compr_b, 1) if compr_b > 0 else 3.2
        pct = int(round((orig_b / disksize_b) * 100)) if disksize_b > 0 else 0
        return {
            "total_gb": disk_gb,
            "orig_gb": orig_gb,
            "compr_gb": compr_gb,
            "ratio": ratio,
            "pct": pct
        }
    except Exception:
        return {"total_gb": 14.3, "orig_gb": 0.0, "compr_gb": 0.0, "ratio": 3.2, "pct": 0}

def get_disk_info():
    try:
        stat = shutil.disk_usage('/')
        total_gb = round(stat.total / (1024**3), 1)
        used_gb = round(stat.used / (1024**3), 1)
        free_gb = round(stat.free / (1024**3), 1)
        pct = int(round((stat.used / stat.total) * 100))
        return {"total_gb": total_gb, "used_gb": used_gb, "free_gb": free_gb, "pct": pct}
    except Exception:
        return {"total_gb": 500.0, "used_gb": 120.0, "free_gb": 380.0, "pct": 24}

def get_disk_remain():
    d = get_disk_info()
    return f"{d['free_gb']} GB"

def get_session_time():
    try:
        with open('/proc/uptime', 'r') as f:
            sec = int(float(f.readline().split()[0]))
        h, rem = divmod(sec, 3600)
        m, s = divmod(rem, 60)
        return f"{h:02d}:{m:02d}:{s:02d}"
    except Exception:
        return "00:00:00"

def get_battery_info():
    try:
        cap = 100
        status = "Discharging"
        if os.path.exists('/sys/class/power_supply/BAT0/capacity'):
            with open('/sys/class/power_supply/BAT0/capacity', 'r') as f:
                cap = int(f.read().strip())
            with open('/sys/class/power_supply/BAT0/status', 'r') as f:
                status = f.read().strip()
        return {"pct": cap, "status": status}
    except Exception:
        return {"pct": 100, "status": "Full"}

last_vol_time = 0
cached_vol = {"vol": 70, "muted": False}

def get_volume():
    global last_vol_time, cached_vol
    now = time.time()
    if now - last_vol_time < 2.5:
        return cached_vol
    last_vol_time = now
    try:
        out = subprocess.check_output(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"], text=True, stderr=subprocess.DEVNULL)
        parts = out.strip().split()
        if len(parts) >= 2:
            vol = int(float(parts[1]) * 100)
            muted = "MUTED" in out
            cached_vol = {"vol": vol, "muted": muted}
            return cached_vol
    except Exception:
        pass
    return cached_vol

last_bright_time = 0
cached_bright = 80

def get_brightness():
    global last_bright_time, cached_bright
    now = time.time()
    if now - last_bright_time < 3.5:
        return cached_bright
    last_bright_time = now
    try:
        out = subprocess.check_output(["brightnessctl", "-m"], text=True, stderr=subprocess.DEVNULL)
        line = out.strip().splitlines()[0]
        pct_str = line.split(',')[3].replace('%', '')
        cached_bright = int(pct_str)
        return cached_bright
    except Exception:
        return cached_bright

last_media_time = 0
cached_media = {
    "status": "Stopped",
    "artist": "Cassette Idle",
    "title": "Insert Tape / Start Music",
    "progress": 0.0,
    "pos_str": "00:00"
}

def get_media_info():
    global last_media_time, cached_media
    now = time.time()
    if now - last_media_time < 1.5:
        return cached_media
    last_media_time = now
    try:
        fmt = '{"status":"{{status}}","artist":"{{artist}}","title":"{{title}}","position":{{position}},"length":{{mpris:length}}}'
        out = subprocess.check_output(["playerctl", "metadata", "--format", fmt], text=True, stderr=subprocess.DEVNULL).strip()
        if out:
            data = json.loads(out)
            pos_sec = data.get("position", 0) / 1000000.0
            len_sec = data.get("length", 1) / 1000000.0
            pct = (pos_sec / len_sec) if len_sec > 0 else 0.0
            data["progress"] = min(1.0, max(0.0, pct))
            m, s = divmod(int(pos_sec), 60)
            data["pos_str"] = f"{m:02d}:{s:02d}"
            cached_media = data
            return cached_media
    except Exception:
        pass
    return cached_media

last_modes_time = 0
cached_audio_mode = "music"
cached_power_mode = "balanced"
cached_crt_mode = "off"
is_caffeine_active = False
bandwidth_history = []

def get_audio_mode():
    global last_modes_time, cached_audio_mode
    now = time.time()
    if now - last_modes_time < 8.0:
        return cached_audio_mode
    try:
        card = subprocess.check_output("pactl list cards short | grep bluez_card | awk '{print $2}' | head -n 1", shell=True, text=True, stderr=subprocess.DEVNULL).strip()
        if card:
            out = subprocess.check_output(f"pactl list cards | awk -v card='{card}' '$0 ~ \"Name: \" card {{flag=1}} flag && /Active Profile:/ {{print $3; exit}}'", shell=True, text=True, stderr=subprocess.DEVNULL).strip()
            cached_audio_mode = "call" if "headset" in out else "music"
            return cached_audio_mode
    except Exception:
        pass
    return cached_audio_mode

def get_power_mode():
    global last_modes_time, cached_power_mode
    now = time.time()
    if now - last_modes_time < 8.0:
        return cached_power_mode
    try:
        cached_power_mode = subprocess.check_output(["powerprofilesctl", "get"], text=True, stderr=subprocess.DEVNULL).strip()
        return cached_power_mode
    except Exception:
        return cached_power_mode

def get_crt_mode():
    global last_modes_time, cached_crt_mode
    now = time.time()
    if now - last_modes_time < 8.0:
        return cached_crt_mode
    last_modes_time = now
    try:
        out = subprocess.check_output(["hyprctl", "getoption", "decoration:screen_shader", "-j"], text=True, stderr=subprocess.DEVNULL)
        data = json.loads(out)
        shader_path = data.get("str", "")
        if "heavy" in shader_path: cached_crt_mode = "heavy"
        elif "scanline" in shader_path: cached_crt_mode = "scanlines"
        elif "warmth-3500" in shader_path: cached_crt_mode = "warm-3500"
        elif "warmth-2400" in shader_path: cached_crt_mode = "warm-2400"
        else: cached_crt_mode = "off"
        return cached_crt_mode
    except Exception:
        return cached_crt_mode

def get_touchpad_info():
    try:
        def opt_int(name):
            out = subprocess.check_output(["hyprctl", "getoption", name, "-j"], text=True, stderr=subprocess.DEVNULL)
            return int(json.loads(out).get("int", 0))
        return {
            "tap_to_click": opt_int("input:touchpad:tap-to-click") == 1,
            "tap_and_drag": opt_int("input:touchpad:tap-and-drag") == 1,
            "drag_lock": opt_int("input:touchpad:drag_lock") == 1,
            "natural_scroll": opt_int("input:touchpad:natural_scroll") == 1,
        }
    except Exception:
        return {"tap_to_click": True, "tap_and_drag": True, "drag_lock": False, "natural_scroll": True}

def get_cursor_timeout():
    try:
        cache_file = os.path.expanduser("~/.cache/cinema_cursor_mode.json")
        if os.path.exists(cache_file):
            with open(cache_file, "r") as f:
                data = json.load(f)
                mode = data.get("mode")
                if mode == "auto": return "auto"
                if mode == "always_3": return "3"
                if mode == "never": return "0"
        return "auto"
    except Exception:
        return "auto"

def get_gpu_usage():
    try:
        files = glob.glob('/sys/class/drm/card*/device/gpu_busy_percent')
        if files:
            with open(files[0], 'r') as f:
                return int(f.read().strip())
    except Exception:
        pass
    return 6

def get_thermal_info():
    try:
        temps = []
        for f in glob.glob('/sys/class/hwmon/hwmon*/temp*_input'):
            try:
                with open(f, 'r') as fh:
                    v = int(fh.read().strip())
                    if 20000 < v < 110000:
                        temps.append(v / 1000.0)
            except Exception:
                pass
        if temps:
            return round(max(temps))
    except Exception:
        pass
    return 48

prev_net_rx = 0
prev_net_tx = 0
prev_net_time = 0

def get_net_traffic():
    global prev_net_rx, prev_net_tx, prev_net_time, bandwidth_history
    try:
        now = time.time()
        rx_total = 0
        tx_total = 0
        with open('/proc/net/dev', 'r') as f:
            for line in f.readlines()[2:]:
                parts = line.strip().split()
                if len(parts) >= 10:
                    iface = parts[0].strip(':')
                    if iface != 'lo':
                        rx_total += int(parts[1])
                        tx_total += int(parts[9])
        dt = now - prev_net_time if prev_net_time > 0 else 1.0
        rx_speed = (rx_total - prev_net_rx) / dt if prev_net_time > 0 else 0
        tx_speed = (tx_total - prev_net_tx) / dt if prev_net_time > 0 else 0
        prev_net_rx = rx_total
        prev_net_tx = tx_total
        prev_net_time = now

        rx_kb = round(max(0, rx_speed) / 1024, 1)
        tx_kb = round(max(0, tx_speed) / 1024, 1)

        bandwidth_history.append({"rx": rx_kb, "tx": tx_kb})
        if len(bandwidth_history) > 30:
            bandwidth_history = bandwidth_history[-30:]

        def fmt(b):
            if b >= 1024*1024:
                return f"{b/(1024*1024):.1f} MB/s"
            return f"{b/1024:.0f} KB/s"

        return {
            "rx": fmt(max(0, rx_speed)),
            "tx": fmt(max(0, tx_speed)),
            "rx_kb": rx_kb,
            "tx_kb": tx_kb
        }
    except Exception:
        return {"rx": "0 KB/s", "tx": "0 KB/s", "rx_kb": 0, "tx_kb": 0}

last_procs_time = 0
cached_procs = []

def get_top_procs():
    global last_procs_time, cached_procs
    now = time.time()
    if now - last_procs_time < 2.5 and cached_procs:
        return cached_procs
    last_procs_time = now
    try:
        out = subprocess.check_output(['ps', '-eo', 'pid,comm,%cpu,%mem', '--sort=-%cpu'], text=True, stderr=subprocess.DEVNULL)
        lines = out.strip().splitlines()[1:]
        procs = []
        for l in lines:
            parts = l.strip().split()
            if len(parts) >= 4:
                pid = parts[0]
                cpu_str = parts[-2]
                mem_str = parts[-1]
                name = " ".join(parts[1:-2])
                if name in ('ps', 'grep', 'bash', 'sleep', 'cat'):
                    continue
                clean_name = name
                nl = name.lower()
                if 'vivaldi' in nl: clean_name = 'vivaldi'
                elif 'webkit' in nl: clean_name = 'webkit'
                elif 'spotify' in nl: clean_name = 'spotify'
                elif 'python' in nl: clean_name = 'python'
                elif 'antigravity' in nl: clean_name = 'antigravity'
                elif 'node' in nl: clean_name = 'node'
                elif 'next' in nl: clean_name = 'next-server'
                elif 'hyprland' in nl: clean_name = 'hyprland'
                try:
                    c = float(cpu_str)
                    m = float(mem_str)
                    procs.append({
                        'pid': pid,
                        'name': clean_name[:12],
                        'cpu': c,
                        'mem': m
                    })
                except Exception:
                    continue
                if len(procs) >= 8:
                    break
        if procs:
            cached_procs = procs
        return cached_procs
    except Exception:
        return cached_procs

cached_net_info = {"ssid": "ONLINE", "ip": "127.0.0.1", "ping": "9 ms", "dnd": False}
last_ping_time = 0

def get_net_info():
    global cached_net_info, last_ping_time
    now = time.time()
    if now - last_ping_time > 4:
        last_ping_time = now
        try:
            ssid = subprocess.check_output("nmcli -t -f active,ssid dev wifi | grep '^yes:' | cut -d: -f2 | head -n 1", shell=True, text=True, stderr=subprocess.DEVNULL).strip()
            cached_net_info["ssid"] = ssid if ssid else "DISCONNECTED"
        except Exception:
            pass

        try:
            wifi_stat = subprocess.check_output("nmcli radio wifi", shell=True, text=True, stderr=subprocess.DEVNULL).strip()
            cached_net_info["wifi_enabled"] = (wifi_stat == "enabled")
        except Exception:
            cached_net_info["wifi_enabled"] = True

        try:
            bt_stat = subprocess.check_output("rfkill list bluetooth | grep 'Soft blocked: yes'", shell=True, text=True, stderr=subprocess.DEVNULL)
            cached_net_info["bt_enabled"] = (len(bt_stat.strip()) == 0)
        except Exception:
            cached_net_info["bt_enabled"] = True

        try:
            air_stat = subprocess.check_output("rfkill list | grep -q 'Soft blocked: yes' && echo blocked || echo unblocked", shell=True, text=True, stderr=subprocess.DEVNULL).strip()
            cached_net_info["airplane"] = (air_stat == "blocked")
        except Exception:
            cached_net_info["airplane"] = False

        try:
            ip_out = subprocess.check_output(['hostname', '-I'], text=True, stderr=subprocess.DEVNULL).strip().split()
            if ip_out:
                cached_net_info["ip"] = ip_out[0]
        except Exception:
            pass

        try:
            import re
            p = subprocess.check_output(['ping', '-c', '1', '-W', '1', '1.1.1.1'], text=True, stderr=subprocess.DEVNULL)
            m = re.search(r'time=([0-9.]+)\s*ms', p)
            if m:
                cached_net_info["ping"] = f"{round(float(m.group(1)))} ms"
        except Exception:
            cached_net_info["ping"] = "-- ms"

        try:
            dnd = subprocess.check_output(['dunstctl', 'is-paused'], text=True, stderr=subprocess.DEVNULL).strip()
            cached_net_info["dnd"] = (dnd == 'true')
        except Exception:
            pass

    return cached_net_info

last_log_time = 0
cached_log = []

def get_system_log():
    global last_log_time, cached_log
    now = time.time()
    if now - last_log_time < 3.0 and cached_log:
        return cached_log
    last_log_time = now
    try:
        out = subprocess.check_output(['journalctl', '-n', '16', '--no-pager', '-o', 'short-monotonic'], text=True, stderr=subprocess.DEVNULL)
        lines = [line.strip() for line in out.strip().splitlines() if line.strip()]
        if lines:
            cached_log = lines[-16:]
        return cached_log
    except Exception:
        return cached_log

last_rf_time = 0
cached_rf = {'ssid': 'ONLINE', 'bssid': '9C:8C:D8:47:D6:F1', 'signal': 95, 'freq': '5280 MHz', 'chan': '56', 'rate': '1170 Mbit/s'}

def get_rf_details():
    global last_rf_time, cached_rf
    now = time.time()
    if now - last_rf_time < 4.0:
        return cached_rf
    last_rf_time = now
    try:
        out = subprocess.check_output("nmcli -t -f active,ssid,bssid,signal,freq,chan,rate dev wifi | grep '^yes:' | head -n 1", shell=True, text=True, stderr=subprocess.DEVNULL).strip()
        if out:
            cleaned = out.replace(r'\:', ':')
            m = re.match(r'^yes:([^:]+):([0-9A-Fa-f:]+):([0-9]+):([^:]+):([0-9]+):(.+)$', cleaned)
            if m:
                cached_rf = {
                    'ssid': m.group(1),
                    'bssid': m.group(2),
                    'signal': int(m.group(3)),
                    'freq': m.group(4).strip(),
                    'chan': m.group(5),
                    'rate': m.group(6).strip()
                }
    except Exception:
        pass
    return cached_rf

last_bat_time = 0
cached_bat_sub = {'cap': 100, 'status': 'Full', 'health': 93, 'cycles': '113', 'power_w': '0.0W', 'volts': '13.1V'}

def get_battery_subsystem():
    global last_bat_time, cached_bat_sub
    now = time.time()
    if now - last_bat_time < 3.0:
        return cached_bat_sub
    last_bat_time = now
    try:
        uevent = '/sys/class/power_supply/BAT0/uevent'
        if os.path.exists(uevent):
            with open(uevent, 'r') as f:
                d = dict(line.strip().split('=', 1) for line in f if '=' in line)
            cap = int(d.get('POWER_SUPPLY_CAPACITY', 100))
            st = d.get('POWER_SUPPLY_STATUS', 'Full')
            cyc = d.get('POWER_SUPPLY_CYCLE_COUNT', '113')
            v_now = int(d.get('POWER_SUPPLY_VOLTAGE_NOW', 13000000)) / 1000000.0
            p_now = int(d.get('POWER_SUPPLY_POWER_NOW', 0)) / 1000000.0
            e_full = int(d.get('POWER_SUPPLY_ENERGY_FULL', 1))
            e_des = int(d.get('POWER_SUPPLY_ENERGY_FULL_DESIGN', 1))
            health = round((e_full / e_des) * 100) if e_des > 0 else 95
            cached_bat_sub = {
                'cap': cap,
                'status': st,
                'health': health,
                'cycles': cyc,
                'power_w': f'{p_now:.1f}W',
                'volts': f'{v_now:.1f}V'
            }
    except Exception:
        pass
    return cached_bat_sub

last_soc_time = 0
cached_sockets = []

def get_active_sockets():
    global last_soc_time, cached_sockets
    now = time.time()
    if now - last_soc_time < 3.0 and cached_sockets:
        return cached_sockets
    last_soc_time = now
    try:
        out = subprocess.check_output(['ss', '-tuln'], text=True, stderr=subprocess.DEVNULL)
        sockets = []
        seen = set()
        for l in out.strip().splitlines()[1:]:
            p = l.strip().split()
            if len(p) >= 5:
                proto = p[0].upper()
                st = p[1]
                local = p[4]
                port = local.split(':')[-1]
                if port in seen:
                    continue
                seen.add(port)
                svc = 'SERVICE'
                if port == '5353': svc = 'mDNS / Avahi'
                elif port == '443': svc = 'HTTPS / TLS'
                elif port == '80': svc = 'HTTP / Web'
                elif port == '22': svc = 'SSH Terminal'
                elif port == '546': svc = 'DHCPv6 Client'
                elif port in ('3702', '1900'): svc = 'UPnP Discovery'
                elif port in ('3000', '5173', '8080'): svc = 'Dev Server'
                elif port == '46874': svc = 'Dynamic RPC'
                else: svc = f'Port {port}'
                sockets.append({'proto': proto, 'port': port, 'service': svc, 'state': st})
                if len(sockets) >= 5:
                    break
        if sockets:
            cached_sockets = sockets
    except Exception:
        pass
    return cached_sockets



class CommandCenterWindow(Gtk.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title="Tokyo Master Deck")
        self.set_default_size(1920, 1080)
        
        # Configure WebKit Settings for Media & Universal Access
        settings = WebKit.Settings()
        settings.set_enable_media_stream(True)
        settings.set_enable_webrtc(True)
        settings.set_media_playback_requires_user_gesture(False)
        settings.set_media_playback_allows_inline(True)
        settings.set_enable_mediasource(True)
        settings.set_enable_webaudio(True)
        settings.set_enable_developer_extras(True)
        settings.set_allow_file_access_from_file_urls(True)
        settings.set_allow_universal_access_from_file_urls(True)
        settings.set_hardware_acceleration_policy(WebKit.HardwareAccelerationPolicy.ALWAYS)

        # Content Manager & Script Message Handler
        content_mgr = WebKit.UserContentManager()
        content_mgr.register_script_message_handler("host")
        content_mgr.connect("script-message-received::host", self.on_script_message)

        # WebView Setup
        self.webview = WebKit.WebView(user_content_manager=content_mgr, settings=settings)
        self.webview.connect("permission-request", self.on_permission_request)
        self.webview.connect("load-changed", self.on_load_changed)

        self.set_child(self.webview)
        self.webview.load_uri(INDEX_URI)

        log("Command Center window initialized")

        # Track visibility to achieve 0.0% CPU when dismissed
        self.is_deck_visible = self._check_initial_visibility()

        # Start stats heartbeat in background thread (never blocks GTK rendering loop)
        self.stats_thread_running = True
        self.stats_thread = threading.Thread(target=self._stats_worker, daemon=True)
        self.stats_thread.start()

        # Hyprland Socket2 listener for instantaneous zero-overhead suspend/resume
        self.hypr_thread = threading.Thread(target=self._hypr_event_listener, daemon=True)
        self.hypr_thread.start()

    def _check_initial_visibility(self):
        try:
            out = subprocess.check_output(["hyprctl", "monitors", "-j"], text=True, stderr=subprocess.DEVNULL)
            data = json.loads(out)
            for m in data:
                if m.get("specialWorkspace", {}).get("name") == "special:center":
                    return True
        except Exception:
            pass
        return False

    def _notify_deck_visibility(self, visible):
        try:
            val_bool = "true" if visible else "false"
            script = f"if (window.onDeckVisibility) {{ window.onDeckVisibility({val_bool}); }}"
            self.webview.evaluate_javascript(script, -1, None, None, None, None, None)
        except Exception:
            pass
        return False

    def _hypr_event_listener(self):
        sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
        rundir = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
        sock_path = f"{rundir}/hypr/{sig}/.socket2.sock"
        while self.stats_thread_running:
            try:
                s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                s.connect(sock_path)
                buf = ""
                while self.stats_thread_running:
                    data = s.recv(4096)
                    if not data:
                        break
                    buf += data.decode("utf-8", errors="ignore")
                    lines = buf.split("\n")
                    buf = lines[-1]
                    for line in lines[:-1]:
                        if not line:
                            continue
                        if "activespecial>>" in line or "activespecialv2>>" in line:
                            is_vis = "special:center" in line
                            if is_vis != self.is_deck_visible:
                                self.is_deck_visible = is_vis
                                GLib.idle_add(self._notify_deck_visibility, is_vis)
            except Exception:
                time.sleep(2.0)

    def on_load_changed(self, webview, event):
        if event == WebKit.LoadEvent.FINISHED:
            self._notify_deck_visibility(self.is_deck_visible)

    def on_permission_request(self, webview, request):
        log(f"Permission requested: {request}")
        try:
            request.allow()
            return True
        except Exception as e:
            log(f"Permission error: {e}")
        return False

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
            log(f"Received action: {action} data: {msg}")

            if action == "set_volume":
                vol = int(msg.get("value", 50))
                subprocess.run(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", f"{vol/100:.2f}"], stderr=subprocess.DEVNULL)
                subprocess.run(["pactl", "set-sink-volume", "@DEFAULT_SINK@", f"{vol}%"], stderr=subprocess.DEVNULL)

            elif action == "set_brightness":
                br = int(msg.get("value", 80))
                subprocess.run(["brightnessctl", "set", f"{br}%"], stderr=subprocess.DEVNULL)

            elif action == "toggle_mic":
                script = os.path.expanduser("~/.config/hypr/scripts/toggle-bt-mic.sh")
                subprocess.run(["bash", script], stderr=subprocess.DEVNULL)

            elif action == "set_audio_profile":
                mode = msg.get("mode", "music")
                global cached_audio_mode
                cached_audio_mode = mode
                last_modes_time = time.time()
                try:
                    card = subprocess.check_output("pactl list cards short | grep bluez_card | awk '{print $2}' | head -n 1", shell=True, text=True, stderr=subprocess.DEVNULL).strip()
                    if card:
                        prof = "headset-head-unit" if mode == "call" else "a2dp-sink"
                        subprocess.run(["pactl", "set-card-profile", card, prof], stderr=subprocess.DEVNULL)
                except Exception:
                    pass

            elif action == "set_shader":
                mode = msg.get("mode", "off")
                global cached_crt_mode
                cached_crt_mode = mode
                last_modes_time = time.time()
                if mode == "heavy":
                    shader = os.path.expanduser("~/.config/hypr/shaders/crt-heavy.glsl")
                    subprocess.run(["hyprctl", "keyword", "decoration:screen_shader", shader], stderr=subprocess.DEVNULL)
                elif mode == "scanlines":
                    shader = os.path.expanduser("~/.config/hypr/shaders/crt-scanlines.glsl")
                    subprocess.run(["hyprctl", "keyword", "decoration:screen_shader", shader], stderr=subprocess.DEVNULL)
                elif mode == "warm-3500":
                    shader = os.path.expanduser("~/.config/hypr/shaders/warmth-3500k.glsl")
                    subprocess.run(["hyprctl", "keyword", "decoration:screen_shader", shader], stderr=subprocess.DEVNULL)
                elif mode == "warm-2400":
                    shader = os.path.expanduser("~/.config/hypr/shaders/warmth-2400k.glsl")
                    subprocess.run(["hyprctl", "keyword", "decoration:screen_shader", shader], stderr=subprocess.DEVNULL)
                else:
                    subprocess.run(["hyprctl", "keyword", "decoration:screen_shader", ""], stderr=subprocess.DEVNULL)

            elif action == "set_power":
                profile = msg.get("profile", "balanced")
                global cached_power_mode
                cached_power_mode = profile
                last_modes_time = time.time()
                subprocess.run(["powerprofilesctl", "set", profile], stderr=subprocess.DEVNULL)

            elif action == "set_touchpad":
                param = msg.get("param")
                val = 1 if msg.get("value") else 0
                if param == "tap_to_click":
                    subprocess.run(["hyprctl", "keyword", "input:touchpad:tap-to-click", str(val)], stderr=subprocess.DEVNULL)
                elif param == "tap_and_drag":
                    subprocess.run(["hyprctl", "keyword", "input:touchpad:tap-and-drag", str(val)], stderr=subprocess.DEVNULL)
                elif param == "drag_lock":
                    subprocess.run(["hyprctl", "keyword", "input:touchpad:drag_lock", str(val)], stderr=subprocess.DEVNULL)
                elif param == "natural_scroll":
                    subprocess.run(["hyprctl", "keyword", "input:touchpad:natural_scroll", str(val)], stderr=subprocess.DEVNULL)

            elif action == "set_cursor_timeout":
                val = str(msg.get("value", "auto"))
                cache_file = os.path.expanduser("~/.cache/cinema_cursor_mode.json")
                mode_str = "auto"
                if val == "3": mode_str = "always_3"
                elif val == "0": mode_str = "never"
                try:
                    with open(cache_file, "w") as f:
                        json.dump({"mode": mode_str}, f)
                except Exception:
                    pass
                if mode_str == "always_3":
                    subprocess.run(["hyprctl", "keyword", "cursor:inactive_timeout", "3"], stderr=subprocess.DEVNULL)
                elif mode_str == "never":
                    subprocess.run(["hyprctl", "keyword", "cursor:inactive_timeout", "0"], stderr=subprocess.DEVNULL)
                else:
                    try:
                        out = subprocess.check_output(["hyprctl", "activewindow", "-j"], text=True, stderr=subprocess.DEVNULL)
                        d = json.loads(out)
                        to = "3" if d.get("fullscreen") else "0"
                        subprocess.run(["hyprctl", "keyword", "cursor:inactive_timeout", to], stderr=subprocess.DEVNULL)
                    except Exception:
                        subprocess.run(["hyprctl", "keyword", "cursor:inactive_timeout", "0"], stderr=subprocess.DEVNULL)

            elif action == "set_caffeine":
                enabled = bool(msg.get("enabled", False))
                target = "on" if enabled else "off"
                subprocess.run(["bash", os.path.expanduser("~/.config/hypr/scripts/toggle-insomnia.sh"), target], stderr=subprocess.DEVNULL)

            elif action == "set_compositor_fx":
                fx = msg.get("fx")
                val = msg.get("value")
                if fx == "animations":
                    subprocess.run(["hyprctl", "keyword", "animations:enabled", str(val)], stderr=subprocess.DEVNULL)
                elif fx == "blur":
                    subprocess.run(["hyprctl", "keyword", "decoration:blur:enabled", str(val)], stderr=subprocess.DEVNULL)
                elif fx == "gaps":
                    subprocess.run(["hyprctl", "keyword", "general:gaps_in", str(val)], stderr=subprocess.DEVNULL)
                    subprocess.run(["hyprctl", "keyword", "general:gaps_out", str(val)], stderr=subprocess.DEVNULL)
                elif fx == "rounding":
                    subprocess.run(["hyprctl", "keyword", "decoration:rounding", str(val)], stderr=subprocess.DEVNULL)

            elif action == "media":
                cmd = msg.get("cmd")
                if cmd in ("play-pause", "next", "previous"):
                    subprocess.run(["playerctl", cmd], stderr=subprocess.DEVNULL)

            elif action == "set_theme":
                theme = msg.get("theme", "trv30")
                self.apply_system_theme(theme)

            elif action == "kill_process":
                pid = msg.get("pid")
                proc_name = msg.get("name", "Process")
                if pid:
                    subprocess.run(["kill", "-15", str(pid)], stderr=subprocess.DEVNULL)
                    subprocess.run(["dunstify", "-a", "osd", "-r", "9992", "⚠️ TERMINATED", f"{proc_name} (PID {pid}) terminated"], stderr=subprocess.DEVNULL)

            elif action == "kill_runaways":
                subprocess.run("killall -9 vivaldi-bin WebKitWebProcess 2>/dev/null || true", shell=True)
                subprocess.run(["dunstify", "-a", "osd", "-r", "9992", "⚡ RUNAWAYS CLEARED", "High-CPU background browser workers purged"], stderr=subprocess.DEVNULL)

            elif action == "toggle_wifi":
                subprocess.run("nmcli radio wifi | grep -q enabled && nmcli radio wifi off || nmcli radio wifi on", shell=True)

            elif action == "toggle_bt":
                subprocess.run("rfkill toggle bluetooth", shell=True)

            elif action == "toggle_airplane":
                subprocess.run("rfkill list | grep -q 'Soft blocked: yes' && rfkill unblock all || rfkill block all", shell=True)

            elif action == "toggle_dnd":
                subprocess.run(["dunstctl", "set-paused", "toggle"], stderr=subprocess.DEVNULL)

            elif action == "sys_action":
                cmd = msg.get("cmd")
                if cmd == "screenshot":
                    subprocess.run(["hyprctl", "dispatch", "togglespecialworkspace", "center"], stderr=subprocess.DEVNULL)
                    subprocess.run(["sleep", "0.2"])
                    subprocess.run("grimblast copy area || grim ~/screenshot_$(date +%s).png", shell=True)
                elif cmd == "lock":
                    subprocess.run(["hyprlock"])
                elif cmd == "suspend":
                    subprocess.run(["systemctl", "suspend"])
                elif cmd == "drop_caches":
                    subprocess.run(["sync"])
                    subprocess.run(["dunstify", "-a", "osd", "-r", "9994", "🧹 BUFFERS FLUSHED", "Filesystem caches synced to disk"], stderr=subprocess.DEVNULL)
                elif cmd == "reload_hypr":
                    subprocess.run(["hyprctl", "reload"])
                    subprocess.run(["dunstify", "-a", "osd", "-r", "9994", "⚡ HYPRLAND RELOADED", "Compositor rules & binds reloaded"], stderr=subprocess.DEVNULL)
                elif cmd == "restart_waybar":
                    subprocess.run("pkill -9 waybar; waybar -c ~/.config/waybar/config-top &", shell=True)
                    subprocess.run(["dunstify", "-a", "osd", "-r", "9994", "♻️ WAYBAR RESTARTED", "Top status HUD re-initialized"], stderr=subprocess.DEVNULL)
                elif cmd == "reboot":
                    subprocess.run(["systemctl", "reboot"])
                elif cmd == "poweroff":
                    subprocess.run(["systemctl", "poweroff"])

            elif action == "ping_test":
                subprocess.run("ping -c 3 1.1.1.1 > /dev/null 2>&1 &", shell=True)
                subprocess.run(["dunstify", "-a", "osd", "-r", "9996", "📡 PING TEST SENT", "ICMP 3-packet probe dispatched to 1.1.1.1"], stderr=subprocess.DEVNULL)

            elif action == "flush_dns":
                subprocess.run(["resolvectl", "flush-caches"], stderr=subprocess.DEVNULL)
                subprocess.run(["dunstify", "-a", "osd", "-r", "9996", "🌐 DNS FLUSHED", "Local DNS resolver cache cleared"], stderr=subprocess.DEVNULL)

            elif action == "rescan_wifi":
                subprocess.run(["nmcli", "dev", "wifi", "rescan"], stderr=subprocess.DEVNULL)
                subprocess.run(["dunstify", "-a", "osd", "-r", "9996", "📡 WI-FI RESCANNED", "802.11 Access Points Refreshed"], stderr=subprocess.DEVNULL)

            elif action == "close":
                subprocess.run(["hyprctl", "dispatch", "togglespecialworkspace", "center"], stderr=subprocess.DEVNULL)
                subprocess.run(["pkill", "-RTMIN+1", "waybar"], stderr=subprocess.DEVNULL)

        except Exception as e:
            log(f"on_script_message error: {e}")

    def apply_system_theme(self, theme):
        themes = {
            "trv30": {"border_active": "rgba(b8a998ff)", "border_inactive": "rgba(000000ff)", "label": "Tokyo 80s TRV30"},
            "cyber": {"border_active": "rgba(00e5ffff)", "border_inactive": "rgba(200040ff)", "label": "Akihabara Cyber"},
            "pvm":   {"border_active": "rgba(00ff41ff)", "border_inactive": "rgba(102010ff)", "label": "Sony PVM CRT"},
            "nerv":  {"border_active": "rgba(ff5500ff)", "border_inactive": "rgba(301000ff)", "label": "NERV Terminal"}
        }
        cfg = themes.get(theme, themes["trv30"])
        subprocess.run(["hyprctl", "keyword", "general:col.active_border", cfg["border_active"]], stderr=subprocess.DEVNULL)
        subprocess.run(["hyprctl", "keyword", "general:col.inactive_border", cfg["border_inactive"]], stderr=subprocess.DEVNULL)
        subprocess.run(["dunstify", "-a", "osd", "-r", "9995", f"📼 TAPE LOADED: {cfg['label']}", "Active System Theme Updated"], stderr=subprocess.DEVNULL)

    def _eval_js_cb(self, script):
        try:
            self.webview.evaluate_javascript(script, -1, None, None, None, None, None)
        except Exception as e:
            log(f"eval error: {e}")
        return False

    def _stats_worker(self):
        while self.stats_thread_running:
            eval_file = "/tmp/command-center-eval.js"
            if os.path.exists(eval_file):
                try:
                    with open(eval_file, "r") as f:
                        cmd_script = f.read()
                    os.remove(eval_file)
                    GLib.idle_add(self._eval_js_cb, cmd_script)
                except Exception as e:
                    log(f"eval error: {e}")

            if not self.is_deck_visible:
                time.sleep(0.4)
                continue
            try:
                cpu_info = get_cpu_info()
                disk_info = get_disk_info()
                stats = {
                    "session_time": get_session_time(),
                    "cpu_usage": cpu_info["total"],
                    "cpu_cores": cpu_info["cores"],
                    "mem": get_memory_info(),
                    "zram": get_zram_info(),
                    "disk": disk_info,
                    "disk_remain": f"{disk_info['free_gb']} GB",
                    "gpu_usage": get_gpu_usage(),
                    "thermal": get_thermal_info(),
                    "net_traffic": get_net_traffic(),
                    "battery": get_battery_info(),
                    "volume": get_volume(),
                    "brightness": get_brightness(),
                    "media": get_media_info(),
                    "audio_mode": get_audio_mode(),
                    "power_mode": get_power_mode(),
                    "crt_mode": get_crt_mode(),
                    "touchpad": get_touchpad_info(),
                    "cursor_timeout": get_cursor_timeout(),
                    "caffeine": os.path.exists(os.path.expanduser("~/.cache/insomnia_mode")),
                    "bandwidth_history": bandwidth_history,
                    "top_procs": get_top_procs(),
                    "net_info": get_net_info(),
                    "rf_info": get_rf_details(),
                    "sockets": get_active_sockets(),
                    "battery_subsystem": get_battery_subsystem(),
                    "system_log": get_system_log()
                }
                json_str = json.dumps(stats)
                GLib.idle_add(self._send_stats_to_webview, json_str)
            except Exception as e:
                log(f"stats worker error: {e}")
            time.sleep(1.5)

    def _send_stats_to_webview(self, json_str):
        eval_file = "/tmp/command-center-eval.js"
        if os.path.exists(eval_file):
            try:
                with open(eval_file, "r") as f:
                    cmd_script = f.read()
                os.remove(eval_file)
                self.webview.evaluate_javascript(cmd_script, -1, None, None, None, None, None)
            except Exception as e:
                log(f"eval error: {e}")

        try:
            script = f"if (window.onHostStats) {{ window.onHostStats({json_str}); }}"
            self.webview.evaluate_javascript(script, -1, None, None, None, None, None)
        except Exception:
            pass
        return False


class CommandCenterApp(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="com.tokyo.commandcenter", flags=Gio.ApplicationFlags.FLAGS_NONE)

    def do_activate(self):
        win = self.props.active_window
        if not win:
            win = CommandCenterWindow(self)
        win.present()

if __name__ == "__main__":
    app = CommandCenterApp()
    app.run(sys.argv)
