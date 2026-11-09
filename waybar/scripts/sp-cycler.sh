#!/bin/bash
ACTION=${1:-status}
ORDER=("music" "discord" "calendar" "notes")
STATE_FILE="/tmp/current_scratchpad"

get_label() {
    case "$1" in
        music) echo "MSC " ;;
        discord) echo "CHAT" ;;
        calendar) echo "CAL " ;;
        notes) echo "MEMO" ;;
        dev) echo "DEV " ;;
        antigravity) echo "AG  " ;;
        center) echo "DECK" ;;
        magic) echo "CUST" ;;
        *) echo "PAD " ;;
    esac
}

get_active() {
    # 1. Check if active window is one of the scratchpads
    local ACTIVE_CLASS=$(hyprctl activewindow -j 2>/dev/null | jq -r '.class // ""')
    case "$ACTIVE_CLASS" in
        Spotify|spotify) echo "music"; return ;;
        vesktop|discord|Discord) echo "discord"; return ;;
        *calendar*) echo "calendar"; return ;;
        notes-term|*copyq*) echo "notes"; return ;;
        *commandcenter*|*command-center*) echo "center"; return ;;
        *radar*) echo "radar"; return ;;
        *displaydeck*|*display-deck*) echo "display"; return ;;
        antigravity-ide) echo "dev"; return ;;
    esac

    # 2. Check if any modal scratchpad is un-stowed on any visible workspace
    for target in "music" "discord" "calendar" "notes"; do
        local CLASS_REGEX=""
        case "$target" in
            music) CLASS_REGEX="^([Ss]potify)$" ;;
            discord) CLASS_REGEX="^([Vv]esktop)$" ;;
            calendar) CLASS_REGEX="calendar" ;;
            notes) CLASS_REGEX="notes-term|com.github.hluk.copyq" ;;
        esac
        local WS=$(hyprctl clients -j 2>/dev/null | jq -r ".[] | select(.class | test(\"$CLASS_REGEX\"; \"i\")) | .workspace.name" | head -n 1)
        if [ -n "$WS" ] && [[ "$WS" != special:* ]]; then
            echo "$target"
            return
        fi
    done

    # 3. Check special workspaces on monitors
    local WS
    WS=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused == true) | .specialWorkspace.name // ""' | grep -E '^special:.+' | sed 's/^special://' | head -n 1)
    if [ -n "$WS" ]; then
        echo "$WS"
        return
    fi
    WS=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | .specialWorkspace.name // ""' | grep -E '^special:.+' | sed 's/^special://' | head -n 1)
    if [ -n "$WS" ]; then
        echo "$WS"
        return
    fi
}

launch_target() {
    local TARGET=$1
    if [ "$TARGET" = "notes" ]; then
        ~/.config/hypr/scripts/launch-notes.sh >/dev/null 2>&1
    elif [ "$TARGET" = "antigravity" ]; then
        ~/.config/hypr/scripts/launch-ag.sh >/dev/null 2>&1
    else
        ~/.config/hypr/scripts/toggle-scratchpad.sh "$TARGET" >/dev/null 2>&1
    fi
}

ACTIVE=$(get_active)

if [ "$ACTION" = "status" ]; then
    if [ -n "$ACTIVE" ]; then
        echo "$ACTIVE" > "$STATE_FILE"
        LABEL=$(get_label "$ACTIVE")
        TEXT="<span foreground=\"#c44444\">●</span> <span foreground=\"#f2a533\">$LABEL</span>"
        TOOLTIP="Scratchpad: $ACTIVE (Active)
Click: Close | Scroll: Cycle"
        jq -nc --arg text "$TEXT" --arg tooltip "$TOOLTIP" --arg class "active" '{"text": $text, "tooltip": $tooltip, "class": $class}'
    else
        CURRENT=$(cat "$STATE_FILE" 2>/dev/null)
        if [ -z "$CURRENT" ]; then CURRENT="music"; fi
        LABEL=$(get_label "$CURRENT")
        TEXT="<span foreground=\"#8a7e72\">○ $LABEL</span>"
        TOOLTIP="Scratchpad: $CURRENT
Click: Open | Scroll: Cycle"
        jq -nc --arg text "$TEXT" --arg tooltip "$TOOLTIP" --arg class "inactive" '{"text": $text, "tooltip": $tooltip, "class": $class}'
    fi

elif [ "$ACTION" = "toggle" ]; then
    if [ -n "$ACTIVE" ]; then
        ~/.config/hypr/scripts/toggle-scratchpad.sh "$ACTIVE" >/dev/null 2>&1
    else
        CURRENT=$(cat "$STATE_FILE" 2>/dev/null)
        if [ -z "$CURRENT" ]; then CURRENT="music"; fi
        launch_target "$CURRENT"
    fi
    ( sleep 0.1 ; pkill -RTMIN+1 waybar ; sleep 0.35 ; pkill -RTMIN+1 waybar ) &

elif [ "$ACTION" = "next" ] || [ "$ACTION" = "prev" ]; then
    CURRENT=$(cat "$STATE_FILE" 2>/dev/null)
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
