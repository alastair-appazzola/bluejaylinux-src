#!/bin/bash
# BluejayLinux Window Manager - Manages application windows and desktop interactions
# Provides window stacking, focus management, and desktop environment

set -e

WM_CONFIG="/etc/bluejay/window-manager.conf"
WM_STATE="/run/bluejay-wm"
WM_FIFO="/run/bluejay-wm.fifo"
WINDOWS_DIR="/run/bluejay-windows"

log_wm() {
    echo "[$(date '+%H:%M:%S')] WM: $1" | tee -a /var/log/bluejay-wm.log
}

log_error() {
    echo "[$(date '+%H:%M:%S')] ERROR: $1" | tee -a /var/log/bluejay-wm.log >&2
}

log_success() {
    echo "[$(date '+%H:%M:%S')] SUCCESS: $1" | tee -a /var/log/bluejay-wm.log
}

# Initialize window manager
init_window_manager() {
    log_wm "Initializing BluejayLinux Window Manager..."
    
    # Create directories
    mkdir -p "$(dirname "$WM_CONFIG")"
    mkdir -p "$(dirname "$WM_STATE")"
    mkdir -p "$WINDOWS_DIR"
    mkdir -p /var/log
    mkdir -p /opt/bluejay/bin
    
    # Create window manager configuration
    create_wm_config
    
    # Initialize window manager state
    init_wm_state
    
    # Create window manager FIFO
    if [ ! -p "$WM_FIFO" ]; then
        mkfifo "$WM_FIFO"
        chmod 666 "$WM_FIFO"
    fi
    
    log_success "Window Manager initialized"
}

# Create window manager configuration
create_wm_config() {
    cat > "$WM_CONFIG" << 'EOF'
# BluejayLinux Window Manager Configuration

# Window appearance
WINDOW_BORDER_WIDTH=2
WINDOW_TITLE_HEIGHT=24
WINDOW_BORDER_COLOR=#404040
WINDOW_ACTIVE_BORDER_COLOR=#0078d4
WINDOW_TITLE_COLOR=#ffffff
WINDOW_TITLE_BG_COLOR=#2d2d2d

# Desktop settings
DESKTOP_COLOR=#1e1e1e
WALLPAPER_PATH=/usr/share/backgrounds/bluejay-default.png
SHOW_DESKTOP_ICONS=true

# Taskbar settings
TASKBAR_HEIGHT=32
TASKBAR_COLOR=#404040
TASKBAR_POSITION=bottom
SHOW_SYSTEM_TRAY=true

# Window behavior
AUTO_RAISE=true
FOCUS_FOLLOWS_MOUSE=false
SNAP_TO_EDGES=true
SNAP_DISTANCE=10

# Desktop effects
ENABLE_SHADOWS=true
ENABLE_ANIMATIONS=true
ENABLE_TRANSPARENCY=true
ENABLE_BLUR=false
ANIMATION_DURATION=200
FADE_DURATION=150
SHADOW_OPACITY=0.5

# Workspace settings
WORKSPACE_COUNT=4
DEFAULT_WORKSPACE=1
SHOW_WORKSPACE_SWITCHER=true
WORKSPACE_SWITCH_ANIMATION=slide

# Compositing settings
ENABLE_COMPOSITING=true
VSYNC_ENABLED=true
HARDWARE_ACCELERATION=auto

# Application menu
SHOW_APPLICATION_MENU=true
MENU_BUTTON_TEXT="Applications"
EOF
    
    log_success "Window manager configuration created"
}

# Initialize window manager state
init_wm_state() {
    cat > "$WM_STATE" << 'EOF'
# BluejayLinux Window Manager State
wm_running=false
window_count=0
active_window=0
focused_window=0
current_workspace=1
next_window_id=1
desktop_visible=true
EOF
    
    log_success "Window manager state initialized"
}

