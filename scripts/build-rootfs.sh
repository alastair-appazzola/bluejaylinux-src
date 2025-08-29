#!/bin/bash
# Build Blue-Jay Linux Root Filesystem

set -e

source ../build-bluejay.sh 2>/dev/null || {
    ROOTFS="/tmp/bluejay-build/rootfs"
    BUILD_ROOT="/tmp/bluejay-build"
}

log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $1"; }

create_base_dirs() {
    log_info "Creating base filesystem structure..."
    
    # Standard Linux directories
    local dirs=(
        "bin" "sbin" "usr/bin" "usr/sbin" "usr/local/bin" "usr/local/sbin"
        "etc" "etc/systemd/system" "etc/bluejay"
        "var" "var/log" "var/cache" "var/lib" "var/tmp"
        "tmp" "root" "home"
        "dev" "proc" "sys" "run"
        "lib" "lib64" "usr/lib" "usr/lib64"
        "opt" "opt/bluejay" "opt/bluejay/tools"
        "boot" "mnt" "media"
    )
    
    # Ensure rootfs base exists
    mkdir -p "${ROOTFS}"
    
    for dir in "${dirs[@]}"; do
        mkdir -p "${ROOTFS}/${dir}"
    done
    
    # Set proper permissions
    chmod 755 "${ROOTFS}"/{bin,sbin,usr,etc,var,tmp,opt,boot,mnt,media}
    chmod 700 "${ROOTFS}/root"
    chmod 1777 "${ROOTFS}/tmp"
    chmod 1777 "${ROOTFS}/var/tmp"
    
    log_success "Base filesystem structure created"
}

