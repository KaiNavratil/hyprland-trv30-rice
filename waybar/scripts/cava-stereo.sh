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

conf_content = """[general]
framerate = 30
bars = 6
sleep_timer = 2
autosens = 1
[input]
method = pipewire
source = auto
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
    while True:
        try:
            # Check if master is alive by checking lock
            with open(lock_file_path, "a") as lf:
                try:
                    fcntl.flock(lf, fcntl.LOCK_EX | fcntl.LOCK_NB)
                    # If we got the lock, master died: take over
                    return
                except (BlockingIOError, IOError):
                    pass # Master is alive
            
            # Read from shared memory file
            if os.path.exists(target_shm):
                mtime = os.path.getmtime(target_shm)
                if time.time() - mtime < 2.0:
                    with open(target_shm, "r") as sf:
                        content = sf.read().strip()
                        if content:
                            emit(content)
                else:
                    emit(idle_text)
            else:
                emit(idle_text)
            time.sleep(0.033)
        except (BrokenPipeError, IOError):
            sys.exit(0)
        except Exception:
            time.sleep(0.05)

def run_master(lock_fd):
    idle_l = format_bars_l(0, 0, 0)
    idle_r = format_bars_r(0, 0, 0)
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
                    b0_l = min(7, max(0, parts[0]))
                    b1_l = min(7, max(0, parts[1]))
                    b2_l = min(7, max(0, parts[2]))
                    out_l = format_bars_l(b0_l, b1_l, b2_l)

                    b0_r = min(7, max(0, parts[3]))
                    b1_r = min(7, max(0, parts[4]))
                    b2_r = min(7, max(0, parts[5]))
                    out_r = format_bars_r(b0_r, b1_r, b2_r)

                    # Update shared memory for followers
                    try:
                        with open(shm_l + ".tmp", "w") as sf:
                            sf.write(out_l)
                        os.replace(shm_l + ".tmp", shm_l)
                        with open(shm_r + ".tmp", "w") as sf:
                            sf.write(out_r)
                        os.replace(shm_r + ".tmp", shm_r)
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