# Start window manager
start_window_manager() {
    log_wm "Starting BluejayLinux Window Manager..."
    
    # Create window manager daemon
    cat > /opt/bluejay/bin/bluejay-wm-daemon << 'EOF'
#!/bin/bash
# BluejayLinux Window Manager Daemon

WM_STATE="/run/bluejay-wm"
WM_FIFO="/run/bluejay-wm.fifo"
INPUT_FIFO="/run/bluejay-input.fifo"
DISPLAY_FIFO="/run/bluejay-wm.fifo"
WINDOWS_DIR="/run/bluejay-windows"
LOG_FILE="/var/log/bluejay-wm.log"

# Window state structure
declare -A windows
declare -A window_titles
declare -A window_positions
declare -A window_sizes
declare -A window_states
declare -A window_pids

log_daemon() {
    echo "[$(date '+%H:%M:%S')] WM_DAEMON: $1" >> "$LOG_FILE"
}

# Load window manager state
load_wm_state() {
    if [ -f "$WM_STATE" ]; then
        . "$WM_STATE"
    else
        wm_running=false
        window_count=0
        active_window=0
        focused_window=0
        current_workspace=1
        next_window_id=1
        desktop_visible=true
    fi
}

# Save window manager state
save_wm_state() {
    cat > "$WM_STATE" << EOF
wm_running=$wm_running
window_count=$window_count
active_window=$active_window
focused_window=$focused_window
current_workspace=$current_workspace
next_window_id=$next_window_id
desktop_visible=$desktop_visible
EOF
}

# Create a new window
create_window() {
    local title="$1"
    local x="${2:-100}"
    local y="${3:-100}"
    local width="${4:-400}"
    local height="${5:-300}"
    local pid="$6"
    
    load_wm_state
    
    local window_id="$next_window_id"
    next_window_id=$((next_window_id + 1))
    window_count=$((window_count + 1))
    
    # Store window information
    windows[$window_id]=1
    window_titles[$window_id]="$title"
    window_positions[$window_id]="$x,$y"
    window_sizes[$window_id]="$width,$height"
    window_states[$window_id]="normal"
    window_pids[$window_id]="$pid"
    
    # Create window state file
    cat > "$WINDOWS_DIR/window-$window_id.state" << EOF
id=$window_id
title=$title
x=$x
y=$y
width=$width
height=$height
state=normal
workspace=$current_workspace
pid=$pid
visible=true
focused=false
EOF
    
    # Focus the new window
    focused_window="$window_id"
    active_window="$window_id"
    
    save_wm_state
    
    # Draw the window
    draw_window "$window_id"
    
    # Update taskbar
    update_taskbar
    
    log_daemon "Created window $window_id: '$title' at ($x,$y) ${width}x${height}"
    
    echo "$window_id"
}

# Draw a window
draw_window() {
    local window_id="$1"
    
    if [ ! -f "$WINDOWS_DIR/window-$window_id.state" ]; then
        return 1
    fi
    
    # Load window state
    . "$WINDOWS_DIR/window-$window_id.state"
    
    local border_color="#404040"
    if [ "$window_id" = "$focused_window" ]; then
        border_color="#0078d4"
    fi
    
    # Draw window border
    /opt/bluejay/bin/bluejay-graphics rect "$((x-2))" "$((y-24))" "$((width+4))" "$((height+26))" "${border_color#\#}"
    
    # Draw title bar
    /opt/bluejay/bin/bluejay-graphics rect "$x" "$((y-22))" "$width" "22" "2d2d2d"
    
    # Draw title text
    /opt/bluejay/bin/bluejay-graphics text "$((x+5))" "$((y-5))" "$title" "ffffff"
    
    # Draw window controls (close button)
    local close_x=$((x + width - 20))
    local close_y=$((y - 20))
    /opt/bluejay/bin/bluejay-graphics rect "$close_x" "$close_y" "16" "16" "ff4444"
    /opt/bluejay/bin/bluejay-graphics text "$((close_x+5))" "$((close_y+12))" "X" "ffffff"
    
    # Draw window content area
    /opt/bluejay/bin/bluejay-graphics rect "$x" "$y" "$width" "$height" "f0f0f0"
    
    log_daemon "Drew window $window_id"
}

# Move window
move_window() {
    local window_id="$1"
    local new_x="$2"
    local new_y="$3"
    
    if [ ! -f "$WINDOWS_DIR/window-$window_id.state" ]; then
        return 1
    fi
    
    # Load current state
    . "$WINDOWS_DIR/window-$window_id.state"
    
    # Clear old position
    /opt/bluejay/bin/bluejay-graphics rect "$((x-2))" "$((y-24))" "$((width+4))" "$((height+26))" "1e1e1e"
    
    # Update position
    x="$new_x"
    y="$new_y"
    
    # Save new state
    cat > "$WINDOWS_DIR/window-$window_id.state" << EOF
id=$window_id
title=$title
x=$x
y=$y
width=$width
height=$height
state=$state
workspace=$workspace
pid=$pid
visible=$visible
focused=$focused
EOF
    
    # Redraw window
    draw_window "$window_id"
    
    log_daemon "Moved window $window_id to ($new_x, $new_y)"
}

# Resize window
resize_window() {
    local window_id="$1"
    local new_width="$2"
    local new_height="$3"
    
    if [ ! -f "$WINDOWS_DIR/window-$window_id.state" ]; then
        return 1
    fi
    
    # Load current state
    . "$WINDOWS_DIR/window-$window_id.state"
    
    # Clear old window
    /opt/bluejay/bin/bluejay-graphics rect "$((x-2))" "$((y-24))" "$((width+4))" "$((height+26))" "1e1e1e"
    
    # Update size
    width="$new_width"
    height="$new_height"
    
    # Save new state
    cat > "$WINDOWS_DIR/window-$window_id.state" << EOF
id=$window_id
title=$title
x=$x
y=$y
width=$width
height=$height
state=$state
workspace=$workspace
pid=$pid
visible=$visible
focused=$focused
EOF
    
    # Redraw window
    draw_window "$window_id"
    
    log_daemon "Resized window $window_id to ${new_width}x${new_height}"
}

# Focus window
focus_window() {
    local window_id="$1"
    
    if [ ! -f "$WINDOWS_DIR/window-$window_id.state" ]; then
        return 1
    fi
    
    load_wm_state
    
    # Unfocus previous window
    if [ "$focused_window" != "0" ] && [ -f "$WINDOWS_DIR/window-$focused_window.state" ]; then
        draw_window "$focused_window"
    fi
    
    # Focus new window
    focused_window="$window_id"
    active_window="$window_id"
    
    save_wm_state
    
    # Redraw with focus
    draw_window "$window_id"
    
    # Update taskbar
    update_taskbar
    
    log_daemon "Focused window $window_id"
}

# Close window
close_window() {
    local window_id="$1"
    
    if [ ! -f "$WINDOWS_DIR/window-$window_id.state" ]; then
        return 1
    fi
    
    # Load window state
    . "$WINDOWS_DIR/window-$window_id.state"
    
    # Clear window from screen
    /opt/bluejay/bin/bluejay-graphics rect "$((x-2))" "$((y-24))" "$((width+4))" "$((height+26))" "1e1e1e"
    
    # Kill associated process if it exists
    if [ "$pid" != "" ] && [ "$pid" != "0" ]; then
        kill "$pid" 2>/dev/null || true
    fi
    
    # Remove window state file
    rm -f "$WINDOWS_DIR/window-$window_id.state"
    
    # Update global state
    load_wm_state
    window_count=$((window_count - 1))
    
    # Update focus if this was the focused window
    if [ "$focused_window" = "$window_id" ]; then
        # Find another window to focus
        local new_focus=0
        for state_file in "$WINDOWS_DIR"/window-*.state; do
            if [ -f "$state_file" ]; then
                local other_id=$(basename "$state_file" .state | cut -d- -f2)
                if [ "$other_id" != "$window_id" ]; then
                    new_focus="$other_id"
                    break
                fi
            fi
        done
        focused_window="$new_focus"
        active_window="$new_focus"
    fi
    
    save_wm_state
    
    # Update taskbar
    update_taskbar
    
    log_daemon "Closed window $window_id"
}

# Update taskbar
update_taskbar() {
    # Get display dimensions
    local display_width=1024
    local display_height=768
    local taskbar_height=32
    
    if [ -f /run/bluejay-display ]; then
        . /run/bluejay-display
    fi
    
    # Clear taskbar area
    /opt/bluejay/bin/bluejay-graphics rect 0 "$((display_height - taskbar_height))" "$display_width" "$taskbar_height" "404040"
    
    # Draw application menu button
    /opt/bluejay/bin/bluejay-graphics rect 5 "$((display_height - taskbar_height + 5))" 80 22 "606060"
    /opt/bluejay/bin/bluejay-graphics text 10 "$((display_height - 10))" "Applications" "ffffff"
    
    # Draw window buttons
    local x_offset=100
    for state_file in "$WINDOWS_DIR"/window-*.state; do
        if [ -f "$state_file" ]; then
            . "$state_file"
            
            local button_color="606060"
            if [ "$id" = "$focused_window" ]; then
                button_color="0078d4"
            fi
            
            /opt/bluejay/bin/bluejay-graphics rect "$x_offset" "$((display_height - taskbar_height + 5))" 120 22 "$button_color"
            
            # Truncate title if too long
            local display_title="$title"
            if [ ${#display_title} -gt 15 ]; then
                display_title="${display_title:0:12}..."
            fi
            
            /opt/bluejay/bin/bluejay-graphics text "$((x_offset + 5))" "$((display_height - 10))" "$display_title" "ffffff"
            
            x_offset=$((x_offset + 125))
        fi
    done
    
    # Draw system tray area
    local tray_x=$((display_width - 200))
    /opt/bluejay/bin/bluejay-graphics rect "$tray_x" "$((display_height - taskbar_height + 5))" 190 22 "606060"
    
    # Draw system indicators
    draw_system_indicators "$tray_x" "$((display_height - taskbar_height + 5))"
    
    # Draw clock
    local current_time=$(date '+%H:%M')
    /opt/bluejay/bin/bluejay-graphics text "$((tray_x + 145))" "$((display_height - 10))" "$current_time" "ffffff"
}

# Draw system indicators in tray
draw_system_indicators() {
    local tray_x="$1"
    local tray_y="$2"
    local x_pos=$((tray_x + 5))
    
    # Network status indicator
    if ip route | grep -q default; then
        # Network connected
        /opt/bluejay/bin/bluejay-graphics rect "$x_pos" "$((tray_y + 3))" 16 16 "00aa00"
        /opt/bluejay/bin/bluejay-graphics text "$((x_pos + 2))" "$((tray_y + 15))" "NET" "ffffff"
    else
        # Network disconnected
        /opt/bluejay/bin/bluejay-graphics rect "$x_pos" "$((tray_y + 3))" 16 16 "aa0000"
        /opt/bluejay/bin/bluejay-graphics text "$((x_pos + 2))" "$((tray_y + 15))" "NET" "ffffff"
    fi
    x_pos=$((x_pos + 20))
    
    # Audio status indicator
    local volume_level=$(amixer get Master 2>/dev/null | grep -oP '\[\K[0-9]+(?=%\])' | head -1 || echo "0")
    if [ "$volume_level" -gt 0 ]; then
        /opt/bluejay/bin/bluejay-graphics rect "$x_pos" "$((tray_y + 3))" 16 16 "0078d4"
        /opt/bluejay/bin/bluejay-graphics text "$((x_pos + 2))" "$((tray_y + 15))" "AUD" "ffffff"
    else
        /opt/bluejay/bin/bluejay-graphics rect "$x_pos" "$((tray_y + 3))" 16 16 "808080"
        /opt/bluejay/bin/bluejay-graphics text "$((x_pos + 2))" "$((tray_y + 15))" "MUT" "ffffff"
    fi
    x_pos=$((x_pos + 20))
    
    # Battery status indicator (if present)
    if [ -d "/sys/class/power_supply/BAT0" ]; then
        local battery_level=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo "0")
        local battery_status=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo "Unknown")
        
        local battery_color="00aa00"
        if [ "$battery_level" -lt 20 ]; then
            battery_color="aa0000"
        elif [ "$battery_level" -lt 50 ]; then
            battery_color="aaaa00"
        fi
        
        if [ "$battery_status" = "Charging" ]; then
            battery_color="00aaaa"
        fi
        
        /opt/bluejay/bin/bluejay-graphics rect "$x_pos" "$((tray_y + 3))" 16 16 "$battery_color"
        /opt/bluejay/bin/bluejay-graphics text "$((x_pos + 2))" "$((tray_y + 15))" "BAT" "ffffff"
        x_pos=$((x_pos + 20))
    fi
    
    # WiFi status indicator
    if iwconfig 2>/dev/null | grep -q "ESSID:"; then
        /opt/bluejay/bin/bluejay-graphics rect "$x_pos" "$((tray_y + 3))" 16 16 "aa00aa"
        /opt/bluejay/bin/bluejay-graphics text "$((x_pos + 2))" "$((tray_y + 15))" "WiFi" "ffffff"
    else
        /opt/bluejay/bin/bluejay-graphics rect "$x_pos" "$((tray_y + 3))" 16 16 "606060"
        /opt/bluejay/bin/bluejay-graphics text "$((x_pos + 2))" "$((tray_y + 15))" "WiFi" "ffffff"
    fi
    x_pos=$((x_pos + 25))
    
    # Workspace indicator
    local current_ws=$(get_current_workspace)
    /opt/bluejay/bin/bluejay-graphics text "$x_pos" "$((tray_y + 15))" "WS$current_ws" "ffffff"
}

# Process input events
process_input_event() {
    local event="$1"
    
    case "$event" in
        MOUSE:*)
            local mouse_info="${event#MOUSE:}"
            IFS=: read -r mouse_x mouse_y button state <<< "$mouse_info"
            
            if [ "$button" = "1" ] && [ "$state" = "true" ]; then
                # Left mouse button click
                handle_mouse_click "$mouse_x" "$mouse_y"
            fi
            ;;
        KEYBOARD:*)
            local keyboard_info="${event#KEYBOARD:}"
            IFS=: read -r key state <<< "$keyboard_info"
            
            if [ "$state" = "true" ]; then
                handle_key_press "$key"
            fi
            ;;
    esac
}

