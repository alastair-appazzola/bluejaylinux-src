#!/bin/bash
# BluejayLinux Service Manager - Proper dependency management and service orchestration
# Fixes race conditions and provides proper service ordering

set -e

# Service states
SERVICE_STOPPED=0
SERVICE_STARTING=1
SERVICE_RUNNING=2
SERVICE_STOPPING=3
SERVICE_FAILED=4

# Global variables
SERVICES_DIR="/etc/bluejay/services"
SERVICES_STATE="/run/bluejay/services"
SERVICES_LOG="/var/log/bluejay-services.log"

# Logging functions
log_service() {
    echo "[$(date '+%H:%M:%S')] SERVICE: $1" | tee -a "$SERVICES_LOG"
}

log_error() {
    echo "[$(date '+%H:%M:%S')] ERROR: $1" | tee -a "$SERVICES_LOG" >&2
}

log_success() {
    echo "[$(date '+%H:%M:%S')] SUCCESS: $1" | tee -a "$SERVICES_LOG"
}

# Initialize service management
init_service_manager() {
    log_service "Initializing BluejayLinux Service Manager..."
    
    # Create directories
    mkdir -p "$SERVICES_DIR"
    mkdir -p "$SERVICES_STATE"
    mkdir -p "$(dirname "$SERVICES_LOG")"
    
    # Create service state directory
    mkdir -p "$SERVICES_STATE/pid"
    mkdir -p "$SERVICES_STATE/status"
    mkdir -p "$SERVICES_STATE/deps"
    
    log_success "Service Manager initialized"
}

# Get service state
get_service_state() {
    local service="$1"
    if [ -f "$SERVICES_STATE/status/$service" ]; then
        cat "$SERVICES_STATE/status/$service"
    else
        echo $SERVICE_STOPPED
    fi
}

# Set service state
set_service_state() {
    local service="$1"
    local state="$2"
    echo "$state" > "$SERVICES_STATE/status/$service"
}

# Check if service is running
is_service_running() {
    local service="$1"
    local state=$(get_service_state "$service")
    [ "$state" = "$SERVICE_RUNNING" ]
}

# Wait for dependency
wait_for_dependency() {
    local dep="$1"
    local timeout="${2:-30}"
    local count=0
    
    log_service "Waiting for dependency: $dep"
    
    while [ $count -lt $timeout ]; do
        if is_service_running "$dep"; then
            log_success "Dependency $dep is ready"
            return 0
        fi
        
        sleep 1
        count=$((count + 1))
    done
    
    log_error "Dependency $dep timed out after ${timeout}s"
    return 1
}

# Check all dependencies
check_dependencies() {
    local service="$1"
    local dep_file="$SERVICES_DIR/$service.deps"
    
    if [ ! -f "$dep_file" ]; then
        return 0  # No dependencies
    fi
    
    log_service "Checking dependencies for $service"
    
    while IFS= read -r dep; do
        # Skip comments and empty lines
        case "$dep" in
            '#'*|'') continue ;;
        esac
        
        if ! wait_for_dependency "$dep" 30; then
            log_error "Failed to satisfy dependency $dep for $service"
            return 1
        fi
    done < "$dep_file"
    
    return 0
}

# Start a service
start_service() {
    local service="$1"
    local service_file="$SERVICES_DIR/$service.service"
    
    if [ ! -f "$service_file" ]; then
        log_error "Service file not found: $service_file"
        return 1
    fi
    
    # Check if already running
    if is_service_running "$service"; then
        log_service "Service $service is already running"
        return 0
    fi
    
    log_service "Starting service: $service"
    set_service_state "$service" $SERVICE_STARTING
    
    # Check dependencies first
    if ! check_dependencies "$service"; then
        set_service_state "$service" $SERVICE_FAILED
        return 1
    fi
    
    # Source the service file
    local exec_start=""
    local exec_stop=""
    local pidfile=""
    local user="root"
    local group="root"
    local restart="no"
    local restart_delay=5
    
    # Parse service file
    while IFS='=' read -r key value; do
        case "$key" in
            ExecStart) exec_start="$value" ;;
            ExecStop) exec_stop="$value" ;;
            PIDFile) pidfile="$value" ;;
            User) user="$value" ;;
            Group) group="$value" ;;
            Restart) restart="$value" ;;
            RestartDelay) restart_delay="$value" ;;
        esac
    done < "$service_file"
    
    if [ -z "$exec_start" ]; then
        log_error "No ExecStart defined in $service_file"
        set_service_state "$service" $SERVICE_FAILED
        return 1
    fi
    
    # Set default pidfile if not specified
    if [ -z "$pidfile" ]; then
        pidfile="$SERVICES_STATE/pid/$service.pid"
    fi
    
    # Start the service
    log_service "Executing: $exec_start"
    
    # Use nohup and background execution
    if [ "$user" = "root" ]; then
        nohup bash -c "$exec_start" </dev/null >/dev/null 2>&1 &
    else
        nohup su -c "$exec_start" "$user" </dev/null >/dev/null 2>&1 &
    fi
    
    local service_pid=$!
    echo "$service_pid" > "$pidfile"
    
    # Wait a moment and check if it's still running
    sleep 2
    if kill -0 "$service_pid" 2>/dev/null; then
        set_service_state "$service" $SERVICE_RUNNING
        echo "$service_pid" > "$SERVICES_STATE/pid/$service.pid"
        log_success "Service $service started successfully (PID: $service_pid)"
        
        # Monitor service if restart is enabled
        if [ "$restart" = "yes" ] || [ "$restart" = "always" ]; then
            monitor_service "$service" "$pidfile" "$exec_start" "$restart_delay" &
        fi
        
        return 0
    else
        set_service_state "$service" $SERVICE_FAILED
        log_error "Service $service failed to start"
        return 1
    fi
}

