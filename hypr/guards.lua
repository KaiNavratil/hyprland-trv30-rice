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
    ["special:dev"] = { "antigravity-ide", "antigravity", "vivaldi" },
    ["special:center"] = { "commandcenter", "command-center", "com.tokyo.commandcenter", "center" },
    ["special:radar"] = { "com.tokyo.radar", "trv30-radar", "desktop-radar", "radar" },
    ["special:display"] = { "com.tokyo.displaydeck", "displaydeck", "display-deck", "display" },
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

--- Scratchpad Guard: Prevents accidental window intrusion into modal scratchpads
function M.check_scratchpad_guard(win, target_ws_name)
    local ws_name = target_ws_name or (win.workspace and win.workspace.name)
    if not ws_name or not ws_name:find("^special:") then return end

    local allowed = ALLOWED_SCRATCHPADS[ws_name]
    if not allowed or allowed[1] == "*" then return end

    local c_class = win.class and win.class:lower() or ""
    local c_title = win.title and win.title:lower() or ""
    local is_allowed = false
    for _, a in ipairs(allowed) do
        if c_class:find(a:lower(), 1, true) or c_title:find(a:lower(), 1, true) then
            is_allowed = true
            break
        end
    end

    if not is_allowed then
        -- Delay eviction by 600ms to allow apps (like kitty notes-term, vivaldi calendar) to set their title/class
        hl.timer(function()
            local cur_win = nil
            for _, w in ipairs(hl.get_windows() or {}) do
                if w.address == win.address then
                    cur_win = w
                    break
                end
            end
            if not cur_win then return end
            local cur_ws = cur_win.workspace and cur_win.workspace.name
            if not cur_ws or not cur_ws:find("^special:") then return end

            local cur_c = cur_win.class and cur_win.class:lower() or ""
            local cur_t = cur_win.title and cur_win.title:lower() or ""
            local still_allowed = false
            for _, a in ipairs(allowed) do
                if cur_c:find(a:lower(), 1, true) or cur_t:find(a:lower(), 1, true) then
                    still_allowed = true
                    break
                end
            end

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
        end, { timeout = 600, type = "oneshot" })
    end
end

--- Closes active window and logs it to recently_closed.json for Super+T instant reopen
function M.kill_and_remember()
    local win = hl.get_active_window()
    if not win then
        hl.dispatch(hl.dsp.window.kill())
        return
    end

    local ws = win.workspace and win.workspace.name or ""
    if not ws:find("^special:") and win.class then
        local c_class = win.class
        local c_title = win.title or ""
        local exec_cmd = c_class:lower()
        if c_class == "vivaldi-stable" then
            if c_title:find("Notion Calendar") then
                exec_cmd = "vivaldi-stable --app=https://calendar.notion.so"
            else
                exec_cmd = "vivaldi-stable"
            end
        elseif c_class == "Spotify" or c_class == "spotify" then
            exec_cmd = "spotify-launcher --skip-update"
        elseif c_class == "vesktop" or c_class == "discord" then
            exec_cmd = "vesktop"
        end

        local entry = string.format(
            '  {\n    "class": %q,\n    "title": %q,\n    "workspace": %q,\n    "monitor": %d,\n    "exec_cmd": %q,\n    "timestamp": %d\n  }',
            c_class, c_title, ws, win.monitor and win.monitor.id or 0, exec_cmd, os.time()
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

    hl.dispatch(hl.dsp.window.kill())
end

--- Sets up native event hooks
function M.setup()
    -- Smart Split & Scratchpad Guard on window events
    hl.on("window.open", function(win)
        M.update_smart_split()
        if win then
            local ws_name = win.workspace and win.workspace.name
            if ws_name and ws_name:find("^special:") and ws_name ~= "special:magic" then
                if win.floating then
                    hl.dispatch(hl.dsp.focus({ window = "address:" .. win.address }))
                    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
                end
            end
            M.check_scratchpad_guard(win)
        end
    end)
    hl.on("window.close", M.update_smart_split)
    hl.on("workspace.active", function()
        M.update_smart_split()
        M.update_cinema_cursor()
    end)

    -- Cinema Cursor Hooks
    hl.on("window.fullscreen", M.update_cinema_cursor)
    hl.on("window.active", M.update_cinema_cursor)

    -- Scratchpad Guard Hook
    hl.on("window.move_to_workspace", function(win, ws)
        if win and ws then
            if ws.name and ws.name:find("^special:") and ws.name ~= "special:magic" then
                if win.floating then
                    hl.dispatch(hl.dsp.focus({ window = "address:" .. win.address }))
                    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
                end
            end
            M.check_scratchpad_guard(win, ws.name)
        end
    end)
end

return M