# Handle mouse click
handle_mouse_click() {
    local click_x="$1"
    local click_y="$2"
    
    # Check if click is on taskbar
    local display_height=768
    local taskbar_height=32
    if [ -f /run/bluejay-display ]; then
        . /run/bluejay-display
    fi
    
    if [ "$click_y" -gt "$((display_height - taskbar_height))" ]; then
        # Taskbar click
        if [ "$click_x" -ge 5 ] && [ "$click_x" -le 85 ]; then
            # Application menu clicked
            show_application_menu
            return
        fi
        
        # Check window buttons
        local x_offset=100
        for state_file in "$WINDOWS_DIR"/window-*.state; do
            if [ -f "$state_file" ]; then
                . "$state_file"
                
                if [ "$click_x" -ge "$x_offset" ] && [ "$click_x" -le "$((x_offset + 120))" ]; then
                    focus_window "$id"
                    return
                fi
                
                x_offset=$((x_offset + 125))
            fi
        done
        return
    fi
    
    # Check if click is on a window
    for state_file in "$WINDOWS_DIR"/window-*.state; do
        if [ -f "$state_file" ]; then
            . "$state_file"
            
            # Check if click is within window bounds (including title bar)
            if [ "$click_x" -ge "$((x-2))" ] && [ "$click_x" -le "$((x+width+2))" ] && \
               [ "$click_y" -ge "$((y-24))" ] && [ "$click_y" -le "$((y+height+2))" ]; then
                
                # Check if click is on close button
                local close_x=$((x + width - 20))
                local close_y=$((y - 20))
                if [ "$click_x" -ge "$close_x" ] && [ "$click_x" -le "$((close_x + 16))" ] && \
                   [ "$click_y" -ge "$close_y" ] && [ "$click_y" -le "$((close_y + 16))" ]; then
                    close_window "$id"
                    return
                fi
                
                # Focus this window
                focus_window "$id"
                return
            fi
        fi
    done
    
    # Click on desktop - show desktop
    show_desktop
}

