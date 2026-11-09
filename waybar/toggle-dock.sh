#!/bin/bash
# ─── トグルドック (Toggle Bottom Dock) ───
# Sends SIGUSR1 to the bottom waybar instance to toggle visibility.
# The bottom bar runs with start_hidden=true, so it starts hidden
# and this script flips it on/off.
# Note: Ensure this script is executable (chmod +x)

pkill -SIGUSR1 -f 'waybar.*config-bottom'
