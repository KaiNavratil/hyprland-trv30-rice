#!/usr/bin/env python3
import json, subprocess, time, os

SESSION_FILE = os.path.expanduser("~/.config/hypr/session.json")

def get_clients():
    try:
        out = subprocess.check_output(["hyprctl", "clients", "-j"], text=True)
        return json.loads(out)
    except:
        return []

def main():
    if not os.path.exists(SESSION_FILE):
        return
        
    try:
        with open(SESSION_FILE, "r") as f:
            target_state = json.load(f)
    except:
        return

    # Keep track of which windows we have already moved by their address
    moved_addresses = set()
    
    # Poll for up to 60 seconds after boot to catch all restoring windows
    for _ in range(30):
        clients = get_clients()
        
        for c in clients:
            addr = c.get("address")
            if addr in moved_addresses:
                continue
                
            c_class = c.get("class", "")
            c_title = c.get("title", "")
            curr_ws = c.get("workspace", {}).get("name", "")
            
            # Find a matching target state
            best_match = None
            for t in target_state:
                if t.get("class") == c_class:
                    best_match = t
                    if t.get("title") == c_title:
                        break # Exact match
            
            if best_match:
                ws = str(best_match.get("workspace", ""))
                if ws and (not ws.startswith("special:") or ws == "special:magic"):
                    if curr_ws != ws:
                        try:
                            target_addr = addr if addr.startswith("0x") else f"0x{addr}"
                            subprocess.run(["hyprctl", "dispatch", "movetoworkspacesilent", f"{ws},address:{target_addr}"], stdout=subprocess.DEVNULL)
                        except Exception:
                            pass
                    moved_addresses.add(addr)
                    target_state.remove(best_match)
                    
        if len(target_state) == 0:
            break
            
        time.sleep(2)

if __name__ == "__main__":
    main()
