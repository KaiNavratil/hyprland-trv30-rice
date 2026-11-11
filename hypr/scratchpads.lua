-- ══════════════════════════════════════════════════════════════════════════════
--  TOKYO 80s TRV30 — NATIVE SCRATCHPAD & HUD MULTI-DECK ENGINE
--  東京 80's デジタル // ネイティブ・スクラッチパッド＆マルチデッキ
-- ══════════════════════════════════════════════════════════════════════════════
local M = {}

local HOME = os.getenv("HOME") or "/home/kaijnav"

M._timers = {}
M._fullscreen_state = {}
M._last_focused = {}
local function set_timeout(fn, ms)
    local t
    t = hl.timer(function()
        pcall(fn)
        for i, val in ipairs(M._timers) do
            if val == t then
                table.remove(M._timers, i)
                break
            end
        end
    end, { timeout = ms, type = "oneshot" })
    table.insert(M._timers, t)
    return t
end

local SCRATCHPAD_CONFIG = {
    music = {
        name = "music",
        class_pattern = "spotify",
        cmd = "spotify-launcher --skip-update",
        gaps_out = 60,
        gaps_in = 0,
        no_border = false,
    },
    discord = {
        name = "discord",
        class_pattern = "vesktop|discord",
        cmd = "vesktop",
        gaps_out = 60,
        gaps_in = 0,
        no_border = false,
    },
    calendar = {
        name = "calendar",
        class_pattern = "vivaldi%-calendar|notion",
        cmd = "vivaldi-stable --app=https://calendar.notion.so",
        gaps_out = 60,
        gaps_in = 0,
        no_border = false,
    },
    notes = {
        name = "notes",
        class_pattern = "notes%-term|copyq|com%.github%.hluk%.copyq",
        cmd = HOME .. "/.config/hypr/scripts/launch-notes.sh",
        gaps_out = 60,
        gaps_in = 4,
        no_border = false,
    },
    dev = {
        name = "dev",
        class_pattern = "antigravity%-ide|antigravity|vivaldi%-localhost",
        cmd = "/opt/antigravity-ide/antigravity-ide",
        gaps_out = 0,
        gaps_in = 0,
        no_border = true,
    },
    magic = {
        name = "magic",
        class_pattern = ".*",
        cmd = nil,
        gaps_out = 0,
        gaps_in = 0,
        no_border = true,
    },
    center = {
        name = "center",
        class_pattern = "commandcenter|command%-center|com%.tokyo%.commandcenter",
        cmd = "env WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1 python3 " .. HOME .. "/.config/hypr/command-center/app.py",
        gaps_out = 0,
        gaps_in = 0,
        no_border = true,
    },
    radar = {
        name = "radar",
        class_pattern = "com%.tokyo%.radar|trv30%-radar|desktop%-radar|radar",
        cmd = "env WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1 python3 " .. HOME .. "/.config/hypr/desktop-radar/app.py",
        gaps_out = 0,
        gaps_in = 0,
        no_border = true,
    },
    display = {
        name = "display",
        class_pattern = "com%.tokyo%.displaydeck|displaydeck|display%-deck",
        cmd = "env WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1 python3 " .. HOME .. "/.config/hypr/display-deck/app.py",
        gaps_out = 0,
        gaps_in = 0,
        no_border = true,
    },
    bluetooth = {
        name = "bluetooth",
        class_pattern = "com%.tokyo%.bluetoothhq|bluetoothhq|bluetooth%-hq",
        cmd = "env WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1 python3 " .. HOME .. "/.config/hypr/bluetooth-hq/app.py",
        gaps_out = 0,
        gaps_in = 0,
        no_border = true,
    },
    antigravity = {
        name = "antigravity",
        class_pattern = "antigravity",
        cmd = "/home/kaijnav/.local/bin/antigravity",
        gaps_out = 0,
        gaps_in = 0,
        no_border = true,
    },
    cava = {
        name = "cava",
        class_pattern = "trv30%-cava|cava",
        cmd = "kitty --class trv30-cava cava",
        gaps_out = 60,
        gaps_in = 0,
        no_border = false,
    },
    sysmon = {
        name = "sysmon",
        class_pattern = "trv30%-btop|btop",
        cmd = "kitty --class trv30-btop btop",
        gaps_out = 60,
        gaps_in = 0,
        no_border = false,
    },
}

