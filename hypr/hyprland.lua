-- ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
-- ┃ TOKYO 80s TRV30 CAMCORDER RICE - HYPRLAND LUA CONFIG        ┃
-- ┃ ソニー TRV30 ハンディカム (DIGITAL VIDEO CASSETTE)          ┃
-- ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

---@module 'hl'

-- ┌─────────────────────────────────────────────────────────────┐
-- │ 1. MONITORS (モニター)                                      │
-- └─────────────────────────────────────────────────────────────┘
package.loaded["monitors"] = nil
package.loaded["spaces"] = nil
package.loaded["guards"] = nil
package.loaded["scratchpads"] = nil
package.loaded["animations"] = nil

require("monitors")

local spaces = require("spaces")
local guards = require("guards")
local scratchpads = require("scratchpads")
local animations = require("animations")

spaces.setup()
guards.setup()
scratchpads.setup()
animations.setup()

-- ┌─────────────────────────────────────────────────────────────┐
-- │ 2. ENVIRONMENT VARIABLES (環境変数)                         │
-- └─────────────────────────────────────────────────────────────┘
hl.env("XCURSOR_SIZE", 24)
hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")
hl.env("HYPRCURSOR_THEME", "hyprcursor")
hl.env("PATH", "/home/kaijnav/.local/bin:" .. (os.getenv("PATH") or ""))
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- ┌─────────────────────────────────────────────────────────────┐
-- │ 3. GENERAL & DWINDLE (一般設定)                             │
-- └─────────────────────────────────────────────────────────────┘
hl.config({
    general = {
        gaps_in = 2,
        gaps_out = 0,
        border_size = 2,
        layout = "dwindle",
        col = {
            active_border = "rgba(b8a998ff)",
            inactive_border = "rgba(0a0808ff)",
        },
    },

    dwindle = {
        preserve_split = true,
        force_split = 0,
    },

    group = {
        drag_into_group = 0,
        merge_groups_on_drag = false,
        auto_group = false,
    },

    decoration = {
        rounding = 0,
        blur = {
            enabled = false,
        },
    },

    animations = {
        enabled = true,
    },

    input = {
        kb_layout = "custom_arrows",
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
            tap_and_drag = true,
            drag_lock = false,
        },
    },

    cursor = {
        no_hardware_cursors = true,
        inactive_timeout = 0,
        hide_on_key_press = false,
        no_warps = true,
        warp_on_change_workspace = 0,
    },

    misc = {
        disable_hyprland_logo = true,
        force_default_wallpaper = 0,
        focus_on_activate = true,
        mouse_move_enables_dpms = false,
        key_press_enables_dpms = true,
        animate_mouse_windowdragging = false,
        animate_manual_resizes = false,
    },

    xwayland = {
        force_zero_scaling = true,
    },
})

-- ┌─────────────────────────────────────────────────────────────┐
-- │ 4. WORKSPACES (ワークスペース)                              │
-- └─────────────────────────────────────────────────────────────┘
-- Desktop Spaces across Dual Monitors:
-- Main Monitor (HDMI-A-1 / Left): Workspaces 1-9
for ws = 1, 9 do
    hl.workspace_rule({
        workspace = ws,
        monitor = "HDMI-A-1",
        default = (ws == 1),
    })
end

-- Companion Monitor (eDP-1 / Right): Workspaces 11-19
for ws = 11, 19 do
    hl.workspace_rule({
        workspace = ws,
        monitor = "eDP-1",
        default = (ws == 11),
    })
end

-- Scratchpads
hl.workspace_rule({ workspace = "special:magic", gaps_out = 0, gaps_in = 0, no_border = true })
hl.workspace_rule({ workspace = "special:music", gaps_out = 60 })
hl.workspace_rule({ workspace = "special:discord", gaps_out = 60 })
hl.workspace_rule({ workspace = "special:notes", gaps_out = 60, gaps_in = 4 })
hl.workspace_rule({ workspace = "special:calendar", gaps_out = 60 })
hl.workspace_rule({ workspace = "special:center", gaps_out = 0, gaps_in = 0, no_border = true })
hl.workspace_rule({ workspace = "special:radar", gaps_out = 0, gaps_in = 0, no_border = true })
hl.workspace_rule({ workspace = "special:display", gaps_out = 0, gaps_in = 0, no_border = true })
hl.workspace_rule({ workspace = "special:antigravity", gaps_out = 0, gaps_in = 0, no_border = true })
hl.workspace_rule({ workspace = "special:dev", gaps_out = 0, gaps_in = 0, no_border = true })
hl.workspace_rule({ workspace = "special:cava", gaps_out = 60, monitor = "eDP-1" })
hl.workspace_rule({ workspace = "special:sysmon", gaps_out = 60, monitor = "eDP-1" })

