#!/usr/bin/env python3
import os, socket, json, subprocess, time

ALLOWED_CLASSES = {
    "special:music": ["Spotify", "spotify"],
    "special:discord": ["vesktop"],
    "special:notes": ["notes-term", "com.github.hluk.copyq"],
    "special:calendar": ["vivaldi-calendar.notion.so__-Default"],
    "special:magic": ["*"] # allow anything
    ,"special:antigravity": ["antigravity"]
    ,"special:dev": ["antigravity-ide", "vivaldi-stable", "vivaldi-localhost"]
    ,"special:center": ["commandcenter", "command-center", "com.tokyo.commandcenter"]
    ,"special:radar": ["com.tokyo.radar", "trv30-radar", "desktop-radar"]
    ,"special:display": ["com.tokyo.displaydeck", "displaydeck", "display-deck"]
}

def get_active_workspace():
    try:
        out = subprocess.check_output(["hyprctl", "activeworkspace", "-j"], text=True)
        return json.loads(out).get("name")
    except:
        return "1"

def check_and_evict(addr, workspace, class_name):
    if not workspace.startswith("special:"):
        return
        
    allowed = ALLOWED_CLASSES.get(workspace, [])
    
    # If the workspace isn't tracked or allows anything
    if "*" in allowed:
        return
        
    # Check if the class is allowed
    is_allowed = False
    for a in allowed:
        if a in class_name: # Simple substring check just in case
            is_allowed = True
            break
            
    if not is_allowed:
        # EVICT!
        active_ws = get_active_workspace()
        if active_ws.startswith("special:"):
            active_ws = "1" # Fallback if they are looking at a scratchpad
        print(f"Evicting {class_name} ({addr}) from {workspace} to {active_ws}")
        subprocess.run(["hyprctl", "dispatch", "movetoworkspacesilent", f"{active_ws},address:0x{addr}"])

def daemon():
    his = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    xdg = os.environ.get("XDG_RUNTIME_DIR", "/run/user/1000")
    if not his: return
    sock_path = f"{xdg}/hypr/{his}/.socket2.sock"
    
    while True:
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.connect(sock_path)
            f = s.makefile('r', encoding='utf-8')
            
            while True:
                line = f.readline()
                if not line: break
                line = line.strip()
                
                # openwindow>>ADDR,WORKSPACE,CLASS,TITLE
                if line.startswith("openwindow>>"):
                    parts = line.split(">>")[1].split(",", 3)
                    if len(parts) >= 3:
                        addr, workspace, class_name = parts[0], parts[1], parts[2]
                        check_and_evict(addr, workspace, class_name)
                        
                # movewindow>>ADDR,WORKSPACE
                elif line.startswith("movewindow>>"):
                    parts = line.split(">>")[1].split(",")
                    if len(parts) >= 2:
                        addr, workspace = parts[0], parts[1]
                        # We don't have class in movewindow event, so we must query hyprctl
                        try:
                            out = subprocess.check_output(["hyprctl", "clients", "-j"], text=True)
                            clients = json.loads(out)
                            for c in clients:
                                if c.get("address") == f"0x{addr}":
                                    check_and_evict(addr, workspace, c.get("class", ""))
                                    break
                        except: pass
        except Exception as e:
            time.sleep(2)
        finally:
            try: s.close()
            except: pass

if __name__ == "__main__":
    while True:
        try: daemon()
        except: time.sleep(2)
