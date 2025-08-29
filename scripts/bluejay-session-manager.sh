#!/bin/bash
# BluejayLinux Session Manager - User session and context handling
# Manages user login, environment setup, and session lifecycle

set -e

SESSION_CONFIG="/etc/bluejay/session.conf"
SESSION_STATE="/run/bluejay-session"
SESSIONS_DIR="/run/bluejay-sessions"

log_session() {
    echo "[$(date '+%H:%M:%S')] SESSION: $1" | tee -a /var/log/bluejay-session.log
}

log_error() {
    echo "[$(date '+%H:%M:%S')] ERROR: $1" | tee -a /var/log/bluejay-session.log >&2
}

log_success() {
    echo "[$(date '+%H:%M:%S')] SUCCESS: $1" | tee -a /var/log/bluejay-session.log
}

# Initialize session manager
init_session_manager() {
    log_session "Initializing BluejayLinux Session Manager..."
    
    mkdir -p "$(dirname "$SESSION_CONFIG")"
    mkdir -p "$(dirname "$SESSION_STATE")"
    mkdir -p "$SESSIONS_DIR"
    mkdir -p /var/log
    mkdir -p /opt/bluejay/bin
    
    create_session_config
    init_session_state
    setup_session_scripts
    
    log_success "Session Manager initialized"
}

create_session_config() {
    cat > "$SESSION_CONFIG" << 'EOF'
# BluejayLinux Session Configuration

# Session settings
DEFAULT_SHELL=/bin/bash
SESSION_TIMEOUT=7200
IDLE_TIMEOUT=1800
MAX_SESSIONS=10

# Environment settings
DEFAULT_PATH=/bin:/sbin:/usr/bin:/usr/sbin:/opt/bluejay/bin
DEFAULT_EDITOR=nano
DEFAULT_BROWSER=bluejay-browser
DEFAULT_TERMINAL=bluejay-terminal

# Desktop settings
DESKTOP_SESSION=bluejay-desktop
WINDOW_MANAGER=bluejay-wm
DISPLAY_MANAGER=bluejay-dm

# Security settings
REQUIRE_PASSWORD=true
LOCK_ON_IDLE=true
SECURE_DELETION=true
AUDIT_SESSIONS=true
EOF
    
    log_success "Session configuration created"
}

init_session_state() {
    cat > "$SESSION_STATE" << 'EOF'
session_manager_running=false
active_sessions=0
total_sessions=0
EOF
    
    log_success "Session state initialized"
}

setup_session_scripts() {
    # Create session startup script
    cat > /opt/bluejay/bin/bluejay-session-start << 'EOF'
#!/bin/bash
# BluejayLinux Session Startup

USER="$1"
SESSION_ID="$2"
SESSION_TYPE="${3:-desktop}"

SESSIONS_DIR="/run/bluejay-sessions"
SESSION_DIR="$SESSIONS_DIR/$SESSION_ID"
LOG_FILE="/var/log/bluejay-session.log"

log_startup() {
    echo "[$(date '+%H:%M:%S')] SESSION_START: $1" >> "$LOG_FILE"
}

start_session() {
    log_startup "Starting session $SESSION_ID for user $USER"
    
    # Create session directory
    mkdir -p "$SESSION_DIR"
    
    # Create session info file
    cat > "$SESSION_DIR/info" << EOF
user=$USER
session_id=$SESSION_ID
session_type=$SESSION_TYPE
start_time=$(date '+%s')
last_activity=$(date '+%s')
status=active
pid=$$
EOF
    
    # Set up environment
    export HOME="/home/$USER"
    export USER="$USER"
    export LOGNAME="$USER"
    export SHELL="/bin/bash"
    export PATH="/bin:/sbin:/usr/bin:/usr/sbin:/opt/bluejay/bin"
    export DISPLAY=":0"
    export XDG_RUNTIME_DIR="/run/user/$(id -u "$USER")"
    export XDG_SESSION_TYPE="x11"
    export XDG_CURRENT_DESKTOP="BluejayLinux"
    
    # Create user runtime directory
    mkdir -p "$XDG_RUNTIME_DIR"
    chown "$USER:$USER" "$XDG_RUNTIME_DIR"
    chmod 700 "$XDG_RUNTIME_DIR"
    
    # Start session services based on type
    case "$SESSION_TYPE" in
        desktop)
            start_desktop_session
            ;;
        console)
            start_console_session
            ;;
        security)
            start_security_session
            ;;
        *)
            log_startup "Unknown session type: $SESSION_TYPE"
            exit 1
            ;;
    esac
}

