#!/usr/bin/env python3
"""
Tokyo TRV30 Smart Launcher Fallback Handler
Executes when user input does not match an exact binary in PATH:
1. Exact aliases (roblox, discord, spotify, files, calendar)
2. Fuzzy matching on installed desktop apps (corrects typos like vialdi, spotfy, nautlus)
3. Safe math calculation with clipboard copy
4. Direct URL navigation in Vivaldi
5. Google Web Search in Vivaldi
Never returns an error or pops up an error box.
"""

import sys
import os
import glob
import re
import difflib
import subprocess
import urllib.parse

def notify(summary, body, icon="system-search"):
    try:
        subprocess.Popen([
            "notify-send",
            "-a", "TRV30 Launcher",
            "-i", icon,
            summary,
            body
        ])
    except Exception:
        pass

def launch_cmd(cmd):
    try:
        subprocess.Popen(cmd, shell=True, start_new_session=True)
    except Exception as e:
        notify("Launch Error", str(e), icon="dialog-error")

def main():
    if len(sys.argv) < 2:
        sys.exit(0)

    raw_query = " ".join(sys.argv[1:]).strip()
    if not raw_query:
        sys.exit(0)

    query_lower = raw_query.lower()

    # Known quick aliases
    aliases = {
        "roblox": "/home/kaijnav/.local/bin/roblox-studio",
        "roblox studio": "/home/kaijnav/.local/bin/roblox-studio",
        "robloxstudio": "/home/kaijnav/.local/bin/roblox-studio",
        "vinegar": "/home/kaijnav/.local/bin/vinegar",
        "files": "nautilus",
        "nautilus": "nautilus",
        "explorer": "nautilus",
        "discord": "vesktop",
        "spotify": "spotify-launcher",
        "calendar": "vivaldi-stable --app=https://calendar.notion.so",
        "notes": "kitty --class notes-term -e nvim",
        "terminal": "kitty",
        "term": "kitty",
        "radar": "/home/kaijnav/.config/hypr/scripts/toggle-radar.sh",
        "bt": "/home/kaijnav/.config/hypr/scripts/toggle-usual-bluetooth.sh",
    }

    if query_lower in aliases:
        notify("アプリ起動 // SHORTCUT", f"Launching {query_lower}", icon="application-x-executable")
        launch_cmd(aliases[query_lower])
        sys.exit(0)

    # Check if executable directly in PATH
    first_word = raw_query.split()[0]
    which_proc = subprocess.run(["which", first_word], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if which_proc.returncode == 0:
        launch_cmd(raw_query)
        sys.exit(0)

    # Check math expression (e.g. 50*20 or 2^8)
    if re.match(r'^[0-9\.\s\+\-\*\/\(\)\^\%]+$', raw_query) and any(c in raw_query for c in "+-*/^%"):
        try:
            expr = raw_query.replace('^', '**')
            result = eval(expr, {"__builtins__": None}, {})
            res_str = f"{result:g}" if isinstance(result, float) else str(result)
            subprocess.run(["wl-copy", res_str], check=False)
            notify("計算結果 // CALCULATOR", f"{raw_query} = {res_str}\n(Copied to clipboard)", icon="accessories-calculator")
            sys.exit(0)
        except Exception:
            pass

    # Check URL
    url_pattern = r'^(https?:\/\/)?([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(\/.*)?$'
    if re.match(url_pattern, raw_query) and " " not in raw_query:
        target_url = raw_query if raw_query.startswith("http") else f"https://{raw_query}"
        notify("ブラウザ // URL", f"Opening {target_url}", icon="vivaldi")
        launch_cmd(f'vivaldi-stable "{target_url}"')
        sys.exit(0)

    # Scan installed desktop apps for fuzzy matching
    app_dirs = [
        os.path.expanduser("~/.local/share/applications"),
        "/usr/share/applications",
        os.path.expanduser("~/.local/share/flatpak/exports/share/applications"),
        "/var/lib/flatpak/exports/share/applications"
    ]
    apps = {}
    for adir in app_dirs:
        if not os.path.isdir(adir):
            continue
        for f in glob.glob(os.path.join(adir, "*.desktop")):
            try:
                with open(f, "r", encoding="utf-8", errors="ignore") as fp:
                    name, exec_cmd, icon, keywords, nodisplay = None, None, "application-x-executable", "", False
                    for line in fp:
                        if line.startswith("Name=") and not name:
                            name = line.strip().split("=", 1)[1]
                        elif line.startswith("Exec=") and not exec_cmd:
                            exec_cmd = line.strip().split("=", 1)[1]
                        elif line.startswith("Icon=") and icon == "application-x-executable":
                            icon = line.strip().split("=", 1)[1]
                        elif line.startswith("Keywords="):
                            keywords += line.strip().split("=", 1)[1].lower() + ";"
                        elif line.strip() == "NoDisplay=true":
                            nodisplay = True
                    if name and exec_cmd and not nodisplay:
                        # Clean exec
                        cleaned_exec = re.sub(r' %[a-zA-Z]', '', exec_cmd).strip()
                        cleaned_exec = re.sub(r'@@.*@@', '', cleaned_exec).strip()
                        apps[name.lower()] = {
                            "name": name,
                            "exec": cleaned_exec,
                            "icon": icon,
                            "keywords": keywords
                        }
            except Exception:
                pass

    # 1. Check substring in app names or keywords
    for key, data in apps.items():
        if query_lower in key or (data["keywords"] and query_lower in data["keywords"]):
            notify("アプリ起動 // MATCH", f"Launching {data['name']}", icon=data["icon"])
            launch_cmd(data["exec"])
            sys.exit(0)

    # 2. Check difflib close matches for typos (e.g. vialdi -> vivaldi)
    close_names = difflib.get_close_matches(query_lower, apps.keys(), n=1, cutoff=0.45)
    if close_names:
        matched = apps[close_names[0]]
        notify("アプリ起動 // TYPO CORRECTED", f"Did you mean {matched['name']}?", icon=matched["icon"])
        launch_cmd(matched["exec"])
        sys.exit(0)

    # Fallback: Web Search in Vivaldi
    encoded = urllib.parse.quote_plus(raw_query)
    search_url = f"https://www.google.com/search?q={encoded}"
    notify("WEB検索 // SEARCH", f"Searching Google for: '{raw_query}'", icon="vivaldi")
    launch_cmd(f'vivaldi-stable "{search_url}"')
    sys.exit(0)

if __name__ == "__main__":
    main()
