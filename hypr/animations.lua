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
    -- Kinetic harmonic oscillator springs
    hl.curve("trvSpring", { type = "spring", mass = 0.9, stiffness = 240, damping = 24 })
    hl.curve("trvDeckSpring", { type = "spring", mass = 1.1, stiffness = 200, damping = 21 })
    hl.curve("trvSnapSpring", { type = "spring", mass = 1.0, stiffness = 320, damping = 30 })

    -- Tokyo 80s CRT & analog beziers
    hl.curve("trvSmooth", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })
    hl.curve("trvSnap", { type = "bezier", points = { {0.16, 1.0}, {0.3, 1.0} } })
    hl.curve("trvEaseOut", { type = "bezier", points = { {0.22, 1.0}, {0.36, 1.0} } })
    hl.curve("trvBeamCollapse", { type = "bezier", points = { {0.4, 0.0}, {0.2, 1.0} } })
    hl.curve("trvAnalogBlink", { type = "bezier", points = { {0.0, 0.0}, {0.58, 1.0} } })
    hl.curve("trvLinear", { type = "bezier", points = { {0.0, 0.0}, {1.0, 1.0} } })

    -- ┌─────────────────────────────────────────────────────────┐
    -- │ 2. ANIMATION LEAVES                                     │
    -- └─────────────────────────────────────────────────────────┘
    -- Windows: Responsive physical spring pop-in & CRT beam collapse close
    hl.animation({ leaf = "windows", enabled = true, speed = 3.4, spring = "trvSpring" })
    hl.animation({ leaf = "windowsIn", enabled = true, speed = 3.2, spring = "trvSpring", style = "popin 85%" })
    hl.animation({ leaf = "windowsOut", enabled = true, speed = 2.4, bezier = "trvBeamCollapse", style = "popin 88%" })
    hl.animation({ leaf = "windowsMove", enabled = true, speed = 3.2, spring = "trvSpring" })

    -- Fade: Phosphor persistence & focus cross-fades
    hl.animation({ leaf = "fade", enabled = true, speed = 2.4, bezier = "trvAnalogBlink" })
    hl.animation({ leaf = "fadeIn", enabled = true, speed = 2.0, bezier = "trvAnalogBlink" })
    hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.8, bezier = "trvLinear" })
    hl.animation({ leaf = "fadeSwitch", enabled = true, speed = 2.6, bezier = "trvSnap" })
    hl.animation({ leaf = "fadeDim", enabled = true, speed = 2.8, bezier = "trvSnap" })

    -- Workspaces: Buttery dual-monitor horizontal slide across 1-9 & 11-19
    hl.animation({ leaf = "workspaces", enabled = true, speed = 3.4, bezier = "trvSmooth", style = "slidefade 78%" })

    -- Special Workspaces (Modal Scratchpads): Cassette deck tray slide with heavy spring inertia
    hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3.4, bezier = "trvSmooth", style = "slidefadevert 82%" })
    hl.animation({ leaf = "specialWorkspaceIn", enabled = true, speed = 3.6, spring = "trvDeckSpring", style = "slidefadevert 82%" })
    hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 2.6, bezier = "trvBeamCollapse", style = "slidefadevert 82%" })

    -- Borders (Subtle, stationary snap)
    hl.animation({ leaf = "border", enabled = true, speed = 2.8, bezier = "trvSnap" })

    -- Layers (Waybar / Dunst / Rofi)
    hl.animation({ leaf = "layers", enabled = true, speed = 3.0, bezier = "trvEaseOut" })
    hl.animation({ leaf = "layersIn", enabled = true, speed = 2.6, bezier = "trvSnap", style = "fade" })
    hl.animation({ leaf = "layersOut", enabled = true, speed = 1.8, bezier = "trvLinear", style = "fade" })
end

return M