start_desktop_session() {
    log_startup "Starting desktop session"
    
    # Start display server if not running
    if ! pgrep bluejay-display-daemon >/dev/null; then
        /opt/bluejay/bin/bluejay-display-server start &
        sleep 2
    fi
    
    # Start window manager if not running  
    if ! pgrep bluejay-wm-daemon >/dev/null; then
        /opt/bluejay/bin/bluejay-window-manager start &
        sleep 2
    fi
    
    # Start input manager if not running
    if ! pgrep bluejay-input-processor >/dev/null; then
        /opt/bluejay/bin/bluejay-input-manager start &
        sleep 1
    fi
    
    # Start session applications
    start_session_applications
    
    # Start desktop shell
    exec su -l "$USER" -c "cd && exec /bin/bash"
}

start_console_session() {
    log_startup "Starting console session"
    
    # Start shell
    exec su -l "$USER"
}

start_security_session() {
    log_startup "Starting security session"
    
    # Start security tools environment
    export PATH="/opt/bluejay/tools/bin:$PATH"
    
    # Start specialized shell
    exec su -l "$USER" -c "cd && exec /opt/bluejay/bin/bluejay-security-shell"
}

start_session_applications() {
    # Applications to start automatically
    local apps=(
        "bluejay-resource-monitor"
        "bluejay-ipc-client receive"
    )
    
    for app in "${apps[@]}"; do
        if command -v "$(echo "$app" | cut -d' ' -f1)" >/dev/null; then
            $app &
            log_startup "Started application: $app"
        fi
    done
}

# Monitor session activity
monitor_session() {
    while [ -f "$SESSION_DIR/info" ]; do
        # Update last activity time
        sed -i "s/last_activity=.*/last_activity=$(date '+%s')/" "$SESSION_DIR/info"
        
        # Check for idle timeout
        . "$SESSION_DIR/info"
        local current_time=$(date '+%s')
        local idle_time=$((current_time - last_activity))
        
        if [ $idle_time -gt 1800 ]; then  # 30 minutes
            log_startup "Session $SESSION_ID idle timeout"
            /opt/bluejay/bin/bluejay-session-manager end-session "$SESSION_ID"
            break
        fi
        
        sleep 60
    done
}

main() {
    start_session
    monitor_session &
}

main "$@"
EOF
    chmod +x /opt/bluejay/bin/bluejay-session-start

    # Create session daemon
    cat > /opt/bluejay/bin/bluejay-session-daemon << 'EOF'
#!/bin/bash
# BluejayLinux Session Manager Daemon

SESSION_STATE="/run/bluejay-session"
SESSIONS_DIR="/run/bluejay-sessions"
LOG_FILE="/var/log/bluejay-session.log"

log_daemon() {
    echo "[$(date '+%H:%M:%S')] SESSION_DAEMON: $1" >> "$LOG_FILE"
}

load_session_state() {
    if [ -f "$SESSION_STATE" ]; then
        . "$SESSION_STATE"
    fi
}

save_session_state() {
    cat > "$SESSION_STATE" << EOF
session_manager_running=$session_manager_running
active_sessions=$active_sessions
total_sessions=$total_sessions
EOF
}

