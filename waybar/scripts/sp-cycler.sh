#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
#  TOKYO 80s TRV30 — Waybar Scratchpad Cycler & Indicator (Optimized 0.57)
#  東京 80's デジタル // ウェイバー・スクラッチパッド・サイクル機構
# ══════════════════════════════════════════════════════════════════════════════

ACTION=${1:-status}
ORDER=("music" "discord" "calendar" "notes")
STATE_FILE="/tmp/current_scratchpad"
ACTIVE_FILE="/tmp/scratchpad_active"

get_label() {
    case "$1" in
        music) echo "MSC " ;;
        discord) echo "CHAT" ;;
        calendar) echo "CAL " ;;
        notes) echo "MEMO" ;;
        dev) echo "DEV " ;;
        antigravity) echo "AG  " ;;
        center) echo "DECK" ;;
        radar) echo "RDR " ;;
        magic) echo "CUST" ;;
        *) echo "PAD " ;;
    esac
}

get_active() {
    if [ -f "$ACTIVE_FILE" ]; then
        local act
        read -r act < "$ACTIVE_FILE" 2>/dev/null
        if [ -n "$act" ]; then
            echo "$act"
            return
        fi
    fi

    # Fast single fallback if file is empty
    local mon_sp
    mon_sp=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused == true) | .specialWorkspace.name // ""' | sed 's/^special://')
    if [ -n "$mon_sp" ] && [ "$mon_sp" != "null" ]; then
        echo "$mon_sp"
        return
    fi
}

launch_target() {
    local TARGET=$1
    hyprctl eval "require('scratchpads').toggle('$TARGET')" >/dev/null 2>&1
}

ACTIVE=$(get_active)

if [ "$ACTION" = "status" ]; then
    if [ -n "$ACTIVE" ]; then
        echo "$ACTIVE" > "$STATE_FILE"
        LABEL=$(get_label "$ACTIVE")
        printf '{"text":"<span foreground=\\"#c44444\\">●</span> <span foreground=\\"#f2a533\\">%s</span>","tooltip":"Scratchpad: %s (Active)\\nClick: Close | Scroll: Cycle","class":"active"}\n' "$LABEL" "$ACTIVE"
    else
        CURRENT=""
        if [ -f "$STATE_FILE" ]; then
            read -r CURRENT < "$STATE_FILE" 2>/dev/null
        fi
        if [ -z "$CURRENT" ]; then CURRENT="music"; fi
        LABEL=$(get_label "$CURRENT")
        printf '{"text":"<span foreground=\\"#8a7e72\\">○ %s</span>","tooltip":"Scratchpad: %s\\nClick: Open | Scroll: Cycle","class":"inactive"}\n' "$LABEL" "$CURRENT"
    fi

elif [ "$ACTION" = "toggle" ]; then
    if [ -n "$ACTIVE" ]; then
        hyprctl eval "require('scratchpads').toggle('$ACTIVE')" >/dev/null 2>&1
    else
        CURRENT=""
        if [ -f "$STATE_FILE" ]; then
            read -r CURRENT < "$STATE_FILE" 2>/dev/null
        fi
        if [ -z "$CURRENT" ]; then CURRENT="music"; fi
        launch_target "$CURRENT"
    fi
    ( sleep 0.1 ; pkill -RTMIN+1 waybar ; sleep 0.35 ; pkill -RTMIN+1 waybar ) &

elif [ "$ACTION" = "next" ] || [ "$ACTION" = "prev" ]; then
    CURRENT=""
    if [ -f "$STATE_FILE" ]; then
        read -r CURRENT < "$STATE_FILE" 2>/dev/null
    fi
    if [ -z "$CURRENT" ]; then CURRENT="music"; fi

    CURRENT_IDX=0
    for i in "${!ORDER[@]}"; do
        if [ "${ORDER[$i]}" = "$CURRENT" ]; then
            CURRENT_IDX=$i
            break
        fi
    done

    LEN=${#ORDER[@]}
    if [ "$ACTION" = "next" ]; then
        NEW_IDX=$(( (CURRENT_IDX + 1) % LEN ))
    else
        NEW_IDX=$(( (CURRENT_IDX - 1 + LEN) % LEN ))
    fi

    NEW_TARGET="${ORDER[$NEW_IDX]}"
    echo "$NEW_TARGET" > "$STATE_FILE"

    if [ -n "$ACTIVE" ]; then
        launch_target "$NEW_TARGET"
    fi
    ( sleep 0.1 ; pkill -RTMIN+1 waybar ; sleep 0.35 ; pkill -RTMIN+1 waybar ) &
fi
