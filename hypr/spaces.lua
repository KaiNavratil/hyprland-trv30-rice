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
M._companion_windows = {}
M._last_mon_count = nil

local EXCLUDED_CLASSES = {
    ["blueman-manager"] = true,
    ["blueman-services"] = true,
    ["blueman-sendto"] = true,
    ["pavucontrol"] = true,
    ["org.pulseaudio.pavucontrol"] = true,
    ["nm-connection-editor"] = true,
    ["nm-applet"] = true,
    ["copyq"] = true,
    ["com.github.hluk.copyq"] = true,
    ["dunst"] = true,
    ["rofi"] = true,
    ["polkit-gnome-authentication-agent-1"] = true,
    ["org.gnome.Polkit"] = true,
    ["pinentry-gtk-2"] = true,
    ["pinentry-gnome3"] = true,
    ["pinentry-qt"] = true,
    ["pinentry"] = true,
    ["xdg-desktop-portal-gtk"] = true,
    ["xdg-desktop-portal-hyprland"] = true,
    ["hyprland-share-picker"] = true,
    ["file-roller"] = true,
    ["org.kde.polkit-kde-authentication-agent-1"] = true,
    ["com.tokyo.radar"] = true,
    ["com.tokyo.commandcenter"] = true,
    ["com.tokyo.displaydeck"] = true,
    ["crt-blink"] = true,
}

local function is_utility_window(win)
    if not win then return true end
    if win.floating == true then return true end
    local cls = win.class and win.class:lower() or ""
    if EXCLUDED_CLASSES[cls] then return true end
    if cls:find("^blueman") or cls:find("^pavucontrol") or cls:find("^nm%-")
       or cls:find("^polkit") or cls:find("^pinentry") or cls:find("^xdg%-desktop%-portal") then
        return true
    end
    return false
end

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
    ["bluetooth devices"] = true,
    ["open file"] = true,
    ["open files"] = true,
    ["save file"] = true,
    ["save as"] = true,
    ["choose file"] = true,
    ["choose files"] = true,
    ["select a file"] = true,
    ["select a folder"] = true,
    ["unlock login keyring"] = true,
    ["volume control"] = true,
    ["network connections"] = true,
    ["file operation progress"] = true,
    ["confirm to replace files"] = true,
    ["authentication required"] = true,
}

local function clean_title_key(t)
    if not t or type(t) ~= "string" then return nil end
    local s = t:gsub("^%([%d%+]+%)%s*", ""):gsub("\\+", ""):gsub('"', ""):gsub("[%c]", " "):match("^%s*(.-)%s*$")
    if not s or #s == 0 or #s > 120 then return nil end
    return s
end

local function is_generic_title(t)
    local clean = clean_title_key(t)
    if not clean or #clean == 0 then return true end
    local lower = clean:lower()
    if GENERIC_TITLES[lower] then return true end
    if lower:find("^new tab") or lower == "vivaldi" then return true end
    if lower:find("^open file") or lower:find("^save file") or lower:find("^select ") or lower:find("^choose ") then return true end
    return false
end

--- Loads window title-to-workspace mapping from cache
function M.load_workspaces_map()
    M._ws_map = {}
    local f = io.open(WORKSPACES_FILE, "r")
    if not f then return end
    local content = f:read("*a")
    f:close()
    if not content or #content > 500000 then return end

    for k, v in content:gmatch('"([^"\r\n]+)"%s*:%s*"([^"\r\n]+)"') do
        local clean_k = clean_title_key(k)
        local clean_v = v:match("^%d+$") or (v == "special:magic" and "special:magic" or nil)
        if clean_k and clean_v and not is_generic_title(clean_k) then
            M._ws_map[clean_k] = clean_v
        end
    end
end