# Handle key press
handle_key_press() {
    local key="$1"
    
    case "$key" in
        "Alt_L+Tab"|"Alt_R+Tab")
            # Alt+Tab window switching
            switch_to_next_window
            ;;
        "Alt_L+F4"|"Alt_R+F4")
            # Alt+F4 close window
            if [ "$focused_window" != "0" ]; then
                close_window "$focused_window"
            fi
            ;;
        "Super_L"|"Super_R")
            # Windows key - show application menu
            show_application_menu
            ;;
    esac
}

# Show application menu
show_application_menu() {
    log_daemon "Showing application menu"
    
    # Simple application menu (would be more sophisticated in real implementation)
    local menu_x=10
    local menu_y=400
    local menu_width=200
    local menu_height=300
    
    # Draw menu background
    /opt/bluejay/bin/bluejay-graphics rect "$menu_x" "$menu_y" "$menu_width" "$menu_height" "f0f0f0"
    /opt/bluejay/bin/bluejay-graphics rect "$menu_x" "$menu_y" "$menu_width" 2 "404040"
    
    # Draw menu items
    local y_offset=20
    local menu_items=("Terminal" "File Manager" "Text Editor" "Web Browser" "Settings")
    
    for item in "${menu_items[@]}"; do
        /opt/bluejay/bin/bluejay-graphics text "$((menu_x + 10))" "$((menu_y + y_offset))" "$item" "000000"
        y_offset=$((y_offset + 25))
    done
}

