#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
#  TOKYO 80s TRV30 — UNIFIED SCRATCHPAD DISPATCHER (Hyprland 0.57+ Lua Forwarder)
# ══════════════════════════════════════════════════════════════════════════════

TARGET="$1"
MODE="$2"

if [ -z "$TARGET" ]; then
    exit 0
fi

IS_STACK="false"
if [ "$MODE" == "--stack" ]; then
    IS_STACK="true"
fi

# Delegate directly to Hyprland's native idempotent Lua scratchpad engine
hyprctl repl "local sp = require('scratchpads'); sp.toggle('$TARGET', $IS_STACK)" >/dev/null 2>&1
