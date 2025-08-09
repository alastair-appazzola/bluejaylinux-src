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
    log_info "Installing system binaries from host..."
    
    # Check if binaries already copied manually
    if [ -f "${ROOTFS}/bin/ls" ] && [ ! -L "${ROOTFS}/bin/ls" ]; then
        log_info "System binaries already installed, skipping..."
        return
    fi
    
    # Copy host system binaries
    log_info "Copying binaries from host system..."
    cp -r /bin/* "${ROOTFS}/bin/" 2>/dev/null || true
    cp -r /sbin/* "${ROOTFS}/sbin/" 2>/dev/null || true
    cp -r /usr/bin/* "${ROOTFS}/usr/bin/" 2>/dev/null || true
    cp -r /usr/sbin/* "${ROOTFS}/usr/sbin/" 2>/dev/null || true
    
    # Set permissions
    chmod +x "${ROOTFS}/bin"/* 2>/dev/null || true
    chmod +x "${ROOTFS}/sbin"/* 2>/dev/null || true
    chmod +x "${ROOTFS}/usr/bin"/* 2>/dev/null || true
    chmod +x "${ROOTFS}/usr/sbin"/* 2>/dev/null || true
    
    log_success "System binaries installed"
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
    log_info "Installing simple init system..."
    
    # Create basic init script
    cat > "${ROOTFS}/sbin/init" << 'EOF'
#!/bin/sh
# Blue-Jay Linux init system

export PATH="/bin:/sbin:/usr/bin:/usr/sbin"

echo "Starting Blue-Jay Linux..."

# Mount essential filesystems
mount -t proc proc /proc
mount -t sysfs sysfs /sys  
mount -t devpts devpts /dev/pts
mount -t tmpfs tmpfs /tmp
mount -t tmpfs tmpfs /run

# Load modules if needed
if [ -d /lib/modules ]; then
    modprobe -a -q $(find /lib/modules -name "*.ko" | sed 's/.*\///;s/\.ko$//' | sort -u) 2>/dev/null || true
fi

# Start networking
ifconfig lo 127.0.0.1 netmask 255.0.0.0 up

# Print Blue-Jay banner
cat << 'BANNER'
 ____  _             
| __ )| |_   _  ___  
|  _ \| | | | |/ _ \ 
| |_) | | |_| |  __/ 
|____/|_|\__,_|\___| 
      _             
     | | __ _ _   _  
  _  | |/ _` | | | | 
 | |_| | (_| | |_| | 
  \___/ \__,_|\__, | 
              |___/  

Blue-Jay Linux - Cybersecurity Made Simple
Version 1.0.0 "Reconnaissance"

BANNER

echo "System ready. Starting shell..."

# Start shell
exec /bin/sh
EOF
    
    chmod +x "${ROOTFS}/sbin/init"
    log_success "Init system installed"
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

main() {
    log_info "Building Blue-Jay Linux root filesystem..."
    
    create_base_dirs
    install_system_binaries
    create_device_nodes
    configure_base_system
    install_init_system
    create_bluejay_user
    
    log_success "Root filesystem build complete"
}

main "$@"