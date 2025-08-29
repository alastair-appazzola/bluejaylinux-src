#!/bin/bash
# BluejayLinux Input Manager - Mouse, keyboard, and input device processing
# Handles input events and translates them to application actions

set -e

INPUT_CONFIG="/etc/bluejay/input.conf"
INPUT_DEVICES_DIR="/dev/input"
INPUT_EVENTS_FIFO="/run/bluejay-input.fifo"
CURSOR_STATE="/run/bluejay-cursor"

log_input() {
    echo "[$(date '+%H:%M:%S')] INPUT: $1" | tee -a /var/log/bluejay-input.log
}

log_error() {
    echo "[$(date '+%H:%M:%S')] ERROR: $1" | tee -a /var/log/bluejay-input.log >&2
}

log_success() {
    echo "[$(date '+%H:%M:%S')] SUCCESS: $1" | tee -a /var/log/bluejay-input.log
}

# Initialize input management
init_input_manager() {
    log_input "Initializing BluejayLinux Input Manager..."
    
    # Create directories
    mkdir -p "$(dirname "$INPUT_CONFIG")"
    mkdir -p "$(dirname "$INPUT_EVENTS_FIFO")"
    mkdir -p "$(dirname "$CURSOR_STATE")"
    mkdir -p /var/log
    
    # Create input configuration
    create_input_config
    
    # Set up input device permissions
    setup_input_permissions
    
    # Initialize cursor state
    init_cursor_state
    
    # Create input event FIFO
    if [ ! -p "$INPUT_EVENTS_FIFO" ]; then
        mkfifo "$INPUT_EVENTS_FIFO"
        chmod 666 "$INPUT_EVENTS_FIFO"
    fi
    
    log_success "Input Manager initialized"
}

# Create input configuration
create_input_config() {
    cat > "$INPUT_CONFIG" << 'EOF'
# BluejayLinux Input Configuration

# Mouse settings
MOUSE_SENSITIVITY=1.0
MOUSE_ACCELERATION=1.0
MOUSE_BUTTON_MAPPING="1:left,2:middle,3:right"
DOUBLE_CLICK_TIMEOUT=300

# Keyboard settings
KEYBOARD_LAYOUT=us
KEYBOARD_REPEAT_DELAY=250
KEYBOARD_REPEAT_RATE=30
CAPS_LOCK_BEHAVIOR=caps

# Input device detection
AUTO_DETECT_DEVICES=true
ENABLE_TOUCHPAD=true
ENABLE_USB_INPUT=true

# Cursor settings
CURSOR_SIZE=16
CURSOR_THEME=default
CURSOR_BLINK_RATE=500

# Event processing
BUFFER_SIZE=1024
EVENT_TIMEOUT=100
ENABLE_RAW_MODE=false
EOF
    
    log_success "Input configuration created"
}

# Setup input device permissions
setup_input_permissions() {
    log_input "Setting up input device permissions..."
    
    # Create input group if it doesn't exist
    if ! getent group input >/dev/null 2>&1; then
        groupadd -r input
        log_input "Created input group"
    fi
    
    # Add bluejay user to input group
    if id -u bluejay >/dev/null 2>&1; then
        usermod -a -G input bluejay
        log_input "Added bluejay user to input group"
    fi
    
    # Set permissions on input devices
    if [ -d "$INPUT_DEVICES_DIR" ]; then
        chgrp -R input "$INPUT_DEVICES_DIR" 2>/dev/null || true
        chmod -R g+r "$INPUT_DEVICES_DIR" 2>/dev/null || true
        log_input "Input device permissions set"
    fi
    
    # Create udev rules for input devices
    cat > /etc/udev/rules.d/99-bluejay-input.rules << 'EOF'
# BluejayLinux Input Device Rules

# Mouse devices
KERNEL=="mouse*", GROUP="input", MODE="0664"
SUBSYSTEM=="input", KERNEL=="mouse*", GROUP="input", MODE="0664"

# Keyboard devices  
KERNEL=="kbd", GROUP="input", MODE="0664"
SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="*keyboard*", GROUP="input", MODE="0664"

# Generic input devices
SUBSYSTEM=="input", GROUP="input", MODE="0664"
KERNEL=="event*", GROUP="input", MODE="0664"

# Touchpad devices
SUBSYSTEM=="input", ATTRS{name}=="*touchpad*", GROUP="input", MODE="0664"
SUBSYSTEM=="input", ATTRS{name}=="*TrackPoint*", GROUP="input", MODE="0664"
EOF
    
    log_success "Input permissions configured"
}

