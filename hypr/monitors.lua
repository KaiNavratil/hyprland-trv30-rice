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
        hl.monitor("HDMI-A-1, preferred, 0x0, 1.00")
        hl.monitor("eDP-1, preferred, 1920x0, 1.30")
    elseif has_dp1 then
        hl.monitor("DP-1, preferred, 0x0, 1.00")
        hl.monitor("eDP-1, preferred, 1920x0, 1.30")
    elseif has_dp2 then
        hl.monitor("DP-2, preferred, 0x0, 1.00")
        hl.monitor("eDP-1, preferred, 1920x0, 1.30")
    else
        hl.monitor("eDP-1, preferred, 0x0, 1.30")
    end

    hl.monitor(", preferred, auto, 1.00")
end

M.apply()

return M