--- Persists window title-to-workspace mapping atomically
function M.save_workspaces_map()
    if not M._ws_map then return end
    local entries = {}
    for k, v in pairs(M._ws_map) do
        local clean_k = clean_title_key(k)
        local clean_v = tostring(v):match("^%d+$") or (tostring(v) == "special:magic" and "special:magic" or nil)
        if clean_k and clean_v and not is_generic_title(clean_k) then
            table.insert(entries, string.format('  "%s": "%s"', clean_k, clean_v))
        end
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
    if is_utility_window(win) then return end
    local addr = win.address

    -- Never re-route a window that was already routed in this session
    if M._routed[addr] then return end

    local cur_ws = win.workspace and win.workspace.name
    -- If window is currently in ANY special workspace (including special:magic), DO NOT route it away!
    if cur_ws and cur_ws:find("^special:") then
        M._routed[addr] = true
        return
    end

    -- If special:magic is currently active on the focused monitor and a newly opened window/tab appears,
    -- adopt it into special:magic
    local active_sp = hl.get_active_special_workspace()
    if active_sp and active_sp.name == "special:magic" then
        M._routed[addr] = true
        hl.dispatch(hl.dsp.window.move({
            workspace = "special:magic",
            window = "address:" .. addr,
            silent = true,
        }))
        local fake_win = { title = win.title, workspace = "special:magic", class = win.class, floating = win.floating }
        M.track_window(fake_win)
        return
    end

    local title = clean_title_key(win.title)
    if not title or is_generic_title(title) then return end

    if not M._ws_map then M.load_workspaces_map() end

    local target_ws = M._ws_map[title]
    if not target_ws then return end

    local mons = hl.get_monitors() or {}
    local tgt_num = tonumber(target_ws)
    if #mons <= 1 and tgt_num and tgt_num >= 11 and tgt_num <= 19 then
        target_ws = tostring(tgt_num - 10)
    end

    if target_ws ~= "special:magic" and (target_ws:find("^special:") or not target_ws:match("^%d+$")) then return end

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
    if is_utility_window(win) then return end
    local ws = type(win.workspace) == "table" and win.workspace.name or (win.workspace.name or tostring(win.workspace))
    if not ws then return end

    local mons = hl.get_monitors() or {}
    local num = tonumber(ws)
    if #mons <= 1 and num and num >= 11 and num <= 19 then
        ws = tostring(num - 10)
    end

    -- Allow normal numbered workspaces and special:magic
    if ws ~= "special:magic" and (ws:find("^special:") or not ws:match("^%d+$")) then return end
    local title = clean_title_key(win.title)
    if not title or is_generic_title(title) then return end

    if not M._ws_map then M.load_workspaces_map() end
    if M._ws_map[title] ~= ws then
        M._ws_map[title] = ws
        M.save_workspaces_map()
    end
end

