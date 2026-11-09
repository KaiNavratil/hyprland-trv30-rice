-- ══════════════════════════════════════════════════════════════════════════════
--  TOKYO 80s TRV30 — HYPRLAND 0.57+ NATIVE ANIMATION ENGINE
--  東京 80's デジタル // ネイティブ物理スプリング＆ベジエ・アニメーション
-- ══════════════════════════════════════════════════════════════════════════════
local M = {}

--- Registers native curves and applies the Tokyo 80s kinetic physics profile
function M.setup()
    -- ┌─────────────────────────────────────────────────────────┐
    -- │ 1. CURVES & SPRINGS (Hyprland 0.57+ Native Physics)     │
    -- └─────────────────────────────────────────────────────────┘
    -- True harmonic oscillator springs
    hl.curve("trvSpring", { type = "spring", mass = 1.0, stiffness = 220, damping = 23 })
    hl.curve("trvSnapSpring", { type = "spring", mass = 1.0, stiffness = 320, damping = 30 })

    -- Tokyo 80s smooth deceleration beziers
    hl.curve("trvSmooth", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })
    hl.curve("trvEaseOut", { type = "bezier", points = { {0.22, 1.0}, {0.36, 1.0} } })
    hl.curve("trvLinear", { type = "bezier", points = { {0.0, 0.0}, {1.0, 1.0} } })

    -- ┌─────────────────────────────────────────────────────────┐
    -- │ 2. ANIMATION LEAVES                                     │
    -- └─────────────────────────────────────────────────────────┘
    -- Windows: Responsive physical spring pop-in & smooth close
    hl.animation({ leaf = "windows", enabled = true, speed = 3.6, spring = "trvSpring" })
    hl.animation({ leaf = "windowsIn", enabled = true, speed = 3.2, spring = "trvSpring", style = "popin 85%" })
    hl.animation({ leaf = "windowsOut", enabled = true, speed = 2.0, bezier = "trvEaseOut", style = "popin 85%" })
    hl.animation({ leaf = "windowsMove", enabled = true, speed = 3.4, spring = "trvSpring" })

    -- Fade: Clean phosphor fade
    hl.animation({ leaf = "fade", enabled = true, speed = 2.4, bezier = "trvEaseOut" })
    hl.animation({ leaf = "fadeIn", enabled = true, speed = 2.0, bezier = "trvEaseOut" })
    hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.8, bezier = "trvLinear" })

    -- Workspaces: Buttery dual-monitor horizontal slide across 1-9 & 11-19
    hl.animation({ leaf = "workspaces", enabled = true, speed = 3.2, bezier = "trvSmooth", style = "slidefade 80%" })

    -- Special Workspaces (Modal Scratchpads): Smooth vertical deck tray slide
    hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3.2, bezier = "trvSmooth", style = "slidefadevert 80%" })

    -- Layers (Waybar / Dunst / Rofi)
    hl.animation({ leaf = "layers", enabled = true, speed = 3.0, bezier = "trvEaseOut" })
    hl.animation({ leaf = "layersIn", enabled = true, speed = 2.6, bezier = "trvEaseOut", style = "fade" })
    hl.animation({ leaf = "layersOut", enabled = true, speed = 1.8, bezier = "trvLinear", style = "fade" })
end

return M
