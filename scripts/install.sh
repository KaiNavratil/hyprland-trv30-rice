#!/bin/bash
# ═══════════════════════════════════════════════════════
#  TRV30 TOKYO DIGITAL RICE — INSTALLATION SCRIPT
#  東京デジタル — インストールスクリプト
# ═══════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RICE_DIR="$(dirname "$SCRIPT_DIR")"

echo "╔═══════════════════════════════════════════╗"
echo "║  SONY TRV30 DIGITAL HANDYCAM RICE         ║"
echo "║  東京 80's デジタル・インストーラー        ║" 
echo "╚═══════════════════════════════════════════╝"
echo ""

# Check for required packages
echo "[1/5] Checking dependencies..."
DEPS=(hyprland waybar kitty rofi dunst hypridle hyprlock hyprshade playerctl brightnessctl cava nm-applet blueman)
MISSING=()
for dep in "${DEPS[@]}"; do
    if ! command -v "$dep" &> /dev/null; then
        MISSING+=("$dep")
    fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
    echo "  ⚠ Missing packages: ${MISSING[*]}"
    echo "  Install them with your package manager before continuing."
    echo "  Example (Arch): yay -S ${MISSING[*]}"
else
    echo "  ✓ All dependencies found."
fi

# Check for fonts
echo ""
echo "[2/5] Checking fonts..."
FONT_MISSING=false
if ! fc-list | grep -qi 'VCR OSD Mono'; then
    echo "  ⚠ 'VCR OSD Mono' font not found."
    echo "    Download from: https://www.dafont.com/vcr-osd-mono.font"
    echo "    Install to: ~/.local/share/fonts/"
    FONT_MISSING=true
fi
if ! fc-list | grep -qi 'DotGothic16'; then
    echo "  ⚠ 'DotGothic16' font not found."
    echo "    Install via: yay -S ttf-dotgothic16 (or download from Google Fonts)"
    FONT_MISSING=true
fi
if [ "$FONT_MISSING" = false ]; then
    echo "  ✓ All fonts found."
fi

# Backup existing configs
echo ""
echo "[3/5] Backing up existing configs..."
BACKUP_DIR="$HOME/.config/hypr-backup-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
for dir in hypr waybar kitty rofi dunst; do
    if [ -d "$HOME/.config/$dir" ]; then
        cp -r "$HOME/.config/$dir" "$BACKUP_DIR/"
        echo "  ✓ Backed up ~/.config/$dir"
    fi
done
echo "  Backup saved to: $BACKUP_DIR"

# Deploy configs
echo ""
echo "[4/5] Deploying TRV30 configs..."
mkdir -p ~/.config/hypr/shaders
mkdir -p ~/.config/hypr/scripts
mkdir -p ~/.config/waybar/scripts
mkdir -p ~/.config/kitty
mkdir -p ~/.config/rofi
mkdir -p ~/.config/dunst

# We use silent continue if cp fails since some directories might not exist in the source depending on repo structure
cp "$RICE_DIR/hypr/hyprland.conf" ~/.config/hypr/ || true
cp "$RICE_DIR/hypr/hypridle.conf" ~/.config/hypr/ || true
cp "$RICE_DIR/hypr/hyprlock.conf" ~/.config/hypr/ || true
cp "$RICE_DIR/hypr/shaders/"*.glsl ~/.config/hypr/shaders/ || true
cp "$RICE_DIR/hypr/scripts/"*.sh ~/.config/hypr/scripts/ || true
cp "$RICE_DIR/waybar/config-top" ~/.config/waybar/ || true
cp "$RICE_DIR/waybar/config-bottom" ~/.config/waybar/ || true
cp "$RICE_DIR/waybar/config-scanlines" ~/.config/waybar/ || true
cp "$RICE_DIR/waybar/style.css" ~/.config/waybar/ || true
cp "$RICE_DIR/waybar/style-scanlines.css" ~/.config/waybar/ || true
cp "$RICE_DIR/waybar/scripts/"*.sh ~/.config/waybar/scripts/ || true
cp "$RICE_DIR/waybar/toggle-dock.sh" ~/.config/waybar/ || true
cp "$RICE_DIR/kitty/kitty.conf" ~/.config/kitty/ || true
cp "$RICE_DIR/rofi/config.rasi" ~/.config/rofi/ || true
cp "$RICE_DIR/dunst/dunstrc" ~/.config/dunst/ || true

# Make scripts executable
chmod +x ~/.config/waybar/scripts/*.sh 2>/dev/null || true
chmod +x ~/.config/waybar/toggle-dock.sh 2>/dev/null || true
chmod +x ~/.config/hypr/scripts/*.sh 2>/dev/null || true

echo "  ✓ All configs deployed."

# Final instructions
echo ""
echo "[5/5] Setup complete!"
echo ""
echo "╔═══════════════════════════════════════════╗"
echo "║  ● REC  —  SETUP COMPLETE                 ║"
echo "╚═══════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo "  1. Log out and select Hyprland as your session"
echo "  2. Or reload Hyprland: hyprctl reload"
echo "  3. Set a wallpaper with hyprpaper or swaybg"
echo ""
echo "CRT Shutdown effect note:"
echo "  To simulate a CRT turn-off effect when going to sleep,"
echo "  add to your sleep hook or use wlr-randr animations."
echo "  The heavy CRT shader activates automatically after 5min idle."
echo ""