--- Updates ~/.config/hypr/workspaces.conf and applies live workspace rules dynamically
function M.apply_workspace_rules()
    local mons = hl.get_monitors() or {}
    if #mons == 0 then return end

    local conf_lines = {
        "# ══════════════════════════════════════════════════════════════════════════════",
        "#  TOKYO 80s TRV30 — DYNAMIC WORKSPACE CONFIGURATION",
        "#  Automatically regenerated on monitor connect / disconnect / layout changes",
        "# ══════════════════════════════════════════════════════════════════════════════",
        ""
    }

    if #mons == 1 then
        local primary = mons[1].name
        table.insert(conf_lines, "# Single Monitor Mode: " .. primary .. " -> Spaces 1-9")
        for s = 1, 9 do
            local def_str = (s == 1) and ", default:true" or ""
            table.insert(conf_lines, string.format("workspace = %d, monitor:%s%s", s, primary, def_str))
            hl.workspace_rule({
                workspace = s,
                monitor = primary,
                default = (s == 1),
            })
            hl.workspace_rule({
                workspace = s + 10,
                persistent = false,
                monitor = "",
            })
        end
    else
        table.sort(mons, function(a, b) return (a.x or 0) < (b.x or 0) end)
        local main_mon = mons[1].name
        local comp_mon = mons[2].name

        table.insert(conf_lines, "# Main Monitor (Left): " .. main_mon .. " -> Spaces 1-9")
        for s = 1, 9 do
            local def_str = (s == 1) and ", default:true" or ""
            table.insert(conf_lines, string.format("workspace = %d, monitor:%s%s", s, main_mon, def_str))
            hl.workspace_rule({
                workspace = s,
                monitor = main_mon,
                default = (s == 1),
            })
        end

        table.insert(conf_lines, "")
        table.insert(conf_lines, "# Companion Monitor (Right): " .. comp_mon .. " -> Companion Spaces 11-19")
        for s = 1, 9 do
            local ws = s + 10
            local def_str = (s == 1) and ", default:true" or ""
            table.insert(conf_lines, string.format("workspace = %d, monitor:%s%s", ws, comp_mon, def_str))
            hl.workspace_rule({
                workspace = ws,
                monitor = comp_mon,
                default = (s == 1),
            })
        end
    end

    local conf_path = HOME .. "/.config/hypr/workspaces.conf"
    local tmp_path = conf_path .. ".tmp"
    local f = io.open(tmp_path, "w")
    if f then
        f:write(table.concat(conf_lines, "\n") .. "\n")
        f:close()
        os.rename(tmp_path, conf_path)
    end
end

--- Handles transitions between 1 monitor and 2 monitors (hotplug / disconnect / layout change)
function M.handle_monitor_topology_change()
    local mons = hl.get_monitors() or {}
    local mon_count = #mons
    if mon_count == 0 then return end

    local prev_count = M._last_mon_count
    M._last_mon_count = mon_count

    M.apply_workspace_rules()

    if mon_count <= 1 then
        -- TRANSITIONING TO 1 DISPLAY:
        -- Merge any windows on companion workspaces 11..19 into main spaces 1..9
        local clients = hl.get_windows() or {}
        for _, c in ipairs(clients) do
            local ws_name = c.workspace and c.workspace.name
            if ws_name and ws_name:match("^%d+$") then
                local num = tonumber(ws_name)
                if num >= 11 and num <= 19 then
                    local target_space = num - 10
                    M._companion_windows[c.address] = target_space
                    hl.dispatch(hl.dsp.window.move({
                        workspace = tostring(target_space),
                        window = "address:" .. c.address,
                        silent = true,
                    }))
                end
            end
        end

        -- Ensure companion workspaces 11..19 are evicted and destroyed
        for s = 1, 9 do
            hl.workspace_rule({ workspace = s + 10, persistent = false })
        end

        -- If current active workspace on the single monitor is in 11..19, switch to 1..9
        local cur_act = mons[1].active_workspace and mons[1].active_workspace.name
        if cur_act and cur_act:match("^%d+$") then
            local act_num = tonumber(cur_act)
            if act_num >= 11 and act_num <= 19 then
                local space = act_num - 10
                hl.dispatch(hl.dsp.focus({ workspace = tostring(space) }))
            end
        end

        M.sync_desktop_spaces()
        os.execute("pkill -SIGUSR2 waybar &")

    elseif mon_count >= 2 and prev_count and prev_count < 2 then
        -- TRANSITIONING BACK TO 2 DISPLAYS:
        -- Restore companion windows that were temporarily merged into 1..9
        local clients = hl.get_windows() or {}
        for _, c in ipairs(clients) do
            local orig_space = M._companion_windows[c.address]
            if orig_space and orig_space >= 1 and orig_space <= 9 then
                local target_ws = tostring(orig_space + 10)
                hl.dispatch(hl.dsp.window.move({
                    workspace = target_ws,
                    window = "address:" .. c.address,
                    silent = true,
                }))
                M._companion_windows[c.address] = nil
            end
        end

        -- Sync active workspaces across both screens
        table.sort(mons, function(a, b) return (a.x or 0) < (b.x or 0) end)
        local m1_ws = mons[1].active_workspace and tonumber(mons[1].active_workspace.name)
        if m1_ws and m1_ws >= 1 and m1_ws <= 9 then
            pcall(function()
                hl.dispatch(hl.dsp.focus({ monitor = mons[2].name }))
                hl.dispatch(hl.dsp.focus({ workspace = tostring(m1_ws + 10) }))
                hl.dispatch(hl.dsp.focus({ monitor = mons[1].name }))
            end)
        end

        M.sync_desktop_spaces()
        os.execute("pkill -SIGUSR2 waybar &")
    else
        M.sync_desktop_spaces()
    end
