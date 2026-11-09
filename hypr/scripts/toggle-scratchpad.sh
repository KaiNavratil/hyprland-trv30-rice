#!/bin/bash

TARGET=$1
MODE=$2


# Focused monitor
CURRENT_MON=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name')
# Is the target currently active on the focused monitor?
ACTIVE=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .specialWorkspace.name' | sed 's/special://')

# Is the target currently open on ANY monitor?
OPEN_ON_MON=$(hyprctl monitors -j | jq -r ".[] | select(.specialWorkspace.name == \"special:$TARGET\") | .name" | head -n 1)

# Check if the target scratchpad actually has any windows in it
WINDOWS=$(hyprctl workspaces -j | jq ".[] | select(.name == \"special:$TARGET\") | .windows")

if [ "$TARGET" != "magic" ]; then
    if [ -z "$WINDOWS" ] || [ "$WINDOWS" -eq 0 ]; then
        # Before launching a new instance, check if the app window already exists on another workspace
        TARGET_CLASS=""
        case "$TARGET" in
            music) TARGET_CLASS="Spotify" ;;
            discord) TARGET_CLASS="vesktop" ;;
            calendar) TARGET_CLASS="vivaldi-calendar" ;;
            dev) TARGET_CLASS="antigravity-ide" ;;
            center) TARGET_CLASS="commandcenter|command-center|com.tokyo.commandcenter" ;;
            notes) TARGET_CLASS="notes-term" ;;
            radar) TARGET_CLASS="com.tokyo.radar" ;;
            display) TARGET_CLASS="com.tokyo.displaydeck|display-deck" ;;
        esac

        if [ -n "$TARGET_CLASS" ]; then
            EXISTING_ADDR=$(hyprctl clients -j | jq -r ".[] | select(.class | test(\"$TARGET_CLASS\"; \"i\")) | .address" | head -n 1)
            if [ -n "$EXISTING_ADDR" ] && [ "$EXISTING_ADDR" != "null" ]; then
                hyprctl dispatch movetoworkspacesilent "special:$TARGET,address:$EXISTING_ADDR" >/dev/null 2>&1
                WINDOWS=1
            fi
        fi
    fi

    if [ -z "$WINDOWS" ] || [ "$WINDOWS" -eq 0 ]; then
        # Prevent spamming launches
        if [ -f "/tmp/scratchpad_launch_$TARGET" ]; then
            # Check if the lockfile is older than 3 seconds
            if [ $(($(date +%s) - $(stat -c %Y "/tmp/scratchpad_launch_$TARGET"))) -gt 3 ]; then
                rm -f "/tmp/scratchpad_launch_$TARGET"
            else
                # Still booting, just toggle the space
                WINDOWS=1 
            fi
        fi
        
        if [ -z "$WINDOWS" ] || [ "$WINDOWS" -eq 0 ]; then
            touch "/tmp/scratchpad_launch_$TARGET"
            # The scratchpad is empty (app is closed). Launch the app!
            if [ "$TARGET" == "discord" ]; then
                hyprctl dispatch exec "[workspace special:discord silent] vesktop"
            elif [ "$TARGET" == "calendar" ]; then
                hyprctl dispatch exec "[workspace special:calendar silent] vivaldi-stable --app=https://calendar.notion.so"
            elif [ "$TARGET" == "music" ]; then
                hyprctl dispatch exec "[workspace special:music silent] spotify-launcher --skip-update"
            elif [ "$TARGET" == "dev" ]; then
                hyprctl dispatch exec "[workspace special:dev silent] /opt/antigravity-ide/antigravity-ide"
            elif [ "$TARGET" == "center" ]; then
                hyprctl dispatch exec "[workspace special:center silent] env WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1 python3 ~/.config/hypr/command-center/app.py"
            elif [ "$TARGET" == "radar" ]; then
                hyprctl dispatch exec "[workspace special:radar silent] env WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1 python3 ~/.config/hypr/desktop-radar/app.py"
            elif [ "$TARGET" == "display" ]; then
                hyprctl dispatch exec "[workspace special:display silent] env WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1 python3 ~/.config/hypr/display-deck/app.py"
            fi
            # Give the compositor a tiny moment to register the launch
            sleep 0.2
        fi
    fi
fi

# Check if target is currently active/focused on this monitor
IS_TARGET_ACTIVE=false
if [ "$OPEN_ON_MON" == "$CURRENT_MON" ]; then
    IS_TARGET_ACTIVE=true
fi
CURR_ACTIVE_WS=$(hyprctl activewindow -j 2>/dev/null | jq -r '.workspace.name // ""')
if [ "$CURR_ACTIVE_WS" == "special:$TARGET" ]; then
    IS_TARGET_ACTIVE=true
fi