# Switch to next window
switch_to_next_window() {
    local next_window=0
    local found_current=false
    
    # Find next window after current focused window
    for state_file in "$WINDOWS_DIR"/window-*.state; do
        if [ -f "$state_file" ]; then
            local window_id=$(basename "$state_file" .state | cut -d- -f2)
            
            if [ "$found_current" = "true" ]; then
                next_window="$window_id"
                break
            fi
            
            if [ "$window_id" = "$focused_window" ]; then
                found_current=true
            elif [ "$next_window" = "0" ]; then
                # First window found - fallback if we're at the end
                next_window="$window_id"
            fi
        fi
    done
    
    if [ "$next_window" != "0" ]; then
        focus_window "$next_window"
    fi
}

# Show desktop
show_desktop() {
    log_daemon "Showing desktop"
    
    # Clear screen and redraw desktop
    /opt/bluejay/bin/bluejay-graphics clear "1e1e1e"
    
    # Redraw all windows
    for state_file in "$WINDOWS_DIR"/window-*.state; do
        if [ -f "$state_file" ]; then
            local window_id=$(basename "$state_file" .state | cut -d- -f2)
            draw_window "$window_id"
        fi
    done
    
    # Redraw taskbar
    update_taskbar
}

# Main event loop
main() {
    log_daemon "Window manager daemon started"
    
    load_wm_state
    wm_running=true
    save_wm_state
    
    # Initialize desktop
    show_desktop
    
    # Event processing loop
    while true; do
        # Check for window manager commands
        if [ -p "$WM_FIFO" ]; then
            while IFS= read -t 0.1 -r event <&3; do
                case "$event" in
                    CREATE_WINDOW:*)
                        local window_info="${event#CREATE_WINDOW:}"
                        IFS=: read -r title x y width height pid <<< "$window_info"
                        create_window "$title" "$x" "$y" "$width" "$height" "$pid"
                        ;;
                    CLOSE_WINDOW:*)
                        local window_id="${event#CLOSE_WINDOW:}"
                        close_window "$window_id"
                        ;;
                    FOCUS_WINDOW:*)
                        local window_id="${event#FOCUS_WINDOW:}"
                        focus_window "$window_id"
                        ;;
                    MOVE_WINDOW:*)
                        local window_info="${event#MOVE_WINDOW:}"
                        IFS=: read -r window_id x y <<< "$window_info"
                        move_window "$window_id" "$x" "$y"
                        ;;
                    RESIZE_WINDOW:*)
                        local window_info="${event#RESIZE_WINDOW:}"
                        IFS=: read -r window_id width height <<< "$window_info"
                        resize_window "$window_id" "$width" "$height"
                        ;;
                esac
            done 3< "$WM_FIFO"
        fi
        
        # Check for input events
        if [ -p "$INPUT_FIFO" ]; then
            while IFS= read -t 0.1 -r event <&4; do
                process_input_event "$event"
            done 4< "$INPUT_FIFO"
        fi
        
        # Update clock every minute
        local current_minute=$(date '+%M')
        if [ "$current_minute" != "$last_minute" ]; then
            update_taskbar
            last_minute="$current_minute"
        fi
        
        # Small sleep to prevent high CPU usage
        sleep 0.1
    done
}

