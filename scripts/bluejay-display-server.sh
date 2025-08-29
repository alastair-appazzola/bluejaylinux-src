#!/bin/bash
# BluejayLinux Display Server - Framebuffer-based display server
# Manages display output, windows, and graphics rendering

set -e

DISPLAY_CONFIG="/etc/bluejay/display.conf"
FRAMEBUFFER_DEVICE="/dev/fb0"
DISPLAY_STATE="/run/bluejay-display"
WINDOW_MANAGER_FIFO="/run/bluejay-wm.fifo"

log_display() {
    echo "[$(date '+%H:%M:%S')] DISPLAY: $1" | tee -a /var/log/bluejay-display.log
}

log_error() {
    echo "[$(date '+%H:%M:%S')] ERROR: $1" | tee -a /var/log/bluejay-display.log >&2
}

log_success() {
    echo "[$(date '+%H:%M:%S')] SUCCESS: $1" | tee -a /var/log/bluejay-display.log
}

# Initialize display server
init_display_server() {
    log_display "Initializing BluejayLinux Display Server..."
    
    # Create directories
    mkdir -p "$(dirname "$DISPLAY_CONFIG")"
    mkdir -p "$(dirname "$DISPLAY_STATE")"
    mkdir -p /var/log
    mkdir -p /opt/bluejay/bin
    
    # Check for framebuffer device
    if [ ! -c "$FRAMEBUFFER_DEVICE" ]; then
        log_error "Framebuffer device not found: $FRAMEBUFFER_DEVICE"
        # Try to load framebuffer module
        modprobe vesafb 2>/dev/null || modprobe efifb 2>/dev/null || true
        if [ ! -c "$FRAMEBUFFER_DEVICE" ]; then
            log_error "Unable to initialize framebuffer"
            return 1
        fi
    fi
    
    # Create display configuration
    create_display_config
    
    # Initialize display state
    init_display_state
    
    # Set up graphics libraries
    setup_graphics_libs
    
    log_success "Display Server initialized"
}

# Create display configuration
create_display_config() {
    cat > "$DISPLAY_CONFIG" << 'EOF'
# BluejayLinux Display Configuration

# Display settings
DISPLAY_WIDTH=1024
DISPLAY_HEIGHT=768
DISPLAY_DEPTH=24
DISPLAY_REFRESH=60

# Framebuffer settings
FRAMEBUFFER_DEVICE=/dev/fb0
DOUBLE_BUFFER=true
VSYNC=true

# Font settings
DEFAULT_FONT=/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf
FONT_SIZE=12
FONT_DPI=96

# Color settings
BACKGROUND_COLOR=#1e1e1e
FOREGROUND_COLOR=#ffffff
ACCENT_COLOR=#0078d4

# Window settings
WINDOW_BORDER_WIDTH=2
WINDOW_TITLE_HEIGHT=24
WINDOW_SHADOW=true

# Performance settings
ENABLE_ACCELERATION=true
RENDER_THREADS=2
BUFFER_SIZE=1024
EOF
    
    log_success "Display configuration created"
}

# Initialize display state
init_display_state() {
    # Get actual framebuffer info
    local fb_info=""
    if [ -r /sys/class/graphics/fb0/virtual_size ]; then
        fb_info=$(cat /sys/class/graphics/fb0/virtual_size 2>/dev/null || echo "1024,768")
    fi
    
    local width=$(echo "$fb_info" | cut -d, -f1)
    local height=$(echo "$fb_info" | cut -d, -f2)
    
    # Set defaults if detection failed
    [ -z "$width" ] && width=1024
    [ -z "$height" ] && height=768
    
    cat > "$DISPLAY_STATE" << EOF
# BluejayLinux Display State
display_width=$width
display_height=$height
display_depth=24
display_running=false
window_count=0
active_window=0
cursor_x=400
cursor_y=300
cursor_visible=true
EOF
    
    log_success "Display state initialized ($width x $height)"
}

