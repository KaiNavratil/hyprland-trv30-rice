#!/bin/bash
# VCR OSD popup script

ACTION=$1

generate_osd_vol() {
    local VOL=$1
    local PCT=$(printf "%3d%%" "$VOL")
    local TOTAL_BARS=$((VOL / 5))
    local BARS=""
    for (( i=1; i<=TOTAL_BARS; i++ )); do
        BARS="${BARS}|"
        if (( i % 20 == 0 )) && [ $i -lt $TOTAL_BARS ]; then
            BARS="${BARS}\n\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0"
        fi
    done
    if [ -n "$BARS" ]; then
        echo -e "VOL ${PCT}  ${BARS}"
    else
        echo -e "VOL ${PCT}"
    fi
}


sync_mute_all_sinks() {
    local TARGET_MUTE=$1
    for sink in $(pactl list sinks short | awk '{print $2}'); do
        pactl set-sink-mute "$sink" "$TARGET_MUTE"
    done
}

get_rounded_vol() {
    wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2 * 100 + 0.5)}'
}

if [ "$ACTION" = "vol-up" ] || [ "$ACTION" = "vol-down" ]; then
    (
        flock -x 200
        CUR_VOL=$(get_rounded_vol)
        if [ "$ACTION" = "vol-up" ]; then
            NEW_VOL=$(( (CUR_VOL / 5 + 1) * 5 ))
            if [ "$NEW_VOL" -gt 2000 ]; then NEW_VOL=2000; fi
            if wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q MUTED; then
                wpctl set-mute @DEFAULT_AUDIO_SINK@ 0
                sync_mute_all_sinks 0
            fi
        else
            NEW_VOL=$(( ((CUR_VOL + 4) / 5 - 1) * 5 ))
            if [ "$NEW_VOL" -lt 0 ]; then NEW_VOL=0; fi
        fi
        wpctl set-volume -l 20.0 @DEFAULT_AUDIO_SINK@ "${NEW_VOL}%"
        OSD_MSG=$(generate_osd_vol "$NEW_VOL")
        dunstify -a "osd" -r 9999 "$OSD_MSG" ""
    ) 200>/tmp/osd_vol.lock

elif [ "$ACTION" = "vol-mute" ]; then
    wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
    MUTE_STATE=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -c MUTED)
    sync_mute_all_sinks "$MUTE_STATE"
    ( sleep 0.1 ; sync_mute_all_sinks "$MUTE_STATE" ) &

    if [ "$MUTE_STATE" = "1" ]; then
        dunstify -a "osd" -r 9999 "VOL  MUTE" ""
    else
        VOL=$(get_rounded_vol)
        OSD_MSG=$(generate_osd_vol "$VOL")
        dunstify -a "osd" -r 9999 "$OSD_MSG" ""
    fi

elif [ "$ACTION" = "next" ]; then
    playerctl next
    dunstify -a "osd" -r 9999 "FFWD ⏩" ""

elif [ "$ACTION" = "prev" ]; then
    playerctl previous
    dunstify -a "osd" -r 9999 "RWD ⏪" ""

elif [ "$ACTION" = "play" ]; then
    playerctl play-pause
    STATUS=$(playerctl status)
    if [ "$STATUS" = "Playing" ]; then
        dunstify -a "osd" -r 9999 "PLAY ▶" ""
    else
        dunstify -a "osd" -r 9999 "PAUSE ❚❚" ""
    fi
fi
