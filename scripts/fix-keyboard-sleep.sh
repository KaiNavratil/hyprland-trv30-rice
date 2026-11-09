#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
#  TOKYO 80s TRV30 — FIX KEYBOARD DISCONNECT ON WAKE FROM SLEEP
#  Fixes MonsGeek / Akko USB keyboards (3151:5029) dropping after suspend
# ══════════════════════════════════════════════════════════════════════════════

set -e

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  MONSGEEK KEYBOARD SLEEP & RESUME FIX                            ║"
echo "║  東京 80's デジタル — キーボード復帰パッチ                        ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

if [ "$EUID" -ne 0 ]; then
    echo "🔒 Root privileges required. Re-running with sudo..."
    exec sudo bash "$0" "$@"
fi

# 1. Install Udev Rule: Disable USB autosuspend and buggy remote wakeup
echo "[1/3] Installing udev power management rule..."
cat << 'EOF' > /etc/udev/rules.d/99-monsgeek-keyboard.rules
# MonsGeek / Akko USB Keyboard (Vendor 3151, Product 5029)
# 1. Keep USB port powered on (disable kernel autosuspend)
ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="3151", ATTRS{idProduct}=="5029", ATTR{power/control}="on", ATTR{power/autosuspend}="-1"

# 2. Disable faulty remote wakeup that hangs keyboard MCU during AMD s2idle
ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="3151", ATTRS{idProduct}=="5029", ATTR{power/wakeup}="disabled"

# 3. Allow user-space access so software reset tools can recover without replugging
SUBSYSTEM=="usb", ATTRS{idVendor}=="3151", ATTRS{idProduct}=="5029", MODE="0666", TAG+="uaccess"
EOF

# 2. Install Systemd Sleep Resume Hook: Automatically re-enumerates keyboard on wake
echo "[2/3] Installing systemd resume recovery hook..."
mkdir -p /etc/systemd/system-sleep/
cat << 'EOF' > /etc/systemd/system-sleep/monsgeek-keyboard-resume.sh
#!/bin/sh
# Automatically resets the MonsGeek keyboard upon waking from sleep / suspend
# Prevents having to manually unplug and replug the USB cable.

case "$1/$2" in
  post/*)
    # Wait briefly for AMD xHCI root hub to power back up
    sleep 0.5
    if /usr/bin/lsusb -d 3151:5029 >/dev/null 2>&1; then
      /usr/bin/usbreset 3151:5029 >/dev/null 2>&1 || true
    fi
    ;;
esac
EOF
chmod +x /etc/systemd/system-sleep/monsgeek-keyboard-resume.sh

# 3. Reload and trigger udev rules immediately
echo "[3/3] Applying udev rules to currently connected devices..."
udevadm control --reload-rules
udevadm trigger --subsystem-match=usb

# Apply live power settings to connected keyboard right now
for dev in /sys/bus/usb/devices/*; do
    if [ -f "$dev/idVendor" ] && [ -f "$dev/idProduct" ]; then
        VENDOR=$(cat "$dev/idVendor" 2>/dev/null || true)
        PRODUCT=$(cat "$dev/idProduct" 2>/dev/null || true)
        if [ "$VENDOR" = "3151" ] && [ "$PRODUCT" = "5029" ]; then
            echo "on" > "$dev/power/control" 2>/dev/null || true
            echo "-1" > "$dev/power/autosuspend" 2>/dev/null || true
            echo "disabled" > "$dev/power/wakeup" 2>/dev/null || true
            echo "  ✓ Live power settings applied to USB device at $(basename "$dev")"
        fi
    fi
done

# 4. Configure systemd-logind to suspend on lid close even when connected to an external display
echo "[4/4] Setting systemd-logind to suspend on lid close with external displays..."
mkdir -p /etc/systemd/logind.conf.d/
cat << 'EOF' > /etc/systemd/logind.conf.d/lid-docked-suspend.conf
[Login]
HandleLidSwitchDocked=suspend
EOF

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  ✅ SUCCESS: Keyboard and Lid Sleep Patches Installed!          ║"
echo "║  - MonsGeek keyboard won't crash or disconnect on resume.        ║"
echo "║  - Laptop will properly sleep on lid close even with monitors.   ║"
echo "║  - (Use Super+O if you ever want Clamshell / Insomnia mode)      ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
