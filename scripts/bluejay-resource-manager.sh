#!/bin/bash
# BluejayLinux Resource Manager - Process limits, memory management, and resource allocation
# Prevents system exhaustion and ensures proper resource distribution

set -e

RESOURCE_CONFIG="/etc/bluejay/resources.conf"
CGROUPS_ROOT="/sys/fs/cgroup"
LIMITS_DIR="/etc/security/limits.d"

log_resource() {
    echo "[$(date '+%H:%M:%S')] RESOURCE: $1" | tee -a /var/log/bluejay-resources.log
}

log_error() {
    echo "[$(date '+%H:%M:%S')] ERROR: $1" | tee -a /var/log/bluejay-resources.log >&2
}

log_success() {
    echo "[$(date '+%H:%M:%S')] SUCCESS: $1" | tee -a /var/log/bluejay-resources.log
}

# Initialize resource management
init_resource_manager() {
    log_resource "Initializing BluejayLinux Resource Manager..."
    
    # Create configuration directories
    mkdir -p "$(dirname "$RESOURCE_CONFIG")"
    mkdir -p "$LIMITS_DIR"
    mkdir -p /var/log
    
    # Enable cgroups v2 if available
    if [ -d "$CGROUPS_ROOT" ]; then
        # Mount cgroups v2 if not mounted
        if ! mountpoint -q "$CGROUPS_ROOT"; then
            mount -t cgroup2 none "$CGROUPS_ROOT" 2>/dev/null || {
                # Fall back to cgroups v1
                mount -t tmpfs cgroup "$CGROUPS_ROOT"
                mkdir -p "$CGROUPS_ROOT/cpu"
                mkdir -p "$CGROUPS_ROOT/memory"
                mkdir -p "$CGROUPS_ROOT/pids"
                mount -t cgroup -ocpu cgroup "$CGROUPS_ROOT/cpu"
                mount -t cgroup -omemory cgroup "$CGROUPS_ROOT/memory"
                mount -t cgroup -opids cgroup "$CGROUPS_ROOT/pids"
            }
        fi
        log_success "Control groups initialized"
    fi
    
    # Set up system-wide resource limits
    setup_system_limits
    
    # Create cgroup hierarchies
    setup_cgroups
    
    # Configure process limits
    setup_process_limits
    
    log_success "Resource Manager initialized"
}

# Setup system-wide limits
setup_system_limits() {
    log_resource "Setting up system-wide resource limits..."
    
    # Create main limits configuration
    cat > "$LIMITS_DIR/10-bluejay-system.conf" << 'EOF'
# BluejayLinux System Resource Limits

# Root user limits (for system processes)
root    soft    nofile      65536
root    hard    nofile      65536
root    soft    nproc       32768
root    hard    nproc       32768
root    soft    memlock     unlimited
root    hard    memlock     unlimited

# Regular user limits  
*       soft    nofile      8192
*       hard    nofile      16384
*       soft    nproc       4096
*       hard    nproc       8192
*       soft    memlock     64
*       hard    memlock     64
*       soft    core        0
*       hard    core        unlimited
*       soft    cpu         unlimited
*       hard    cpu         unlimited
*       soft    data        unlimited
*       hard    data        unlimited
*       soft    fsize       unlimited
*       hard    fsize       unlimited
*       soft    rss         unlimited
*       hard    rss         unlimited
*       soft    stack       8192
*       hard    stack       unlimited
*       soft    as          unlimited
*       hard    as          unlimited
*       soft    maxlogins   10
*       hard    maxlogins   10

# Security-focused user limits
bluejay soft    nofile      16384
bluejay hard    nofile      32768
bluejay soft    nproc       8192
bluejay hard    nproc       16384
EOF

    # Set kernel parameters for resource management
    cat > /etc/sysctl.d/10-bluejay-resources.conf << 'EOF'
# BluejayLinux Resource Management Kernel Parameters

# Process limits
kernel.pid_max = 4194304
kernel.threads-max = 2097152

# Memory management
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.vfs_cache_pressure = 50
vm.min_free_kbytes = 65536

# File system limits
fs.file-max = 2097152
fs.nr_open = 1048576

# Network limits
net.core.somaxconn = 4096
net.core.netdev_max_backlog = 5000

# Security limits
kernel.yama.ptrace_scope = 1
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
EOF

    # Apply sysctl settings
    if command -v sysctl >/dev/null; then
        sysctl -p /etc/sysctl.d/10-bluejay-resources.conf 2>/dev/null || true
    fi
    
    log_success "System limits configured"
}

