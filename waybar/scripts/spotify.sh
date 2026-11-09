#!/bin/bash
# Usage: ~/.config/waybar/scripts/spotify.sh [cassette|playback]

MODE=$1

if ! command -v playerctl &> /dev/null; then
    if [ "$MODE" = "playback" ]; then echo '{"text": ""}'; else echo ""; fi
    exit 0
fi

STATUS=$(playerctl status 2>/dev/null)

if [ "$STATUS" = "" ]; then
    if [ "$MODE" = "cassette" ]; then
        echo "[⊙ ─── ⊙] NO TAPE"
    else
        echo '{"text": "NO TAPE", "tooltip": "No media playing"}'
    fi
    exit 0
fi

ARTIST=$(playerctl metadata artist 2>/dev/null)
TITLE=$(playerctl metadata title 2>/dev/null)

if [ "$MODE" = "cassette" ]; then
    MAX_TITLE=25
    if [ ${#TITLE} -gt $MAX_TITLE ]; then
        TITLE="${TITLE:0:$MAX_TITLE}…"
    fi
    if [ "$STATUS" = "Playing" ]; then
        echo "[⊙ ═══ ⊙] $TITLE"
    else
        echo "[⊙ ─── ⊙] $TITLE"
    fi
elif [ "$MODE" = "playback" ]; then
    COMBINED="$ARTIST – $TITLE"
    MAX_COMBINED=40
    if [ ${#COMBINED} -gt $MAX_COMBINED ]; then
        COMBINED="${COMBINED:0:$MAX_COMBINED}…"
    fi

    if [ "$STATUS" = "Playing" ]; then
        TEXT="▶ PLAY │ $COMBINED"
    else
        TEXT="❚❚ PAUSE │ $COMBINED"
    fi

    # Progress calculation
    PROGRESS=$(playerctl position 2>/dev/null)
    LENGTH_MICROS=$(playerctl metadata mpris:length 2>/dev/null)
    PERCENT=0
    if [ -n "$PROGRESS" ] && [ -n "$LENGTH_MICROS" ] && [ "$LENGTH_MICROS" -gt 0 ]; then
        PERCENT=$(awk "BEGIN { p = $PROGRESS / ($LENGTH_MICROS / 1000000); if (p>1) p=1; if (p<0) p=0; print p }")
    fi

    # Dynamic expanding timeline padding (50 chars total)
    PAD_TOTAL=$(( 50 - ${#TEXT} ))
    if [ $PAD_TOTAL -lt 0 ]; then PAD_TOTAL=0; fi
    PAD_LEFT=$(( PAD_TOTAL / 2 ))
    PAD_RIGHT=$(( PAD_TOTAL - PAD_LEFT ))

    LINE_LEFT=$(awk "BEGIN { print int($PAD_LEFT * $PERCENT) }")
    SPACE_LEFT=$(( PAD_LEFT - LINE_LEFT ))
    
    LINE_RIGHT=$(awk "BEGIN { print int($PAD_RIGHT * $PERCENT) }")
    SPACE_RIGHT=$(( PAD_RIGHT - LINE_RIGHT ))

    if [ "$SPACE_LEFT" -gt 0 ]; then STR_SPACE_LEFT=$(printf "%${SPACE_LEFT}s" ""); else STR_SPACE_LEFT=""; fi
    if [ "$LINE_LEFT" -gt 0 ]; then STR_LINE_LEFT=$(printf "%${LINE_LEFT}s" "" | sed 's/ /─/g'); else STR_LINE_LEFT=""; fi
    
    if [ "$LINE_RIGHT" -gt 0 ]; then STR_LINE_RIGHT=$(printf "%${LINE_RIGHT}s" "" | sed 's/ /─/g'); else STR_LINE_RIGHT=""; fi
    if [ "$SPACE_RIGHT" -gt 0 ]; then STR_SPACE_RIGHT=$(printf "%${SPACE_RIGHT}s" ""); else STR_SPACE_RIGHT=""; fi

    FINAL_TEXT="${STR_SPACE_LEFT}${STR_LINE_LEFT}${TEXT}${STR_LINE_RIGHT}${STR_SPACE_RIGHT}"
    
    TOOLTIP="Left-Click: ⏯ Play/Pause\nRight-Click: ⏭ Next\nMiddle-Click: ⏮ Prev"

    jq -n -c --arg text "$FINAL_TEXT" --arg tooltip "$TOOLTIP" '{"text": $text, "tooltip": $tooltip}'
fi