if [ "$IS_TARGET_ACTIVE" = true ]; then
    # Target is already open and active/focused on THIS monitor: hide it and remove anchor if any
    rm -f "/tmp/scratchpad_anchored_$TARGET"

    # Save fullscreen state if any window on this scratchpad is fullscreen
    FS_ADDR=$(hyprctl clients -j | jq -r ".[] | select(.workspace.name == \"special:$TARGET\" and .fullscreen > 0) | .address" | head -n 1)
    if [ -n "$FS_ADDR" ] && [ "$FS_ADDR" != "null" ]; then
        echo "$FS_ADDR" > "/tmp/scratchpad_fullscreen_$TARGET"
    else
        rm -f "/tmp/scratchpad_fullscreen_$TARGET"
    fi

    # Save last focused window on this scratchpad
    LAST_FOCUSED=$(hyprctl activewindow -j | jq -r '.address')
    if [ -n "$LAST_FOCUSED" ] && [ "$LAST_FOCUSED" != "null" ]; then
        IS_IN_SP=$(hyprctl clients -j | jq -r ".[] | select(.address == \"$LAST_FOCUSED\" and .workspace.name == \"special:$TARGET\") | .address")
        if [ -n "$IS_IN_SP" ] && [ "$IS_IN_SP" != "null" ]; then
            echo "$LAST_FOCUSED" > "/tmp/scratchpad_lastfocus_$TARGET"
        fi
    fi

    hyprctl dispatch togglespecialworkspace "$TARGET"
