#!/bin/bash
# BluejayLinux Audio Manager - Audio subsystem support and sound management
# Handles audio devices, mixing, and sound output

set -e

AUDIO_CONFIG="/etc/bluejay/audio.conf"
AUDIO_STATE="/run/bluejay-audio"
AUDIO_DEVICES_DIR="/run/bluejay-audio-devices"

log_audio() {
    echo "[$(date '+%H:%M:%S')] AUDIO: $1" | tee -a /var/log/bluejay-audio.log
}

log_error() {
    echo "[$(date '+%H:%M:%S')] ERROR: $1" | tee -a /var/log/bluejay-audio.log >&2
}

log_success() {
    echo "[$(date '+%H:%M:%S')] SUCCESS: $1" | tee -a /var/log/bluejay-audio.log
}

init_audio_manager() {
    log_audio "Initializing BluejayLinux Audio Manager..."
    
    mkdir -p "$(dirname "$AUDIO_CONFIG")"
    mkdir -p "$(dirname "$AUDIO_STATE")"
    mkdir -p "$AUDIO_DEVICES_DIR"
    mkdir -p /var/log
    mkdir -p /opt/bluejay/bin
    
    create_audio_config
    init_audio_state
    setup_audio_system
    
    log_success "Audio Manager initialized"
}

create_audio_config() {
    cat > "$AUDIO_CONFIG" << 'EOF'
# BluejayLinux Audio Configuration

# Audio system settings
AUDIO_SYSTEM=alsa
SAMPLE_RATE=44100
SAMPLE_FORMAT=16bit
CHANNELS=2
BUFFER_SIZE=1024

# Device settings
DEFAULT_OUTPUT_DEVICE=default
DEFAULT_INPUT_DEVICE=default
ENABLE_HOTPLUG=true

# Volume settings
MASTER_VOLUME=75
DEFAULT_VOLUME=50
VOLUME_STEP=5

# Mixer settings
ENABLE_SOFTWARE_MIXING=true
MAX_CLIENTS=8
ENABLE_RESAMPLING=true
EOF
    
    log_success "Audio configuration created"
}

init_audio_state() {
    cat > "$AUDIO_STATE" << 'EOF'
audio_manager_running=false
audio_server_running=false
master_volume=75
muted=false
active_devices=0
playing_streams=0
EOF
    
    log_success "Audio state initialized"
}

setup_audio_system() {
    # Create simple audio server
    cat > /opt/bluejay/bin/bluejay-audio-server << 'EOF'
#!/bin/bash
# BluejayLinux Audio Server

AUDIO_STATE="/run/bluejay-audio"
AUDIO_DEVICES_DIR="/run/bluejay-audio-devices"
LOG_FILE="/var/log/bluejay-audio.log"

log_server() {
    echo "[$(date '+%H:%M:%S')] AUDIO_SERVER: $1" >> "$LOG_FILE"
}

load_audio_state() {
    if [ -f "$AUDIO_STATE" ]; then
        . "$AUDIO_STATE"
    fi
}

save_audio_state() {
    cat > "$AUDIO_STATE" << EOF
audio_manager_running=$audio_manager_running
audio_server_running=$audio_server_running
master_volume=$master_volume
muted=$muted
active_devices=$active_devices
playing_streams=$playing_streams
EOF
}

detect_audio_devices() {
    log_server "Detecting audio devices..."
    
    local device_count=0
    
    # Check for ALSA devices
    if [ -d /proc/asound ]; then
        for card_dir in /proc/asound/card*; do
            if [ -d "$card_dir" ]; then
                local card_num=$(basename "$card_dir" | sed 's/card//')
                local card_name="Unknown"
                
                if [ -f "$card_dir/id" ]; then
                    card_name=$(cat "$card_dir/id")
                fi
                
                # Create device info
                cat > "$AUDIO_DEVICES_DIR/card$card_num" << EOF
device_id=card$card_num
device_name=$card_name
device_type=sound_card
status=available
EOF
                
                device_count=$((device_count + 1))
                log_server "Found audio device: card$card_num ($card_name)"
            fi
        done
    fi
    
    # Check for OSS devices
    if [ -c /dev/dsp ]; then
        cat > "$AUDIO_DEVICES_DIR/dsp" << EOF
device_id=dsp
device_name=OSS DSP
device_type=oss_device
status=available
EOF
        device_count=$((device_count + 1))
        log_server "Found OSS audio device: /dev/dsp"
    fi
    
    # Update state
    load_audio_state
    active_devices=$device_count
    save_audio_state
    
    log_server "Detected $device_count audio devices"
}

start_audio_server() {
    log_server "Starting audio server..."
    
    load_audio_state
    audio_server_running=true
    save_audio_state
    
    # Detect devices
    detect_audio_devices
    
    # Audio server main loop
    while [ "$audio_server_running" = "true" ]; do
        # Check for audio requests
        for request_file in /tmp/bluejay-audio-*.req; do
            if [ -f "$request_file" ]; then
                process_audio_request "$request_file"
                rm -f "$request_file"
            fi
        done
        
        sleep 0.1
    done
}

process_audio_request() {
    local req_file="$1"
    local command=""
    local params=""
    
    if [ -f "$req_file" ]; then
        . "$req_file"
    fi
    
    case "$command" in
        play)
            play_audio "$params"
            ;;
        stop)
            stop_audio "$params"
            ;;
        volume)
            set_volume "$params"
            ;;
        mute)
            toggle_mute
            ;;
    esac
}

