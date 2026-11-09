#!/usr/bin/env bash
# Tokyo 80s TRV30 — Launch/Toggle Antigravity Scratchpad (Native Forwarder)
hyprctl eval "require('scratchpads').toggle('antigravity')" >/dev/null 2>&1