main "$@"
EOF
    chmod +x /opt/bluejay/bin/bluejay-wm-daemon
    
    # Start the window manager daemon
    /opt/bluejay/bin/bluejay-wm-daemon &
    local daemon_pid=$!
    echo "$daemon_pid" > /run/bluejay-wm-daemon.pid
    
    # Update state
    . "$WM_STATE"
    wm_running=true
    cat > "$WM_STATE" << EOF
wm_running=$wm_running
window_count=$window_count
active_window=$active_window
focused_window=$focused_window
current_workspace=$current_workspace
next_window_id=$next_window_id
desktop_visible=$desktop_visible
EOF
    
    log_success "Window manager started (PID: $daemon_pid)"
}

# Stop window manager
stop_window_manager() {
    log_wm "Stopping window manager..."
    
    if [ -f /run/bluejay-wm-daemon.pid ]; then
        local pid=$(cat /run/bluejay-wm-daemon.pid)
        kill "$pid" 2>/dev/null || true
        rm -f /run/bluejay-wm-daemon.pid
        log_success "Window manager daemon stopped"
    fi
    
    # Close all windows
    for state_file in "$WINDOWS_DIR"/window-*.state; do
        if [ -f "$state_file" ]; then
            . "$state_file"
            if [ "$pid" != "" ] && [ "$pid" != "0" ]; then
                kill "$pid" 2>/dev/null || true
            fi
            rm -f "$state_file"
        fi
    done
    
    # Update state
    . "$WM_STATE"
    wm_running=false
    window_count=0
    active_window=0
    focused_window=0
    cat > "$WM_STATE" << EOF
wm_running=$wm_running
window_count=$window_count
active_window=$active_window
focused_window=$focused_window
current_workspace=$current_workspace
next_window_id=$next_window_id
desktop_visible=$desktop_visible
EOF
    
    log_success "Window manager stopped"
}