# Setup graphics libraries
setup_graphics_libs() {
    log_display "Setting up graphics libraries..."
    
    # Create simple graphics library
    cat > /opt/bluejay/bin/bluejay-graphics << 'EOF'
#!/bin/bash
# BluejayLinux Simple Graphics Library

FRAMEBUFFER="/dev/fb0"
DISPLAY_STATE="/run/bluejay-display"

# Load display state
load_display_state() {
    if [ -f "$DISPLAY_STATE" ]; then
        . "$DISPLAY_STATE"
    else
        display_width=1024
        display_height=768
        display_depth=24
    fi
}

# Clear screen
clear_screen() {
    local color="${1:-000000}"
    
    if [ -w "$FRAMEBUFFER" ]; then
        # Simple clear - just write zeros (black)
        dd if=/dev/zero of="$FRAMEBUFFER" bs=1024 count=1024 2>/dev/null || true
    fi
}

# Draw pixel (simplified)
draw_pixel() {
    local x="$1" y="$2" color="${3:-ffffff}"
    
    # This is a placeholder - real implementation would calculate framebuffer offset
    # and write pixel data directly
    echo "PIXEL: ($x, $y) = #$color" >> /var/log/bluejay-graphics.log
}

# Draw rectangle
draw_rect() {
    local x="$1" y="$2" width="$3" height="$4" color="${5:-ffffff}"
    
    # Placeholder implementation
    echo "RECT: ($x, $y) ${width}x${height} = #$color" >> /var/log/bluejay-graphics.log
}

# Draw text (simplified)
draw_text() {
    local x="$1" y="$2" text="$3" color="${4:-ffffff}"
    
    # This would use a font renderer in real implementation
    echo "TEXT: ($x, $y) '$text' = #$color" >> /var/log/bluejay-graphics.log
}

# Draw cursor
draw_cursor() {
    local x="$1" y="$2"
    
    # Draw simple cursor (arrow shape)
    draw_pixel "$x" "$y" "ffffff"
    draw_pixel "$((x+1))" "$((y+1))" "ffffff"
    draw_pixel "$((x+2))" "$((y+2))" "ffffff"
    draw_pixel "$((x+1))" "$((y+2))" "ffffff"
    draw_pixel "$x" "$((y+3))" "ffffff"
}

# Main command handler
case "$1" in
    clear) clear_screen "$2" ;;
    pixel) draw_pixel "$2" "$3" "$4" ;;
    rect) draw_rect "$2" "$3" "$4" "$5" "$6" ;;
    text) draw_text "$2" "$3" "$4" "$5" ;;
    cursor) draw_cursor "$2" "$3" ;;
    *) echo "Usage: $0 {clear|pixel|rect|text|cursor} [args]" ;;
esac
EOF
    chmod +x /opt/bluejay/bin/bluejay-graphics
    
    log_success "Graphics libraries set up"
}

# Start display server
start_display_server() {
    log_display "Starting BluejayLinux Display Server..."
    
    # Create window manager FIFO
    if [ ! -p "$WINDOW_MANAGER_FIFO" ]; then
        mkfifo "$WINDOW_MANAGER_FIFO"
        chmod 666 "$WINDOW_MANAGER_FIFO"
    fi
    
    # Create display server daemon
    cat > /opt/bluejay/bin/bluejay-display-daemon << 'EOF'
#!/bin/bash
# BluejayLinux Display Server Daemon

DISPLAY_STATE="/run/bluejay-display"
WINDOW_MANAGER_FIFO="/run/bluejay-wm.fifo"
INPUT_FIFO="/run/bluejay-input.fifo"
LOG_FILE="/var/log/bluejay-display.log"

log_daemon() {
    echo "[$(date '+%H:%M:%S')] DISPLAY_DAEMON: $1" >> "$LOG_FILE"
}

# Load display state
load_display_state() {
    if [ -f "$DISPLAY_STATE" ]; then
        . "$DISPLAY_STATE"
    fi
}

# Save display state
save_display_state() {
    cat > "$DISPLAY_STATE" << EOF
display_width=$display_width
display_height=$display_height
display_depth=$display_depth
display_running=$display_running
window_count=$window_count
active_window=$active_window
cursor_x=$cursor_x
cursor_y=$cursor_y
cursor_visible=$cursor_visible
EOF
}

# Initialize display
init_display() {
    load_display_state
    
    # Clear screen
    /opt/bluejay/bin/bluejay-graphics clear 1e1e1e
    
    # Draw desktop background
    /opt/bluejay/bin/bluejay-graphics rect 0 0 "$display_width" "$display_height" "2d2d2d"
    
    # Draw taskbar
    local taskbar_height=32
    /opt/bluejay/bin/bluejay-graphics rect 0 $((display_height - taskbar_height)) "$display_width" "$taskbar_height" "404040"
    
    # Draw title
    /opt/bluejay/bin/bluejay-graphics text 10 10 "BluejayLinux Desktop" "ffffff"
    
    # Draw cursor
    /opt/bluejay/bin/bluejay-graphics cursor "$cursor_x" "$cursor_y"
    
    display_running=true
    save_display_state
    
    log_daemon "Display initialized"
}

# Process window manager events
process_wm_event() {
    local event="$1"
    
    case "$event" in
        CREATE_WINDOW:*)
            local window_info="${event#CREATE_WINDOW:}"
            window_count=$((window_count + 1))
            active_window=$window_count
            log_daemon "Created window: $window_info"
            ;;
        DESTROY_WINDOW:*)
            local window_id="${event#DESTROY_WINDOW:}"
            window_count=$((window_count - 1))
            log_daemon "Destroyed window: $window_id"
            ;;
        FOCUS_WINDOW:*)
            local window_id="${event#FOCUS_WINDOW:}"
            active_window="$window_id"
            log_daemon "Focused window: $window_id"
            ;;
        MOVE_WINDOW:*)
            local window_info="${event#MOVE_WINDOW:}"
            log_daemon "Moved window: $window_info"
            ;;
        RESIZE_WINDOW:*)
            local window_info="${event#RESIZE_WINDOW:}"
            log_daemon "Resized window: $window_info"
            ;;
    esac
    
    save_display_state
}

