#!/bin/sh
# BluejayLinux Advanced Init System
# Comprehensive initialization for cybersecurity-focused OS

export PATH="/bin:/sbin:/usr/bin:/usr/sbin:/opt/bluejay/tools/bin"

# System identification
BLUEJAY_VERSION="1.0.0"
BLUEJAY_CODENAME="Reconnaissance"
BLUEJAY_LOGO="
 ____  _             _               _ _
| __ )| |_   _  ___ (_) __ _ _   _   | (_)_ __  _   ___  __
|  _ \| | | | |/ _ \| |/ _\` | | | |  | | | '_ \| | | \ \/ /
| |_) | | |_| |  __/| | (_| | |_| |  | | | | | | |_| |>  < 
|____/|_|\__,_|\___|/ |\__,_|\__, |  |_|_|_| |_|\__,_/_/\_\\
                   |__/      |___/                         
                                                           
         Cybersecurity Made Simple
         Version ${BLUEJAY_VERSION} \"${BLUEJAY_CODENAME}\"
"

# Logging functions
log() {
    echo "[ $(date '+%H:%M:%S') ] $1" | tee -a /var/log/bluejay-init.log
}

log_error() {
    echo "[ $(date '+%H:%M:%S') ] ERROR: $1" | tee -a /var/log/bluejay-init.log >&2
}

log_success() {
    echo "[ $(date '+%H:%M:%S') ] SUCCESS: $1" | tee -a /var/log/bluejay-init.log
}

# Emergency shell function
emergency_shell() {
    log_error "Critical error during boot. Starting emergency shell..."
    echo "BluejayLinux Emergency Shell"
    echo "Type 'exit' to continue boot or 'reboot' to restart"
    exec /bin/sh
}

# Mount essential filesystems
mount_essential() {
    log "Mounting essential filesystems..."
    
    # Create mount points if they don't exist
    mkdir -p /proc /sys /dev /dev/pts /tmp /run /var/log
    
    # Mount virtual filesystems
    if ! mount -t proc proc /proc; then
        log_error "Failed to mount /proc"
        return 1
    fi
    
    if ! mount -t sysfs sysfs /sys; then
        log_error "Failed to mount /sys"
        return 1
    fi
    
    if ! mount -t devtmpfs devtmpfs /dev; then
        log_error "Failed to mount /dev"
        return 1
    fi
    
    if ! mount -t devpts devpts /dev/pts; then
        log_error "Failed to mount /dev/pts"
        return 1
    fi
    
    if ! mount -t tmpfs tmpfs /tmp; then
        log_error "Failed to mount /tmp"
        return 1
    fi
    
    if ! mount -t tmpfs tmpfs /run; then
        log_error "Failed to mount /run"
        return 1
    fi
    
    # Mount /var/log for persistent logging
    mkdir -p /var/log
    if ! mount -t tmpfs tmpfs /var/log; then
        log_error "Failed to mount /var/log"
        return 1
    fi
    
    log_success "Essential filesystems mounted"
    return 0
}

# Load kernel modules
load_modules() {
    log "Loading kernel modules..."
    
    # Check if modules directory exists
    if [ ! -d /lib/modules ]; then
        log "No kernel modules directory found, skipping module loading"
        return 0
    fi
    
    # Load essential modules for hardware support
    local essential_modules=(
        "ahci"        # SATA support
        "e1000"       # Intel network
        "e1000e"      # Intel network (newer)
        "r8169"       # Realtek network
        "usb_storage" # USB storage
        "sd_mod"      # SCSI disk support
        "ext4"        # EXT4 filesystem
        "vfat"        # FAT filesystem
    )
    
    for module in "${essential_modules[@]}"; do
        if [ -f "/lib/modules/$(uname -r)/kernel/drivers"*"/${module}.ko" ]; then
            if modprobe "$module" 2>/dev/null; then
                log "Loaded module: $module"
            else
                log "Failed to load module: $module (non-critical)"
            fi
        fi
    done
    
    # Auto-load modules for detected hardware
    if [ -x /sbin/modprobe ] && [ -f /proc/modules ]; then
        log "Auto-detecting and loading hardware modules..."
        # This would normally use udev, but we'll do basic detection
        find /sys/devices -name modalias -exec cat {} \; 2>/dev/null | sort -u | \
        while read -r alias; do
            modprobe "$alias" 2>/dev/null || true
        done
    fi
    
    log_success "Kernel modules loaded"
    return 0
}

# Setup network interfaces
setup_network() {
    log "Setting up network interfaces..."
    
    # Bring up loopback interface
    if ! ip link set lo up; then
        log_error "Failed to bring up loopback interface"
        return 1
    fi
    
    if ! ip addr add 127.0.0.1/8 dev lo; then
        log_error "Failed to configure loopback address"
        return 1
    fi
    
    # Auto-configure network interfaces
    for iface in $(ip link show | grep -E '^[0-9]+:' | cut -d: -f2 | tr -d ' ' | grep -v '^lo$'); do
        if [ "$iface" != "lo" ]; then
            log "Configuring interface: $iface"
            
            # Bring up the interface
            if ip link set "$iface" up; then
                log "Interface $iface brought up"
                
                # Try DHCP if dhclient is available
                if command -v dhclient >/dev/null 2>&1; then
                    dhclient "$iface" -timeout 10 2>/dev/null &
                    log "Started DHCP client for $iface"
                else
                    log "DHCP client not available for $iface"
                fi
            else
                log "Failed to bring up interface: $iface"
            fi
        fi
    done
    
    log_success "Network setup completed"
    return 0
}

# Initialize system services
init_services() {
    log "Initializing system services..."
    
    # Set hostname
    if [ -f /etc/hostname ]; then
        hostname="$(cat /etc/hostname)"
        if [ -n "$hostname" ]; then
            hostname "$hostname"
            log "Hostname set to: $hostname"
        fi
    fi
    
    # Setup /etc/hosts if it doesn't exist
    if [ ! -f /etc/hosts ]; then
        cat > /etc/hosts << 'EOF'
127.0.0.1   localhost
::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
EOF
    fi
    
    # Initialize service manager
    if [ -x /opt/bluejay/bin/bluejay-service-manager ]; then
        log "Initializing BluejayLinux Service Manager..."
        /opt/bluejay/bin/bluejay-service-manager init
        
        # Start essential services in proper dependency order
        log "Starting system services..."
        /opt/bluejay/bin/bluejay-service-manager start-all
    else
        # Fallback to manual service startup
        log "Service manager not available, using manual startup..."
        local services=(
            "/sbin/syslogd"   # System logging
            "/sbin/klogd"     # Kernel logging
            "/sbin/crond"     # Cron daemon
        )
        
        for service in "${services[@]}"; do
            if [ -x "$service" ]; then
                if "$service" 2>/dev/null; then
                    log "Started service: $(basename "$service")"
                else
                    log "Failed to start service: $(basename "$service")"
                fi
            fi
        done
    fi
    
    log_success "System services initialized"
    return 0
}

# Security initialization
init_security() {
    log "Initializing security subsystems..."
    
    # Set up entropy for random number generation
    if [ -c /dev/urandom ] && [ -c /dev/random ]; then
        log "Entropy sources available"
    else
        log_error "Entropy sources not available"
        return 1
    fi
    
    # Initialize SELinux if enabled
    if [ -f /selinux/enforce ] && [ -x /sbin/load_policy ]; then
        log "Initializing SELinux..."
        if /sbin/load_policy -i 2>/dev/null; then
            log_success "SELinux policy loaded"
        else
            log "SELinux policy not loaded"
        fi
    fi
    
    # Initialize AppArmor if enabled  
    if [ -d /sys/kernel/security/apparmor ] && [ -x /sbin/apparmor_parser ]; then
        log "Initializing AppArmor..."
        if [ -d /etc/apparmor.d ]; then
            for profile in /etc/apparmor.d/*; do
                if [ -f "$profile" ]; then
                    /sbin/apparmor_parser -r "$profile" 2>/dev/null || true
                fi
            done
            log_success "AppArmor profiles loaded"
        fi
    fi
    
    # Set secure permissions on sensitive files
    chmod 600 /etc/shadow 2>/dev/null || true
    chmod 600 /etc/gshadow 2>/dev/null || true
    chmod 644 /etc/passwd 2>/dev/null || true
    chmod 644 /etc/group 2>/dev/null || true
    
    # Setup secure tmp directories
    chmod 1777 /tmp 2>/dev/null || true
    chmod 1777 /var/tmp 2>/dev/null || true
    
    log_success "Security subsystems initialized"
    return 0
}

# Hardware detection and initialization
init_hardware() {
    log "Initializing hardware..."
    
    # Initialize random number generator
    if [ -c /dev/hwrng ]; then
        log "Hardware RNG detected"
    fi
    
    # Setup console
    if [ -c /dev/console ]; then
        # Set console font and keymap if available
        if [ -x /usr/bin/setfont ]; then
            /usr/bin/setfont 2>/dev/null || true
        fi
        
        if [ -x /usr/bin/loadkeys ]; then
            /usr/bin/loadkeys us 2>/dev/null || true
        fi
    fi
    
    # Initialize storage devices
    if [ -x /sbin/blkid ]; then
        log "Scanning block devices..."
        /sbin/blkid 2>/dev/null | while read -r line; do
            device=$(echo "$line" | cut -d: -f1)
            log "Found block device: $device"
        done
    fi
    
    log_success "Hardware initialization completed"
    return 0
}

# Mount additional filesystems from /etc/fstab
mount_filesystems() {
    log "Mounting additional filesystems..."
    
    if [ -f /etc/fstab ]; then
        # Parse /etc/fstab and mount filesystems
        grep -v '^#' /etc/fstab | grep -v '^$' | while IFS=' ' read -r device mountpoint fstype options dump pass; do
            # Skip already mounted essential filesystems
            case "$mountpoint" in
                /|/proc|/sys|/dev|/dev/pts|/tmp|/run) continue ;;
            esac
            
            if [ -n "$device" ] && [ -n "$mountpoint" ] && [ -n "$fstype" ]; then
                # Create mount point if it doesn't exist
                mkdir -p "$mountpoint" 2>/dev/null
                
                # Mount the filesystem
                if mount -t "$fstype" "$device" "$mountpoint" 2>/dev/null; then
                    log "Mounted $device on $mountpoint ($fstype)"
                else
                    log "Failed to mount $device on $mountpoint"
                fi
            fi
        done
    else
        log "No /etc/fstab found, skipping additional mounts"
    fi
    
    log_success "Additional filesystems processed"
    return 0
}

# Initialize BluejayLinux specific features
init_bluejay() {
    log "Initializing BluejayLinux specific features..."
    
    # Create BluejayLinux directories
    mkdir -p /opt/bluejay/tools
    mkdir -p /opt/bluejay/reports
    mkdir -p /opt/bluejay/configs
    mkdir -p /home/bluejay
    
    # Set up BluejayLinux tools PATH
    export PATH="/opt/bluejay/tools/bin:$PATH"
    
    # Initialize tool databases if available
    if [ -x /opt/bluejay/tools/bin/updatedb ]; then
        /opt/bluejay/tools/bin/updatedb 2>/dev/null &
        log "Started security tools database update"
    fi
    
    # Load BluejayLinux-specific configurations
    if [ -f /opt/bluejay/configs/system.conf ]; then
        . /opt/bluejay/configs/system.conf
        log "Loaded BluejayLinux system configuration"
    fi
    
    log_success "BluejayLinux features initialized"
    return 0
}

# Display system information
show_system_info() {
    clear
    echo "$BLUEJAY_LOGO"
    echo
    echo "System Information:"
    echo "=================="
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo "Hostname: $(hostname)"
    echo "Uptime: $(uptime | cut -d' ' -f4-)"
    echo "Memory: $(free -h | grep '^Mem:' | awk '{print $3 "/" $2}')"
    echo
    
    # Show network interfaces
    echo "Network Interfaces:"
    ip addr show | grep -E '^[0-9]+:' | while read -r line; do
        iface=$(echo "$line" | cut -d: -f2 | tr -d ' ')
        state=$(echo "$line" | grep -o '<[^>]*>' | tr -d '<>')
        echo "  $iface: $state"
    done
    echo
    
    # Show mounted filesystems
    echo "Mounted Filesystems:"
    mount | grep -v '^tmpfs\|^proc\|^sysfs\|^devtmpfs\|^devpts' | while read -r line; do
        device=$(echo "$line" | awk '{print $1}')
        mountpoint=$(echo "$line" | awk '{print $3}')
        fstype=$(echo "$line" | awk '{print $5}')
        echo "  $device on $mountpoint ($fstype)"
    done
    echo
}

# Main initialization sequence
main() {
    log "BluejayLinux Init System starting..."
    
    # Redirect stdout/stderr to both console and log
    exec > >(tee -a /dev/console) 2>&1
    
    # Mount essential filesystems first
    if ! mount_essential; then
        emergency_shell
        exit 1
    fi
    
    # Initialize hardware early
    if ! init_hardware; then
        log_error "Hardware initialization failed, continuing anyway..."
    fi
    
    # Load kernel modules
    if ! load_modules; then
        log_error "Module loading failed, continuing anyway..."
    fi
    
    # Set up networking
    if ! setup_network; then
        log_error "Network setup failed, continuing anyway..."
    fi
    
    # Initialize security
    if ! init_security; then
        log_error "Security initialization failed, continuing anyway..."
    fi
    
    # Mount additional filesystems
    if ! mount_filesystems; then
        log_error "Additional filesystem mounting failed, continuing anyway..."
    fi
    
    # Initialize system services
    if ! init_services; then
        log_error "Service initialization failed, continuing anyway..."
    fi
    
    # Initialize BluejayLinux features
    if ! init_bluejay; then
        log_error "BluejayLinux initialization failed, continuing anyway..."
    fi
    
    log_success "BluejayLinux initialization completed"
    
    # Show system information
    show_system_info
    
    # Start shell or specified init program
    if [ -n "$1" ]; then
        log "Starting requested program: $1"
        exec "$@"
    else
        echo "Welcome to BluejayLinux!"
        echo "Type 'bluejay-tools' to see available security tools"
        echo "Type 'help' for more information"
        echo
        
        # Start interactive shell
        log "Starting interactive shell"
        exec /bin/sh -l
    fi
}

# Error handling
set -e
trap 'log_error "Init script failed at line $LINENO"; emergency_shell' ERR

# Start main initialization
main "$@"