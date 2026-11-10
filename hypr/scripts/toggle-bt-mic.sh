#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
#  TOKYO 80s TRV30 — AUDIO QUALITY & BLUETOOTH PROFILE TOGGLER
#  Toggles between Hi-Fi Stereo (Music Mode) and Headset (Call / Mic Mode)
#  Keybind: Super + H
# ══════════════════════════════════════════════════════════════════════════════

# Find active Bluetooth audio card
CARD=$(pactl list cards short 2>/dev/null | grep bluez_card | awk '{print $2}' | head -n 1)

if [ -z "$CARD" ]; then
    # Try finding connected device via bluetoothctl if card isn't registered yet
    DEV_MAC=$(bluetoothctl devices Connected 2>/dev/null | head -n 1 | awk '{print $2}')
    if [ -n "$DEV_MAC" ]; then
        CARD="bluez_card.${DEV_MAC//:/_}"
    fi
fi

if [ -z "$CARD" ]; then
    dunstify -a "TRV30_OSD" -r 9998 -u normal -i "audio-headphones" "🔊 AUDIO PROFILE" "No Bluetooth headphones connected\nUsing built-in speakers & mic" -t 2000
    exit 0
fi

DEV_MAC=$(echo "$CARD" | sed 's/bluez_card\.//' | sed 's/_/:/g')
CARD_INFO=$(pactl list cards 2>/dev/null | awk -v card="$CARD" '$0 ~ "Name: " card {flag=1} flag; /Card #/ && !($0 ~ card) {flag=0}')
CURRENT_PROFILE=$(echo "$CARD_INFO" | awk '/Active Profile:/ {print $3; exit}')

# High-fidelity music profiles in priority order
A2DP_PROFILES=("a2dp-sink" "a2dp-sink-aac" "a2dp-sink-sbc_xq" "a2dp-sink-sbc")

if [[ "$CURRENT_PROFILE" =~ headset ]]; then
    # ─── CURRENTLY IN CALL MODE -> SWITCH TO HIGH QUALITY MUSIC MODE ──────
    SUCCESS=0
    for prof in "${A2DP_PROFILES[@]}"; do
        if echo "$CARD_INFO" | grep -q "$prof:"; then
            if pactl set-card-profile "$CARD" "$prof" 2>/dev/null; then
                SUCCESS=1
                ACTIVE_CODEC="$prof"
                break
            fi
        fi
    done

    # If setting failed because BlueZ dropped A2DP endpoints, reconnect
    if [ $SUCCESS -eq 0 ]; then
        bluetoothctl connect "$DEV_MAC" >/dev/null 2>&1
        sleep 0.8
        for prof in "${A2DP_PROFILES[@]}"; do
            if pactl set-card-profile "$CARD" "$prof" 2>/dev/null; then
                SUCCESS=1
                ACTIVE_CODEC="$prof"
                break
            fi
        done
    fi

    # Set default sink to bluetooth
    sleep 0.2
    BT_SINK=$(pactl list sinks short 2>/dev/null | grep bluez_output | awk '{print $2}' | head -n 1)
    if [ -n "$BT_SINK" ]; then
        pactl set-default-sink "$BT_SINK"
        # Move all current audio playback streams to Bluetooth sink
        pactl list sink-inputs short 2>/dev/null | while read -r stream; do
            stream_id=$(echo "$stream" | awk '{print $1}')
            pactl move-sink-input "$stream_id" "$BT_SINK" 2>/dev/null || true
        done
    fi

    # Keep laptop mic active to preserve high-res audio and prevent HFP reversion
    LAPTOP_MIC=$(pactl list sources short 2>/dev/null | grep -E "alsa_input.*Mic1" | awk '{print $2}' | head -n 1)
    if [ -z "$LAPTOP_MIC" ]; then
        LAPTOP_MIC=$(pactl list sources short 2>/dev/null | grep alsa_input | awk '{print $2}' | head -n 1)
    fi
    if [ -n "$LAPTOP_MIC" ]; then
        pactl set-default-source "$LAPTOP_MIC"
    fi

    CODEC_NAME="Hi-Fi Stereo"
    [[ "$ACTIVE_CODEC" =~ aac ]] && CODEC_NAME="AAC 48kHz Stereo"
    [[ "$ACTIVE_CODEC" =~ aptx ]] && CODEC_NAME="aptX High-Res Stereo"
    [[ "$ACTIVE_CODEC" =~ sbc_xq ]] && CODEC_NAME="SBC-XQ High-Bitrate"

    dunstify -a "TRV30_OSD" -r 9998 -u normal -i "audio-headphones" "🎧 HI-FI MUSIC MODE" "Prinstine Audio Active: $CODEC_NAME\nLaptop Mic Armed (Zero Distortion)" -t 2500

else
    # ─── CURRENTLY IN MUSIC MODE -> SWITCH TO CALL / MIC MODE ─────────────
    CALL_PROFILES=("headset-head-unit" "headset-head-unit-msbc" "headset-head-unit-cvsd")
    SUCCESS=0
    for prof in "${CALL_PROFILES[@]}"; do
        if echo "$CARD_INFO" | grep -q "$prof:"; then
            if pactl set-card-profile "$CARD" "$prof" 2>/dev/null; then
                SUCCESS=1
                break
            fi
        fi
    done

    sleep 0.3
    BT_SINK=$(pactl list sinks short 2>/dev/null | grep bluez_output | awk '{print $2}' | head -n 1)
    if [ -n "$BT_SINK" ]; then
        pactl set-default-sink "$BT_SINK"
    fi

    BT_SOURCE=$(pactl list sources short 2>/dev/null | grep bluez_input | awk '{print $2}' | head -n 1)
    if [ -n "$BT_SOURCE" ]; then
        pactl set-default-source "$BT_SOURCE"
        # Move all current recording streams to Bluetooth mic
        pactl list source-outputs short 2>/dev/null | while read -r stream; do
            stream_id=$(echo "$stream" | awk '{print $1}')
            pactl move-source-output "$stream_id" "$BT_SOURCE" 2>/dev/null || true
        done
    fi

    dunstify -a "TRV30_OSD" -r 9998 -u normal -i "audio-input-microphone" "🎙️ CALL MODE" "EarFun Headset Mic Active (mSBC Voice)\nAudio set to voice communications" -t 2500
fi
