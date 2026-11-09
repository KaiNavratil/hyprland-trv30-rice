#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
#  DISABLE MOUSE WAKEUP ON SYSTEM SLEEP / SUSPEND
#  Prevents optical mice (Razer DeathAdder) and desk bumps from waking the PC
# ══════════════════════════════════════════════════════════════════════════════

echo "🔒 Creating udev rule to prevent mice from waking system..."
cat << 'EOF' | sudo tee /etc/udev/rules.d/90-disable-mouse-wakeup.rules
# Disable wakeup for Razer mice (Vendor 1532) and all USB mice
ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="1532", ATTR{power/wakeup}="disabled"
ACTION=="add", SUBSYSTEM=="input", ENV{ID_INPUT_MOUSE}=="1", ATTR{power/wakeup}="disabled"
EOF

sudo udevadm control --reload-rules && sudo udevadm trigger
echo "✅ Done! Bumping the mouse will no longer wake the laptop from sleep."
