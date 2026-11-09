#!/bin/bash
if [ -f /tmp/hypr_shader_state ]; then
    STATE=$(cat /tmp/hypr_shader_state)
    if [[ "$STATE" == *"crt-heavy"* ]]; then
        SHADER_PATH="~/.config/hypr/shaders/crt-heavy.glsl"
    else
        SHADER_PATH="[[EMPTY]]"
    fi
else
    SHADER_PATH="~/.config/hypr/shaders/crt-heavy.glsl"
fi

# Spawn glitch animation, which will pull the trigger itself
kitty --class crt-blink -o font_family="VCR OSD Mono" -o font_size=16 -o background=#000000 -o foreground=#00ff41 -o window_padding_width=0 -e bash -c "
    for i in {1..4}; do
        cat /dev/urandom | hexdump -C | head -n \$((RANDOM % 40 + 10))
        sleep 0.05
        clear
        sleep 0.05
    done
    cat /dev/urandom | hexdump -C | head -n 60
    
    # Trigger compilation from INSIDE kitty, guaranteeing this frame is frozen
    hyprctl --batch \"keyword decoration:screen_shader $SHADER_PATH\"
    
    # Wait out the freeze and disappear
    sleep 1.0
" &