# Setup control groups
setup_cgroups() {
    log_resource "Setting up control groups..."
    
    if [ ! -d "$CGROUPS_ROOT" ]; then
        log_resource "Control groups not available, skipping"
        return 0
    fi
    
    # Create BluejayLinux cgroup hierarchy
    local bluejay_cgroup="$CGROUPS_ROOT/bluejay"
    
    # Check for cgroups v2
    if [ -f "$CGROUPS_ROOT/cgroup.controllers" ]; then
        # cgroups v2
        mkdir -p "$bluejay_cgroup"
        mkdir -p "$bluejay_cgroup/system"
        mkdir -p "$bluejay_cgroup/user"
        mkdir -p "$bluejay_cgroup/security"
        
        # Enable controllers
        echo "+cpu +memory +pids" > "$CGROUPS_ROOT/cgroup.subtree_control" 2>/dev/null || true
        echo "+cpu +memory +pids" > "$bluejay_cgroup/cgroup.subtree_control" 2>/dev/null || true
        
        # Set system limits (80% of resources for system)
        local total_memory=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
        local system_memory=$((total_memory * 80 / 100))
        echo "${system_memory}K" > "$bluejay_cgroup/system/memory.max" 2>/dev/null || true
        echo "8192" > "$bluejay_cgroup/system/pids.max" 2>/dev/null || true
        
        # Set user limits (15% of resources for regular users)
        local user_memory=$((total_memory * 15 / 100))
        echo "${user_memory}K" > "$bluejay_cgroup/user/memory.max" 2>/dev/null || true
        echo "4096" > "$bluejay_cgroup/user/pids.max" 2>/dev/null || true
        
        # Set security tools limits (5% reserved for security tools)
        local security_memory=$((total_memory * 5 / 100))
        echo "${security_memory}K" > "$bluejay_cgroup/security/memory.max" 2>/dev/null || true
        echo "2048" > "$bluejay_cgroup/security/pids.max" 2>/dev/null || true
        
    else
        # cgroups v1
        for controller in cpu memory pids; do
            local controller_path="$CGROUPS_ROOT/$controller"
            if [ -d "$controller_path" ]; then
                mkdir -p "$controller_path/bluejay"
                mkdir -p "$controller_path/bluejay/system"
                mkdir -p "$controller_path/bluejay/user"
                mkdir -p "$controller_path/bluejay/security"
                
                # Set limits based on controller type
                case "$controller" in
                    memory)
                        local total_memory=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
                        local system_memory=$((total_memory * 80 / 100))
                        local user_memory=$((total_memory * 15 / 100))
                        local security_memory=$((total_memory * 5 / 100))
                        
                        echo "${system_memory}000" > "$controller_path/bluejay/system/memory.limit_in_bytes" 2>/dev/null || true
                        echo "${user_memory}000" > "$controller_path/bluejay/user/memory.limit_in_bytes" 2>/dev/null || true  
                        echo "${security_memory}000" > "$controller_path/bluejay/security/memory.limit_in_bytes" 2>/dev/null || true
                        ;;
                    pids)
                        echo "8192" > "$controller_path/bluejay/system/pids.max" 2>/dev/null || true
                        echo "4096" > "$controller_path/bluejay/user/pids.max" 2>/dev/null || true
                        echo "2048" > "$controller_path/bluejay/security/pids.max" 2>/dev/null || true
                        ;;
                    cpu)
                        # Set CPU shares (system gets more CPU time)
                        echo "2048" > "$controller_path/bluejay/system/cpu.shares" 2>/dev/null || true
                        echo "1024" > "$controller_path/bluejay/user/cpu.shares" 2>/dev/null || true
                        echo "512" > "$controller_path/bluejay/security/cpu.shares" 2>/dev/null || true
                        ;;
                esac
            fi
        done
    fi
    
    log_success "Control groups configured"
}