end

--- Synchronizes persistent workspaces so empty spaces vanish from Waybar with 0 latency
function M.sync_desktop_spaces()
    local occupied = {}
    local clients = hl.get_windows() or {}
    for _, c in ipairs(clients) do
        local ws = c.workspace and c.workspace.name
        if ws and ws:match("^%d+$") and not is_utility_window(c) then
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
        else
            hl.workspace_rule({ workspace = s + 10, persistent = false })
        end
    end
end

--- Synchronously switches Desktop Spaces across both monitors in native C++/Lua memory
function M.switch_desktop_space(space_num)
    local mons = hl.get_monitors() or {}
    if #mons == 0 then return end

    -- Verify all monitors are initialized before attempting switch
    for _, m in ipairs(mons) do
        if not m or not m.name or not m.active_workspace then return end
    end

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
            pcall(function() hl.dispatch(hl.dsp.workspace.toggle_special(sp_name)) end)
        else
            f:close()
        end
    end

    is_syncing = true
    M._last_switch_time = os.time()

    if #mons <= 1 then
        local target_ws = tostring(space_num)
        pcall(function()
            hl.dispatch(hl.dsp.focus({ workspace = target_ws }))
        end)
        M.sync_desktop_spaces()
        hl.timer(function()
            is_syncing = false
        end, { timeout = 350, type = "oneshot" })
        return
    end

    -- Switch non-focused monitors first, focused monitor last (retaining input focus)
    for idx, m in ipairs(mons) do
        if m.name ~= focused_name then
            local target_ws = tostring(space_num + (idx - 1) * 10)
            pcall(function()
                hl.dispatch(hl.dsp.focus({ monitor = m.name }))
                hl.dispatch(hl.dsp.focus({ workspace = target_ws }))
            end)
        end
    end

    -- Switch focused monitor
    for idx, m in ipairs(mons) do
        if m.name == focused_name then
            local target_ws = tostring(space_num + (idx - 1) * 10)
            pcall(function()
                hl.dispatch(hl.dsp.focus({ monitor = m.name }))
                hl.dispatch(hl.dsp.focus({ workspace = target_ws }))
            end)
            break
        end
    end

    M.sync_desktop_spaces()
    hl.timer(function()
        is_syncing = false
    end, { timeout = 350, type = "oneshot" })
end