# Show window manager status
show_wm_status() {
    echo "BluejayLinux Window Manager Status"
    echo "=================================="
    echo ""
    
    # Window manager state
    if [ -f "$WM_STATE" ]; then
        . "$WM_STATE"
        echo "Window Manager Running: $wm_running"
        echo "Window Count: $window_count"
        echo "Active Window: $active_window"
        echo "Focused Window: $focused_window"
        echo "Current Workspace: $current_workspace"
        echo "Desktop Visible: $desktop_visible"
    else
        echo "Window manager not initialized"
    fi
    echo ""
    
    # List windows
    echo "Windows:"
    if [ -d "$WINDOWS_DIR" ]; then
        for state_file in "$WINDOWS_DIR"/window-*.state; do
            if [ -f "$state_file" ]; then
                . "$state_file"
                local status=""
                [ "$id" = "$focused_window" ] && status=" (focused)"
                echo "  Window $id: '$title' at ($x,$y) ${width}x${height}$status"
            fi
        done
    else
        echo "  No windows"
    fi
    echo ""
    
    # Daemon status
    echo "Window Manager Daemon:"
    if [ -f /run/bluejay-wm-daemon.pid ]; then
        local pid=$(cat /run/bluejay-wm-daemon.pid)
        if kill -0 "$pid" 2>/dev/null; then
            echo "  Running (PID: $pid)"
        else
            echo "  Not running (stale PID file)"
        fi
    else
        echo "  Not running"
    fi
}