play_audio() {
    local audio_file="$1"
    
    log_server "Playing audio: $audio_file"
    
    # Simple audio playback using available tools
    if command -v aplay >/dev/null && [ "${audio_file##*.}" = "wav" ]; then
        aplay "$audio_file" &
        local play_pid=$!
        echo "$play_pid" > "/tmp/bluejay-audio-playing-$$"
        
        # Update state
        load_audio_state
        playing_streams=$((playing_streams + 1))
        save_audio_state
        
    elif command -v mpg123 >/dev/null && [ "${audio_file##*.}" = "mp3" ]; then
        mpg123 "$audio_file" &
        local play_pid=$!
        echo "$play_pid" > "/tmp/bluejay-audio-playing-$$"
        
        load_audio_state
        playing_streams=$((playing_streams + 1))
        save_audio_state
        
    else
        log_server "No suitable player found for $audio_file"
    fi
}

stop_audio() {
    local stream_id="$1"
    
    if [ -f "/tmp/bluejay-audio-playing-$stream_id" ]; then
        local pid=$(cat "/tmp/bluejay-audio-playing-$stream_id")
        kill "$pid" 2>/dev/null || true
        rm -f "/tmp/bluejay-audio-playing-$stream_id"
        
        load_audio_state
        playing_streams=$((playing_streams - 1))
        save_audio_state
        
        log_server "Stopped audio stream: $stream_id"
    fi
}

set_volume() {
    local volume="$1"
    
    if [ "$volume" -ge 0 ] && [ "$volume" -le 100 ]; then
        # Set volume using available tools
        if command -v amixer >/dev/null; then
            amixer set Master "$volume%" >/dev/null 2>&1
        fi
        
        load_audio_state
        master_volume="$volume"
        save_audio_state
        
        log_server "Set volume to: $volume%"
    fi
}

toggle_mute() {
    load_audio_state
    
    if [ "$muted" = "false" ]; then
        # Mute
        if command -v amixer >/dev/null; then
            amixer set Master mute >/dev/null 2>&1
        fi
        muted=true
        log_server "Audio muted"
    else
        # Unmute
        if command -v amixer >/dev/null; then
            amixer set Master unmute >/dev/null 2>&1
        fi
        muted=false
        log_server "Audio unmuted"
    fi
    
    save_audio_state
}

main() {
    start_audio_server
}

main "$@"
EOF
    chmod +x /opt/bluejay/bin/bluejay-audio-server

    # Create audio client utility
    cat > /opt/bluejay/bin/bluejay-audio-client << 'EOF'
#!/bin/bash
# BluejayLinux Audio Client

CLIENT_ID="$$"

play_file() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        echo "File not found: $file"
        return 1
    fi
    
    cat > "/tmp/bluejay-audio-$CLIENT_ID.req" << EOF
command=play
params=$file
client_id=$CLIENT_ID
EOF
    
    echo "Playing: $file"
}

stop_playback() {
    cat > "/tmp/bluejay-audio-$CLIENT_ID.req" << EOF
command=stop
params=$CLIENT_ID
client_id=$CLIENT_ID
EOF
    
    echo "Stopped playback"
}

set_volume() {
    local volume="$1"
    
    cat > "/tmp/bluejay-audio-$CLIENT_ID.req" << EOF
command=volume
params=$volume
client_id=$CLIENT_ID
EOF
    
    echo "Volume set to: $volume%"
}

