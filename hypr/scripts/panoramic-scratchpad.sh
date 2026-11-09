#!/usr/bin/env bash
# Tokyo 80s TRV30 — Panoramic Scratchpad Coordinator (Native 0.57 Forwarder)
TARGET="${1:-music}"
hyprctl eval "require('scratchpads').toggle_panoramic('$TARGET')" >/dev/null 2>&1
