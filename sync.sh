#!/usr/bin/env bash
set -e

RICE_DIR="/home/kaijnav/.gemini/antigravity/scratch/hyprland-trv30-rice"
echo "[*] Syncing live configs to $RICE_DIR..."

cp -r ~/.config/hypr/. "$RICE_DIR/hypr/"
cp -r ~/.config/waybar/. "$RICE_DIR/waybar/"
cp -r ~/.config/kitty/. "$RICE_DIR/kitty/"
cp -r ~/.config/dunst/. "$RICE_DIR/dunst/"
cp -r ~/.config/rofi/. "$RICE_DIR/rofi/"
mkdir -p "$RICE_DIR/wireplumber"
cp -r ~/.config/wireplumber/. "$RICE_DIR/wireplumber/" 2>/dev/null || true
mkdir -p "$RICE_DIR/xdg-desktop-portal"
cp -r ~/.config/xdg-desktop-portal/. "$RICE_DIR/xdg-desktop-portal/" 2>/dev/null || true
mkdir -p "$RICE_DIR/dbus-services"
cp -r ~/.local/share/dbus-1/services/. "$RICE_DIR/dbus-services/" 2>/dev/null || true
cp -a ~/.config/mimeapps.list "$RICE_DIR/" 2>/dev/null || true
mkdir -p "$RICE_DIR/bin"
cp -a ~/.local/bin/hyprctl "$RICE_DIR/bin/" 2>/dev/null || true
cp -a ~/.local/bin/antigravity "$RICE_DIR/bin/" 2>/dev/null || true
cp -a ~/.local/bin/wl-copy "$RICE_DIR/bin/" 2>/dev/null || true
cp -a ~/.local/bin/wl-paste "$RICE_DIR/bin/" 2>/dev/null || true
cp -a ~/.local/bin/wtype "$RICE_DIR/bin/" 2>/dev/null || true
cp -a ~/.local/bin/vinegar "$RICE_DIR/bin/" 2>/dev/null || true
cp -a ~/.local/bin/roblox-studio "$RICE_DIR/bin/" 2>/dev/null || true
mkdir -p "$RICE_DIR/applications"
cp -a ~/.local/share/applications/roblox-studio.desktop "$RICE_DIR/applications/" 2>/dev/null || true
mkdir -p "$RICE_DIR/copyq"
cp -a ~/.config/copyq/*.conf ~/.config/copyq/*.ini "$RICE_DIR/copyq/" 2>/dev/null || true

cd "$RICE_DIR"
git add -A

if git diff --cached --quiet; then
    echo "[+] No changes to commit."
else
    git commit -m "~"
    echo "[+] Committed changes with comment '~'"
fi

if git remote get-url origin >/dev/null 2>&1; then
    echo "[*] Pushing to GitHub..."
    git push origin main
    echo "[+] Successfully pushed to GitHub!"
else
    echo "[!] Remote 'origin' not configured yet."
fi
