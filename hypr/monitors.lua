-- ═══════════════════════════════════════════════════════════════════════════════
--  TOKYO 80s TRV30 — DYNAMIC MONITOR CONFIGURATION
--  東京 80s TRV30 // ディスプレイ構成設定
-- ═══════════════════════════════════════════════════════════════════════════════

-- External Big Monitor (Left): native 1080p crisp 1:1 scale
hl.monitor({
    output   = "HDMI-A-1",
    mode     = "preferred",
    position = "0x0",
    scale    = 1.00,
})

-- Laptop Screen (Right): positioned to the right, scaled at 1.30 for easy reading from a distance
hl.monitor({
    output   = "eDP-1",
    mode     = "preferred",
    position = "auto-right",
    scale    = 1.30,
})

-- Fallback for other displays or standalone laptop
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1.20,
})
