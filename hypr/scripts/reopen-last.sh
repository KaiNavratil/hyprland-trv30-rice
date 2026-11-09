#!/usr/bin/env bash
# Tokyo 80s TRV30 — Reopen Last Closed Window (Native 0.57 Forwarder)
hyprctl eval "require('guards').reopen_last()" >/dev/null 2>&1
