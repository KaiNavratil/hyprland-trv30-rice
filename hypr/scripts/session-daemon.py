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
    while True:
        clients = get_clients()
        state = []
        for c in clients:
            ws_name = c.get("workspace", {}).get("name", "")
            if ws_name.startswith("special:"):
                continue # Ignore scratchpads
            
            state.append({
                "class": c.get("class", ""),
                "title": c.get("title", ""),
                "workspace": ws_name
            })
        
        # Save atomically
        try:
            with open(SESSION_FILE + ".tmp", "w") as f:
                json.dump(state, f)
            os.rename(SESSION_FILE + ".tmp", SESSION_FILE)
        except Exception as e:
            pass
            
        time.sleep(5)

if __name__ == "__main__":
    main()