# Initialize cursor state
init_cursor_state() {
    cat > "$CURSOR_STATE" << 'EOF'
# BluejayLinux Cursor State
x=400
y=300
visible=true
button_left=false
button_middle=false
button_right=false
EOF
    
    log_success "Cursor state initialized"
}

# Detect input devices
detect_input_devices() {
    log_input "Detecting input devices..."
    
    local devices=()
    local keyboards=()
    local mice=()
    local touchpads=()
    
    # Check for input event devices
    if [ -d "$INPUT_DEVICES_DIR" ]; then
        for device in "$INPUT_DEVICES_DIR"/event*; do
            if [ -c "$device" ]; then
                local device_name=""
                local device_type=""
                
                # Get device information using udevadm if available
                if command -v udevadm >/dev/null; then
                    device_name=$(udevadm info -q property -n "$device" | grep "ID_INPUT_" | head -1 | cut -d= -f2 2>/dev/null || echo "Unknown")
                fi
                
                # Determine device type by checking capabilities
                local capabilities=""
                if [ -r "$device" ]; then
                    # This is a simplified detection - real implementation would use libevdev
                    case "$(basename "$device")" in
                        event0|event1) device_type="keyboard"; keyboards+=("$device") ;;
                        event2|event3) device_type="mouse"; mice+=("$device") ;;
                        *) device_type="input"; devices+=("$device") ;;
                    esac
                fi
                
                log_input "Found $device_type: $device ($device_name)"
            fi
        done
    fi
    
    # Check for legacy input devices
    [ -c /dev/psaux ] && mice+=("/dev/psaux") && log_input "Found PS/2 mouse: /dev/psaux"
    [ -c /dev/input/mice ] && mice+=("/dev/input/mice") && log_input "Found generic mouse: /dev/input/mice"
    
    # Store detected devices
    {
        echo "# Detected Input Devices"
        echo "KEYBOARDS=(${keyboards[*]})"
        echo "MICE=(${mice[*]})"
        echo "TOUCHPADS=(${touchpads[*]})"
        echo "OTHER_DEVICES=(${devices[*]})"
    } > /run/bluejay-input-devices.conf
    
    local total=$((${#keyboards[@]} + ${#mice[@]} + ${#touchpads[@]} + ${#devices[@]}))
    log_success "Detected $total input devices"
}

# Start input event processor
start_input_processor() {
    log_input "Starting input event processor..."
    
    # Source detected devices
    if [ -f /run/bluejay-input-devices.conf ]; then
        . /run/bluejay-input-devices.conf
    else
        detect_input_devices
        . /run/bluejay-input-devices.conf
    fi
    
    # Create input event processor
    cat > /opt/bluejay/bin/bluejay-input-processor << 'EOF'
#!/bin/bash
# BluejayLinux Input Event Processor

INPUT_FIFO="/run/bluejay-input.fifo"
CURSOR_STATE="/run/bluejay-cursor"
LOG_FILE="/var/log/bluejay-input.log"

log_event() {
    echo "[$(date '+%H:%M:%S')] EVENT: $1" >> "$LOG_FILE"
}

# Read cursor state
read_cursor_state() {
    if [ -f "$CURSOR_STATE" ]; then
        . "$CURSOR_STATE"
    else
        x=400; y=300; visible=true
        button_left=false; button_middle=false; button_right=false
    fi
}

# Write cursor state
write_cursor_state() {
    cat > "$CURSOR_STATE" << EOF
x=$x
y=$y
visible=$visible
button_left=$button_left
button_middle=$button_middle
button_right=$button_right
EOF
}

# Process mouse event
process_mouse_event() {
    local dx="$1" dy="$2" button="$3" state="$4"
    
    read_cursor_state
    
    # Update cursor position
    if [ "$dx" != "0" ] || [ "$dy" != "0" ]; then
        x=$((x + dx))
        y=$((y + dy))
        
        # Keep cursor on screen (assume 800x600 for now)
        [ "$x" -lt 0 ] && x=0
        [ "$x" -gt 800 ] && x=800
        [ "$y" -lt 0 ] && y=0
        [ "$y" -gt 600 ] && y=600
        
        log_event "MOUSE_MOVE x=$x y=$y"
    fi
    
    # Update button state
    case "$button" in
        1) button_left="$state"; log_event "MOUSE_BUTTON left=$state x=$x y=$y" ;;
        2) button_middle="$state"; log_event "MOUSE_BUTTON middle=$state x=$x y=$y" ;;
        3) button_right="$state"; log_event "MOUSE_BUTTON right=$state x=$x y=$y" ;;
    esac
    
    write_cursor_state
    
    # Send event to applications
    echo "MOUSE:$x:$y:$button:$state" > "$INPUT_FIFO" &
}