# Setup process limits
setup_process_limits() {
    log_resource "Setting up process limits..."
    
    # Create default resource configuration
    cat > "$RESOURCE_CONFIG" << 'EOF'
# BluejayLinux Resource Configuration

# Memory limits (in MB)
SYSTEM_MEMORY_LIMIT=80%
USER_MEMORY_LIMIT=15%
SECURITY_MEMORY_LIMIT=5%

# Process limits
MAX_USER_PROCESSES=4096
MAX_SYSTEM_PROCESSES=8192
MAX_SECURITY_PROCESSES=2048

# File descriptor limits
MAX_FILE_DESCRIPTORS=16384
MAX_OPEN_FILES=8192

# CPU limits
CPU_INTENSIVE_LIMIT=80%
BACKGROUND_CPU_LIMIT=20%

# Disk I/O limits
MAX_DISK_WRITE_BW=100M
MAX_DISK_READ_BW=200M
EOF

    # Create resource monitoring script
    cat > /opt/bluejay/bin/bluejay-resource-monitor << 'EOF'
#!/bin/bash
# BluejayLinux Resource Monitor

while true; do
    # Monitor memory usage
    memory_usage=$(free | grep Mem | awk '{printf "%.2f", $3/$2 * 100.0}')
    if (( $(echo "$memory_usage > 90" | bc -l) )); then
        echo "[$(date)] WARNING: High memory usage: ${memory_usage}%" >> /var/log/bluejay-resources.log
        
        # Kill memory-intensive processes if needed
        ps aux --sort=-%mem | head -10 | while read user pid cpu mem vsz rss tty stat start time command; do
            if (( $(echo "$mem > 20" | bc -l) )) && [ "$user" != "root" ]; then
                echo "[$(date)] Killing memory-intensive process: $pid ($command)" >> /var/log/bluejay-resources.log
                kill -TERM "$pid" 2>/dev/null || true
            fi
        done
    fi
    
    # Monitor CPU usage
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    if (( $(echo "$cpu_usage > 95" | bc -l) )); then
        echo "[$(date)] WARNING: High CPU usage: ${cpu_usage}%" >> /var/log/bluejay-resources.log
    fi
    
    # Monitor disk usage
    disk_usage=$(df / | tail -1 | awk '{print $5}' | cut -d'%' -f1)
    if [ "$disk_usage" -gt 90 ]; then
        echo "[$(date)] WARNING: High disk usage: ${disk_usage}%" >> /var/log/bluejay-resources.log
    fi
    
    # Monitor process count
    process_count=$(ps aux | wc -l)
    if [ "$process_count" -gt 1000 ]; then
        echo "[$(date)] WARNING: High process count: $process_count" >> /var/log/bluejay-resources.log
    fi
    
    sleep 30
done
EOF
    chmod +x /opt/bluejay/bin/bluejay-resource-monitor
    
    log_success "Process limits configured"
}

