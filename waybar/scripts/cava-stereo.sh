#!/usr/bin/env python3
import ctypes
import os
import signal
import subprocess
import sys
import time

def set_pdeathsig():
    try:
        libc = ctypes.CDLL("libc.so.6")
        libc.prctl(1, signal.SIGTERM)
    except Exception:
        pass

set_pdeathsig()

side = sys.argv[1] if len(sys.argv) > 1 else "left"
conf_path = f"/tmp/cava_config_{side}_{os.getuid()}"

conf_content = """[general]
framerate = 30
bars = 6
[output]
channels = stereo
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 7
bar_delimiter = 59
"""

try:
    with open(conf_path, "w") as f:
        f.write(conf_content)
except Exception:
    pass

bars = ["<span alpha='1'>█</span>", "▂", "▃", "▄", "▅", "▆", "▇", "█"]

def format_bars(p0, p1, p2):
    if side == "left":
        return f"L [{bars[p2]}{bars[p1]}{bars[p0]}]"
    else:
        return f"[{bars[p0]}{bars[p1]}{bars[p2]}] R"

last_out = None

def emit(text):
    global last_out
    if text != last_out:
        try:
            sys.stdout.write(text + "\n")
            sys.stdout.flush()
            last_out = text
        except (BrokenPipeError, IOError):
            sys.exit(0)

# Immediately display resting state so Waybar shows both sides instantly on boot
emit(format_bars(0, 0, 0))

while True:
    proc = None
    try:
        proc = subprocess.Popen(
            ["cava", "-p", conf_path],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            preexec_fn=set_pdeathsig,
        )
        for line in proc.stdout:
            parts = [int(x) if x.isdigit() else 0 for x in line.strip().split(";") if x != ""]
            if len(parts) >= 6:
                if side == "left":
                    b0 = min(7, max(0, parts[0]))
                    b1 = min(7, max(0, parts[1]))
                    b2 = min(7, max(0, parts[2]))
                    emit(format_bars(b0, b1, b2))
                else:
                    b0 = min(7, max(0, parts[3]))
                    b1 = min(7, max(0, parts[4]))
                    b2 = min(7, max(0, parts[5]))
                    emit(format_bars(b0, b1, b2))
        proc.wait()
    except (BrokenPipeError, IOError):
        sys.exit(0)
    except Exception:
        pass
    finally:
        if proc and proc.poll() is None:
            try:
                proc.terminate()
            except Exception:
                pass
    emit(format_bars(0, 0, 0))
    time.sleep(1)