# Process keyboard event
process_keyboard_event() {
    local key="$1" state="$2"
    
    log_event "KEYBOARD key=$key state=$state"
    
    # Send event to applications
    echo "KEYBOARD:$key:$state" > "$INPUT_FIFO" &
}

# Simple event loop (placeholder)
main() {
    log_event "Input processor started"
    
    # In a real implementation, this would use libevdev or similar to read raw input events
    # For now, we create a simple event simulator
    
    while true; do
        # Simulate some input events for testing
        if [ -f /run/bluejay-simulate-input ]; then
            # Read simulated events
            while IFS=: read -r type data; do
                case "$type" in
                    MOUSE)
                        IFS=, read -r dx dy button state <<< "$data"
                        process_mouse_event "$dx" "$dy" "$button" "$state"
                        ;;
                    KEYBOARD)
                        IFS=, read -r key state <<< "$data"
                        process_keyboard_event "$key" "$state"
                        ;;
                esac
            done < /run/bluejay-simulate-input
            rm -f /run/bluejay-simulate-input
        fi
        
        sleep 0.1
    done
}

main "$@"
EOF
    chmod +x /opt/bluejay/bin/bluejay-input-processor
    
    # Start the processor
    /opt/bluejay/bin/bluejay-input-processor &
    local processor_pid=$!
    echo "$processor_pid" > /run/bluejay-input-processor.pid
    
    log_success "Input processor started (PID: $processor_pid)"
}

# Stop input processor
stop_input_processor() {
    if [ -f /run/bluejay-input-processor.pid ]; then
        local pid=$(cat /run/bluejay-input-processor.pid)
        kill "$pid" 2>/dev/null || true
        rm -f /run/bluejay-input-processor.pid
        log_success "Input processor stopped"
    fi
}

# Set keyboard layout
set_keyboard_layout() {
    local layout="${1:-us}"
    
    log_input "Setting keyboard layout to: $layout"
    
    # Use loadkeys if available
    if command -v loadkeys >/dev/null; then
        loadkeys "$layout" 2>/dev/null || {
            log_error "Failed to load keyboard layout: $layout"
            return 1
        }
    fi
    
    # Update configuration
    sed -i "s/KEYBOARD_LAYOUT=.*/KEYBOARD_LAYOUT=$layout/" "$INPUT_CONFIG"
    
    log_success "Keyboard layout set to $layout"
}

# Configure mouse sensitivity
set_mouse_sensitivity() {
    local sensitivity="${1:-1.0}"
    
    log_input "Setting mouse sensitivity to: $sensitivity"
    
    # Update configuration
    sed -i "s/MOUSE_SENSITIVITY=.*/MOUSE_SENSITIVITY=$sensitivity/" "$INPUT_CONFIG"
    
    # Apply to running input processor (would need IPC in real implementation)
    
    log_success "Mouse sensitivity set to $sensitivity"
}