--- Automatically enforces bilateral synchronization across dual monitors
function M.enforce_dual_monitor_sync(ws)
    if is_syncing then return end
    if os.time() - (M._last_switch_time or 0) < 1 then return end
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

    -- Safety check: ensure all monitors have valid, initialized active workspaces
    for _, m in ipairs(mons) do
        if not m or not m.name or not m.active_workspace or not m.active_workspace.name then
            return
        end
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
                    pcall(function()
                        hl.dispatch(hl.dsp.focus({ monitor = m.name }))
                        hl.dispatch(hl.dsp.focus({ workspace = t }))
                    end)
                end
            end
        end

        -- Sync focused monitor last (preserving focus)
        for idx, m in ipairs(mons) do
            if m.name == focused_name then
                local t = (idx == 1) and target_main or target_comp
                local cur = (idx == 1) and cur_main or cur_comp
                if cur ~= t then
                    pcall(function()
                        hl.dispatch(hl.dsp.focus({ monitor = m.name }))
                        hl.dispatch(hl.dsp.focus({ workspace = t }))
                    end)
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
        if ws and (ws == "special:magic" or not ws:find("^special:")) and not is_utility_window(c) then
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
    M.handle_monitor_topology_change()

    -- Initial scan of clients on startup
    for _, c in ipairs(hl.get_windows() or {}) do
        if not is_utility_window(c) then
            M.route_window(c)
            M.track_window(c)
        end
    end

    -- Periodic in-memory space persistence & auto-healing (every 4 seconds)
    hl.timer(function()
        pcall(function()
            local mons = hl.get_monitors() or {}
            if M._last_mon_count and #mons ~= M._last_mon_count then
                M.handle_monitor_topology_change()
            else
                M.sync_desktop_spaces()
            end
            M.save_session()

            -- Auto-heal any bilateral desync across dual monitors
            local now = os.time()
            if #mons > 1 and not is_syncing and (now - (M._last_switch_time or 0) >= 2) then
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
        end)
    end, { timeout = 4000, type = "repeat" })

    -- Enforce automatic bilateral sync on workspace activation (debounced to prevent hotplug races)
    local sync_timer = nil
    local pending_active_ws = nil
    hl.on("workspace.active", function(ws)
        if is_syncing then return end
        if os.time() - (M._last_switch_time or 0) < 1 then return end
        pending_active_ws = ws
        if sync_timer then return end
        sync_timer = hl.timer(function()
            sync_timer = nil
            if is_syncing then return end
            if os.time() - (M._last_switch_time or 0) < 1 then return end
            pcall(function()
                local cur_ws = pending_active_ws or hl.get_active_workspace()
                M.enforce_dual_monitor_sync(cur_ws)
            end)
        end, { timeout = 250, type = "oneshot" })
    end)

    -- Automatic window routing & title learning hooks
    hl.on("window.open", function(win)
        pcall(function()
            if win and win.address and not is_utility_window(win) then
                M._newly_opened[win.address] = os.time()
                M.route_window(win)
            end
            M.sync_desktop_spaces()
        end)
    end)

    hl.on("window.title", function(win)
        pcall(function()
            if win and win.address and not is_utility_window(win) then
                if not M._routed[win.address] then
                    M.route_window(win)
                end
                -- Continuously track workspace location when title updates
                local cur_ws = win.workspace and win.workspace.name
                if cur_ws and (cur_ws == "special:magic" or cur_ws:match("^%d+$")) then
                    local fake_win = { title = win.title, workspace = cur_ws, class = win.class, floating = win.floating }
                    M.track_window(fake_win)
                end
            end
        end)
    end)

    hl.on("window.move_to_workspace", function(win, ws)
        pcall(function()
            if win and ws then
                M._routed[win.address] = true
                if not is_utility_window(win) then
                    local fake_win = { title = win.title, workspace = ws, class = win.class, floating = win.floating }
                    M.track_window(fake_win)
                end
            end
            M.sync_desktop_spaces()
        end)
    end)

    hl.on("window.close", function(win)
        pcall(function()
            if win and win.address then
                M._routed[win.address] = nil
                M._newly_opened[win.address] = nil
            end
            M.sync_desktop_spaces()
        end)
    end)

    local function on_monitor_event()
        hl.timer(function()
            pcall(function()
                local monitors_mod = package.loaded["monitors"]
                if monitors_mod and monitors_mod.apply then
                    monitors_mod.apply()
                end
                M.handle_monitor_topology_change()
            end)
        end, { timeout = 250, type = "oneshot" })
    end

    hl.on("monitor.layout_changed", on_monitor_event)
    hl.on("monitor.added", on_monitor_event)
    hl.on("monitor.removed", on_monitor_event)
end

return M
