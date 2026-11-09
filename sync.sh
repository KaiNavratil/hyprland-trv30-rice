#!/usr/bin/env bash
set -e

RICE_DIR="/home/kaijnav/.gemini/antigravity/scratch/hyprland-trv30-rice"
echo "[*] Syncing live configs to $RICE_DIR..."

cp -r ~/.config/hypr/. "$RICE_DIR/hypr/"
cp -r ~/.config/waybar/. "$RICE_DIR/waybar/"
cp -r ~/.config/kitty/. "$RICE_DIR/kitty/"
cp -r ~/.config/dunst/. "$RICE_DIR/dunst/"
cp -r ~/.config/rofi/. "$RICE_DIR/rofi/"
mkdir -p "$RICE_DIR/bin"
cp -a ~/.local/bin/hyprctl "$RICE_DIR/bin/" 2>/dev/null || true

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
