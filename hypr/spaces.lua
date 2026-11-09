-- ══════════════════════════════════════════════════════════════════════════════
--  TOKYO 80s TRV30 — NATIVE DUAL-MONITOR DESKTOP SPACE ENGINE
--  東京 80's デジタル // ネイティブ双頭空間同期エンジン
-- ══════════════════════════════════════════════════════════════════════════════
local M = {}

local HOME = os.getenv("HOME") or "/home/kaijnav"
local SESSION_FILE = HOME .. "/.config/hypr/session.json"
local WORKSPACES_FILE = HOME .. "/.cache/window_workspaces.json"

local GENERIC_TITLES = {
    ["vivaldi - vivaldi"] = true,
    ["vivaldi"] = true,
    ["settings - vivaldi"] = true,
    ["start page - vivaldi"] = true,
    ["new tab - vivaldi"] = true,
    ["new tab"] = true,
}

--- Synchronizes persistent workspaces so empty spaces vanish from Waybar with 0 latency
function M.sync_desktop_spaces()
    local occupied = {}
    local clients = hl.get_windows() or {}
    for _, c in ipairs(clients) do
        local ws = c.workspace and c.workspace.name
        if ws and ws:match("^%d+$") then
            local num = tonumber(ws)
            local space = ((num - 1) % 10) + 1
            if space >= 1 and space <= 9 then
                occupied[space] = true
            end
        end
    end

    local mons = hl.get_monitors() or {}
    for _, m in ipairs(mons) do
        local aws = m.active_workspace and m.active_workspace.name
        if aws and aws:match("^%d+$") then
            local num = tonumber(aws)
            local space = ((num - 1) % 10) + 1
            if space >= 1 and space <= 9 then
                occupied[space] = true
            end
        end
    end

    for s = 1, 9 do
        local is_occ = occupied[s] == true
        hl.workspace_rule({ workspace = s, persistent = is_occ })
        if #mons > 1 then
            hl.workspace_rule({ workspace = s + 10, persistent = is_occ })
        end
    end
end

--- Synchronously switches Desktop Spaces across both monitors in native C++/Lua memory
function M.switch_desktop_space(space_num)
    local mons = hl.get_monitors() or {}
    if #mons == 0 then return end

    -- Sort monitors left-to-right by X position
    table.sort(mons, function(a, b) return (a.x or 0) < (b.x or 0) end)

    local focused_mon = hl.get_active_monitor()
    local focused_name = focused_mon and focused_mon.name or mons[1].name

    -- Stow any unanchored scratchpad currently open on the focused monitor
    local sp = hl.get_active_special_workspace()
    if sp and sp.name and sp.name:find("^special:") then
        local sp_name = sp.name:gsub("^special:", "")
        local anchor_file = "/tmp/scratchpad_anchored_" .. sp_name
        local f = io.open(anchor_file, "r")
        if not f then
            hl.dispatch(hl.dsp.workspace.toggle_special(sp_name))
        else
            f:close()
        end
    end

    -- Switch non-focused monitors first, focused monitor last (retaining input focus)
    for idx, m in ipairs(mons) do
        if m.name ~= focused_name then
            local target_ws = tostring(space_num + (idx - 1) * 10)
            hl.dispatch(hl.dsp.focus({ monitor = m.name }))
            hl.dispatch(hl.dsp.focus({ workspace = target_ws }))
        end
    end

    -- Switch focused monitor
    for idx, m in ipairs(mons) do
        if m.name == focused_name then
            local target_ws = tostring(space_num + (idx - 1) * 10)
            hl.dispatch(hl.dsp.focus({ monitor = m.name }))
            hl.dispatch(hl.dsp.focus({ workspace = target_ws }))
            break
        end
    end

    M.sync_desktop_spaces()
end

--- Moves active window to the correct Desktop Space (1-9 HDMI, 11-19 eDP)
function M.move_window_to_space(space_num)
    local win = hl.get_active_window()
    if not win then return end

    local mons = hl.get_monitors() or {}
    local is_edp = win.monitor and win.monitor.name and win.monitor.name:find("^eDP")
    local dest = tostring((#mons > 1 and is_edp) and (space_num + 10) or space_num)
    hl.dispatch(hl.dsp.window.move({ workspace = dest, window = "address:" .. win.address }))
    M.sync_desktop_spaces()
end

--- Swaps all windows between current workspace and the one to its left/right
function M.swap_workspace(dir)
    local ws = hl.get_active_workspace()
    if not ws then return end

    local cur_id = ws.id
    local target_id
    if dir == "left" then
        target_id = cur_id - 1
        if target_id < 1 then target_id = 9 end
    else
        target_id = cur_id + 1
        if target_id > 9 then target_id = 1 end
    end

    local cur_wins = hl.get_workspace_windows(cur_id) or {}
    local tgt_wins = hl.get_workspace_windows(target_id) or {}
    local temp_ws = "99"

    for _, w in ipairs(tgt_wins) do
        hl.dispatch(hl.dsp.window.move({ workspace = temp_ws, window = "address:" .. w.address, silent = true }))
    end
    for _, w in ipairs(cur_wins) do
        hl.dispatch(hl.dsp.window.move({ workspace = tostring(target_id), window = "address:" .. w.address, silent = true }))
    end
    for _, w in ipairs(tgt_wins) do
        hl.dispatch(hl.dsp.window.move({ workspace = tostring(cur_id), window = "address:" .. w.address, silent = true }))
    end

    hl.dispatch(hl.dsp.focus({ workspace = tostring(target_id) }))
    M.sync_desktop_spaces()
end

--- Persists current windows & workspaces atomically to session.json without subprocesses
function M.save_session()
    local clients = hl.get_windows() or {}
    local session_state = {}

    for _, c in ipairs(clients) do
        local ws = c.workspace and c.workspace.name
        if ws and not ws:find("^special:") then
            table.insert(session_state, string.format(
                '  {"class": %q, "title": %q, "workspace": %q, "monitor": %d}',
                c.class or "", c.title or "", ws, c.monitor and c.monitor.id or 0
            ))
        end
    end

    local json_str = "[\n" .. table.concat(session_state, ",\n") .. "\n]\n"
    local tmp_file = SESSION_FILE .. ".tmp"
    local f = io.open(tmp_file, "w")
    if f then
        f:write(json_str)
        f:close()
        os.rename(tmp_file, SESSION_FILE)
    end
end

--- Sets up native event hooks and timers
function M.setup()
    -- Periodic in-memory space persistence & session state saving (every 4 seconds)
    hl.timer(function()
        M.sync_desktop_spaces()
        M.save_session()
    end, { timeout = 4000, type = "repeat" })

    -- Synchronize spaces on window/workspace events
    hl.on("workspace.active", function()
        M.sync_desktop_spaces()
    end)
    hl.on("window.close", function()
        M.sync_desktop_spaces()
    end)
    hl.on("monitor.layout_changed", function()
        M.sync_desktop_spaces()
    end)
end

return M