-- ┌─────────────────────────────────────────────────────────────┐
-- │ 6. WINDOW RULES (ウィンドウルール)                          │
-- └─────────────────────────────────────────────────────────────┘
hl.window_rule({
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name = "workspace_special_music",
    match = { class = "^([Ss]potify)$" },
    workspace = "special:music silent",
    tile = true,
})

hl.window_rule({
    name = "workspace_special_discord",
    match = { class = "^([Vv]esktop)$" },
    workspace = "special:discord silent",
    tile = true,
})

hl.window_rule({
    name = "workspace_special_notes_term",
    match = { class = "^(notes-term)$" },
    workspace = "special:notes silent",
    tile = true,
})

hl.window_rule({
    name = "workspace_special_notes_copyq",
    match = { class = "^(com\\.github\\.hluk\\.copyq|copyq)$" },
    workspace = "special:notes silent",
    tile = true,
})

hl.window_rule({
    name = "workspace_special_calendar",
    match = { class = "^(vivaldi-calendar\\.notion\\.so.*)$" },
    workspace = "special:calendar silent",
    tile = true,
})

hl.window_rule({
    name = "workspace_special_center",
    match = { class = "^(com\\.tokyo\\.commandcenter|command-center)$" },
    workspace = "special:center silent",
    tile = true,
})

hl.window_rule({
    name = "workspace_special_radar",
    match = { class = "^(com\\.tokyo\\.radar)$" },
    workspace = "special:radar silent",
    tile = true,
})

hl.window_rule({
    name = "workspace_special_display",
    match = { class = "^(com\\.tokyo\\.displaydeck)$" },
    workspace = "special:display silent",
    tile = true,
})

hl.window_rule({
    name = "workspace_special_dev_ide",
    match = { class = "^(antigravity-ide)$" },
    workspace = "special:dev silent",
    tile = true,
})

hl.window_rule({
    name = "workspace_special_dev_browser",
    match = { class = "^(vivaldi-localhost.*)$" },
    workspace = "special:dev silent",
    tile = true,
})

hl.window_rule({
    name = "workspace_special_antigravity",
    match = { class = "^(antigravity)$" },
    workspace = "special:antigravity silent",
    tile = true,
})

hl.window_rule({
    name = "workspace_special_cava",
    match = { class = "^(trv30-cava)$" },
    workspace = "special:cava silent",
    tile = true,
})

hl.window_rule({
    name = "workspace_special_sysmon",
    match = { class = "^(trv30-btop)$" },
    workspace = "special:sysmon silent",
    tile = true,
})

hl.window_rule({
    name = "crt_blink_overlay",
    match = { class = "^(crt-blink)$" },
    float = true,
    fullscreen = 1,
})

-- ┌─────────────────────────────────────────────────────────────┐
-- │ 7. DEVICE RULES (入力デバイスルール)                        │
-- └─────────────────────────────────────────────────────────────┘
hl.device({
    name = "earfun-air-pro-4-(avrcp)",
    enabled = false,
})

-- ┌─────────────────────────────────────────────────────────────┐
-- │ 8. KEYBINDINGS (キーバインド)                               │
-- └─────────────────────────────────────────────────────────────┘
local mod = "SUPER"

-- Applications
hl.bind(mod .. " + Return", hl.dsp.exec_cmd("kitty"))
hl.bind(mod .. " + Space", hl.dsp.exec_cmd("pkill rofi || rofi -show drun"))
hl.bind(mod .. " + A", function() scratchpads.toggle("antigravity") end)
hl.bind(mod .. " + SHIFT + left", function() spaces.swap_workspace("left") end)
hl.bind(mod .. " + SHIFT + right", function() spaces.swap_workspace("right") end)
hl.bind(mod .. " + Q", guards.kill_and_remember)
hl.bind(mod .. " + SHIFT + Q", hl.dsp.window.kill())

-- Neutralize Ctrl+Q (prevent accidental app exits in browsers/terminals)
hl.bind("CTRL + Q", hl.dsp.exec_cmd("true"))