# Stop a service
stop_service() {
    local service="$1"
    local pidfile="$SERVICES_STATE/pid/$service.pid"
    
    if ! is_service_running "$service"; then
        log_service "Service $service is not running"
        return 0
    fi
    
    log_service "Stopping service: $service"
    set_service_state "$service" $SERVICE_STOPPING
    
    if [ -f "$pidfile" ]; then
        local pid=$(cat "$pidfile")
        if kill -0 "$pid" 2>/dev/null; then
            # Try graceful shutdown first
            kill "$pid" 2>/dev/null || true
            sleep 5
            
            # Force kill if still running
            if kill -0 "$pid" 2>/dev/null; then
                kill -9 "$pid" 2>/dev/null || true
                sleep 2
            fi
        fi
        rm -f "$pidfile"
    fi
    
    set_service_state "$service" $SERVICE_STOPPED
    log_success "Service $service stopped"
}

# Monitor service and restart if needed
monitor_service() {
    local service="$1"
    local pidfile="$2" 
    local exec_start="$3"
    local restart_delay="$4"
    
    while true; do
        sleep "$restart_delay"
        
        if [ -f "$pidfile" ]; then
            local pid=$(cat "$pidfile")
            if ! kill -0 "$pid" 2>/dev/null; then
                log_service "Service $service died, restarting..."
                start_service "$service"
            fi
        else
            # PID file missing, service probably dead
            if is_service_running "$service"; then
                log_service "Service $service PID file missing, restarting..."
                start_service "$service"
            fi
        fi
    done
}

