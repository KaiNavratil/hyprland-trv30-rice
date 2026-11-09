#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
#  TOKYO 80s TRV30 — Launch Notes & CopyQ Hub
#  東京 80's デジタル // ノート＆クリップボードハブ起動
# ══════════════════════════════════════════════════════════════════════════════

# Ensure notes directory and default scratchpad files exist
mkdir -p ~/.config/notes
touch ~/.config/notes/scratch.txt ~/.config/notes/todo.txt ~/.config/notes/ideas.txt

# Start CopyQ server daemon if not running
if ! pgrep -x "copyq" > /dev/null; then
    copyq --start-server &
    sleep 0.2
fi

# Show CopyQ GUI window
copyq show &

# Launch Kitty Neovim into special:notes silent if not already running
if ! pgrep -f "kitty --class notes-term" > /dev/null; then
    rm -f ~/.local/state/nvim/swap/*scratch.txt.swp
    rm -f ~/.local/state/nvim/swap/*todo.txt.swp
    rm -f ~/.local/state/nvim/swap/*ideas.txt.swp
    hyprctl dispatch exec "[workspace special:notes silent] kitty --class notes-term nvim -p ~/.config/notes/scratch.txt ~/.config/notes/todo.txt ~/.config/notes/ideas.txt"
    sleep 0.3
fi

# If called with --toggle or explicitly, show the hub via native Lua engine
if [ "$1" == "--toggle" ]; then
    hyprctl eval "require('scratchpads').toggle('notes')" >/dev/null 2>&1
fi
