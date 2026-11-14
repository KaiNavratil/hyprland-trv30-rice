#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
#  TOKYO 80s TRV30 — USUAL BLUETOOTH TOGGLER
#  東京 80s TRV30 // 通常無線機器 (EarFun Air Pro 4) 接続統御
#  Keybind: Super + Shift + B
#
#  If disconnected / disabled: Enables Bluetooth radio & connects to EarFun Air Pro 4
#  If connected: Disconnects Bluetooth
# ══════════════════════════════════════════════════════════════════════════════

USUAL_MAC="70:5A:6F:6B:56:7B"
USUAL_NAME="EarFun Air Pro 4"

# 1. Check if Bluetooth RF is soft-blocked or disabled
IS_BLOCKED=$(rfkill list bluetooth 2>/dev/null | grep -i "soft blocked: yes")
POWER_STATE=$(bluetoothctl show 2>/dev/null | grep -i "Powered:" | awk '{print $2}')

# 2. Check if Usual device is currently connected
DEV_INFO=$(bluetoothctl info "$USUAL_MAC" 2>/dev/null)
IS_CONNECTED=$(echo "$DEV_INFO" | grep -i "Connected: yes")

if [ -n "$IS_CONNECTED" ]; then
    # ─── ALREADY CONNECTED -> DISCONNECT & POWER OFF ─────────────────────────
    dunstify -a "TRV30_OSD" -r 9997 -u normal -i "bluetooth-disabled" \
        "📡 BLUETOOTH OFF" "Disconnecting $USUAL_NAME & powering down Bluetooth radio...\nEarbuds released for phone connection." -t 2000

    bluetoothctl disconnect "$USUAL_MAC" >/dev/null 2>&1
    sleep 0.3
    bluetoothctl power off >/dev/null 2>&1

    # Switch default sink back to laptop speakers if needed
    SPEAKER_SINK=$(pactl list sinks short 2>/dev/null | grep -E "alsa_output.*HiFi.*Speaker|alsa_output.*speaker|alsa_output" | awk '{print $2}' | head -n 1)
    if [ -n "$SPEAKER_SINK" ]; then
        pactl set-default-sink "$SPEAKER_SINK" 2>/dev/null || true
    fi

    dunstify -a "TRV30_OSD" -r 9997 -u normal -i "bluetooth-disabled" \
        "💤 BLUETOOTH POWERED OFF" "$USUAL_NAME disconnected & radio disabled.\nPhone connection ready | Internal Audio Active." -t 2500
else
    # ─── NOT CONNECTED -> ENABLE & CONNECT ───────────────────────────────────
    # If RF blocked or powered off, restore power
    if [ -n "$IS_BLOCKED" ]; then
        rfkill unblock bluetooth 2>/dev/null
        sleep 0.3
    fi

    if [ "$POWER_STATE" != "yes" ]; then
        bluetoothctl power on >/dev/null 2>&1
        sleep 0.5
    fi

    dunstify -a "TRV30_OSD" -r 9997 -u normal -i "bluetooth-active" \
        "📡 CONNECTING USUAL..." "Powering on Bluetooth adapter...\nSearching for $USUAL_NAME" -t 2500

    CONNECT_OUT=$(bluetoothctl connect "$USUAL_MAC" 2>&1)

    if echo "$CONNECT_OUT" | grep -iq "successful"; then
        # Wait for PipeWire / BlueZ endpoints to establish
        sleep 1.0

        # Lock in Hi-Fi music mode (aptX / AAC)
        CARD="bluez_card.${USUAL_MAC//:/_}"
        for prof in "a2dp-sink" "a2dp-sink-aac" "a2dp-sink-sbc_xq" "a2dp-sink-sbc"; do
            if pactl set-card-profile "$CARD" "$prof" 2>/dev/null; then
                ACTIVE_CODEC="$prof"
                break
            fi
        done

        # Move active streams to Bluetooth sink
        BT_SINK=$(pactl list sinks short 2>/dev/null | grep bluez_output | awk '{print $2}' | head -n 1)
        if [ -n "$BT_SINK" ]; then
            pactl set-default-sink "$BT_SINK"
            pactl list sink-inputs short 2>/dev/null | while read -r stream; do
                stream_id=$(echo "$stream" | awk '{print $1}')
                pactl move-sink-input "$stream_id" "$BT_SINK" 2>/dev/null || true
            done
        fi

        # Keep internal digital mic active to prevent HFP 16kHz mono degradation
        LAPTOP_MIC=$(pactl list sources short 2>/dev/null | grep -E "alsa_input.*Mic1" | awk '{print $2}' | head -n 1)
        [ -n "$LAPTOP_MIC" ] && pactl set-default-source "$LAPTOP_MIC" 2>/dev/null || true

        BATTERY=$(bluetoothctl info "$USUAL_MAC" 2>/dev/null | awk -F '[()]' '/Battery Percentage:/ {print $2}')
        BAT_STR=""
        [ -n "$BATTERY" ] && BAT_STR=" | Battery: ${BATTERY}%"

        CODEC_LABEL="Hi-Fi Stereo"
        [[ "$ACTIVE_CODEC" =~ aac ]] && CODEC_LABEL="AAC 48kHz"
        [[ "$ACTIVE_CODEC" =~ aptx ]] && CODEC_LABEL="aptX High-Res"

        dunstify -a "TRV30_OSD" -r 9997 -u normal -i "audio-headphones" \
            "🎧 USUAL CONNECTED" "$USUAL_NAME ($CODEC_LABEL)${BAT_STR}\nHigh-Fidelity Audio Linked" -t 3000
    else
        # Could not connect immediately (e.g. headphones in case, powered off, or linked to phone)
        # Power radio off so it doesn't fight phone or keep radio running needlessly
        bluetoothctl power off >/dev/null 2>&1
        dunstify -a "TRV30_OSD" -r 9997 -u critical -i "dialog-warning" \
            "⚠️ CONNECTION FAILED" "$USUAL_NAME not found or linked to phone.\nBluetooth powered down." -t 4000
    fi
fi
