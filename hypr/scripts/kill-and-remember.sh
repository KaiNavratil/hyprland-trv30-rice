#!/usr/bin/env bash
# Tokyo 80s TRV30 — Kill Active Window & Remember (Native 0.57 Forwarder)
hyprctl eval "require('guards').kill_and_remember()" >/dev/null 2>&1
