#!/bin/bash
# ═══════════════════════════════════════════════════════
#  SUPER DOUBLE-TAP DETECTOR (CUSTOM MAGIC SCRATCHPAD)
#  スーパーキー・ダブルタップ検出（カスタム・スクラッチパッド）
# ═══════════════════════════════════════════════════════

DOWN_FILE="/tmp/hypr_super_down"
TAP_FILE="/tmp/hypr_super_last_tap"

# Fast millisecond timestamp using bash internal variable
t=${EPOCHREALTIME/.}
NOW=${t:0:13}

ACTION="${1:-release}"

if [ "$ACTION" == "down" ]; then
    echo "$NOW" > "$DOWN_FILE"
    exit 0
fi

# Release phase:
if [ -f "$DOWN_FILE" ]; then
    read -r DOWN < "$DOWN_FILE" 2>/dev/null
    rm -f "$DOWN_FILE"
    if [ -n "$DOWN" ]; then
        HOLD=$((NOW - DOWN))
        # If Super was held for > 300ms, it was a hold or combo, discard tap state
        if [ "$HOLD" -gt 300 ]; then
            rm -f "$TAP_FILE"
            exit 0
        fi
    fi
fi

if [ -f "$TAP_FILE" ]; then
    read -r LAST < "$TAP_FILE" 2>/dev/null
    if [ -n "$LAST" ]; then
        DIFF=$((NOW - LAST))
        # If second tap release is within 400ms of first tap release (and > 50ms)
        if [ "$DIFF" -gt 50 ] && [ "$DIFF" -lt 400 ]; then
            rm -f "$TAP_FILE"
            # Double tap detected: toggle custom magic scratchpad
            bash ~/.config/hypr/scripts/toggle-scratchpad.sh magic
            exit 0
        fi
    fi
fi

# Record first tap
echo "$NOW" > "$TAP_FILE"
