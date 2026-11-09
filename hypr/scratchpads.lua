-- ══════════════════════════════════════════════════════════════════════════════
--  TOKYO 80s TRV30 — NATIVE SCRATCHPAD & HUD MULTI-DECK ENGINE
--  東京 80's デジタル // ネイティブ・スクラッチパッド＆マルチデッキ
-- ══════════════════════════════════════════════════════════════════════════════
local M = {}

local HOME = os.getenv("HOME") or "/home/kaijnav"

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
        class_pattern = "antigravity%-ide|antigravity",
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

    -- Check if target is already open on THIS monitor
    local is_open_here = cur_sp and cur_sp.name == target_special

    if is_open_here then
        -- Stow target and clear anchor
        os.remove("/tmp/scratchpad_anchored_" .. target)
        hl.dispatch(hl.dsp.workspace.toggle_special(target))
        if target == "notes" then
            os.execute("copyq hide &")
        end
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
        monitor = cur_mon.name,
    })

    if target == "notes" then
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

    -- Ensure windows are tiled to respect gaps
    for _, w in ipairs(hl.get_windows() or {}) do
        if w.workspace and w.workspace.name == target_special then
            hl.dispatch(hl.dsp.window.float({ action = "settiled", window = "address:" .. w.address }))
        end
    end

    if target == "notes" then
        hl.dispatch(hl.dsp.window.float({ action = "settiled", window = "class:notes-term" }))
        hl.dispatch(hl.dsp.window.float({ action = "settiled", window = "class:com.github.hluk.copyq" }))
        hl.timer(function()
            hl.dispatch(hl.dsp.window.float({ action = "settiled", window = "class:notes-term" }))
            hl.dispatch(hl.dsp.window.float({ action = "settiled", window = "class:com.github.hluk.copyq" }))
            hl.dispatch(hl.dsp.focus({ window = "class:notes-term" }))
        end, { timeout = 200, type = "oneshot" })
    end

    os.execute("(sleep 0.1; pkill -RTMIN+1 waybar; sleep 0.3; pkill -RTMIN+1 waybar) &")
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

return M
