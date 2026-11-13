-- ══════════════════════════════════════════════════════════════════════════════
--  TOKYO 80s TRV30 — NATIVE HYPRLAND GUARDS & AUTOMATION ENGINE
--  東京 80's デジタル // ネイティブ・ガード＆オートメーション
-- ══════════════════════════════════════════════════════════════════════════════
local M = {}

local HOME = os.getenv("HOME") or "/home/kaijnav"
local RECENTLY_CLOSED_FILE = HOME .. "/.cache/recently_closed.json"

local ALLOWED_SCRATCHPADS = {
    ["special:music"] = { "spotify" },
    ["special:discord"] = { "vesktop", "discord" },
    ["special:notes"] = { "notes-term", "copyq", "com.github.hluk.copyq" },
    ["special:calendar"] = { "vivaldi-calendar", "notion" },
    ["special:magic"] = { "*" },
    ["special:antigravity"] = { "antigravity" },
    ["special:dev"] = { "antigravity-ide", "vivaldi" },
    ["special:center"] = { "commandcenter", "command-center", "com.tokyo.commandcenter", "center" },
    ["special:radar"] = { "com.tokyo.radar", "trv30-radar", "desktop-radar", "radar" },
    ["special:display"] = { "com.tokyo.displaydeck", "displaydeck", "display-deck", "display" },
    ["special:bluetooth"] = { "com.tokyo.bluetoothhq", "bluetoothhq", "bluetooth-hq" },
    ["special:cava"] = { "trv30-cava", "cava" },
    ["special:sysmon"] = { "trv30-btop", "btop" },
}

local MEDIA_CLASSES = {
    ["mpv"] = true,
    ["vlc"] = true,
    ["celluloid"] = true,
    ["totem"] = true,
    ["kodi"] = true,
    ["plexmediaplayer"] = true,
    ["stremio"] = true,
    ["popcorntime"] = true,
    ["netflix"] = true,
    ["jellyfinmediaplayer"] = true,
}

local MEDIA_KEYWORDS = {
    "youtube", "netflix", "crunchyroll", "twitch", "prime video",
    "disney+", "hulu", "bilibili", "movie", "watch", "video", "stream"
}

--- Smart-Split: Preserves natural mouse-driven split tracking (force_split = 0)
function M.update_smart_split()
    hl.config({ dwindle = { force_split = 0 } })
end

--- Cinema-Cursor: Auto-hides cursor after 3s on fullscreen/video, 0s (never) on desktop
function M.update_cinema_cursor()
    local win = hl.get_active_window()
    if not win then
        hl.config({ cursor = { inactive_timeout = 0 } })
        return
    end

    local is_media = false
    if win.fullscreen and win.fullscreen > 0 then
        is_media = true
    elseif win.class and MEDIA_CLASSES[win.class:lower()] then
        is_media = true
    elseif win.title then
        local t = win.title:lower()
        for _, kw in ipairs(MEDIA_KEYWORDS) do
            if t:find(kw, 1, true) then
                is_media = true
                break
            end
        end
    end

    if is_media then
        hl.config({ cursor = { inactive_timeout = 3 } })
    else
        hl.config({ cursor = { inactive_timeout = 0 } })
    end
end

local function is_win_allowed_in_sp(c_class, c_title, allowed_list)
    for _, a in ipairs(allowed_list) do
        if a == "antigravity" then
            -- Strict check: Antigravity 2 must be exact "antigravity", never "antigravity-ide"
            if c_class == "antigravity" then
                return true
            end
        elseif a == "antigravity-ide" then
            -- Strict check: Antigravity IDE
            if c_class == "antigravity-ide" or c_class:find("^antigravity%-ide") then
                return true
            end
        else
            if c_class:find(a:lower(), 1, true) or c_title:find(a:lower(), 1, true) then
                return true
            end
        end
    end
    return false
end