local PANORAMIC_DECKS = {
    music = {
        name = "MUSIC STUDIO // 音響機構",
        main = "music",
        comp = "cava",
    },
    comms = {
        name = "COMMS OPS // 通信作戦",
        main = "discord",
        comp = "calendar",
    },
    discord = {
        name = "COMMS OPS // 通信作戦",
        main = "discord",
        comp = "calendar",
    },
    research = {
        name = "RESEARCH DECK // 開発記録",
        main = "dev",
        comp = "notes",
    },
    notes = {
        name = "RESEARCH DECK // 開発記録",
        main = "dev",
        comp = "notes",
    },
    cockpit = {
        name = "COMMAND CENTER // 司令室",
        main = "center",
        comp = "sysmon",
    },
    center = {
        name = "COMMAND CENTER // 司令室",
        main = "center",
        comp = "sysmon",
    },
}

--- Check if an anchor file exists for this scratchpad
local function is_anchored(name)
    local f = io.open("/tmp/scratchpad_anchored_" .. name, "r")
    if f then
        f:close()
        return true
    end
    return false
end

--- Updates atomic state file for Waybar and external scripts (0 hyprctl overhead)
function M.update_active_scratchpad(override_name)
    local active_name = ""
    if type(override_name) == "string" then
        active_name = override_name
    else
        local ok, sp = pcall(hl.get_active_special_workspace)
        if ok and sp and sp.name and type(sp.name) == "string" and sp.name:find("^special:") then
            active_name = sp.name:gsub("^special:", "")
        end
    end

    local tmp = "/tmp/scratchpad_active.tmp"
    local f = io.open(tmp, "w")
    if f then
        f:write(active_name .. "\n")
        f:close()
        os.rename(tmp, "/tmp/scratchpad_active")
    end
end

--- Remembers fullscreen state and active window for a scratchpad before it is hidden
function M.remember_state(target)
    M._fullscreen_state = M._fullscreen_state or {}
    M._last_focused = M._last_focused or {}

    local target_special = "special:" .. target
    local fs_win = nil
    local fs_class = nil

    for _, w in ipairs(hl.get_windows() or {}) do
        if w.workspace and w.workspace.name == target_special then
            if w.fullscreen and w.fullscreen > 0 then
                fs_win = w.address
                fs_class = w.class
            end
        end
    end

    M._fullscreen_state[target] = { address = fs_win, class = fs_class }

    local cur_act = hl.get_active_window()
    if cur_act and cur_act.workspace and cur_act.workspace.name == target_special then
        M._last_focused[target] = { address = cur_act.address, class = cur_act.class }
    end
end

