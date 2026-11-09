#!/bin/bash
# Toggle between EarFun A2DP (High-Res Music) and HFP (Headset Mic)

CARD=$(pactl list cards short | grep bluez_card | awk '{print $2}' | head -n 1)
if [ -z "$CARD" ]; then
    dunstify -a "osd" -r 9998 "BT AUDIO" "No Bluetooth audio device connected"
    exit 1
fi

CURRENT_PROFILE=$(pactl list cards | awk -v card="$CARD" '$0 ~ "Name: " card {flag=1} flag && /Active Profile:/ {print $3; exit}')

if [[ "$CURRENT_PROFILE" =~ headset ]]; then
    # Currently in Headset mode -> Switch to Music Mode (a2dp-sink)
    pactl set-card-profile "$CARD" a2dp-sink
    sleep 0.4
    BT_SINK=$(pactl list sinks short | grep bluez_output | awk '{print $2}' | head -n 1)
    if [ -n "$BT_SINK" ]; then
        pactl set-default-sink "$BT_SINK"
    fi
    LAPTOP_MIC=$(pactl list sources short | grep -E "alsa_input.*Mic1" | awk '{print $2}' | head -n 1)
    if [ -n "$LAPTOP_MIC" ]; then
        pactl set-default-source "$LAPTOP_MIC"
    fi
    dunstify -a "osd" -r 9998 "🎧 MUSIC MODE" "EarFun aptX Hi-Fi Active (Mic Off)"
else
    # Currently in A2DP mode -> Switch to Call Mode (headset-head-unit)
    pactl set-card-profile "$CARD" headset-head-unit
    sleep 0.5
    BT_SINK=$(pactl list sinks short | grep bluez_output | awk '{print $2}' | head -n 1)
    if [ -n "$BT_SINK" ]; then
        pactl set-default-sink "$BT_SINK"
    fi
    BT_SOURCE=$(pactl list sources short | grep bluez_input | awk '{print $2}' | head -n 1)
    if [ -n "$BT_SOURCE" ]; then
        pactl set-default-source "$BT_SOURCE"
    fi
    dunstify -a "osd" -r 9998 "🎙️ CALL MODE" "EarFun Mic Active (mSBC Voice)"
fi
