#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
#  AUTO-CONNECT / PAIR BEATS PILL
# ══════════════════════════════════════════════════════════════════════════════

# 1. Ensure Bluetooth is unblocked and powered
rfkill unblock bluetooth
bluetoothctl power on >/dev/null 2>&1

echo "🔍 Searching for Beats Pill..."
echo "👉 Make sure your Beats Pill is in PAIRING MODE (hold power button ~3s until light pulses/blinks)."

# Check if already paired
PAIRED_MAC=$(bluetoothctl devices Paired | grep -i -E "beats.*pill|pill" | awk '{print $2}' | head -n 1)

if [ -n "$PAIRED_MAC" ]; then
    echo "Found already paired device: $PAIRED_MAC. Connecting..."
    bluetoothctl connect "$PAIRED_MAC"
    exit 0
fi

# Scan for up to 15 seconds or until found
FOUND_MAC=""
for i in {1..3}; do
    echo "Scanning attempt $i/3..."
    bluetoothctl --timeout 5 scan on >/dev/null 2>&1
    
    # Check classic or LE beats pill
    FOUND_MAC=$(bluetoothctl devices | grep -i -E "beats.*pill|pill" | awk '{print $2}' | head -n 1)
    if [ -n "$FOUND_MAC" ]; then
        break
    fi
done

if [ -z "$FOUND_MAC" ]; then
    echo "❌ Beats Pill not found."
    echo "Tips:"
    echo "  1. Turn off and back on."
    echo "  2. Hold the power button until the LED blinks white."
    echo "  3. If previously paired to your phone, disconnect from your phone first."
    exit 1
fi

DEVICE_NAME=$(bluetoothctl info "$FOUND_MAC" | grep "Name:" | cut -d ' ' -f 2-)
echo "✅ Detected: $DEVICE_NAME ($FOUND_MAC)"
echo "🔗 Pairing and trusting..."

bluetoothctl trust "$FOUND_MAC"
bluetoothctl pair "$FOUND_MAC"
bluetoothctl connect "$FOUND_MAC"

sleep 2

if bluetoothctl info "$FOUND_MAC" | grep -q "Connected: yes"; then
    echo "🎉 Successfully connected to $DEVICE_NAME!"
    # Switch default audio sink to Beats Pill if found in WirePlumber
    PILL_SINK_ID=$(wpctl status | grep -i -E "beats|pill|bluez_output" | grep -o "[0-9]\+" | head -n 1)
    if [ -n "$PILL_SINK_ID" ]; then
        wpctl set-default "$PILL_SINK_ID"
        wpctl set-volume "$PILL_SINK_ID" 40%
        echo "🔊 Audio output routed to Beats Pill (Sink ID: $PILL_SINK_ID)"
    fi
    dunstify -a "osd" -r 9996 "🎵 BEATS PILL CONNECTED" "Audio routed to $DEVICE_NAME"
else
    echo "⚠️ Pairing initiated. If prompted for PIN or confirmation, verify on device."
fi

