-- ═══════════════════════════════════════════════════════════════════════════════
--  TOKYO 80s TRV30 — DYNAMIC MONITOR CONFIGURATION
--  東京 80s TRV30 // ディスプレイ構成設定
-- ═══════════════════════════════════════════════════════════════════════════════
local M = {}

local function is_output_connected(name)
    local f = io.open("/sys/class/drm/card1-" .. name .. "/status", "r")
    if not f then return false end
    local status = f:read("*l") or ""
    f:close()
    return status:match("^connected") ~= nil
end

function M.apply()
    local has_hdmi = is_output_connected("HDMI-A-1")
    local has_dp1 = is_output_connected("DP-1")
    local has_dp2 = is_output_connected("DP-2")

    if has_hdmi then
        hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "0x0", scale = 1.00 })
        hl.monitor({ output = "eDP-1", mode = "preferred", position = "1920x0", scale = 1.30 })
    elseif has_dp1 then
        hl.monitor({ output = "DP-1", mode = "preferred", position = "0x0", scale = 1.00 })
        hl.monitor({ output = "eDP-1", mode = "preferred", position = "1920x0", scale = 1.30 })
    elseif has_dp2 then
        hl.monitor({ output = "DP-2", mode = "preferred", position = "0x0", scale = 1.00 })
        hl.monitor({ output = "eDP-1", mode = "preferred", position = "1920x0", scale = 1.30 })
    else
        hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x0", scale = 1.30 })
    end

    hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1.00 })
end

M.apply()

return M
