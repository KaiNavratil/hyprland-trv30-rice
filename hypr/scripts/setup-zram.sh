#!/bin/bash
# ═══════════════════════════════════════════════════════
#  ZRAM OPTIMIZATION SCRIPT
#  Configures full-RAM ZRAM + optimized kernel swappiness
# ═══════════════════════════════════════════════════════

set -e

# Ensure running with sudo
if [ "$EUID" -ne 0 ]; then
    echo "This script requires root privileges to configure /etc/."
    echo "Re-running with sudo..."
    exec sudo bash "$0" "$@"
fi

echo "==> [1/3] Writing /etc/systemd/zram-generator.conf..."
cat << 'EOF' > /etc/systemd/zram-generator.conf
[zram0]
zram-size = ram
compression-algorithm = zstd
EOF

echo "==> [2/3] Writing kernel swappiness tuning to /etc/sysctl.d/99-zram.conf..."
cat << 'EOF' > /etc/sysctl.d/99-zram.conf
# Aggressive swapping into fast compressed ZRAM prevents file-cache eviction
vm.swappiness = 180
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
vm.page-cluster = 0
EOF

sysctl --system > /dev/null

echo "==> [3/3] Checking if live reload is safe..."
AVAILABLE_MEM_MB=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
SWAP_USED_MB=$(awk '/SwapTotal/ {t=$2} /SwapFree/ {f=$2} END {print int((t-f)/1024)}' /proc/meminfo)

echo "    Current Available RAM: ${AVAILABLE_MEM_MB} MB"
echo "    Current Swap in use:   ${SWAP_USED_MB} MB"

if [ "$AVAILABLE_MEM_MB" -gt "$((SWAP_USED_MB + 1024))" ]; then
    echo "==> Sufficient RAM available. Applying new ZRAM size live..."
    swapoff /dev/zram0 2>/dev/null || true
    systemctl daemon-reload
    systemctl restart systemd-zram-setup@zram0.service
    echo ""
    echo "✓ ZRAM successfully upgraded live!"
else
    echo ""
    echo "⚠️  RAM is currently too full to safely flush swap without freezing."
    echo "   Configs are saved! Please do ONE of the following:"
    echo "   1. Hibernate background tabs in Vivaldi (F2 -> 'Hibernate Background Tabs'), then run this script again."
    echo "   OR"
    echo "   2. Simply reboot your laptop (sudo reboot), and the new 14 GB ZRAM will activate automatically on boot."
fi

echo ""
echo "Current Swap Status:"
swapon --show
zramctl 2>/dev/null || true