cleanup_stale_sessions() {
    log_daemon "Cleaning up stale sessions"
    
    for session_dir in "$SESSIONS_DIR"/*; do
        if [ -d "$session_dir" ] && [ -f "$session_dir/info" ]; then
            . "$session_dir/info"
            
            # Check if process is still running
            if ! kill -0 "$pid" 2>/dev/null; then
                log_daemon "Cleaning up stale session: $session_id"
                rm -rf "$session_dir"
                
                load_session_state
                active_sessions=$((active_sessions - 1))
                save_session_state
            fi
        fi
    done
}

monitor_sessions() {
    while [ "$session_manager_running" = "true" ]; do
        cleanup_stale_sessions
        
        # Update session statistics
        load_session_state
        local current_count=0
        for session_dir in "$SESSIONS_DIR"/*; do
            if [ -d "$session_dir" ] && [ -f "$session_dir/info" ]; then
                current_count=$((current_count + 1))
            fi
        done
        
        active_sessions="$current_count"
        save_session_state
        
        sleep 30
    done
}

main() {
    log_daemon "Session manager daemon started"
    
    load_session_state
    session_manager_running=true
    save_session_state
    
    monitor_sessions
}

main "$@"
EOF
    chmod +x /opt/bluejay/bin/bluejay-session-daemon
    
    log_success "Session scripts created"
}

start_session_manager() {
    log_session "Starting Session Manager..."
    
    # Start session daemon
    /opt/bluejay/bin/bluejay-session-daemon &
    local daemon_pid=$!
    echo "$daemon_pid" > /run/bluejay-session-daemon.pid
    
    # Update state
    . "$SESSION_STATE"
    session_manager_running=true
    cat > "$SESSION_STATE" << EOF
session_manager_running=$session_manager_running
active_sessions=$active_sessions
total_sessions=$total_sessions
EOF
    
    log_success "Session Manager started (PID: $daemon_pid)"
}

stop_session_manager() {
    log_session "Stopping Session Manager..."
    
    if [ -f /run/bluejay-session-daemon.pid ]; then
        local pid=$(cat /run/bluejay-session-daemon.pid)
        kill "$pid" 2>/dev/null || true
        rm -f /run/bluejay-session-daemon.pid
    fi
    
    # End all active sessions
    for session_dir in "$SESSIONS_DIR"/*; do
        if [ -d "$session_dir" ] && [ -f "$session_dir/info" ]; then
            . "$session_dir/info"
            if [ "$pid" != "" ] && [ "$pid" != "0" ]; then
                kill "$pid" 2>/dev/null || true
            fi
            rm -rf "$session_dir"
        fi
    done
    
    # Update state
    . "$SESSION_STATE"
    session_manager_running=false
    active_sessions=0
    cat > "$SESSION_STATE" << EOF
session_manager_running=$session_manager_running
active_sessions=$active_sessions
total_sessions=$total_sessions
EOF
    
    log_success "Session Manager stopped"
}

start_user_session() {
    local user="$1"
    local session_type="${2:-desktop}"
    
    if [ -z "$user" ]; then
        log_error "Username required"
        return 1
    fi
    
    if ! id "$user" >/dev/null 2>&1; then
        log_error "User $user does not exist"
        return 1
    fi
    
    log_session "Starting session for user: $user"
    
    # Generate session ID
    local session_id="session_$(date +%s)_$$"
    
    # Start session
    /opt/bluejay/bin/bluejay-session-start "$user" "$session_id" "$session_type" &
    local session_pid=$!
    
    # Update statistics
    . "$SESSION_STATE"
    active_sessions=$((active_sessions + 1))
    total_sessions=$((total_sessions + 1))
    cat > "$SESSION_STATE" << EOF
session_manager_running=$session_manager_running
active_sessions=$active_sessions
total_sessions=$total_sessions
EOF
    
    log_success "Session $session_id started for user $user (PID: $session_pid)"
    echo "$session_id"
}

end_user_session() {
    local session_id="$1"
    
    if [ -z "$session_id" ]; then
        log_error "Session ID required"
        return 1
    fi
    
    local session_dir="$SESSIONS_DIR/$session_id"
    if [ ! -d "$session_dir" ]; then
        log_error "Session $session_id not found"
        return 1
    fi
    
    log_session "Ending session: $session_id"
    
    # Load session info
    . "$session_dir/info"
    
    # Kill session process
    if [ "$pid" != "" ] && [ "$pid" != "0" ]; then
        kill "$pid" 2>/dev/null || true
        
        # Give it time to clean up
        sleep 2
        
        # Force kill if still running
        kill -9 "$pid" 2>/dev/null || true
    fi
    
    # Remove session directory
    rm -rf "$session_dir"
    
    # Update statistics
    . "$SESSION_STATE"
    active_sessions=$((active_sessions - 1))
    cat > "$SESSION_STATE" << EOF
session_manager_running=$session_manager_running
active_sessions=$active_sessions
total_sessions=$total_sessions
EOF
    
    log_success "Session $session_id ended"
}

show_session_status() {
    echo "BluejayLinux Session Manager Status"
    echo "==================================="
    echo ""
    
    if [ -f "$SESSION_STATE" ]; then
        . "$SESSION_STATE"
        echo "Session Manager Running: $session_manager_running"
        echo "Active Sessions: $active_sessions"
        echo "Total Sessions: $total_sessions"
    else
        echo "Session manager not initialized"
    fi
    echo ""
    
    echo "Active Sessions:"
    if [ -d "$SESSIONS_DIR" ]; then
        for session_dir in "$SESSIONS_DIR"/*; do
            if [ -d "$session_dir" ] && [ -f "$session_dir/info" ]; then
                . "$session_dir/info"
                local duration=$(($(date '+%s') - start_time))
                echo "  Session $session_id: user=$user type=$session_type duration=${duration}s"
            fi
        done
    else
        echo "  No active sessions"
    fi
}

main() {
    case "$1" in
        init) init_session_manager ;;
        start) start_session_manager ;;
        stop) stop_session_manager ;;
        start-session) start_user_session "$2" "$3" ;;
        end-session) end_user_session "$2" ;;
        status) show_session_status ;;
        help|*)
            echo "Usage: $0 {init|start|stop|start-session|end-session|status|help}"
            echo ""
            echo "Commands:"
            echo "  init                           Initialize session manager"
            echo "  start                          Start session manager daemon"
            echo "  stop                           Stop session manager"
            echo "  start-session <user> [type]   Start user session (desktop/console/security)"
            echo "  end-session <id>               End specific session"
            echo "  status                         Show session status"
            ;;
    esac
}

main "$@"