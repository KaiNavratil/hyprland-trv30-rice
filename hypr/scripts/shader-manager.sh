#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
#  TOKYO 80s TRV30 — SHADER MANAGER (シェーダー・マネージャー)
#  Cycles, toggles, and manages Hyprland GPU screen shaders with retro OSD
# ══════════════════════════════════════════════════════════════════════════════

SHADER_DIR="$HOME/.config/hypr/shaders"
STATE_FILE="/tmp/hypr_shader_state"
CACHE_FILE="$HOME/.config/hypr/state/shader_mode"

mkdir -p "$HOME/.config/hypr/state"

# Shader list in cycle order
SHADERS=(
    "off"
    "trv30-amber-bloom.glsl"
    "crt-scanlines.glsl"
    "crt-heavy.glsl"
    "crt-fisheye.glsl"
    "warmth-3500k.glsl"
    "warmth-2400k.glsl"
)

# Human-readable labels for OSD
declare -A LABELS=(
    ["off"]="OFF (DIRECT CLEAN)"
    ["trv30-amber-bloom.glsl"]="TRV30 CRT BLOOM"
    ["crt-scanlines.glsl"]="SUBTLE SCANLINES"
    ["crt-heavy.glsl"]="VCR RETRO HEAVY"
    ["crt-fisheye.glsl"]="CRT FISHEYE 80s"
    ["warmth-3500k.glsl"]="3500K WARM TUNGSTEN"
    ["warmth-2400k.glsl"]="2400K CANDLE AMBER"
)

get_current() {
    if [ -f "$STATE_FILE" ]; then
        cat "$STATE_FILE"
    else
        echo "off"
    fi
}

notify_osd() {
    local name="$1"
    local label="${LABELS[$name]:-$name}"
    local icon="video-display"
    if [ "$name" = "off" ]; then
        dunstify -a "TRV30_OSD" -r 9991 -u normal -i "$icon" "📺 CRT SHADER" "STATE: $label" -t 1800
    else
        dunstify -a "TRV30_OSD" -r 9991 -u normal -i "$icon" "📺 CRT SHADER" "ACTIVE: $label" -t 1800
    fi
}

apply_shader() {
    local target="$1"
    if [ "$target" = "off" ] || [ -z "$target" ]; then
        hyprctl keyword decoration:screen_shader "" >/dev/null 2>&1
        echo "off" > "$STATE_FILE"
        echo "off" > "$CACHE_FILE"
        notify_osd "off"
    else
        local full_path="$SHADER_DIR/$target"
        if [ -f "$full_path" ]; then
            hyprctl keyword decoration:screen_shader "$full_path" >/dev/null 2>&1
            echo "$target" > "$STATE_FILE"
            echo "$target" > "$CACHE_FILE"
            notify_osd "$target"
        else
            echo "Error: Shader $full_path not found" >&2
        fi
    fi
}

ACTION="${1:-toggle}"

case "$ACTION" in
    toggle)
        CURR=$(get_current)
        if [ "$CURR" = "off" ] || [ -z "$CURR" ]; then
            # Turn on default TRV30 bloom
            apply_shader "trv30-amber-bloom.glsl"
        else
            apply_shader "off"
        fi
        ;;

    next)
        CURR=$(get_current)
        COUNT=${#SHADERS[@]}
        IDX=0
        for i in "${!SHADERS[@]}"; do
            if [ "${SHADERS[$i]}" = "$CURR" ]; then
                IDX=$i
                break
            fi
        done
        NEXT_IDX=$(( (IDX + 1) % COUNT ))
        apply_shader "${SHADERS[$NEXT_IDX]}"
        ;;

    prev)
        CURR=$(get_current)
        COUNT=${#SHADERS[@]}
        IDX=0
        for i in "${!SHADERS[@]}"; do
            if [ "${SHADERS[$i]}" = "$CURR" ]; then
                IDX=$i
                break
            fi
        done
        PREV_IDX=$(( (IDX - 1 + COUNT) % COUNT ))
        apply_shader "${SHADERS[$PREV_IDX]}"
        ;;

    set)
        TARGET="$2"
        apply_shader "$TARGET"
        ;;

    status)
        CURR=$(get_current)
        echo "$CURR"
        ;;

    *)
        echo "Usage: $0 {toggle|next|prev|set <shader>|status}"
        exit 1
        ;;
esac