else
    # Target is NOT open on THIS monitor.
    # If it is open on ANOTHER monitor, close it on that monitor first!
    if [ -n "$OPEN_ON_MON" ] && [ "$OPEN_ON_MON" != "$CURRENT_MON" ]; then
        hyprctl dispatch focusmonitor "$OPEN_ON_MON" >/dev/null 2>&1
        hyprctl dispatch togglespecialworkspace "$TARGET" >/dev/null 2>&1
        hyprctl dispatch focusmonitor "$CURRENT_MON" >/dev/null 2>&1
    fi

    # Lock this scratchpad strictly to the currently focused monitor so it only takes up 1 monitor
    if [ -n "$CURRENT_MON" ]; then
        GAP_OUT=60
        GAP_IN=0
        NO_BORDER="false"
        if [ "$TARGET" == "center" ] || [ "$TARGET" == "dev" ] || [ "$TARGET" == "antigravity" ] || [ "$TARGET" == "radar" ] || [ "$TARGET" == "display" ] || [ "$TARGET" == "magic" ]; then
            GAP_OUT=0
            GAP_IN=0
            NO_BORDER="true"
        elif [ "$TARGET" == "notes" ]; then
            GAP_OUT=60
            GAP_IN=4
            NO_BORDER="false"
        fi
        hyprctl eval "hl.workspace_rule({ workspace = 'special:$TARGET', gaps_out = $GAP_OUT, gaps_in = $GAP_IN, no_border = $NO_BORDER, monitor = '$CURRENT_MON' })" >/dev/null 2>&1
    fi

    # Only hide currently active scratchpad if explicit single/exclusive mode requested (allows overlapping by default!)
    if [ ! -z "$ACTIVE" ] && [ "$ACTIVE" != "$TARGET" ]; then
        if [ "$MODE" == "--exclusive" ] || [ "$MODE" == "--single" ]; then
            rm -f "/tmp/scratchpad_anchored_$ACTIVE"

            # Preserve any fullscreen window state on the active scratchpad before stowing it
            FS_ADDR_ACTIVE=$(hyprctl clients -j | jq -r ".[] | select(.workspace.name == \"special:$ACTIVE\" and .fullscreen > 0) | .address" | head -n 1)
            if [ -n "$FS_ADDR_ACTIVE" ] && [ "$FS_ADDR_ACTIVE" != "null" ]; then
                echo "$FS_ADDR_ACTIVE" > "/tmp/scratchpad_fullscreen_$ACTIVE"
            else
                rm -f "/tmp/scratchpad_fullscreen_$ACTIVE"
            fi

            LAST_FOCUSED_ACTIVE=$(hyprctl activewindow -j | jq -r '.address')
            if [ -n "$LAST_FOCUSED_ACTIVE" ] && [ "$LAST_FOCUSED_ACTIVE" != "null" ]; then
                IS_IN_SP_ACTIVE=$(hyprctl clients -j | jq -r ".[] | select(.address == \"$LAST_FOCUSED_ACTIVE\" and .workspace.name == \"special:$ACTIVE\") | .address")
                if [ -n "$IS_IN_SP_ACTIVE" ] && [ "$IS_IN_SP_ACTIVE" != "null" ]; then
                    echo "$LAST_FOCUSED_ACTIVE" > "/tmp/scratchpad_lastfocus_$ACTIVE"
                fi
            fi

            hyprctl dispatch togglespecialworkspace "$ACTIVE"
        fi
    fi

    # Bind and migrate the special workspace and its windows to CURRENT_MON
    hyprctl dispatch moveworkspacetomonitor "special:$TARGET" "$CURRENT_MON" >/dev/null 2>&1
    for addr in $(hyprctl clients -j | jq -r ".[] | select(.workspace.name == \"special:$TARGET\") | .address"); do
        hyprctl dispatch movetoworkspacesilent "special:$TARGET,address:$addr" >/dev/null 2>&1
    done

    # Now show the target on this monitor (allows overlapping with existing scratchpads!)
    hyprctl dispatch togglespecialworkspace "$TARGET"
    hyprctl dispatch moveworkspacetomonitor "special:$TARGET" "$CURRENT_MON" >/dev/null 2>&1
    
    # Ensure all scratchpad windows are tiled so Hyprland enforces exact workspace margins (gapsout:60 or gapsout:0)
    for addr in $(hyprctl clients -j | jq -r ".[] | select(.workspace.name == \"special:$TARGET\") | .address"); do
        hyprctl dispatch movetoworkspacesilent "special:$TARGET,address:$addr" >/dev/null 2>&1
        hyprctl dispatch settiled address:$addr >/dev/null 2>&1
    done

    # Window focus and fullscreen restoration
    SAVED_FS=""
    [ -f "/tmp/scratchpad_fullscreen_$TARGET" ] && SAVED_FS=$(cat "/tmp/scratchpad_fullscreen_$TARGET")

    # 1. Check if a window in this scratchpad is already fullscreen in Hyprland
    CURR_FS=$(hyprctl clients -j | jq -r ".[] | select(.workspace.name == \"special:$TARGET\" and .fullscreen > 0) | .address" | head -n 1)

    if [ -n "$CURR_FS" ] && [ "$CURR_FS" != "null" ]; then
        # Window is already fullscreen in Hyprland! Focus it to ensure input focus without disturbing fullscreen
        hyprctl dispatch focuswindow address:$CURR_FS >/dev/null 2>&1
    elif [ -n "$SAVED_FS" ] && [ "$SAVED_FS" != "null" ]; then
        # Window was fullscreen when stowed, restore fullscreen
        FS_EXISTS=$(hyprctl clients -j | jq -r ".[] | select(.address == \"$SAVED_FS\" and .workspace.name == \"special:$TARGET\") | .address")
        if [ -n "$FS_EXISTS" ] && [ "$FS_EXISTS" != "null" ]; then
            hyprctl dispatch focuswindow address:$SAVED_FS >/dev/null 2>&1
            hyprctl dispatch fullscreen 0 >/dev/null 2>&1
        fi
    else
        # Not fullscreen: prefer workspace's lastwindow or saved lastfocus over arbitrary head -n 1
        WS_LAST=$(hyprctl workspaces -j | jq -r ".[] | select(.name == \"special:$TARGET\") | .lastwindow")
        SAVED_FOCUS=""
        [ -f "/tmp/scratchpad_lastfocus_$TARGET" ] && SAVED_FOCUS=$(cat "/tmp/scratchpad_lastfocus_$TARGET")

        TARGET_FOCUS=""
        if [ -n "$WS_LAST" ] && [ "$WS_LAST" != "null" ] && [ "$WS_LAST" != "0x0" ]; then
            TARGET_FOCUS=$(hyprctl clients -j | jq -r ".[] | select(.address == \"$WS_LAST\" and .workspace.name == \"special:$TARGET\") | .address")
        fi
        if [ -z "$TARGET_FOCUS" ] || [ "$TARGET_FOCUS" == "null" ]; then
            if [ -n "$SAVED_FOCUS" ] && [ "$SAVED_FOCUS" != "null" ]; then
                TARGET_FOCUS=$(hyprctl clients -j | jq -r ".[] | select(.address == \"$SAVED_FOCUS\" and .workspace.name == \"special:$TARGET\") | .address")
            fi
        fi
        if [ -z "$TARGET_FOCUS" ] || [ "$TARGET_FOCUS" == "null" ]; then
            TARGET_FOCUS=$(hyprctl clients -j | jq -r ".[] | select(.workspace.name == \"special:$TARGET\") | .address" | head -n 1)
        fi

        if [ -n "$TARGET_FOCUS" ] && [ "$TARGET_FOCUS" != "null" ]; then
            hyprctl dispatch focuswindow address:$TARGET_FOCUS >/dev/null 2>&1
        fi
    fi
    
    if [ "$TARGET" == "notes" ]; then
        copyq show
    fi
fi

# Force Waybar to update the scratchpad indicator immediately and after animation
( sleep 0.1 ; pkill -RTMIN+1 waybar ; sleep 0.3 ; pkill -RTMIN+1 waybar ) &
