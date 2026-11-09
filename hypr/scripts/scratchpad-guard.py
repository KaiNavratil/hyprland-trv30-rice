#!/usr/bin/env python3
import os, socket, json, subprocess, time

ALLOWED_CLASSES = {
    "special:music": ["spotify"],
    "special:discord": ["vesktop", "discord"],
    "special:notes": ["notes-term", "copyq", "com.github.hluk.copyq"],
    "special:calendar": ["vivaldi-calendar", "notion"],
    "special:magic": ["*"], # allow anything
    "special:antigravity": ["antigravity"],
    "special:dev": ["antigravity-ide", "antigravity", "vivaldi"],
    "special:center": ["commandcenter", "command-center", "com.tokyo.commandcenter", "center"],
    "special:radar": ["com.tokyo.radar", "trv30-radar", "desktop-radar", "radar"],
    "special:display": ["com.tokyo.displaydeck", "displaydeck", "display-deck", "display"],
    "special:cava": ["trv30-cava", "cava"],
    "special:sysmon": ["trv30-btop", "btop"]
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
        
    # Check if the class is allowed (case-insensitive substring check)
    is_allowed = False
    for a in allowed:
        if a.lower() in class_name.lower():
            is_allowed = True
            break
            
    if not is_allowed:
        # EVICT!
        active_ws = get_active_workspace()
        if active_ws.startswith("special:"):
            active_ws = "1" # Fallback if viewing a scratchpad
        target_addr = addr if addr.startswith("0x") else f"0x{addr}"
        print(f"Evicting {class_name} ({target_addr}) from {workspace} to {active_ws}")
        subprocess.run(["hyprctl", "dispatch", "movetoworkspacesilent", f"{active_ws},address:{target_addr}"])

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
                        # We don't have class in movewindow event, so query hyprctl
                        try:
                            out = subprocess.check_output(["hyprctl", "clients", "-j"], text=True)
                            clients = json.loads(out)
                            for c in clients:
                                if c.get("address") == f"0x{addr}" or c.get("address") == addr:
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