-- Reopen closed windows (Super+T and Super+Shift+T - Native Engine)
hl.bind(mod .. " + T", guards.reopen_last)
hl.bind(mod .. " + SHIFT + T", guards.reopen_last)
hl.bind(mod .. " + CTRL + T", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + M", hl.dsp.exec_cmd("bash ~/.config/hypr/scripts/lock.sh"))

hl.bind(mod .. " + B", hl.dsp.exec_cmd("~/.config/hypr/scripts/power-mode.sh"))
hl.bind(mod .. " + SHIFT + B", hl.dsp.exec_cmd("bash ~/.config/waybar/scripts/restart-waybar.sh"))
hl.bind(mod .. " + SHIFT + C", hl.dsp.exec_cmd("bash ~/.config/hypr/scripts/toggle-vcr.sh"))
hl.bind(mod .. " + O", hl.dsp.exec_cmd("bash ~/.config/hypr/scripts/toggle-insomnia.sh"))
hl.bind(mod .. " + G", function() scratchpads.toggle("display") end)

-- Window Management
hl.bind(mod .. " + left", hl.dsp.window.swap({ direction = "left" }))
hl.bind(mod .. " + right", hl.dsp.window.swap({ direction = "right" }))
hl.bind(mod .. " + up", hl.dsp.window.swap({ direction = "up" }))
hl.bind(mod .. " + down", hl.dsp.window.swap({ direction = "down" }))
hl.bind("ALT + Tab", function() scratchpads.toggle("radar") end)
hl.bind(mod .. " + Tab", hl.dsp.focus({ last = true }))
hl.bind(mod .. " + W", function() scratchpads.toggle("radar") end)
hl.bind(mod .. " + H", hl.dsp.exec_cmd("~/.config/hypr/scripts/toggle-bt-mic.sh"))
hl.bind(mod .. " + ALT + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + J", hl.dsp.focus({ direction = "down" }))
hl.bind(mod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + L", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + F", hl.dsp.window.fullscreen())

-- Multi-Monitor Management
hl.bind(mod .. " + SHIFT + D", hl.dsp.exec_cmd("~/.config/hypr/scripts/display-menu.sh"))
hl.bind(mod .. " + comma", hl.dsp.focus({ monitor = "-1" }))
hl.bind(mod .. " + period", hl.dsp.focus({ monitor = "+1" }))
hl.bind(mod .. " + bracketleft", hl.dsp.focus({ monitor = "-1" }))
hl.bind(mod .. " + bracketright", hl.dsp.focus({ monitor = "+1" }))
hl.bind(mod .. " + SHIFT + comma", hl.dsp.window.move({ monitor = "-1" }))
hl.bind(mod .. " + SHIFT + period", hl.dsp.window.move({ monitor = "+1" }))
hl.bind(mod .. " + SHIFT + bracketleft", hl.dsp.window.move({ monitor = "-1" }))
hl.bind(mod .. " + SHIFT + bracketright", hl.dsp.window.move({ monitor = "+1" }))

-- Master Layout
hl.bind(mod .. " + SHIFT + H", hl.dsp.layout("swapwithmaster master"))
hl.bind(mod .. " + SHIFT + L", hl.dsp.layout("rollnext"))

-- Workspaces (Native C++/Lua Desktop Space Engine)
for i = 1, 9 do
    hl.bind(mod .. " + " .. i, function() spaces.switch_desktop_space(i) end)
    hl.bind(mod .. " + SHIFT + " .. i, function() spaces.move_window_to_space(i) end)
end

-- Scratchpad Toggles & Multi-Deck Controls (Native C++/Lua Engine)
hl.bind(mod .. " + Escape", function() scratchpads.toggle("magic") end)
hl.bind(mod .. " + SHIFT + Escape", hl.dsp.window.move({ workspace = "special:magic" }))
hl.bind(mod .. " + grave", function() scratchpads.toggle("magic") end)
hl.bind(mod .. " + SHIFT + grave", hl.dsp.window.move({ workspace = "special:magic" }))

-- Single-Monitor Scratchpads
hl.bind(mod .. " + Z", function() scratchpads.toggle("music") end)
hl.bind(mod .. " + X", function() scratchpads.toggle("discord") end)
hl.bind(mod .. " + C", function() scratchpads.toggle("calendar") end)
hl.bind(mod .. " + D", function() scratchpads.toggle("dev") end)
hl.bind(mod .. " + V", function() scratchpads.toggle("notes") end)

-- Bloat Escape (TRV30 Master Deck Command Center: Super + Plus / Equal)
hl.bind(mod .. " + equal", function() scratchpads.toggle("center") end)
hl.bind(mod .. " + plus", function() scratchpads.toggle("center") end)
hl.bind(mod .. " + SHIFT + equal", function() scratchpads.toggle("center") end)
hl.bind(mod .. " + SHIFT + plus", function() scratchpads.toggle("center") end)
hl.bind(mod .. " + KP_Add", function() scratchpads.toggle("center") end)

-- Panoramic (Multi-Monitor Coordinated) Scratchpads (Native C++/Lua Engine)
hl.bind(mod .. " + SHIFT + Z", function() scratchpads.toggle_panoramic("music") end)
hl.bind(mod .. " + SHIFT + X", function() scratchpads.toggle_panoramic("comms") end)
hl.bind(mod .. " + SHIFT + V", function() scratchpads.toggle_panoramic("research") end)
hl.bind(mod .. " + CTRL + equal", function() scratchpads.toggle_panoramic("cockpit") end)

-- Scratchpad Stacking & Concurrent Mode (Native C++/Lua Engine)
hl.bind(mod .. " + CTRL + Z", function() scratchpads.toggle("music", true) end)
hl.bind(mod .. " + CTRL + X", function() scratchpads.toggle("discord", true) end)
hl.bind(mod .. " + CTRL + C", function() scratchpads.toggle("calendar", true) end)
hl.bind(mod .. " + CTRL + D", function() scratchpads.toggle("dev", true) end)
hl.bind(mod .. " + CTRL + V", function() scratchpads.toggle("notes", true) end)
hl.bind(mod .. " + CTRL + G", function() scratchpads.toggle("display", true) end)

-- Scratchpad Anchor Lock & HUD Pin (Super+Y and Super+Shift+P)
hl.bind(mod .. " + Y", scratchpads.toggle_anchor)
hl.bind(mod .. " + SHIFT + P", scratchpads.toggle_anchor)

-- Media Controls
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("~/.config/hypr/scripts/osd.sh play"))
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("~/.config/hypr/scripts/osd.sh next"))
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("~/.config/hypr/scripts/osd.sh prev"))

