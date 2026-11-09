#!/usr/bin/env bash
# Tokyo 80s TRV30 — Move Window to Desktop Space (Native 0.57 Forwarder)
SPACE="${1:-1}"
hyprctl eval "require('spaces').move_window_to_space($SPACE)" >/dev/null 2>&1
