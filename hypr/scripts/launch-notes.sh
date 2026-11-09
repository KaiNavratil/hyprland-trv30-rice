#!/bin/bash

# Ensure notes directory exists
mkdir -p ~/.config/notes
touch ~/.config/notes/scratch.txt ~/.config/notes/todo.txt ~/.config/notes/ideas.txt

# Launch Kitty with Neovim if not running
if ! pgrep -f "kitty --class notes-term" > /dev/null; then
    # Clean up stale swap files in case the scratchpad was forcefully closed previously
    rm -f ~/.local/state/nvim/swap/*scratch.txt.swp
    rm -f ~/.local/state/nvim/swap/*todo.txt.swp
    rm -f ~/.local/state/nvim/swap/*ideas.txt.swp
    
    kitty --class notes-term nvim -p ~/.config/notes/scratch.txt ~/.config/notes/todo.txt ~/.config/notes/ideas.txt &
    sleep 0.5
fi

# Launch CopyQ daemon if not running
if ! pgrep -x "copyq" > /dev/null; then
    copyq &
    sleep 0.5
fi

# Ensure both windows are tiled in the scratchpad (matching 60px margins)
hyprctl dispatch settiled class:notes-term >/dev/null 2>&1
hyprctl dispatch settiled class:com.github.hluk.copyq >/dev/null 2>&1

# Finally, toggle the workspace to show them
~/.config/hypr/scripts/toggle-scratchpad.sh notes