install_system_binaries() {
    log_info "Installing essential system binaries..."
    
    # Check if already installed
    if [ -f "${ROOTFS}/bin/busybox" ]; then
        log_info "System binaries already installed, skipping..."
        return
    fi
    
    # Install BusyBox as the primary userland
    if command -v busybox >/dev/null 2>&1; then
        log_info "Installing BusyBox..."
        cp "$(which busybox)" "${ROOTFS}/bin/busybox"
        chmod +x "${ROOTFS}/bin/busybox"
        
        # Create BusyBox symlinks for essential commands
        cd "${ROOTFS}/bin"
        ln -sf busybox sh
        ln -sf busybox ls
        ln -sf busybox cat
        ln -sf busybox cp
        ln -sf busybox mv
        ln -sf busybox rm
        ln -sf busybox mkdir
        ln -sf busybox rmdir
        ln -sf busybox chmod
        ln -sf busybox chown
        ln -sf busybox mount
        ln -sf busybox umount
        ln -sf busybox ps
        ln -sf busybox kill
        ln -sf busybox grep
        ln -sf busybox sed
        ln -sf busybox awk
        ln -sf busybox vi
        ln -sf busybox ash
        ln -sf busybox bash
        
        cd "${ROOTFS}/sbin"
        ln -sf ../bin/busybox init
        ln -sf ../bin/busybox ifconfig
        ln -sf ../bin/busybox route
        ln -sf ../bin/busybox modprobe
        ln -sf ../bin/busybox insmod
        ln -sf ../bin/busybox rmmod
        ln -sf ../bin/busybox lsmod
        
        log_success "BusyBox installed with symlinks"
    else
        log_error "BusyBox not found. Please install busybox first."
        log_info "Creating minimal shell script fallbacks..."
        
        # Create minimal shell script versions of essential commands
        cat > "${ROOTFS}/bin/sh" << 'EOF'
#!/bin/bash
exec /bin/bash "$@"
EOF
        
        cat > "${ROOTFS}/bin/ls" << 'EOF'
#!/bin/bash
echo "Minimal ls implementation"
for f in "$@"; do
    if [ -z "$f" ]; then f='.'; fi
    if [ -d "$f" ]; then
        echo "Directory: $f"
        for item in "$f"/*; do
            [ -e "$item" ] && basename "$item"
        done
    elif [ -f "$f" ]; then
        echo "File: $f"
    fi
done
EOF
        
        chmod +x "${ROOTFS}/bin/"*
        log_success "Minimal shell scripts created"
    fi
}

create_device_nodes() {
    log_info "Creating essential device nodes..."
    
    cd "${ROOTFS}/dev"
    
    # Create basic device nodes (skip if they exist)
    mknod -m 666 null c 1 3 2>/dev/null || true
    mknod -m 666 zero c 1 5 2>/dev/null || true
    mknod -m 644 random c 1 8 2>/dev/null || true
    mknod -m 644 urandom c 1 9 2>/dev/null || true
    mknod -m 622 console c 5 1 2>/dev/null || true
    mknod -m 666 tty c 5 0 2>/dev/null || true
    mknod -m 666 ptmx c 5 2 2>/dev/null || true
    
    # Create ttys
    mkdir -p pts
    for i in {0..7}; do
        mknod -m 620 "tty${i}" c 4 $i 2>/dev/null || true
    done
    
    log_success "Device nodes created"
}

configure_base_system() {
    log_info "Configuring base system..."
    
    # Create /etc/passwd
    cat > "${ROOTFS}/etc/passwd" << 'EOF'
root:x:0:0:root:/root:/bin/sh
bluejay:x:1000:1000:Blue-Jay User:/home/bluejay:/bin/bash
nobody:x:65534:65534:Nobody:/:/bin/false
EOF
    
    # Create /etc/group
    cat > "${ROOTFS}/etc/group" << 'EOF'
root:x:0:
bluejay:x:1000:
nogroup:x:65534:
EOF
    
    # Create /etc/shadow
    cat > "${ROOTFS}/etc/shadow" << 'EOF'
root:*:19000:0:99999:7:::
bluejay:*:19000:0:99999:7:::
nobody:*:19000:0:99999:7:::
EOF
    chmod 640 "${ROOTFS}/etc/shadow"
    
    # Create /etc/hostname
    echo "bluejay-linux" > "${ROOTFS}/etc/hostname"
    
    # Create /etc/hosts
    cat > "${ROOTFS}/etc/hosts" << 'EOF'
127.0.0.1   localhost bluejay-linux
::1         localhost bluejay-linux
EOF
    
    # Create /etc/fstab
    cat > "${ROOTFS}/etc/fstab" << 'EOF'
# Blue-Jay Linux fstab
proc            /proc           proc    defaults                0   0
sysfs           /sys            sysfs   defaults                0   0
devpts          /dev/pts        devpts  defaults                0   0
tmpfs           /tmp            tmpfs   defaults,nodev,nosuid   0   0
tmpfs           /run            tmpfs   defaults,nodev,nosuid   0   0
EOF
    
    # Create Blue-Jay specific configs
    mkdir -p "${ROOTFS}/etc/bluejay"
    cat > "${ROOTFS}/etc/bluejay/release" << EOF
DISTRIB_ID="Blue-Jay Linux"
DISTRIB_RELEASE="1.0.0"
DISTRIB_CODENAME="Reconnaissance" 
DISTRIB_DESCRIPTION="Blue-Jay Linux 1.0.0 (Reconnaissance)"
VERSION="1.0.0"
VERSION_CODENAME="Reconnaissance"
VERSION_ID="1.0"
ID="bluejay"
ID_LIKE="debian"
PRETTY_NAME="Blue-Jay Linux 1.0.0"
HOME_URL="https://bluejay-linux.org"
SUPPORT_URL="https://bluejay-linux.org/support"
BUG_REPORT_URL="https://bluejay-linux.org/bugs"
PRIVACY_POLICY_URL="https://bluejay-linux.org/privacy"
EOF
    
    # Link to standard locations
    ln -sf /etc/bluejay/release "${ROOTFS}/etc/lsb-release"
    ln -sf /etc/bluejay/release "${ROOTFS}/etc/os-release"
    
    log_success "Base system configured"
}

install_init_system() {
    log_info "Installing BluejayLinux advanced init system..."
    
    # Copy the advanced init system
    if [ -f "$(dirname "$0")/bluejay-init.sh" ]; then
        cp "$(dirname "$0")/bluejay-init.sh" "${ROOTFS}/sbin/init"
        chmod +x "${ROOTFS}/sbin/init"
        log_success "BluejayLinux advanced init system installed"
    else
        log_error "BluejayLinux init script not found, creating basic fallback..."
        
        # Create basic fallback init script
        cat > "${ROOTFS}/sbin/init" << 'EOF'
#!/bin/sh
# BluejayLinux Basic Init System (Fallback)

export PATH="/bin:/sbin:/usr/bin:/usr/sbin:/opt/bluejay/tools/bin"

echo "Starting BluejayLinux (Basic Mode)..."

# Mount essential filesystems
mkdir -p /proc /sys /dev/pts /tmp /run
mount -t proc proc /proc || echo "Failed to mount /proc"
mount -t sysfs sysfs /sys || echo "Failed to mount /sys"
mount -t devpts devpts /dev/pts || echo "Failed to mount /dev/pts"
mount -t tmpfs tmpfs /tmp || echo "Failed to mount /tmp"
mount -t tmpfs tmpfs /run || echo "Failed to mount /run"

# Set hostname
if [ -f /etc/hostname ]; then
    hostname "$(cat /etc/hostname)"
fi

# Basic networking
ip link set lo up 2>/dev/null || ifconfig lo up 2>/dev/null || true
ip addr add 127.0.0.1/8 dev lo 2>/dev/null || ifconfig lo 127.0.0.1 netmask 255.0.0.0 2>/dev/null || true

# Load essential modules
if [ -d /lib/modules ]; then
    for module in ahci e1000 e1000e r8169 sd_mod ext4; do
        modprobe "$module" 2>/dev/null || true
    done
fi

echo "
BluejayLinux - Cybersecurity Made Simple
Version 1.0.0 'Reconnaissance'

System ready. Type 'bluejay-tools' to see available security tools.
"

# Start shell
exec /bin/sh -l
EOF
        
        chmod +x "${ROOTFS}/sbin/init"
        log_success "Basic init system installed"
    fi
}

create_bluejay_user() {
    log_info "Setting up Blue-Jay user environment..."
    
    mkdir -p "${ROOTFS}/home/bluejay"
    
    # Create user profile
    cat > "${ROOTFS}/home/bluejay/.profile" << 'EOF'
# Blue-Jay Linux User Profile
export PATH="/opt/bluejay/tools/bin:$PATH"
export PS1="\[\033[01;34m\]bluejay@\h\[\033[00m\]:\[\033[01;32m\]\w\[\033[00m\]\$ "

# Cybersec aliases
alias nmap-quick='nmap -T4 -F'
alias nmap-full='nmap -T4 -A -v'
alias netstat-listen='netstat -tlnp'
alias ports='ss -tuln'

# Tool shortcuts
alias msf='msfconsole'
alias burp='java -jar /opt/bluejay/tools/burpsuite/burpsuite_community.jar'

echo "Welcome to Blue-Jay Linux - Your Cybersecurity Toolkit"
echo "Type 'bluejay-tools' to see available security tools"
EOF
    
    # Create tools launcher script
    cat > "${ROOTFS}/usr/bin/bluejay-tools" << 'EOF'
#!/bin/sh
echo "Blue-Jay Linux Security Tools:"
echo "================================"
echo "Network Analysis:"
echo "  nmap          - Network mapper"
echo "  netcat        - Network swiss army knife" 
echo "  tcpdump       - Packet analyzer"
echo ""
echo "Web Security:"
echo "  curl          - URL transfer tool"
echo "  wget          - Web downloader"
echo ""
echo "System Analysis:"
echo "  ps            - Process list"
echo "  netstat       - Network statistics"
echo "  ss            - Socket statistics"
echo ""
echo "More tools will be added in future releases!"
EOF
    chmod +x "${ROOTFS}/usr/bin/bluejay-tools"
    
    # Set ownership (will need to be fixed in final system)
    chown -R 1000:1000 "${ROOTFS}/home/bluejay" 2>/dev/null || true
    
    log_success "Blue-Jay user environment created"
}

install_medium_level_managers() {
    log_info "Installing medium-level system managers..."
    
    # Create BluejayLinux bin directory
    mkdir -p "${ROOTFS}/opt/bluejay/bin"
    
    # Copy all medium-level managers
    local managers=(
        "bluejay-service-manager.sh"
        "bluejay-resource-manager.sh"
        "bluejay-input-manager.sh"
        "bluejay-display-server.sh"
        "bluejay-window-manager.sh"
        "bluejay-ipc-manager.sh"
        "bluejay-session-manager.sh"
        "bluejay-audio-manager.sh"
        "bluejay-hotplug-manager.sh"
        "bluejay-power-manager.sh"
    )
    
    for manager in "${managers[@]}"; do
        if [ -f "scripts/$manager" ]; then
            cp "scripts/$manager" "${ROOTFS}/opt/bluejay/bin/${manager%.sh}"
            chmod +x "${ROOTFS}/opt/bluejay/bin/${manager%.sh}"
            log_info "Installed: ${manager%.sh}"
        fi
    done
    
    # Install medium-level testing framework
    if [ -f "scripts/bluejay-medium-test.sh" ]; then
        cp "scripts/bluejay-medium-test.sh" "${ROOTFS}/opt/bluejay/bin/bluejay-medium-test"
        chmod +x "${ROOTFS}/opt/bluejay/bin/bluejay-medium-test"
        log_info "Installed medium-level testing framework"
    fi
    
    # Create systemd-style service files for medium-level components
    mkdir -p "${ROOTFS}/etc/bluejay/services"
    
    # Service definitions with proper dependencies
    local services=(
        "bluejay-service-manager:/opt/bluejay/bin/bluejay-service-manager init"
        "bluejay-resource-manager:/opt/bluejay/bin/bluejay-resource-manager start-monitor"
        "bluejay-input-manager:/opt/bluejay/bin/bluejay-input-manager start"
        "bluejay-display-server:/opt/bluejay/bin/bluejay-display-server start"
        "bluejay-window-manager:/opt/bluejay/bin/bluejay-window-manager start"
        "bluejay-ipc-manager:/opt/bluejay/bin/bluejay-ipc-manager start"
        "bluejay-session-manager:/opt/bluejay/bin/bluejay-session-manager start"
        "bluejay-audio-manager:/opt/bluejay/bin/bluejay-audio-manager start"
        "bluejay-hotplug-manager:/opt/bluejay/bin/bluejay-hotplug-manager start"
        "bluejay-power-manager:/opt/bluejay/bin/bluejay-power-manager start"
    )
    
    for service_def in "${services[@]}"; do
        local service_name="${service_def%%:*}"
        local service_cmd="${service_def#*:}"
        
        cat > "${ROOTFS}/etc/bluejay/services/${service_name}.service" << EOF
ExecStart=$service_cmd
PIDFile=/run/${service_name}.pid
Restart=yes
RestartDelay=5
EOF
    done
    
    # Set up service dependencies
    echo "bluejay-input-manager" > "${ROOTFS}/etc/bluejay/services/bluejay-display-server.deps"
    echo "bluejay-display-server" > "${ROOTFS}/etc/bluejay/services/bluejay-window-manager.deps"
    echo "bluejay-ipc-manager" > "${ROOTFS}/etc/bluejay/services/bluejay-session-manager.deps"
    
    log_success "Medium-level managers installed and configured"
}

main() {
    log_info "Building Blue-Jay Linux root filesystem..."
    
    create_base_dirs
    install_system_binaries
    create_device_nodes
    configure_base_system
    install_init_system
    create_bluejay_user
    install_medium_level_managers
    
    log_success "Root filesystem build complete with medium-level functionality"
}

main "$@"