# Process input events
process_input_event() {
    local event="$1"
    
    case "$event" in
        MOUSE:*)
            local mouse_info="${event#MOUSE:}"
            IFS=: read -r new_x new_y button state <<< "$mouse_info"
            
            if [ "$new_x" != "$cursor_x" ] || [ "$new_y" != "$cursor_y" ]; then
                # Erase old cursor
                /opt/bluejay/bin/bluejay-graphics rect "$cursor_x" "$cursor_y" 4 4 "2d2d2d"
                
                # Update position
                cursor_x="$new_x"
                cursor_y="$new_y"
                
                # Draw new cursor
                /opt/bluejay/bin/bluejay-graphics cursor "$cursor_x" "$cursor_y"
                
                save_display_state
            fi
            
            if [ "$button" != "0" ] && [ "$state" = "true" ]; then
                log_daemon "Mouse click at ($cursor_x, $cursor_y) button $button"
                # Process click events (window focus, etc.)
            fi
            ;;
        KEYBOARD:*)
            local keyboard_info="${event#KEYBOARD:}"
            IFS=: read -r key state <<< "$keyboard_info"
            log_daemon "Key event: $key ($state)"
            ;;
    esac
}

# Main event loop
main() {
    log_daemon "Display server daemon started"
    
    # Initialize display
    init_display
    
    # Event processing loop
    while true; do
        # Check for window manager events
        if [ -p "$WINDOW_MANAGER_FIFO" ]; then
            while IFS= read -t 0.1 -r event <&3; do
                process_wm_event "$event"
            done 3< "$WINDOW_MANAGER_FIFO"
        fi
        
        # Check for input events
        if [ -p "$INPUT_FIFO" ]; then
            while IFS= read -t 0.1 -r event <&4; do
                process_input_event "$event"
            done 4< "$INPUT_FIFO"
        fi
        
        # Small sleep to prevent high CPU usage
        sleep 0.05
    done
}

main "$@"
EOF
    chmod +x /opt/bluejay/bin/bluejay-display-daemon
    
    # Start the display daemon
    /opt/bluejay/bin/bluejay-display-daemon &
    local daemon_pid=$!
    echo "$daemon_pid" > /run/bluejay-display-daemon.pid
    
    # Update state
    . "$DISPLAY_STATE"
    display_running=true
    cat > "$DISPLAY_STATE" << EOF
display_width=$display_width
display_height=$display_height
display_depth=$display_depth
display_running=$display_running
window_count=$window_count
active_window=$active_window
cursor_x=$cursor_x
cursor_y=$cursor_y
cursor_visible=$cursor_visible
EOF
    
    log_success "Display server started (PID: $daemon_pid)"
}

# Stop display server
stop_display_server() {
    log_display "Stopping display server..."
    
    if [ -f /run/bluejay-display-daemon.pid ]; then
        local pid=$(cat /run/bluejay-display-daemon.pid)
        kill "$pid" 2>/dev/null || true
        rm -f /run/bluejay-display-daemon.pid
        log_success "Display daemon stopped"
    fi
    
    # Clear screen
    if [ -w "$FRAMEBUFFER_DEVICE" ]; then
        /opt/bluejay/bin/bluejay-graphics clear 000000
    fi
    
    # Update state
    . "$DISPLAY_STATE"
    display_running=false
    cat > "$DISPLAY_STATE" << EOF
display_width=$display_width
display_height=$display_height
display_depth=$display_depth
display_running=$display_running
window_count=$window_count
active_window=$active_window
cursor_x=$cursor_x
cursor_y=$cursor_y
cursor_visible=$cursor_visible
EOF
    
    log_success "Display server stopped"
}