--- Scratchpad Guard: Prevents accidental window intrusion into modal scratchpads
function M.check_scratchpad_guard(win, target_ws_name)
    if not win or win.floating then return end
    local ws_name = target_ws_name or (win.workspace and win.workspace.name)
    if not ws_name or not ws_name:find("^special:") then return end

    local allowed = ALLOWED_SCRATCHPADS[ws_name]
    if not allowed or allowed[1] == "*" then return end

    local c_class = win.class and win.class:lower() or ""
    local c_title = win.title and win.title:lower() or ""
    local is_allowed = is_win_allowed_in_sp(c_class, c_title, allowed)

    if not is_allowed then
        -- Delay eviction by 600ms to allow apps (like kitty notes-term, vivaldi calendar) to set their title/class
        hl.timer(function()
            pcall(function()
                local cur_win = nil
                for _, w in ipairs(hl.get_windows() or {}) do
                    if w.address == win.address then
                        cur_win = w
                        break
                    end
                end
                if not cur_win or cur_win.floating then return end
                local cur_ws = cur_win.workspace and cur_win.workspace.name
                if not cur_ws or not cur_ws:find("^special:") then return end

                local cur_c = cur_win.class and cur_win.class:lower() or ""
                local cur_t = cur_win.title and cur_win.title:lower() or ""
                local still_allowed = is_win_allowed_in_sp(cur_c, cur_t, allowed)

                if not still_allowed then
                    local mon = hl.get_active_monitor()
                    local dest = mon and mon.active_workspace and mon.active_workspace.name or "1"
                    if dest:find("^special:") then dest = "1" end
                    hl.dispatch(hl.dsp.window.move({
                        workspace = dest,
                        window = "address:" .. cur_win.address,
                        silent = true
                    }))
                end
            end)
        end, { timeout = 600, type = "oneshot" })
    end
end

--- Closes active window and logs it to recently_closed.json for Super+T instant reopen
function M.kill_and_remember()
    local win = hl.get_active_window()
    if not win then
        hl.dispatch(hl.dsp.window.close())
        return
    end

    local ws = win.workspace and win.workspace.name or ""
    if win.class and (not ws:find("^special:") or ws == "special:dev") then
        local c_class = win.class
        local c_title = win.title or ""
        local exec_cmd = c_class:lower()
        if c_class:find("vivaldi%-localhost") then
            exec_cmd = "vivaldi-stable --app=http://localhost:3000"
        elseif c_class == "vivaldi-stable" then
            if c_title:find("Notion Calendar") then
                exec_cmd = "vivaldi-stable --app=https://calendar.notion.so"
            else
                exec_cmd = "vivaldi-stable"
            end
        elseif c_class == "Spotify" or c_class == "spotify" then
            exec_cmd = "spotify-launcher --skip-update"
        elseif c_class == "vesktop" or c_class == "discord" then
            exec_cmd = "vesktop"
        elseif c_class == "antigravity-ide" then
            exec_cmd = "/usr/bin/antigravity-ide"
        elseif c_class == "antigravity" then
            exec_cmd = "/home/kaijnav/.local/bin/antigravity"
        end

        local is_fs = (win.fullscreen and win.fullscreen > 0) or false
        local entry = string.format(
            '  {\n    "class": %q,\n    "title": %q,\n    "workspace": %q,\n    "monitor": %d,\n    "exec_cmd": %q,\n    "fullscreen": %s,\n    "timestamp": %d\n  }',
            c_class, c_title, ws, win.monitor and win.monitor.id or 0, exec_cmd, tostring(is_fs), os.time()
        )

        local f = io.open(RECENTLY_CLOSED_FILE, "r")
        local content = f and f:read("*a") or "[]"
        if f then f:close() end

        local new_content
        if content:find("^%s*%[%s*%]") or not content:find("%[") then
            new_content = "[\n" .. entry .. "\n]"
        else
            new_content = content:gsub("^%s*%[%s*", "[\n" .. entry .. ",\n")
        end

        local out = io.open(RECENTLY_CLOSED_FILE .. ".tmp", "w")
        if out then
            out:write(new_content)
            out:close()
            os.rename(RECENTLY_CLOSED_FILE .. ".tmp", RECENTLY_CLOSED_FILE)
        end
    end

    hl.dispatch(hl.dsp.window.close({ window = "address:" .. win.address }))
end

