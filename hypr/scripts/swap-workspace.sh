#!/usr/bin/env bash
# Tokyo 80s TRV30 — Swap Workspace Windows (Native 0.57 Forwarder)
DIR="${1:-right}"
hyprctl eval "require('spaces').swap_workspace('$DIR')" >/dev/null 2>&1