# List all services
list_services() {
    local filter="${1:-all}"
    
    echo "BluejayLinux Services:"
    echo "===================="
    printf "%-20s %-10s %-10s\n" "SERVICE" "STATE" "PID"
    echo "--------------------------------------------"
    
    for service_file in "$SERVICES_DIR"/*.service; do
        if [ ! -f "$service_file" ]; then
            continue
        fi
        
        local service=$(basename "$service_file" .service)
        local state=$(get_service_state "$service")
        local pid=""
        
        local state_name="STOPPED"
        case "$state" in
            $SERVICE_STARTING) state_name="STARTING" ;;
            $SERVICE_RUNNING) state_name="RUNNING" ;;
            $SERVICE_STOPPING) state_name="STOPPING" ;;
            $SERVICE_FAILED) state_name="FAILED" ;;
        esac
        
        if [ -f "$SERVICES_STATE/pid/$service.pid" ]; then
            pid=$(cat "$SERVICES_STATE/pid/$service.pid" 2>/dev/null || echo "")
        fi
        
        # Filter services
        case "$filter" in
            all) ;;
            running) [ "$state" != "$SERVICE_RUNNING" ] && continue ;;
            stopped) [ "$state" != "$SERVICE_STOPPED" ] && continue ;;
            failed) [ "$state" != "$SERVICE_FAILED" ] && continue ;;
        esac
        
        printf "%-20s %-10s %-10s\n" "$service" "$state_name" "$pid"
    done
}

# Create default service definitions
create_default_services() {
    log_service "Creating default service definitions..."
    
    # System logging service
    cat > "$SERVICES_DIR/syslog.service" << 'EOF'
# System logging service
ExecStart=/sbin/syslogd -n
PIDFile=/run/syslogd.pid
Restart=yes
RestartDelay=5
EOF

    # Kernel logging service
    cat > "$SERVICES_DIR/klog.service" << 'EOF'
# Kernel logging service  
ExecStart=/sbin/klogd -n
PIDFile=/run/klogd.pid
Restart=yes
RestartDelay=5
EOF
    
    echo "syslog" > "$SERVICES_DIR/klog.deps"
    
    # Cron service
    cat > "$SERVICES_DIR/cron.service" << 'EOF'
# Cron daemon service
ExecStart=/usr/sbin/cron -f
PIDFile=/run/crond.pid
Restart=yes
RestartDelay=10
EOF

    # Network management service
    cat > "$SERVICES_DIR/network.service" << 'EOF'
# Network management service
ExecStart=/opt/bluejay/bin/bluejay-network-manager
PIDFile=/run/network-manager.pid
Restart=yes
RestartDelay=5
EOF

    # Display manager service
    cat > "$SERVICES_DIR/display-manager.service" << 'EOF'
# Display manager service
ExecStart=/opt/bluejay/bin/bluejay-display-manager
PIDFile=/run/display-manager.pid
Restart=yes
RestartDelay=3
User=root
EOF
    
    echo "network" > "$SERVICES_DIR/display-manager.deps"
    
    # Audio service
    cat > "$SERVICES_DIR/audio.service" << 'EOF'
# Audio service
ExecStart=/opt/bluejay/bin/bluejay-audio-manager
PIDFile=/run/audio-manager.pid
Restart=yes
RestartDelay=5
EOF
    
    log_success "Default service definitions created"
}

# Show service status
show_service_status() {
    local service="$1"
    
    if [ -z "$service" ]; then
        list_services
        return
    fi
    
    local service_file="$SERVICES_DIR/$service.service"
    if [ ! -f "$service_file" ]; then
        log_error "Service $service not found"
        return 1
    fi
    
    local state=$(get_service_state "$service")
    local pid=""
    if [ -f "$SERVICES_STATE/pid/$service.pid" ]; then
        pid=$(cat "$SERVICES_STATE/pid/$service.pid" 2>/dev/null || echo "")
    fi
    
    echo "Service: $service"
    echo "========"
    case "$state" in
        $SERVICE_STOPPED) echo "Status: STOPPED" ;;
        $SERVICE_STARTING) echo "Status: STARTING" ;;
        $SERVICE_RUNNING) echo "Status: RUNNING (PID: $pid)" ;;
        $SERVICE_STOPPING) echo "Status: STOPPING" ;;
        $SERVICE_FAILED) echo "Status: FAILED" ;;
    esac
    
    echo "Configuration:"
    cat "$service_file"
    
    if [ -f "$SERVICES_DIR/$service.deps" ]; then
        echo ""
        echo "Dependencies:"
        cat "$SERVICES_DIR/$service.deps"
    fi
}

# Main command handler
main() {
    local command="${1:-help}"
    local service="$2"
    
    case "$command" in
        init)
            init_service_manager
            create_default_services
            ;;
        start)
            if [ -z "$service" ]; then
                log_error "Service name required"
                exit 1
            fi
            start_service "$service"
            ;;
        stop)
            if [ -z "$service" ]; then
                log_error "Service name required"
                exit 1
            fi
            stop_service "$service"
            ;;
        restart)
            if [ -z "$service" ]; then
                log_error "Service name required"
                exit 1
            fi
            stop_service "$service"
            sleep 2
            start_service "$service"
            ;;
        status)
            show_service_status "$service"
            ;;
        list)
            list_services "$service"
            ;;
        start-all)
            log_service "Starting all services..."
            # Start in dependency order
            local services=(syslog klog network cron audio display-manager)
            for svc in "${services[@]}"; do
                if [ -f "$SERVICES_DIR/$svc.service" ]; then
                    start_service "$svc"
                fi
            done
            ;;
        stop-all)
            log_service "Stopping all services..."
            for service_file in "$SERVICES_DIR"/*.service; do
                local svc=$(basename "$service_file" .service)
                stop_service "$svc"
            done
            ;;
        help|*)
            echo "BluejayLinux Service Manager"
            echo "Usage: $0 <command> [service]"
            echo ""
            echo "Commands:"
            echo "  init          Initialize service manager"
            echo "  start <svc>   Start a service"
            echo "  stop <svc>    Stop a service"
            echo "  restart <svc> Restart a service"
            echo "  status [svc]  Show service status"
            echo "  list [filter] List services (all/running/stopped/failed)"
            echo "  start-all     Start all services"
            echo "  stop-all      Stop all services"
            echo "  help          Show this help"
            ;;
    esac
}

main "$@"