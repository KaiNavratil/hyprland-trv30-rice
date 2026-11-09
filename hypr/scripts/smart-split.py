#!/usr/bin/env python3
import os, socket, json, subprocess, time

def get_active_ws_windows():
    try:
        out = subprocess.check_output(["hyprctl", "activeworkspace", "-j"], text=True)
        return json.loads(out).get("windows", 0)
    except:
        return 0

def set_force_split(val):
    subprocess.run(["hyprctl", "keyword", "dwindle:force_split", str(val)], stdout=subprocess.DEVNULL)
    # print(f"Set force_split to {val}", flush=True)

def close_special_workspace():
    try:
        out = subprocess.check_output(["hyprctl", "monitors", "-j"], text=True)
        monitors = json.loads(out)
        for m in monitors:
            special = m.get("specialWorkspace", {}).get("name", "")
            if special and special.startswith("special:"):
                name = special.replace("special:", "")
                subprocess.run(["hyprctl", "dispatch", "togglespecialworkspace", name], stdout=subprocess.DEVNULL)
    except:
        pass

def main():
    his = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    xdg = os.environ.get("XDG_RUNTIME_DIR", "/run/user/1000")
    if not his:
        time.sleep(2)
        return
        
    sock_path = f"{xdg}/hypr/{his}/.socket2.sock"

    while True:
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.connect(sock_path)
            
            count = get_active_ws_windows()
            if count == 1:
                set_force_split(2)
            else:
                set_force_split(0)

            f = s.makefile('r', encoding='utf-8')
            while True:
                line = f.readline()
                if not line: break
                line = line.strip()
                
                if line.startswith("workspace>>") or line.startswith("openwindow>>") or line.startswith("closewindow>>") or line.startswith("movewindow>>") or line.startswith("activewindow>>"):
                    count = get_active_ws_windows()
                    if count == 1:
                        set_force_split(2)
                    else:
                        set_force_split(0)
        except Exception as e:
            time.sleep(2)
        finally:
            try: s.close()
            except: pass

if __name__ == "__main__":
    while True:
        try: main()
        except: time.sleep(2)
