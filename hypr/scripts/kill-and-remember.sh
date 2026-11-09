#!/bin/bash
# Tokyo 80s TRV30 — Kill Active Window & Remember for Reopen (Super + Q)

APP_JSON=$(hyprctl activewindow -j)
APP_CLASS=$(echo "$APP_JSON" | jq -r '.class // ""')
APP_TITLE=$(echo "$APP_JSON" | jq -r '.title // ""')
WS_NAME=$(echo "$APP_JSON" | jq -r '.workspace.name // ""')
MON_ID=$(echo "$APP_JSON" | jq -r '.monitor // 0')

if [[ "$APP_CLASS" == "null" || -z "$APP_CLASS" ]]; then
    hyprctl dispatch killactive
    exit 0
fi

EXEC_CMD=""

case "$APP_CLASS" in
    "vivaldi-stable") 
        if [[ "$APP_TITLE" == *"Notion Calendar"* ]]; then
            EXEC_CMD="vivaldi-stable --app=https://calendar.notion.so"
        else
            EXEC_CMD="vivaldi-stable"
        fi
        ;;
    "kitty") EXEC_CMD="kitty" ;;
    "code"|"Code") EXEC_CMD="code" ;;
    "discord"|"Vesktop"|"vesktop") EXEC_CMD="vesktop" ;;
    "Spotify"|"spotify") EXEC_CMD="spotify-launcher --skip-update" ;;
    "org.pulseaudio.pavucontrol") EXEC_CMD="pavucontrol" ;;
    "copyq") EXEC_CMD="copyq show" ;;
    "GitHub Desktop"|"github-desktop") EXEC_CMD="github-desktop" ;;
    "antigravity-ide") EXEC_CMD="/opt/antigravity-ide/antigravity-ide" ;;
    "antigravity") EXEC_CMD="antigravity" ;;
    *) 
        EXEC_CMD="${APP_CLASS,,}"
        ;;
esac

# Push to recently_closed.json stack if not a scratchpad
if [ -n "$EXEC_CMD" ] && [[ "$WS_NAME" != special:* ]]; then
    echo "[workspace $WS_NAME] $EXEC_CMD" > ~/.cache/last_closed_app

    python3 -c "
import json, os, time

path = os.path.expanduser('~/.cache/recently_closed.json')
history = []
if os.path.exists(path):
    try:
        with open(path, 'r') as f:
            history = json.load(f)
    except:
        history = []

entry = {
    'class': '''$APP_CLASS''',
    'title': '''$APP_TITLE''',
    'workspace': '$WS_NAME',
    'monitor': $MON_ID,
    'exec_cmd': '''$EXEC_CMD''',
    'timestamp': time.time()
}

if not (history and history[0].get('title') == entry['title']):
    history.insert(0, entry)
    try:
        with open(path, 'w') as f:
            json.dump(history[:30], f, indent=2)
    except:
        pass
"
fi

# Kill the active window
hyprctl dispatch killactive
