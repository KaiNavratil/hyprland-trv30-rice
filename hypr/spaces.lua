-- ══════════════════════════════════════════════════════════════════════════════
--  TOKYO 80s TRV30 — NATIVE DUAL-MONITOR DESKTOP SPACE ENGINE
--  東京 80's デジタル // ネイティブ双頭空間同期エンジン
-- ══════════════════════════════════════════════════════════════════════════════
local M = {}

local HOME = os.getenv("HOME") or "/home/kaijnav"
local SESSION_FILE = HOME .. "/.config/hypr/session.json"
local WORKSPACES_FILE = HOME .. "/.cache/window_workspaces.json"

local is_syncing = false
M._ws_map = nil
M._routed = {}
M._newly_opened = {}

local GENERIC_TITLES = {
    ["vivaldi - vivaldi"] = true,
    ["vivaldi"] = true,
    ["settings - vivaldi"] = true,
    ["start page - vivaldi"] = true,
    ["new tab - vivaldi"] = true,
    ["new tab"] = true,
    ["kitty"] = true,
    ["~"] = true,
    [""] = true,
}

local function is_generic_title(t)
    if not t or #t == 0 then return true end
    local clean = t:lower():match("^%s*(.-)%s*$")
    if not clean or #clean == 0 then return true end
    if GENERIC_TITLES[clean] then return true end
    if clean:find("^new tab") or clean == "vivaldi" then return true end
    return false
end

--- Loads window title-to-workspace mapping from cache
function M.load_workspaces_map()
    M._ws_map = {}
    local f = io.open(WORKSPACES_FILE, "r")
    if not f then return end
    local content = f:read("*a")
    f:close()
    for k, v in content:gmatch('"([^"]+)"%s*:%s*"([^"]+)"') do
        M._ws_map[k] = v
    end
end

--- Persists window title-to-workspace mapping atomically
function M.save_workspaces_map()
    if not M._ws_map then return end
    local entries = {}
    for k, v in pairs(M._ws_map) do
        table.insert(entries, string.format('  %q: %q', k, v))
    end
    table.sort(entries)
    local json_str = "{\n" .. table.concat(entries, ",\n") .. "\n}\n"
    local tmp = WORKSPACES_FILE .. ".tmp"
    local f = io.open(tmp, "w")
    if f then
        f:write(json_str)
        f:close()
        os.rename(tmp, WORKSPACES_FILE)
    end
end

--- Automatically routes a window to its saved workspace based on title memory
function M.route_window(win)
    if not win or not win.address then return end
    local addr = win.address

    -- Never re-route a window that was already routed in this session
    if M._routed[addr] then return end

    local title = win.title
    if is_generic_title(title) then return end

    local cur_ws = win.workspace and win.workspace.name
    if not cur_ws or cur_ws:find("^special:") then return end

    if not M._ws_map then M.load_workspaces_map() end

    local target_ws = M._ws_map[title]
    if not target_ws or target_ws:find("^special:") then return end

    if cur_ws ~= target_ws then
        M._routed[addr] = true
        hl.dispatch(hl.dsp.window.move({
            workspace = target_ws,
            window = "address:" .. addr,
            silent = true,
        }))
        M.sync_desktop_spaces()
    else
        M._routed[addr] = true
    end
end

--- Updates window workspace mapping in memory and on disk when a window moves
function M.track_window(win)
    if not win or not win.title or not win.workspace then return end
    local ws = win.workspace.name
    if not ws or ws:find("^special:") or not ws:match("^%d+$") then return end
    local title = win.title
    if is_generic_title(title) then return end

    if not M._ws_map then M.load_workspaces_map() end
    if M._ws_map[title] ~= ws then
        M._ws_map[title] = ws
        M.save_workspaces_map()
    end
end

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

    -- Sort monitors left-to-right by X position (HDMI-A-1 Left, eDP-1 Right)
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
            local sp_mod = package.loaded["scratchpads"]
            if sp_mod and sp_mod.remember_state then
                sp_mod.remember_state(sp_name)
            end
            hl.dispatch(hl.dsp.workspace.toggle_special(sp_name))
        else
            f:close()
        end
    end

    is_syncing = true

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
    is_syncing = false
end

--- Automatically enforces bilateral synchronization across dual monitors
function M.enforce_dual_monitor_sync(ws)
    if is_syncing then return end
    if not ws then return end

    local ws_name = ws.name and tostring(ws.name) or ""
    if not ws_name:match("^%d+$") then return end

    local num = tonumber(ws_name)
    if not num then return end

    local space_num = ((num - 1) % 10) + 1
    if space_num < 1 or space_num > 9 then return end

    local mons = hl.get_monitors() or {}
    if #mons <= 1 then
        M.sync_desktop_spaces()
        return
    end

    -- Sort monitors left-to-right by X position (HDMI-A-1 Left, eDP-1 Right)
    table.sort(mons, function(a, b) return (a.x or 0) < (b.x or 0) end)
    local main_mon = mons[1] -- Left: HDMI-A-1 (Spaces 1-9)
    local comp_mon = mons[2] -- Right: eDP-1 (Spaces 11-19)

    local target_main = tostring(space_num)
    local target_comp = tostring(space_num + 10)

    local cur_main = main_mon.active_workspace and tostring(main_mon.active_workspace.name) or ""
    local cur_comp = comp_mon.active_workspace and tostring(comp_mon.active_workspace.name) or ""

    if cur_main ~= target_main or cur_comp ~= target_comp then
        is_syncing = true

        local focused_mon = hl.get_active_monitor()
        local focused_name = focused_mon and focused_mon.name or main_mon.name

        -- Sync non-focused monitor first
        for idx, m in ipairs(mons) do
            if m.name ~= focused_name then
                local t = (idx == 1) and target_main or target_comp
                local cur = (idx == 1) and cur_main or cur_comp
                if cur ~= t then
                    hl.dispatch(hl.dsp.focus({ monitor = m.name }))
                    hl.dispatch(hl.dsp.focus({ workspace = t }))
                end
            end
        end

        -- Sync focused monitor last (preserving focus)
        for idx, m in ipairs(mons) do
            if m.name == focused_name then
                local t = (idx == 1) and target_main or target_comp
                local cur = (idx == 1) and cur_main or cur_comp
                if cur ~= t then
                    hl.dispatch(hl.dsp.focus({ monitor = m.name }))
                    hl.dispatch(hl.dsp.focus({ workspace = t }))
                end
                break
            end
        end

        M.sync_desktop_spaces()
        is_syncing = false
    else
        M.sync_desktop_spaces()
    end
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

