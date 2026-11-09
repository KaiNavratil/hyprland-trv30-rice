#!/usr/bin/env bash
# Tokyo 80s TRV30 — Dual-Monitor Desktop Space Switcher (Native 0.57 Forwarder)
SPACE="${1:-1}"
hyprctl eval "require('spaces').switch_desktop_space($SPACE)" >/dev/null 2>&1
