#!/bin/bash
# Note: Ensure this script is executable (chmod +x)
# Usage: ~/.config/waybar/scripts/cava-waybar.sh

# Cava config for waybar
CAVA_CONF=$(mktemp)
cat <<EOF > "$CAVA_CONF"
[general]
framerate = 60
bars = 3

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 7
bar_delimiter = 59
channels = mono
EOF

trap "rm -f $CAVA_CONF; exit 0" SIGINT SIGTERM EXIT

cava -p "$CAVA_CONF" | while read -r line; do
    output=""
    IFS=';' read -ra BARS <<< "$line"
    for bar in "${BARS[@]}"; do
        case $bar in
            0) output+=" " ;;
            1) output+="▂" ;;
            2) output+="▃" ;;
            3) output+="▄" ;;
            4) output+="▅" ;;
            5) output+="▆" ;;
            6) output+="▇" ;;
            7) output+="█" ;;
            *) output+=" " ;;
        esac
    done
    echo "$output" 2>/dev/null || exit 0
done