--- Native scratchpad toggler
function M.toggle(target, is_stack)
    local cur_mon = hl.get_active_monitor()
    if not cur_mon then return end

    local cfg = SCRATCHPAD_CONFIG[target] or {
        name = target,
        class_pattern = target,
        gaps_out = 60,
        gaps_in = 0,
        no_border = false,
    }

    local target_special = "special:" .. target
    local cur_sp = hl.get_active_special_workspace()

    -- Check if target is already open on THIS monitor or ANY monitor
    local is_open_on_mon = nil
    if cur_sp and cur_sp.name == target_special then
        is_open_on_mon = cur_mon.name
    else
        for _, m in ipairs(hl.get_monitors() or {}) do
            local msp = m.active_special_workspace or m.specialWorkspace
            local msp_name = (type(msp) == "table") and msp.name or tostring(msp or "")
            if msp_name == target_special then
                is_open_on_mon = m.name
                break
            end
        end
    end

    if is_open_on_mon then
        -- Remember fullscreen and focus state before stowing
        M.remember_state(target)

        -- Stow target and clear anchor
        os.remove("/tmp/scratchpad_anchored_" .. target)
        if is_open_on_mon ~= cur_mon.name then
            hl.dispatch(hl.dsp.focus({ monitor = is_open_on_mon }))
        end
        hl.dispatch(hl.dsp.workspace.toggle_special(target))
        if is_open_on_mon ~= cur_mon.name then
            hl.dispatch(hl.dsp.focus({ monitor = cur_mon.name }))
        end
        if target == "notes" then
            os.execute("copyq hide &")
        end
        M.update_active_scratchpad("")
        set_timeout(M.update_active_scratchpad, 100)
        os.execute("pkill -RTMIN+1 waybar &")
        return
    end

    -- If target workspace exists on another monitor, migrate it to the current monitor
    for _, ws in ipairs(hl.get_workspaces() or {}) do
        if ws.name == target_special and ws.monitor and ws.monitor.name ~= cur_mon.name then
            hl.dispatch(hl.dsp.workspace.move({ workspace = target_special, monitor = cur_mon.name }))
            break
        end
    end

    -- If not stacking, stow any unanchored scratchpad currently visible on THIS monitor
    if not is_stack and cur_sp and cur_sp.name and cur_sp.name:find("^special:") then
        local active_sp = cur_sp.name:gsub("^special:", "")
        if active_sp ~= target and not is_anchored(active_sp) then
            M.remember_state(active_sp)
            hl.dispatch(hl.dsp.workspace.toggle_special(active_sp))
            if active_sp == "notes" then
                os.execute("copyq hide &")
            end
        end
    end

    -- Apply workspace rules for margins on this monitor
    hl.workspace_rule({
        workspace = target_special,
        gaps_out = cfg.gaps_out,
        gaps_in = cfg.gaps_in,
        no_border = cfg.no_border,
        border_size = cfg.no_border and 0 or 2,
        monitor = cur_mon.name,
    })

    if target == "dev" then
        -- Tokyo 80s TRV30 Dev Deck: Antigravity IDE + Localhost Browser
        local wins = hl.get_windows() or {}
        local ide_found = false
        local browser_found = false
        for _, w in ipairs(wins) do
            local c_class = w.class or ""
            if c_class == "antigravity-ide" or c_class:find("antigravity%-ide") then
                ide_found = true
                if not (w.workspace and w.workspace.name == target_special) then
                    hl.dispatch(hl.dsp.window.move({
                        workspace = target_special,
                        window = "address:" .. w.address,
                        silent = true,
                    }))
                end
            elseif c_class:find("vivaldi%-localhost") then
                browser_found = true
                if not (w.workspace and w.workspace.name == target_special) then
                    hl.dispatch(hl.dsp.window.move({
                        workspace = target_special,
                        window = "address:" .. w.address,
                        silent = true,
                    }))
                end
            end
        end

        if not ide_found then
            hl.exec_cmd("/opt/antigravity-ide/antigravity-ide")
        end
        if not browser_found then
            hl.exec_cmd("vivaldi-stable --app=http://localhost:3000")
        end
    elseif target == "notes" then
        -- Tokyo 80s TRV30 Dual-Window Copy-Paste Hub
        -- 1. Ensure notes files exist
        os.execute("mkdir -p " .. HOME .. "/.config/notes && touch " .. HOME .. "/.config/notes/scratch.txt " .. HOME .. "/.config/notes/todo.txt " .. HOME .. "/.config/notes/ideas.txt &")

        -- 2. Ensure CopyQ server is running and show GUI
        os.execute("pgrep -x copyq >/dev/null || (copyq --start-server &)")
        os.execute("copyq show &")

        -- 3. Check for notes-term and copyq windows
        local term_found = false
        local copyq_found = false
        for _, w in ipairs(hl.get_windows() or {}) do
            local c_class = w.class or ""
            if c_class == "notes-term" then
                term_found = true
                if not (w.workspace and w.workspace.name == target_special) then
                    hl.dispatch(hl.dsp.window.move({
                        workspace = target_special,
                        window = "address:" .. w.address,
                        silent = true,
                    }))
                end
            elseif c_class:lower():find("copyq") then
                copyq_found = true
                if not (w.workspace and w.workspace.name == target_special) then
                    hl.dispatch(hl.dsp.window.move({
                        workspace = target_special,
                        window = "address:" .. w.address,
                        silent = true,
                    }))
                end
            end
        end

        if not term_found then
            os.execute("rm -f " .. HOME .. "/.local/state/nvim/swap/*scratch.txt.swp " .. HOME .. "/.local/state/nvim/swap/*todo.txt.swp " .. HOME .. "/.local/state/nvim/swap/*ideas.txt.swp &")
            hl.exec_cmd("kitty --class notes-term nvim -p " .. HOME .. "/.config/notes/scratch.txt " .. HOME .. "/.config/notes/todo.txt " .. HOME .. "/.config/notes/ideas.txt")
        end
    else
        -- Check if the scratchpad currently contains any windows
        local wins = hl.get_windows() or {}
        local has_window = false
        local candidate_win = nil

        for _, w in ipairs(wins) do
            local ws = w.workspace and w.workspace.name
            if ws == target_special then
                has_window = true
                break
            elseif target ~= "magic" and cfg.class_pattern and not candidate_win then
                local c_class = w.class or ""
                if c_class:lower():match(cfg.class_pattern) then
                    candidate_win = w
                end
            end
        end

        -- If empty, adopt existing candidate or launch
        if not has_window and target ~= "magic" then
            if candidate_win then
                hl.dispatch(hl.dsp.window.move({
                    workspace = target_special,
                    window = "address:" .. candidate_win.address,
                    silent = true,
                }))
                has_window = true
            elseif cfg.cmd then
                hl.exec_cmd(cfg.cmd)
            end
        end
    end

    -- Toggle special workspace on
    hl.dispatch(hl.dsp.workspace.toggle_special(target))

    -- Ensure windows are tiled to respect gaps (immediate and async timer passes)
    local function enforce_tiled()
        local saved_fs = M._fullscreen_state and M._fullscreen_state[target]
        local saved_foc = M._last_focused and M._last_focused[target]

        local wins_in_sp = {}
        local current_fs_win = nil
        local matched_saved_fs_win = nil
        local matched_saved_foc_win = nil
        local notes_term_win = nil
        local best_history_win = nil
        local best_history_id = 999999
        local first_win = nil

        for _, w in ipairs(hl.get_windows() or {}) do
            if w.workspace and w.workspace.name == target_special then
                table.insert(wins_in_sp, w)
                if not first_win then first_win = w end

                -- Check fullscreen status
                if w.fullscreen and w.fullscreen > 0 then
                    if cfg.gaps_out > 0 then
                        -- For modal HUD scratchpads (music, discord, calendar, notes), enforce un-fullscreen
                        hl.dispatch(hl.dsp.focus({ window = "address:" .. w.address }))
                        hl.dispatch(hl.dsp.window.fullscreen())
                    else
                        -- For 0-gap decks (dev, magic, antigravity), track current fullscreen window
                        current_fs_win = w
                    end
                end

                if saved_fs and ((saved_fs.address and w.address == saved_fs.address) or (saved_fs.class and w.class and w.class:find(saved_fs.class, 1, true))) then
                    matched_saved_fs_win = w
                end

                if saved_foc and ((saved_foc.address and w.address == saved_foc.address) or (saved_foc.class and w.class and w.class:find(saved_foc.class, 1, true))) then
                    matched_saved_foc_win = w
                end

                if target == "notes" and (w.class == "notes-term" or (w.title and w.title:lower():find("notes"))) then
                    notes_term_win = w
                end

                if w.floating then
                    hl.dispatch(hl.dsp.focus({ window = "address:" .. w.address }))
                    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
                end

                local hid = tonumber(w.focusHistoryID) or 999999
                if hid < best_history_id then
                    best_history_id = hid
                    best_history_win = w
                end
            end
        end

        if #wins_in_sp == 0 then return end

        local sp_win = nil

        -- Priority 1: Current fullscreen window in this special workspace
        if current_fs_win then
            sp_win = current_fs_win
            M._fullscreen_state[target] = { address = current_fs_win.address, class = current_fs_win.class }
        else
            M._fullscreen_state[target] = { address = nil, class = nil }
            -- Priority 2: Notes term for notes hub
            if target == "notes" and notes_term_win then
                sp_win = notes_term_win
            -- Priority 3: Last focused window in this scratchpad
            elseif matched_saved_foc_win then
                sp_win = matched_saved_foc_win
            -- Priority 4: Most recently active window (lowest focus history)
            elseif best_history_win then
                sp_win = best_history_win
            else
                sp_win = first_win
            end
        end

        if sp_win then
            local act = hl.get_active_window()
            if not act or act.address ~= sp_win.address then
                hl.dispatch(hl.dsp.focus({ window = "address:" .. sp_win.address }))
            end
        end
    end

    enforce_tiled()
    set_timeout(enforce_tiled, 150)
    set_timeout(enforce_tiled, 450)
    M.update_active_scratchpad(target)
    set_timeout(M.update_active_scratchpad, 120)

    os.execute("(sleep 0.1; pkill -RTMIN+1 waybar; sleep 0.3; pkill -RTMIN+1 waybar) &")
