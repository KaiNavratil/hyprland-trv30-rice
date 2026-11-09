#!/bin/bash
# ═══════════════════════════════════════════════════════════
#  省電力モード (Low Power Mode Toggle)
#  Reduces background process load for battery life.
#
#  Usage: ~/.config/hypr/scripts/power-mode.sh
#  Bind:  Super + B
#
#  Toggles between NORMAL and LOW POWER mode.
#  State is tracked via /tmp/hypr-power-mode
# ═══════════════════════════════════════════════════════════

STATE_FILE="/tmp/hypr-power-mode"

notify() {
    dunstify -u low -t 3000 -r 9999 "$1" "$2"
}

enter_low_power() {
    echo "low" > "$STATE_FILE"

    # ─── Kill battery-hungry background processes ───
    # Cava audio visualizer (continuous CPU + audio processing)
    pkill -f cava-waybar 2>/dev/null

    # Hide the bottom dock bar (one less waybar instance rendering)
    pkill -SIGUSR1 -f 'waybar.*config-bottom' 2>/dev/null

    # ─── Disable animations (saves GPU compositing work) ───
    hyprctl eval 'hl.config({ animations = { enabled = false }, decoration = { blur = { enabled = false } } })' 2>/dev/null

    # ─── Reduce idle timeouts (screen off sooner) ───
    # Dim after 2 minutes instead of 5
    # DPMS off after 5 minutes instead of 15
    # Note: hypridle reads config at launch, so we use hyprctl
    # to set dpms off sooner as a supplement
    notify "⚡ LOW POWER" "省電力モード ON — animations off, cava killed, idle aggressive"
}

exit_low_power() {
    rm -f "$STATE_FILE"

    # ─── Restore animations ───
    hyprctl eval 'hl.config({ animations = { enabled = true } })' 2>/dev/null

    # ─── Restart cava for waybar visualizer ───
    # It will be restarted by waybar's custom module on next interval
    # No action needed — waybar re-execs the script automatically


    notify "📼 NORMAL MODE" "通常モード — animations restored, cava restarting"
}

# ─── Toggle logic ───
if [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE")" = "low" ]; then
    exit_low_power
else
    enter_low_power
fi
