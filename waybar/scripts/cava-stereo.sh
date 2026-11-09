#!/usr/bin/env python3
import ctypes
import fcntl
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
shm_l = "/dev/shm/cava_out_left"
shm_r = "/dev/shm/cava_out_right"
lock_file_path = f"/dev/shm/cava_master_{os.getuid()}.lock"
conf_path = f"/tmp/cava_config_shared_{os.getuid()}"

# 18 FPS: buttery smooth for 3-bar meters while cutting FFT and GTK redraw churn by 40%
conf_content = """[general]
framerate = 18
bars = 6
sleep_timer = 2
autosens = 1
[smoothing]
noise_reduction = 80
[input]
method = pipewire
source = auto
[output]
channels = stereo
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 8
bar_delimiter = 59
"""

try:
    with open(conf_path, "w") as f:
        f.write(conf_content)
except Exception:
    pass

# 9 discrete levels (0 to 8).
# Level 0 is a faint amber floor tick (lower 1/8th block U+2581 with 30% alpha)
# This perfectly matches the width of U+2581..U+2588, eliminating jitter and black bar artifacts!
bars = [
    "<span alpha='30%'> </span>",
    " ",
    "▂",
    "▃",
    "▄",
    "▅",
    "▆",
    "▇",
    "█"
]

def format_bars_l(p0, p1, p2):
    return f"L [{bars[p2]}{bars[p1]}{bars[p0]}]"

def format_bars_r(p0, p1, p2):
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

# Immediately display resting state
emit(format_bars_l(0, 0, 0) if side == "left" else format_bars_r(0, 0, 0))

def run_follower():
    target_shm = shm_l if side == "left" else shm_r
    idle_text = format_bars_l(0, 0, 0) if side == "left" else format_bars_r(0, 0, 0)
    last_mtime = 0.0
    last_check_master = time.time()
    
    while True:
        try:
            now = time.time()
            if os.path.exists(target_shm):
                mtime = os.path.getmtime(target_shm)
                time_since_update = now - mtime
                
                if time_since_update < 1.5:
                    # Active audio stream
                    if mtime != last_mtime:
                        last_mtime = mtime
                        with open(target_shm, "r") as sf:
                            content = sf.read().strip()
                            if content:
                                emit(content)
                    time.sleep(0.05)  # ~20 FPS during playback
                else:
                    # Silence / idle state: emit resting state and sleep calmly
                    emit(idle_text)
                    if now - last_check_master > 5.0:
                        last_check_master = now
                        with open(lock_file_path, "a") as lf:
                            try:
                                fcntl.flock(lf, fcntl.LOCK_EX | fcntl.LOCK_NB)
                                return  # Master died, take over
                            except (BlockingIOError, IOError):
                                pass
                    time.sleep(0.3)  # Low-power sleep during silence
            else:
                emit(idle_text)
                time.sleep(0.5)
        except (BrokenPipeError, IOError):
            sys.exit(0)
        except Exception:
            time.sleep(0.2)

def run_master(lock_fd):
    idle_l = format_bars_l(0, 0, 0)
    idle_r = format_bars_r(0, 0, 0)
    last_shm_l = None
    last_shm_r = None
    
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
                    b0_l = min(8, max(0, parts[0]))
                    b1_l = min(8, max(0, parts[1]))
                    b2_l = min(8, max(0, parts[2]))
                    out_l = format_bars_l(b0_l, b1_l, b2_l)

                    b0_r = min(8, max(0, parts[3]))
                    b1_r = min(8, max(0, parts[4]))
                    b2_r = min(8, max(0, parts[5]))
                    out_r = format_bars_r(b0_r, b1_r, b2_r)

                    # Only update shared memory if visual bars have changed
                    if out_l != last_shm_l or out_r != last_shm_r:
                        try:
                            with open(shm_l + ".tmp", "w") as sf:
                                sf.write(out_l)
                            os.replace(shm_l + ".tmp", shm_l)
                            with open(shm_r + ".tmp", "w") as sf:
                                sf.write(out_r)
                            os.replace(shm_r + ".tmp", shm_r)
                            last_shm_l = out_l
                            last_shm_r = out_r
                        except Exception:
                            pass

                    emit(out_l if side == "left" else out_r)
            proc.wait()
        except (BrokenPipeError, IOError):
            sys.exit(0)
        except Exception:
            pass
        finally:
            if proc and proc.poll() is None:
                try: proc.terminate()
                except Exception: pass
        
        # When cava exits or sleeps: ensure resting state is saved once
        if last_shm_l != idle_l or last_shm_r != idle_r:
            try:
                with open(shm_l + ".tmp", "w") as sf:
                    sf.write(idle_l)
                os.replace(shm_l + ".tmp", shm_l)
                with open(shm_r + ".tmp", "w") as sf:
                    sf.write(idle_r)
                os.replace(shm_r + ".tmp", shm_r)
                last_shm_l = idle_l
                last_shm_r = idle_r
            except Exception:
                pass
        emit(idle_l if side == "left" else idle_r)
        time.sleep(1)

# Main entry
while True:
    try:
        lock_fd = open(lock_file_path, "a")
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        run_master(lock_fd)
    except (BlockingIOError, IOError):
        run_follower()
    except Exception:
        time.sleep(0.5)