end

--- Panoramic (Multi-Monitor) Coordinated Scratchpad Toggler
function M.toggle_panoramic(deck_key)
    local deck = PANORAMIC_DECKS[deck_key]
    if not deck then
        M.toggle(deck_key)
        return
    end

    local mons = hl.get_monitors() or {}
    if #mons <= 1 then
        M.toggle(deck.main)
        return
    end

    local main_mon = nil
    local comp_mon = nil
    local focused_mon = hl.get_active_monitor()
    local focused_name = focused_mon and focused_mon.name or nil

    for _, m in ipairs(mons) do
        if m.name == "HDMI-A-1" or (not m.name:find("^eDP") and not main_mon) then
            main_mon = m
        else
            comp_mon = m
        end
    end
    if not main_mon then main_mon = mons[1] end
    if not comp_mon then comp_mon = mons[2] end

    local main_sp_target = "special:" .. deck.main
    local comp_sp_target = "special:" .. deck.comp

    local main_sp_obj = main_mon.active_special_workspace or main_mon.specialWorkspace
    local comp_sp_obj = comp_mon.active_special_workspace or comp_mon.specialWorkspace
    local main_cur_sp = main_sp_obj and (type(main_sp_obj) == "table" and main_sp_obj.name or tostring(main_sp_obj)) or ""
    local comp_cur_sp = comp_sp_obj and (type(comp_sp_obj) == "table" and comp_sp_obj.name or tostring(comp_sp_obj)) or ""

    if main_cur_sp == main_sp_target and comp_cur_sp == comp_sp_target then
        os.remove("/tmp/scratchpad_anchored_" .. deck.main)
        os.remove("/tmp/scratchpad_anchored_" .. deck.comp)
        hl.dispatch(hl.dsp.focus({ monitor = main_mon.name }))
        hl.dispatch(hl.dsp.workspace.toggle_special(deck.main))
        hl.dispatch(hl.dsp.focus({ monitor = comp_mon.name }))
        hl.dispatch(hl.dsp.workspace.toggle_special(deck.comp))
        if focused_name then
            hl.dispatch(hl.dsp.focus({ monitor = focused_name }))
        end
        os.execute(string.format('dunstify -a "osd" -r 9997 -u normal "[ ❖ PANORAMIC STOWED / パノラマ格納 ]" "%s DISMISSED ACROSS ALL DISPLAYS"', deck.name))
        M.update_active_scratchpad("")
        set_timeout(M.update_active_scratchpad, 100)
        os.execute("pkill -RTMIN+1 waybar &")
        return
    end

    hl.dispatch(hl.dsp.focus({ monitor = main_mon.name }))
    if main_cur_sp and main_cur_sp:find("^special:") and main_cur_sp ~= main_sp_target then
        hl.dispatch(hl.dsp.workspace.toggle_special(main_cur_sp:gsub("^special:", "")))
    end
    if main_cur_sp ~= main_sp_target then
        M.toggle(deck.main, true)
    end

    hl.dispatch(hl.dsp.focus({ monitor = comp_mon.name }))
    if comp_cur_sp and comp_cur_sp:find("^special:") and comp_cur_sp ~= comp_sp_target then
        hl.dispatch(hl.dsp.workspace.toggle_special(comp_cur_sp:gsub("^special:", "")))
    end
    if comp_cur_sp ~= comp_sp_target then
        M.toggle(deck.comp, true)
    end

    if focused_name then
        hl.dispatch(hl.dsp.focus({ monitor = focused_name }))
    end

    os.execute(string.format('dunstify -a "osd" -r 9997 -u normal "[ ❖ PANORAMIC ENGAGED / パノラマ展開 ]" "%s ONLINE ACROSS DUAL SCREENS"', deck.name))
    M.update_active_scratchpad(deck.main)
    set_timeout(M.update_active_scratchpad, 120)
    os.execute("pkill -RTMIN+1 waybar &")