--- Pops the most recently closed window and re-launches it in its original workspace
function M.reopen_last()
    local f = io.open(RECENTLY_CLOSED_FILE, "r")
    if not f then
        os.execute('dunstify -u low -t 1500 "REOPEN" "No recently closed windows in history"')
        return
    end
    local raw = f:read("*a")
    f:close()

    local items = {}
    for entry in raw:gmatch("%b{}") do
        local cls = entry:match('"class"%s*:%s*"([^"]+)"')
        local title = entry:match('"title"%s*:%s*"([^"]+)"')
        local ws = entry:match('"workspace"%s*:%s*"([^"]+)"')
        local mon = entry:match('"monitor"%s*:%s*(%d+)')
        local exec_cmd = entry:match('"exec_cmd"%s*:%s*"([^"]+)"')
        local fs = entry:match('"fullscreen"%s*:%s*(%a+)')
        if exec_cmd and ws then
            table.insert(items, {
                class = cls or "",
                title = title or "",
                workspace = ws,
                monitor = tonumber(mon) or 0,
                exec_cmd = exec_cmd,
                fullscreen = fs == "true",
            })
        end
    end

    if #items == 0 then
        os.execute('dunstify -u low -t 1500 "REOPEN" "No recently closed windows in history"')
        return
    end

    local target = table.remove(items, 1)

    local new_entries = {}
    for _, it in ipairs(items) do
        table.insert(new_entries, string.format(
            '  {\n    "class": %q,\n    "title": %q,\n    "workspace": %q,\n    "monitor": %d,\n    "exec_cmd": %q,\n    "fullscreen": %s\n  }',
            it.class, it.title, it.workspace, it.monitor, it.exec_cmd, tostring(it.fullscreen)
        ))
    end
    local out = io.open(RECENTLY_CLOSED_FILE .. ".tmp", "w")
    if out then
        out:write("[\n" .. table.concat(new_entries, ",\n") .. "\n]\n")
        out:close()
        os.rename(RECENTLY_CLOSED_FILE .. ".tmp", RECENTLY_CLOSED_FILE)
    end

    hl.exec_cmd(string.format("[workspace %s] %s", target.workspace, target.exec_cmd))

    if target.fullscreen then
        hl.timer(function()
            pcall(function()
                for _, w in ipairs(hl.get_windows() or {}) do
                    local c = w.class or ""
                    if c == target.class or (target.class:find("vivaldi%-localhost") and c:find("vivaldi%-localhost")) then
                        if not (w.fullscreen and w.fullscreen > 0) then
                            hl.dispatch(hl.dsp.focus({ window = "address:" .. w.address }))
                            hl.dispatch(hl.dsp.window.fullscreen())
                        end
                        break
                    end
                end
            end)
        end, { timeout = 400, type = "oneshot" })
    end

    local ws_num = tonumber(target.workspace)
    local space_str = string.format("Workspace %s", target.workspace)
    if ws_num then
        if ws_num > 10 then
            space_str = string.format("Space %d (Companion Monitor)", ws_num - 10)
        else
            space_str = string.format("Space %d (Main Monitor)", ws_num)
        end
    end

    local display_name = (target.title and #target.title > 0 and target.title:find(" - ")) and target.title or (target.class or target.exec_cmd)
    if #display_name > 42 then
        display_name = display_name:sub(1, 39) .. "..."
    end

    os.execute(string.format('dunstify -u low -t 2000 "● REOPEN" "Restoring to %s:\\n%s"', space_str, display_name))
end

--- Sets up native event hooks
function M.setup()
    -- Smart Split & Scratchpad Guard on window events
    hl.on("window.open", function(win)
        pcall(function()
            M.update_smart_split()
            if win then
                local ws_name = win.workspace and win.workspace.name
                if ws_name and ws_name:find("^special:") and ws_name ~= "special:magic" and ws_name ~= "special:dev" and ws_name ~= "special:antigravity" and ws_name ~= "special:center" and ws_name ~= "special:radar" and ws_name ~= "special:display" and ws_name ~= "special:bluetooth" then
                    if win.fullscreen and win.fullscreen > 0 then
                        hl.dispatch(hl.dsp.focus({ window = "address:" .. win.address }))
                        hl.dispatch(hl.dsp.window.fullscreen())
                    end
                    if win.floating then
                        hl.dispatch(hl.dsp.focus({ window = "address:" .. win.address }))
                        hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
                    end
                end
                M.check_scratchpad_guard(win)
            end
        end)
    end)
    hl.on("window.close", function() pcall(M.update_smart_split) end)
    hl.on("workspace.active", function()
        pcall(function()
            M.update_smart_split()
            M.update_cinema_cursor()
        end)
    end)

    -- Cinema Cursor Hooks
    hl.on("window.fullscreen", function() pcall(M.update_cinema_cursor) end)
    hl.on("window.active", function() pcall(M.update_cinema_cursor) end)

    -- Scratchpad Guard Hook
    hl.on("window.move_to_workspace", function(win, ws)
        pcall(function()
            if win and ws then
                if ws.name and ws.name:find("^special:") and ws.name ~= "special:magic" and ws.name ~= "special:dev" and ws.name ~= "special:antigravity" and ws.name ~= "special:center" and ws.name ~= "special:radar" and ws.name ~= "special:display" and ws.name ~= "special:bluetooth" then
                    if win.fullscreen and win.fullscreen > 0 then
                        hl.dispatch(hl.dsp.focus({ window = "address:" .. win.address }))
                        hl.dispatch(hl.dsp.window.fullscreen())
                    end
                    if win.floating then
                        hl.dispatch(hl.dsp.focus({ window = "address:" .. win.address }))
                        hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
                    end
                end
                M.check_scratchpad_guard(win, ws.name)
            end
        end)
    end)
end

return M
