#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
#  TOKYO 80s TRV30 — Dunst Notification App Tracker
#  Records notification ID to app name mappings for click-action routing
# ══════════════════════════════════════════════════════════════════════════════

DIR="/tmp/dunst_active_notifs"
mkdir -p "$DIR" 2>/dev/null

if [ -n "$DUNST_ID" ]; then
    APP="${DUNST_APP_NAME:-vesktop}"
    echo "$APP" > "$DIR/$DUNST_ID"
fi
