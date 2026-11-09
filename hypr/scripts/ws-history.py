#!/usr/bin/env python3
import os
import socket
import sys
import subprocess
import time
import json
import select

HISTORY_FILE = "/tmp/hypr_ws_history.txt"
STATE_FILE = "/tmp/hypr_ws_state.txt"

def add_history(ws):
    try:
        with open(HISTORY_FILE, "r") as f:
            history = [line.strip() for line in f.readlines() if line.strip()]
    except:
        history = []
    
    history = [x for x in history if x != ws]
    history.append(ws)
    
    history = history[-15:]
    with open(HISTORY_FILE, "w") as f:
        f.write("\n".join(history) + "\n")

def go_prev(direction):
    try:
        with open(HISTORY_FILE, "r") as f:
            history = [line.strip() for line in f.readlines() if line.strip()]
    except:
        return

    now = time.time()
    try:
        with open(STATE_FILE, "r") as f:
            parts = f.read().split()
            last_time = float(parts[0])
            cursor = int(parts[1])
    except:
        last_time = 0
        cursor = -1

    if now - last_time < 2.5:
        if direction == "older": cursor -= 1
        else: cursor += 1
    else:
        if direction == "older": cursor = -3
        else: cursor = -2

    if cursor > -1: cursor = -1
    if abs(cursor) > len(history): cursor = -len(history)

    if len(history) > 0:
        target = history[cursor]
        with open(STATE_FILE, "w") as f:
            f.write(f"{now} {cursor}\n")
        subprocess.run(["hyprctl", "dispatch", "workspace", target])

def daemon():
    his = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    xdg = os.environ.get("XDG_RUNTIME_DIR", "/run/user/1000")
    if not his: return
    sock_path = f"{xdg}/hypr/{his}/.socket2.sock"

    try:
        out = subprocess.check_output(["hyprctl", "activeworkspace", "-j"], text=True)
        ws = str(json.loads(out).get("name", ""))
        if ws and not ws.startswith("special:"):
            add_history(ws)
    except: pass

    while True:
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.connect(sock_path)
            s.setblocking(False)
            expired_handled = True
            buffer = ""
            
            while True:
                ready, _, _ = select.select([s], [], [], 0.5)
                if ready:
                    try:
                        data = s.recv(4096)
                        if not data: break
                        buffer += data.decode('utf-8')
                        while "\n" in buffer:
                            line, buffer = buffer.split("\n", 1)
                            line = line.strip()
                            if line.startswith("workspace>>"):
                                ws = line.split(">>")[1]
                                if not ws.startswith("special:"):
                                    traversing = False
                                    try:
                                        with open(STATE_FILE, "r") as statef:
                                            parts = statef.read().split()
                                            if time.time() - float(parts[0]) < 2.5:
                                                traversing = True
                                    except: pass
                                    
                                    if not traversing:
                                        add_history(ws)
                                    else:
                                        expired_handled = False
                    except BlockingIOError: pass
                else:
                    if not expired_handled:
                        try:
                            with open(STATE_FILE, "r") as statef:
                                parts = statef.read().split()
                                last_time = float(parts[0])
                            if last_time > 0 and time.time() - last_time >= 2.5:
                                expired_handled = True
                                with open(STATE_FILE, "w") as statef:
                                    statef.write("0 -1\n")
                                out = subprocess.check_output(["hyprctl", "activeworkspace", "-j"], text=True)
                                ws = str(json.loads(out).get("name", ""))
                                if ws and not ws.startswith("special:"):
                                    add_history(ws)
                        except: pass
        finally:
            try: s.close()
            except: pass

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "prev1":
        go_prev("newer")
    elif len(sys.argv) > 1 and sys.argv[1] == "prev2":
        go_prev("older")
    else:
        while True:
            try: daemon()
            except: time.sleep(2)