# Create a new window
new_window() {
    local title="${1:-New Window}"
    local x="${2:-100}"
    local y="${3:-100}"
    local width="${4:-400}"
    local height="${5:-300}"
    
    if [ ! -p "$WM_FIFO" ]; then
        log_error "Window manager not running"
        return 1
    fi
    
    echo "CREATE_WINDOW:$title:$x:$y:$width:$height:$$" > "$WM_FIFO"
    log_wm "Requested new window: '$title'"
}

# Close a window
close_window_by_id() {
    local window_id="$1"
    
    if [ -z "$window_id" ]; then
        log_error "Window ID required"
        return 1
    fi
    
    if [ ! -p "$WM_FIFO" ]; then
        log_error "Window manager not running"
        return 1
    fi
    
    echo "CLOSE_WINDOW:$window_id" > "$WM_FIFO"
    log_wm "Requested close window: $window_id"
}

# Get current workspace
get_current_workspace() {
    if [ -f "$WM_STATE" ]; then
        . "$WM_STATE"
        echo "$current_workspace"
    else
        echo "1"
    fi
}

# Switch to workspace
switch_workspace() {
    local workspace_num="$1"
    
    if [ -z "$workspace_num" ] || [ "$workspace_num" -lt 1 ] || [ "$workspace_num" -gt 4 ]; then
        log_error "Invalid workspace number (1-4)"
        return 1
    fi
    
    if [ ! -p "$WM_FIFO" ]; then
        log_error "Window manager not running"
        return 1
    fi
    
    echo "SWITCH_WORKSPACE:$workspace_num" > "$WM_FIFO"
    log_wm "Switched to workspace $workspace_num"
}

# Toggle desktop visibility
toggle_desktop() {
    if [ ! -p "$WM_FIFO" ]; then
        log_error "Window manager not running"
        return 1
    fi
    
    echo "TOGGLE_DESKTOP" > "$WM_FIFO"
    log_wm "Toggled desktop visibility"
}

# Apply window effects
apply_window_effects() {
    local window_id="$1"
    local effect="$2"
    
    if [ -z "$window_id" ] || [ -z "$effect" ]; then
        log_error "Window ID and effect type required"
        return 1
    fi
    
    if [ ! -p "$WM_FIFO" ]; then
        log_error "Window manager not running"
        return 1
    fi
    
    case "$effect" in
        fade_in|fade_out|minimize|maximize|shadow|blur)
            echo "WINDOW_EFFECT:$window_id:$effect" > "$WM_FIFO"
            log_wm "Applied effect '$effect' to window $window_id"
            ;;
        *)
            log_error "Unknown effect: $effect"
            return 1
            ;;
    esac
}

# Main command handler
main() {
    local command="${1:-help}"
    
    case "$command" in
        init)
            init_window_manager
            ;;
        start)
            start_window_manager
            ;;
        stop)
            stop_window_manager
            ;;
        restart)
            stop_window_manager
            sleep 2
            start_window_manager
            ;;
        status)
            show_wm_status
            ;;
        new-window)
            new_window "$2" "$3" "$4" "$5" "$6"
            ;;
        close-window)
            close_window_by_id "$2"
            ;;
        switch-workspace)
            switch_workspace "$2"
            ;;
        toggle-desktop)
            toggle_desktop
            ;;
        window-effect)
            apply_window_effects "$2" "$3"
            ;;
        help|*)
            echo "BluejayLinux Window Manager"
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  init                           Initialize window manager"
            echo "  start                          Start window manager"
            echo "  stop                           Stop window manager"
            echo "  restart                        Restart window manager"
            echo "  status                         Show window manager status"
            echo "  new-window [title] [x] [y] [w] [h]  Create new window"
            echo "  close-window <id>              Close window by ID"
            echo "  switch-workspace <num>         Switch to workspace (1-4)"
            echo "  toggle-desktop                 Show/hide desktop"
            echo "  window-effect <id> <effect>    Apply effect to window"
            echo "  help                           Show this help"
            ;;
    esac
}

main "$@"