# Show display status
show_display_status() {
    echo "BluejayLinux Display Server Status"
    echo "=================================="
    echo ""
    
    # Display information
    if [ -f "$DISPLAY_STATE" ]; then
        . "$DISPLAY_STATE"
        echo "Display Resolution: ${display_width}x${display_height}@${display_depth}bit"
        echo "Display Running: $display_running"
        echo "Window Count: $window_count"
        echo "Active Window: $active_window"
        echo "Cursor Position: ($cursor_x, $cursor_y)"
        echo "Cursor Visible: $cursor_visible"
    else
        echo "Display not initialized"
    fi
    echo ""
    
    # Framebuffer information
    echo "Framebuffer Device: $FRAMEBUFFER_DEVICE"
    if [ -c "$FRAMEBUFFER_DEVICE" ]; then
        echo "Framebuffer Available: Yes"
        if [ -r /sys/class/graphics/fb0/virtual_size ]; then
            local fb_size=$(cat /sys/class/graphics/fb0/virtual_size 2>/dev/null || echo "Unknown")
            echo "Framebuffer Size: $fb_size"
        fi
    else
        echo "Framebuffer Available: No"
    fi
    echo ""
    
    # Daemon status
    echo "Display Daemon:"
    if [ -f /run/bluejay-display-daemon.pid ]; then
        local pid=$(cat /run/bluejay-display-daemon.pid)
        if kill -0 "$pid" 2>/dev/null; then
            echo "  Running (PID: $pid)"
        else
            echo "  Not running (stale PID file)"
        fi
    else
        echo "  Not running"
    fi
}

# Set display resolution
set_resolution() {
    local width="$1" height="$2"
    
    if [ -z "$width" ] || [ -z "$height" ]; then
        log_error "Resolution requires width and height"
        return 1
    fi
    
    log_display "Setting display resolution to ${width}x${height}"
    
    # Update configuration
    sed -i "s/DISPLAY_WIDTH=.*/DISPLAY_WIDTH=$width/" "$DISPLAY_CONFIG"
    sed -i "s/DISPLAY_HEIGHT=.*/DISPLAY_HEIGHT=$height/" "$DISPLAY_CONFIG"
    
    # Update state
    if [ -f "$DISPLAY_STATE" ]; then
        . "$DISPLAY_STATE"
        display_width="$width"
        display_height="$height"
        cat > "$DISPLAY_STATE" << EOF
display_width=$display_width
display_height=$display_height
display_depth=$display_depth
display_running=$display_running
window_count=$window_count
active_window=$active_window
cursor_x=$cursor_x
cursor_y=$cursor_y
cursor_visible=$cursor_visible
EOF
    fi
    
    log_success "Resolution set to ${width}x${height}"
}

# Test display
test_display() {
    log_display "Running display test..."
    
    if [ ! -c "$FRAMEBUFFER_DEVICE" ]; then
        log_error "Framebuffer device not available"
        return 1
    fi
    
    # Clear screen
    /opt/bluejay/bin/bluejay-graphics clear 000080
    sleep 1
    
    # Draw test pattern
    /opt/bluejay/bin/bluejay-graphics rect 100 100 200 150 "ff0000"
    /opt/bluejay/bin/bluejay-graphics rect 350 100 200 150 "00ff00"
    /opt/bluejay/bin/bluejay-graphics rect 600 100 200 150 "0000ff"
    
    /opt/bluejay/bin/bluejay-graphics text 100 300 "BluejayLinux Display Test" "ffffff"
    /opt/bluejay/bin/bluejay-graphics text 100 350 "Framebuffer Graphics Working!" "ffff00"
    
    log_success "Display test completed"
}

# Main command handler
main() {
    local command="${1:-help}"
    
    case "$command" in
        init)
            init_display_server
            ;;
        start)
            start_display_server
            ;;
        stop)
            stop_display_server
            ;;
        restart)
            stop_display_server
            sleep 2
            start_display_server
            ;;
        status)
            show_display_status
            ;;
        resolution)
            set_resolution "$2" "$3"
            ;;
        test)
            test_display
            ;;
        help|*)
            echo "BluejayLinux Display Server"
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  init                    Initialize display server"
            echo "  start                   Start display server"
            echo "  stop                    Stop display server"
            echo "  restart                 Restart display server"
            echo "  status                  Show display status"
            echo "  resolution <w> <h>      Set display resolution"
            echo "  test                    Run display test"
            echo "  help                    Show this help"
            ;;
    esac
}

main "$@"