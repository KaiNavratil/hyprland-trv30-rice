#!/bin/bash
# Cleanly kill all waybar instances
killall waybar
sleep 0.5

# Restart the top bar
nohup waybar -c ~/.config/waybar/config-top -s ~/.config/waybar/style.css >/dev/null 2>&1 &
disown



# Restart the background scanlines (optional visual effect)
# waybar -c ~/.config/waybar/config-scanlines -s ~/.config/waybar/style-scanlines.css &