# Apply resource limits to a process
apply_limits() {
    local pid="$1"
    local category="${2:-user}"  # system, user, security
    
    if [ -z "$pid" ] || [ ! -d "/proc/$pid" ]; then
        log_error "Invalid PID: $pid"
        return 1
    fi
    
    log_resource "Applying $category limits to process $pid"
    
    # Move to appropriate cgroup
    local cgroup_path
    if [ -f "$CGROUPS_ROOT/cgroup.controllers" ]; then
        # cgroups v2
        cgroup_path="$CGROUPS_ROOT/bluejay/$category"
        echo "$pid" > "$cgroup_path/cgroup.procs" 2>/dev/null || true
    else
        # cgroups v1
        for controller in cpu memory pids; do
            local controller_path="$CGROUPS_ROOT/$controller"
            if [ -d "$controller_path/bluejay/$category" ]; then
                echo "$pid" > "$controller_path/bluejay/$category/cgroup.procs" 2>/dev/null || true
            fi
        done
    fi
    
    # Apply additional limits using ulimit if process is a shell
    case "$category" in
        system)
            # System processes get higher limits
            ;;
        user)
            # Regular user limits
            ;;
        security)
            # Security tools get specialized limits
            ;;
    esac
    
    log_success "Limits applied to process $pid"
}

# Monitor system resources
monitor_resources() {
    echo "BluejayLinux Resource Monitor"
    echo "============================"
    echo ""
    
    # Memory information
    echo "Memory Usage:"
    free -h
    echo ""
    
    # CPU information
    echo "CPU Usage:"
    top -bn1 | head -3
    echo ""
    
    # Disk usage
    echo "Disk Usage:"
    df -h
    echo ""
    
    # Process count
    echo "Process Count: $(ps aux | wc -l)"
    echo ""
    
    # Control group information
    if [ -d "$CGROUPS_ROOT/bluejay" ]; then
        echo "Control Groups:"
        for category in system user security; do
            local cgroup="$CGROUPS_ROOT/bluejay/$category"
            if [ -d "$cgroup" ]; then
                local procs=0
                if [ -f "$cgroup/cgroup.procs" ]; then
                    procs=$(wc -l < "$cgroup/cgroup.procs" 2>/dev/null || echo 0)
                fi
                echo "  $category: $procs processes"
            fi
        done
    fi
    
    # Load averages
    echo ""
    echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
}

# Clean up zombie processes
cleanup_zombies() {
    log_resource "Cleaning up zombie processes..."
    
    local zombie_count=$(ps aux | awk '$8 ~ /^Z/ { print $2 }' | wc -l)
    if [ "$zombie_count" -gt 0 ]; then
        log_resource "Found $zombie_count zombie processes"
        
        # Kill parent processes of zombies
        ps aux | awk '$8 ~ /^Z/ { print $3 }' | sort -u | while read ppid; do
            if [ "$ppid" != "1" ] && [ "$ppid" != "0" ]; then
                log_resource "Sending SIGCHLD to parent process $ppid"
                kill -CHLD "$ppid" 2>/dev/null || true
            fi
        done
        
        log_success "Zombie cleanup completed"
    else
        log_resource "No zombie processes found"
    fi
}

# Main command handler
main() {
    local command="${1:-help}"
    
    case "$command" in
        init)
            init_resource_manager
            ;;
        monitor)
            monitor_resources
            ;;
        apply)
            local pid="$2"
            local category="$3"
            apply_limits "$pid" "$category"
            ;;
        cleanup)
            cleanup_zombies
            ;;
        start-monitor)
            log_resource "Starting resource monitor daemon..."
            /opt/bluejay/bin/bluejay-resource-monitor &
            echo $! > /run/bluejay-resource-monitor.pid
            log_success "Resource monitor started"
            ;;
        stop-monitor)
            if [ -f /run/bluejay-resource-monitor.pid ]; then
                local pid=$(cat /run/bluejay-resource-monitor.pid)
                kill "$pid" 2>/dev/null || true
                rm -f /run/bluejay-resource-monitor.pid
                log_success "Resource monitor stopped"
            fi
            ;;
        help|*)
            echo "BluejayLinux Resource Manager"
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  init                  Initialize resource management"
            echo "  monitor               Show current resource usage"
            echo "  apply <pid> [cat]     Apply limits to process (system/user/security)"
            echo "  cleanup               Clean up zombie processes"
            echo "  start-monitor         Start resource monitoring daemon"
            echo "  stop-monitor          Stop resource monitoring daemon"
            echo "  help                  Show this help"
            ;;
    esac
}

main "$@"