toggle_mute() {
    cat > "/tmp/bluejay-audio-$CLIENT_ID.req" << EOF
command=mute
params=
client_id=$CLIENT_ID
EOF
    
    echo "Toggled mute"
}

case "$1" in
    play) play_file "$2" ;;
    stop) stop_playback ;;
    volume) set_volume "$2" ;;
    mute) toggle_mute ;;
    *) 
        echo "Usage: $0 {play|stop|volume|mute} [args]"
        echo ""
        echo "Commands:"
        echo "  play <file>     Play audio file"
        echo "  stop            Stop current playback"  
        echo "  volume <level>  Set volume (0-100)"
        echo "  mute            Toggle mute"
        ;;
esac
EOF
    chmod +x /opt/bluejay/bin/bluejay-audio-client
    
    log_success "Audio system set up"
}

start_audio_manager() {
    log_audio "Starting Audio Manager..."
    
    # Load audio modules if needed
    modprobe snd 2>/dev/null || true
    modprobe snd-pcm 2>/dev/null || true
    modprobe snd-mixer 2>/dev/null || true
    
    # Start audio server
    /opt/bluejay/bin/bluejay-audio-server &
    local server_pid=$!
    echo "$server_pid" > /run/bluejay-audio-server.pid
    
    # Update state
    . "$AUDIO_STATE"
    audio_manager_running=true
    cat > "$AUDIO_STATE" << EOF
audio_manager_running=$audio_manager_running
audio_server_running=$audio_server_running
master_volume=$master_volume
muted=$muted
active_devices=$active_devices
playing_streams=$playing_streams
EOF
    
    log_success "Audio Manager started (Server PID: $server_pid)"
}

stop_audio_manager() {
    log_audio "Stopping Audio Manager..."
    
    if [ -f /run/bluejay-audio-server.pid ]; then
        local pid=$(cat /run/bluejay-audio-server.pid)
        kill "$pid" 2>/dev/null || true
        rm -f /run/bluejay-audio-server.pid
    fi
    
    # Stop all playing streams
    for playing_file in /tmp/bluejay-audio-playing-*; do
        if [ -f "$playing_file" ]; then
            local pid=$(cat "$playing_file")
            kill "$pid" 2>/dev/null || true
            rm -f "$playing_file"
        fi
    done
    
    # Update state
    . "$AUDIO_STATE"
    audio_manager_running=false
    audio_server_running=false
    playing_streams=0
    cat > "$AUDIO_STATE" << EOF
audio_manager_running=$audio_manager_running
audio_server_running=$audio_server_running
master_volume=$master_volume
muted=$muted
active_devices=$active_devices
playing_streams=$playing_streams
EOF
    
    log_success "Audio Manager stopped"
}

show_audio_status() {
    echo "BluejayLinux Audio Manager Status"
    echo "================================="
    echo ""
    
    if [ -f "$AUDIO_STATE" ]; then
        . "$AUDIO_STATE"
        echo "Audio Manager Running: $audio_manager_running"
        echo "Audio Server Running: $audio_server_running"
        echo "Master Volume: $master_volume%"
        echo "Muted: $muted"
        echo "Active Devices: $active_devices"
        echo "Playing Streams: $playing_streams"
    else
        echo "Audio manager not initialized"
    fi
    echo ""
    
    echo "Audio Devices:"
    if [ -d "$AUDIO_DEVICES_DIR" ]; then
        for device_file in "$AUDIO_DEVICES_DIR"/*; do
            if [ -f "$device_file" ]; then
                . "$device_file"
                echo "  $device_id: $device_name ($device_type) - $status"
            fi
        done
    else
        echo "  No devices detected"
    fi
}

test_audio() {
    log_audio "Running audio test..."
    
    # Generate test tone if speaker-test is available
    if command -v speaker-test >/dev/null; then
        echo "Playing test tone for 3 seconds..."
        timeout 3 speaker-test -t sine -f 1000 -l 1 >/dev/null 2>&1 || true
        log_success "Audio test completed"
    else
        log_audio "speaker-test not available, skipping audio test"
    fi
}

main() {
    case "$1" in
        init) init_audio_manager ;;
        start) start_audio_manager ;;
        stop) stop_audio_manager ;;
        restart) stop_audio_manager; sleep 2; start_audio_manager ;;
        status) show_audio_status ;;
        test) test_audio ;;
        help|*)
            echo "Usage: $0 {init|start|stop|restart|status|test|help}"
            echo ""
            echo "BluejayLinux Audio Manager - Audio subsystem support"
            ;;
    esac
}

main "$@"