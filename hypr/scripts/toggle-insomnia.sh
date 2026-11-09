#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
#  CLAMSHELL & INSOMNIA MODE TOGGLE (SUPER + O)
#  Prevents laptop from sleeping, locking, or turning off when lid is closed
# ══════════════════════════════════════════════════════════════════════════════

STATE_FILE="$HOME/.cache/insomnia_mode"
ACTION="${1:-toggle}"

is_active() {
    [ -f "$STATE_FILE" ] && pgrep -f "systemd-inhibit.*Clamshell" >/dev/null
}

enable_mode() {
    # 1. Terminate any stale inhibitor
    pkill -f "systemd-inhibit.*Clamshell" 2>/dev/null

    # 2. Launch systemd inhibitor blocking sleep, idle, and lid close suspend
    systemd-inhibit --what=handle-lid-switch:sleep:idle \
                    --who="Clamshell" \
                    --why="Super+O Clamshell Mode" \
                    --mode=block \
                    sleep infinity >/dev/null 2>&1 &

    # 3. Pause hypridle so screen does not dim, auto-lock, or turn off DPMS
    pkill -STOP hypridle 2>/dev/null

    # 4. Save state
    touch "$STATE_FILE"

    # 5. OSD Notification
    dunstify -a "osd" -r 9998 -u normal \
        "☕ CLAMSHELL MODE: ACTIVE" \
        "Laptop will not sleep, lock, or turn off on lid close\n[SUPER + O] to toggle off"
}

disable_mode() {
    # 1. Kill systemd inhibitor
    pkill -f "systemd-inhibit.*Clamshell" 2>/dev/null

    # 2. Resume hypridle for standard idle timers and lock
    pkill -CONT hypridle 2>/dev/null

    # 3. Clean state
    rm -f "$STATE_FILE"

    # 4. Ensure display is awake and enabled
    hyprctl dispatch dpms on eDP-1 >/dev/null 2>&1

    # 5. OSD Notification
    dunstify -a "osd" -r 9998 -u normal \
        "💤 CLAMSHELL MODE: OFF" \
        "Standard sleep, lock, and lid-close suspend restored"
}

case "$ACTION" in
    on)
        enable_mode
        ;;
    off)
        disable_mode
        ;;
    toggle)
        if is_active; then
            disable_mode
        else
            enable_mode
        fi
        ;;
    status)
        if is_active; then
            echo "active"
            exit 0
        else
            echo "inactive"
            exit 1
        fi
        ;;
    *)
        echo "Usage: $0 {on|off|toggle|status}"
        exit 1
        ;;
esac