end

--- Toggles scratchpad anchor lock / window pin
function M.toggle_anchor()
    local cur_sp = hl.get_active_special_workspace()
    local sp = cur_sp and cur_sp.name
    if sp and sp:find("^special:") then
        local sp_name = sp:gsub("^special:", "")
        local anchor_file = "/tmp/scratchpad_anchored_" .. sp_name
        local f = io.open(anchor_file, "r")
        if f then
            f:close()
            os.remove(anchor_file)
            os.execute(string.format('dunstify -a "osd" -r 9998 -u normal "[ 🔓 ANCHOR RELEASED ]" "DECK [%s] WILL HIDE ON DESKTOP SWITCH"', sp_name:upper()))
        else
            local out = io.open(anchor_file, "w")
            if out then
                out:write("anchored\n")
                out:close()
            end
            os.execute(string.format('dunstify -a "osd" -r 9998 -u normal "[ 📌 ANCHOR ENGAGED ]" "DECK [%s] PINNED ACROSS ALL DESKTOP SPACES"', sp_name:upper()))
        end
    else
        local win = hl.get_active_window()
        if win and win.floating then
            hl.dispatch(hl.dsp.window.pin())
            os.execute(string.format('dunstify -a "osd" -r 9998 -u normal "[ 📌 PIN TOGGLED ]" "%s PINNED/UNPINNED"', (win.title or "WINDOW"):sub(1, 30)))
        else
            os.execute('dunstify -a "osd" -r 9998 -u low "[ ℹ ANCHOR HUD ]" "OPEN A SCRATCHPAD OR FLOAT A WINDOW (Super+Ctrl+T) TO PIN"')
        end
    end
end

--- Sets up native scratchpad hooks
function M.setup()
    hl.on("workspace.active", function()
        pcall(M.update_active_scratchpad)
    end)
    hl.on("window.active", function()
        pcall(M.update_active_scratchpad)
    end)
    pcall(M.update_active_scratchpad)
end

return M