# Show input status
show_input_status() {
    echo "BluejayLinux Input Status"
    echo "========================"
    echo ""
    
    # Input devices
    echo "Input Devices:"
    if [ -f /run/bluejay-input-devices.conf ]; then
        . /run/bluejay-input-devices.conf
        echo "  Keyboards: ${#KEYBOARDS[@]}"
        echo "  Mice: ${#MICE[@]}"
        echo "  Touchpads: ${#TOUCHPADS[@]}"
        echo "  Other: ${#OTHER_DEVICES[@]}"
    else
        echo "  Not detected yet"
    fi
    echo ""
    
    # Cursor state
    echo "Cursor State:"
    if [ -f "$CURSOR_STATE" ]; then
        . "$CURSOR_STATE"
        echo "  Position: ($x, $y)"
        echo "  Visible: $visible"
        echo "  Buttons: L=$button_left M=$button_middle R=$button_right"
    else
        echo "  Not initialized"
    fi
    echo ""
    
    # Processor status
    echo "Input Processor:"
    if [ -f /run/bluejay-input-processor.pid ]; then
        local pid=$(cat /run/bluejay-input-processor.pid)
        if kill -0 "$pid" 2>/dev/null; then
            echo "  Running (PID: $pid)"
        else
            echo "  Not running (stale PID file)"
        fi
    else
        echo "  Not running"
    fi
}

# Simulate input event (for testing)
simulate_input() {
    local type="$1"
    shift
    
    case "$type" in
        mouse-move)
            local dx="${1:-10}" dy="${2:-10}"
            echo "MOUSE:$dx,$dy,0,false" >> /run/bluejay-simulate-input
            log_input "Simulated mouse move: dx=$dx dy=$dy"
            ;;
        mouse-click)
            local button="${1:-1}" x="${2:-400}" y="${3:-300}"
            echo "MOUSE:0,0,$button,true" >> /run/bluejay-simulate-input
            echo "MOUSE:0,0,$button,false" >> /run/bluejay-simulate-input
            log_input "Simulated mouse click: button=$button"
            ;;
        key-press)
            local key="$1"
            echo "KEYBOARD:$key,true" >> /run/bluejay-simulate-input
            echo "KEYBOARD:$key,false" >> /run/bluejay-simulate-input
            log_input "Simulated key press: $key"
            ;;
        *)
            log_error "Unknown input simulation type: $type"
            return 1
            ;;
    esac
}

# Main command handler
main() {
    local command="${1:-help}"
    
    case "$command" in
        init)
            init_input_manager
            ;;
        detect)
            detect_input_devices
            ;;
        start)
            start_input_processor
            ;;
        stop)
            stop_input_processor
            ;;
        restart)
            stop_input_processor
            sleep 1
            start_input_processor
            ;;
        status)
            show_input_status
            ;;
        keyboard-layout)
            set_keyboard_layout "$2"
            ;;
        mouse-sensitivity)
            set_mouse_sensitivity "$2"
            ;;
        simulate)
            simulate_input "$2" "$3" "$4" "$5"
            ;;
        help|*)
            echo "BluejayLinux Input Manager"
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  init                       Initialize input management"
            echo "  detect                     Detect input devices"
            echo "  start                      Start input processor"
            echo "  stop                       Stop input processor"
            echo "  restart                    Restart input processor"
            echo "  status                     Show input status"
            echo "  keyboard-layout <layout>   Set keyboard layout"
            echo "  mouse-sensitivity <val>    Set mouse sensitivity"
            echo "  simulate <type> [args]     Simulate input events"
            echo "  help                       Show this help"
            echo ""
            echo "Simulation types:"
            echo "  mouse-move <dx> <dy>       Simulate mouse movement"
            echo "  mouse-click <btn> [x] [y]  Simulate mouse click"
            echo "  key-press <key>            Simulate key press"
            ;;
    esac
}

main "$@"