-- Volume & Brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("~/.config/hypr/scripts/osd.sh vol-up"), { repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("~/.config/hypr/scripts/osd.sh vol-down"), { repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("~/.config/hypr/scripts/osd.sh vol-mute"))
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 5%+"), { repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { repeating = true })

-- Delete Key (60% Keyboard: Super + Backspace -> Del)
hl.bind(mod .. " + Backspace", hl.dsp.send_shortcut({ mods = "", key = "Delete", window = "activewindow" }), { repeating = true })
hl.bind(mod .. " + SHIFT + Backspace", hl.dsp.send_shortcut({ mods = "SHIFT", key = "Delete", window = "activewindow" }), { repeating = true })

-- Notification Controls (Dismiss)
hl.bind(mod .. " + N", hl.dsp.exec_cmd("dunstctl close"))
hl.bind(mod .. " + SHIFT + N", hl.dsp.exec_cmd("dunstctl close-all"))

-- Screenshot
hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh"))
hl.bind(mod .. " + P", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh"))
hl.bind(mod .. " + ALT + S", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot-ocr.sh"))
hl.bind(mod .. " + ALT + P", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot-ocr.sh"))

-- Mouse binds
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Laptop Lid Switch (Clamshell / Insomnia Mode)
hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("bash ~/.config/hypr/scripts/lid-handler.sh close"), { locked = true })
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd("bash ~/.config/hypr/scripts/lid-handler.sh open"), { locked = true })

-- ┌─────────────────────────────────────────────────────────────┐
-- │ 9. AUTOSTART (自動起動)                                     │
-- └─────────────────────────────────────────────────────────────┘
hl.on("hyprland.start", function()
    -- System tray & core utilities
    hl.exec_cmd("waybar -c ~/.config/waybar/config-top -s ~/.config/waybar/style.css")
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("blueman-applet")
    hl.exec_cmd("/usr/lib/hyprpolkitagent/hyprpolkitagent")
    hl.exec_cmd("dunst")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("copyq --start-server")
    hl.exec_cmd("bash ~/.config/hypr/scripts/toggle-vcr.sh")

    -- Background utilities & daemons
    hl.exec_cmd("python3 ~/.config/hypr/scripts/audio-guard.py")
    hl.exec_cmd("python3 ~/.config/hypr/scripts/session-restorer.py")
    hl.exec_cmd("env WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1 python3 ~/.config/hypr/desktop-radar/app.py")

    -- Auto-launch apps
    hl.exec_cmd("vivaldi-stable")
    hl.exec_cmd("kitty")
    hl.exec_cmd("vivaldi-stable --app=https://calendar.notion.so")
    hl.exec_cmd("spotify-launcher --skip-update")
    hl.exec_cmd("vesktop")
end)