--- Swaps all windows between current Desktop Space and the one to its left/right
function M.swap_workspace(dir)
    local ws = hl.get_active_workspace()
    if not ws then return end

    local cur_num = tonumber(ws.name)
    if not cur_num then return end

    local cur_space = ((cur_num - 1) % 10) + 1
    local target_space
    if dir == "left" then
        target_space = cur_space - 1
        if target_space < 1 then target_space = 9 end
    else
        target_space = cur_space + 1
        if target_space > 9 then target_space = 1 end
    end

    local mons = hl.get_monitors() or {}
    local temp_ws = "99"

    -- Swap on Left / Main Monitor (HDMI-A-1)
    local cur_wins_1 = hl.get_workspace_windows(cur_space) or {}
    local tgt_wins_1 = hl.get_workspace_windows(target_space) or {}
    for _, w in ipairs(tgt_wins_1) do
        hl.dispatch(hl.dsp.window.move({ workspace = temp_ws, window = "address:" .. w.address, silent = true }))
    end
    for _, w in ipairs(cur_wins_1) do
        hl.dispatch(hl.dsp.window.move({ workspace = tostring(target_space), window = "address:" .. w.address, silent = true }))
    end
    for _, w in ipairs(tgt_wins_1) do
        hl.dispatch(hl.dsp.window.move({ workspace = tostring(cur_space), window = "address:" .. w.address, silent = true }))
    end

    -- If dual monitors, swap synchronously on Right / Companion Monitor (eDP-1)
    if #mons > 1 then
        local cur_comp = cur_space + 10
        local tgt_comp = target_space + 10
        local cur_wins_2 = hl.get_workspace_windows(cur_comp) or {}
        local tgt_wins_2 = hl.get_workspace_windows(tgt_comp) or {}
        for _, w in ipairs(tgt_wins_2) do
            hl.dispatch(hl.dsp.window.move({ workspace = temp_ws, window = "address:" .. w.address, silent = true }))
        end
        for _, w in ipairs(cur_wins_2) do
            hl.dispatch(hl.dsp.window.move({ workspace = tostring(tgt_comp), window = "address:" .. w.address, silent = true }))
        end
        for _, w in ipairs(tgt_wins_2) do
            hl.dispatch(hl.dsp.window.move({ workspace = tostring(cur_comp), window = "address:" .. w.address, silent = true }))
        end
    end

    M.switch_desktop_space(target_space)
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
            M.track_window(c)
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
    M.load_workspaces_map()

    -- Initial scan of clients on startup
    for _, c in ipairs(hl.get_windows() or {}) do
        M.route_window(c)
        M.track_window(c)
    end

    -- Periodic in-memory space persistence & auto-healing (every 4 seconds)
    hl.timer(function()
        M.sync_desktop_spaces()
        M.save_session()

        -- Auto-heal any bilateral desync across dual monitors
        local mons = hl.get_monitors() or {}
        if #mons > 1 and not is_syncing then
            table.sort(mons, function(a, b) return (a.x or 0) < (b.x or 0) end)
            local m1_ws = mons[1].active_workspace and tonumber(mons[1].active_workspace.name)
            local m2_ws = mons[2].active_workspace and tonumber(mons[2].active_workspace.name)
            if m1_ws and m2_ws then
                local sp1 = ((m1_ws - 1) % 10) + 1
                local sp2 = ((m2_ws - 1) % 10) + 1
                if sp1 ~= sp2 then
                    local focused = hl.get_active_monitor()
                    local heal_space = (focused and focused.name == mons[2].name) and sp2 or sp1
                    M.switch_desktop_space(heal_space)
                end
            end
        end
    end, { timeout = 4000, type = "repeat" })

    -- Enforce automatic bilateral sync on ANY workspace activation
    hl.on("workspace.active", function(ws)
        M.enforce_dual_monitor_sync(ws)
    end)

    -- Automatic window routing & title learning hooks
    hl.on("window.open", function(win)
        if win and win.address then
            M._newly_opened[win.address] = os.time()
            M.route_window(win)
        end
        M.sync_desktop_spaces()
    end)

    hl.on("window.title", function(win)
        if win and win.address then
            if not M._routed[win.address] then
                M.route_window(win)
            else
                M.track_window(win)
            end
        end
    end)

    hl.on("window.move_to_workspace", function(win, ws)
        if win and ws then
            M._routed[win.address] = true
            local fake_win = { title = win.title, workspace = ws }
            M.track_window(fake_win)
        end
        M.sync_desktop_spaces()
    end)

    hl.on("window.close", function(win)
        if win and win.address then
            M._routed[win.address] = nil
            M._newly_opened[win.address] = nil
        end
        M.sync_desktop_spaces()
    end)

    hl.on("monitor.layout_changed", function()
        M.sync_desktop_spaces()
    end)
end

return M
