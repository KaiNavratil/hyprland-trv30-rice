#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
#  TOKYO 80s TRV30 — DISPLAY LAYOUT MANAGER (ROFI)
#  Easily switch between Extend (Right/Left/Above), Mirror, and Single Monitor
# ══════════════════════════════════════════════════════════════════════════════

INTERNAL="eDP-1"
# Find the first external monitor that is not eDP-1
EXTERNAL=$(hyprctl monitors all -j | jq -r ".[] | select(.name != \"$INTERNAL\") | .name" | head -n 1)

if [ -z "$EXTERNAL" ]; then
    dunstify -a "osd" -r 9997 -u normal "🖥️ NO EXTERNAL DISPLAY" "Connect an HDMI / USB-C / DisplayPort monitor first."
    exit 1
fi

OPTIONS="1. ▶  EXTEND RIGHT   [Laptop ── External]
2. ◀  EXTEND LEFT    [External ── Laptop]
3. ▲  EXTEND ABOVE   [Laptop Below]
4. ▼  EXTEND BELOW   [Laptop Above]
5. ⧉  MIRROR DISPLAY [Duplicate Screen]
6. 💻 LAPTOP ONLY    [Disable External]
7. 🖥️  EXTERNAL ONLY  [Clamshell / Desk Mode]
8. 💤 SLEEP / SCREEN OFF [Ignore Mouse Wakes]"

CHOSEN=$(echo -e "$OPTIONS" | rofi -dmenu -i -p "モニター // DISPLAY CONFIG" -theme-str 'window { width: 520px; height: 360px; } listview { lines: 8; }')

case "$CHOSEN" in
    *"EXTEND RIGHT"*)
        hyprctl eval "hl.monitor({ output = '$INTERNAL', mode = 'preferred', position = '0x0', scale = 1.20, disabled = false })"
        hyprctl eval "hl.monitor({ output = '$EXTERNAL', mode = 'preferred', position = 'auto-right', scale = 1.00, disabled = false })"
        dunstify -a "osd" -r 9997 -u normal "🖥️ DISPLAY: EXTEND RIGHT" "External display placed to the right of laptop"
        ;;
    *"EXTEND LEFT"*)
        hyprctl eval "hl.monitor({ output = '$EXTERNAL', mode = 'preferred', position = '0x0', scale = 1.00, disabled = false })"
        hyprctl eval "hl.monitor({ output = '$INTERNAL', mode = 'preferred', position = 'auto-right', scale = 1.30, disabled = false })"
        dunstify -a "osd" -r 9997 -u normal "🖥️ DISPLAY: EXTEND LEFT" "Big monitor on left (1080p), Laptop on right (1.3x scale)"
        ;;
    *"EXTEND ABOVE"*)
        hyprctl eval "hl.monitor({ output = '$INTERNAL', mode = 'preferred', position = '0x0', scale = 1.20, disabled = false })"
        hyprctl eval "hl.monitor({ output = '$EXTERNAL', mode = 'preferred', position = 'auto-up', scale = 1.00, disabled = false })"
        dunstify -a "osd" -r 9997 -u normal "🖥️ DISPLAY: EXTEND ABOVE" "External display placed above laptop"
        ;;
    *"EXTEND BELOW"*)
        hyprctl eval "hl.monitor({ output = '$INTERNAL', mode = 'preferred', position = '0x0', scale = 1.20, disabled = false })"
        hyprctl eval "hl.monitor({ output = '$EXTERNAL', mode = 'preferred', position = 'auto-down', scale = 1.00, disabled = false })"
        dunstify -a "osd" -r 9997 -u normal "🖥️ DISPLAY: EXTEND BELOW" "External display placed below laptop"
        ;;
    *"MIRROR DISPLAY"*)
        hyprctl eval "hl.config({ cursor = { no_hardware_cursors = true } })"
        hyprctl eval "hl.monitor({ output = '$INTERNAL', mode = 'preferred', position = '0x0', scale = 1.20, disabled = false })"
        hyprctl eval "hl.monitor({ output = '$EXTERNAL', mode = 'preferred', position = 'auto', scale = 1.00, mirror = '$INTERNAL', disabled = false })"
        dunstify -a "osd" -r 9997 -u normal "⧉ DISPLAY: MIRROR MODE" "Mirroring laptop display to external screen"
        ;;
    *"LAPTOP ONLY"*)
        hyprctl eval "hl.monitor({ output = '$INTERNAL', mode = 'preferred', position = '0x0', scale = 1.20, disabled = false })"
        hyprctl eval "hl.monitor({ output = '$EXTERNAL', disabled = true })"
        python3 -c "import json, subprocess; [subprocess.run(['hyprctl', 'dispatch', 'movetoworkspacesilent', f'{int(c[\"workspace\"][\"name\"])-10},address:{c[\"address\"]}']) for c in json.loads(subprocess.check_output(['hyprctl', 'clients', '-j'])) if c.get('workspace',{}).get('name','').isdigit() and 11 <= int(c['workspace']['name']) <= 19]"
        dunstify -a "osd" -r 9997 -u normal "💻 DISPLAY: LAPTOP ONLY" "External display off. Windows merged to Spaces 1-9"
        ;;
    *"EXTERNAL ONLY"*)
        hyprctl eval "hl.monitor({ output = '$EXTERNAL', mode = 'preferred', position = '0x0', scale = 1.00, disabled = false })"
        hyprctl eval "hl.monitor({ output = '$INTERNAL', disabled = true })"
        python3 -c "import json, subprocess; [subprocess.run(['hyprctl', 'dispatch', 'movetoworkspacesilent', f'{int(c[\"workspace\"][\"name\"])-10},address:{c[\"address\"]}']) for c in json.loads(subprocess.check_output(['hyprctl', 'clients', '-j'])) if c.get('workspace',{}).get('name','').isdigit() and 11 <= int(c['workspace']['name']) <= 19]"
        dunstify -a "osd" -r 9997 -u normal "🖥️ DISPLAY: EXTERNAL ONLY" "Laptop screen off. Windows merged to Spaces 1-9"
        ;;
    *"SLEEP"*)
        bash ~/.config/hypr/scripts/sleep-system.sh screen
        ;;
esac

# Ensure spaces engine synchronizes topology seamlessly
hyprctl eval "require('spaces').handle_monitor_topology_change()" >/dev/null 2>&1 || true
