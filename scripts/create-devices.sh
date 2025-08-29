#!/bin/bash
# BluejayLinux Device Creation and System Integration Script

set -e

source ../build-bluejay.sh 2>/dev/null || {
    ROOTFS="/tmp/bluejay-build/rootfs"
}

log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $1"; }

create_device_nodes() {
    log_info "Creating essential device nodes..."
    
    cd "${ROOTFS}/dev"
    
    # Remove any existing device nodes
    rm -f null zero random urandom console tty ptmx full kmsg
    rm -f tty[0-9]* loop[0-9]* ram[0-9]* hd[a-z] hd[a-z][0-9]*
    rm -f sd[a-z] sd[a-z][0-9]* sr[0-9]* st[0-9]* sg[0-9]*
    
    # Essential character devices
    log_info "Creating character devices..."
    mknod -m 666 null c 1 3
    mknod -m 666 zero c 1 5
    mknod -m 644 random c 1 8
    mknod -m 644 urandom c 1 9
    mknod -m 600 console c 5 1
    mknod -m 666 tty c 5 0
    mknod -m 666 ptmx c 5 2
    mknod -m 666 full c 1 7
    mknod -m 644 kmsg c 1 11
    
    # Memory devices
    mknod -m 640 mem c 1 1
    mknod -m 640 kmem c 1 2
    mknod -m 640 port c 1 4
    
    # Standard TTYs
    log_info "Creating TTY devices..."
    for i in {0..11}; do
        mknod -m 620 "tty${i}" c 4 $i
    done
    
    # Virtual consoles
    for i in {1..6}; do
        mknod -m 600 "vc/${i}" c 4 $i 2>/dev/null || true
    done
    
    # Serial ports
    for i in {0..3}; do
        mknod -m 660 "ttyS${i}" c 4 $(( 64 + i ))
    done
    
    # Block devices for storage
    log_info "Creating block devices..."
    
    # IDE/PATA drives
    for drive in {a..d}; do
        mknod -m 660 "hd${drive}" b 3 $(( ($(printf "%d" "'${drive}") - 97) * 64 ))
        
        # Partitions
        for part in {1..15}; do
            mknod -m 660 "hd${drive}${part}" b 3 $(( ($(printf "%d" "'${drive}") - 97) * 64 + part ))
        done
    done
    
    # SCSI/SATA drives
    local major=8
    for drive in {a..z}; do
        local minor=$(( ($(printf "%d" "'${drive}") - 97) * 16 ))
        mknod -m 660 "sd${drive}" b $major $minor
        
        # Partitions
        for part in {1..15}; do
            mknod -m 660 "sd${drive}${part}" b $major $(( minor + part ))
        done
    done
    
    # CD/DVD drives
    for i in {0..3}; do
        mknod -m 660 "sr${i}" b 11 $i
        ln -sf "sr${i}" "scd${i}"  # Compatibility link
    done
    
    # Loop devices
    for i in {0..7}; do
        mknod -m 660 "loop${i}" b 7 $i
    done
    
    # RAM disks
    for i in {0..15}; do
        mknod -m 660 "ram${i}" b 1 $i
    done
    ln -sf ram1 ramdisk  # Compatibility link
    
    # Floppy drives
    for i in {0..3}; do
        mknod -m 660 "fd${i}" b 2 $i
    done
    
    # Additional useful devices
    log_info "Creating additional system devices..."
    
    # Framebuffer devices
    for i in {0..7}; do
        mknod -m 660 "fb${i}" c 29 $i
    done
    
    # Input devices
    mkdir -p input
    for i in {0..31}; do
        mknod -m 640 "input/event${i}" c 13 $(( 64 + i ))
        mknod -m 640 "input/mouse${i}" c 13 $(( 32 + i ))
    done
    
    # Sound devices
    mkdir -p snd
    mknod -m 660 "snd/controlC0" c 116 0
    mknod -m 660 "snd/pcmC0D0p" c 116 16
    mknod -m 660 "snd/pcmC0D0c" c 116 24
    mknod -m 660 "snd/timer" c 116 33
    
    # Network devices (will be created by kernel)
    # But create TUN/TAP device
    mknod -m 660 "net/tun" c 10 200
    
    # Miscellaneous devices
    mknod -m 666 "rtc" c 10 135
    mknod -m 644 "psaux" c 10 1
    mknod -m 640 "nvram" c 10 144
    mknod -m 644 "agpgart" c 10 175
    
    # USB devices placeholder
    mkdir -p "bus/usb"
    
    # Device mapper
    mknod -m 640 "mapper/control" c 10 236
    
    # Set proper ownership (will need to be fixed at runtime)
    chown -R 0:0 . 2>/dev/null || true
    
    # Fix permissions
    chmod 755 .
    chmod 755 input snd net bus bus/usb mapper vc 2>/dev/null || true
    
    log_success "Device nodes created"
}

create_system_files() {
    log_info "Creating essential system files..."
    
    # Create mtab as symlink to /proc/mounts
    ln -sf /proc/mounts "${ROOTFS}/etc/mtab"
    
    # Create resolv.conf
    cat > "${ROOTFS}/etc/resolv.conf" << 'EOF'
# BluejayLinux DNS Configuration
# This file will be updated by network configuration tools

# Google DNS (fallback)
nameserver 8.8.8.8
nameserver 8.8.4.4

# Cloudflare DNS (backup)
nameserver 1.1.1.1
nameserver 1.0.0.1
EOF
    
    # Create nsswitch.conf
    cat > "${ROOTFS}/etc/nsswitch.conf" << 'EOF'
# BluejayLinux Name Service Switch Configuration

passwd:     files
group:      files
shadow:     files
hosts:      files dns
networks:   files
protocols:  files
services:   files
ethers:     files
rpc:        files
netgroup:   files
automount:  files
aliases:    files
EOF
    
    # Create shells file
    cat > "${ROOTFS}/etc/shells" << 'EOF'
# Valid login shells
/bin/sh
/bin/bash
/bin/ash
/bin/dash
EOF
    
    # Create login.defs
    cat > "${ROOTFS}/etc/login.defs" << 'EOF'
# BluejayLinux Login Configuration

# Password aging controls
PASS_MAX_DAYS   365
PASS_MIN_DAYS   1
PASS_MIN_LEN    8
PASS_WARN_AGE   7

# Min/max values for automatic uid selection
UID_MIN         1000
UID_MAX         65000
SYS_UID_MIN     100
SYS_UID_MAX     999

# Min/max values for automatic gid selection
GID_MIN         1000
GID_MAX         65000
SYS_GID_MIN     100
SYS_GID_MAX     999

# User home directories
CREATE_HOME     yes
USERGROUPS_ENAB yes

# Security settings
ENCRYPT_METHOD  SHA512
SHA_CRYPT_MIN_ROUNDS    5000
SHA_CRYPT_MAX_ROUNDS    10000

# Environment
UMASK           022
ENV_SUPATH      PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV_PATH        PATH=/usr/local/bin:/usr/bin:/bin:/opt/bluejay/tools/bin

# Terminal settings
TTYGROUP        tty
TTYPERM         0600

# Mail settings
MAIL_DIR        /var/mail

# Logging
LOG_UNKFAIL_ENAB    no
LOG_OK_LOGINS       no
SYSLOG_SU_ENAB      yes
SYSLOG_SG_ENAB      yes
LASTLOG_ENAB        yes

# Home directory permissions
HOME_MODE       0750
EOF
    
    # Create securetty (allowed root login terminals)
    cat > "${ROOTFS}/etc/securetty" << 'EOF'
# BluejayLinux Secure TTY Configuration
# Terminals where root is allowed to login

console
tty1
tty2
tty3
tty4
tty5
tty6
ttyS0
ttyS1
vc/1
vc/2
vc/3
vc/4
vc/5
vc/6
EOF
    
    # Create issue (login banner)
    cat > "${ROOTFS}/etc/issue" << 'EOF'

BluejayLinux 1.0.0 "Reconnaissance"
Cybersecurity Made Simple

Welcome to BluejayLinux - The Ultimate Security Distribution

Type 'bluejay-tools' to see available security tools
Type 'help' for more information

EOF
    
    # Create motd (message of the day)
    cat > "${ROOTFS}/etc/motd" << 'EOF'

 ____  _             _               _
| __ )| |_   _  ___ (_) __ _ _   _   | |   (_)_ __  _   ___  __
|  _ \| | | | |/ _ \| |/ _` | | | |  | |   | | '_ \| | | \ \/ /
| |_) | | |_| |  __/| | (_| | |_| |  | |___| | | | | |_| |>  <
|____/|_|\__,_|\___|| |\__,_|\__, |  |_____|_|_| |_|\__,_/_/\_\
                   |__/      |___/

        Cybersecurity Made Simple
        Version 1.0.0 "Reconnaissance"

========================================================================
Welcome to BluejayLinux - The Ultimate Cybersecurity Distribution
========================================================================

Quick Start Guide:
  bluejay-tools      - View available security tools
  bluejay-help       - Get help and documentation
  bluejay-config     - Configure system settings
  bluejay-update     - Update security databases

Network Commands:
  nmap               - Network scanning and discovery
  netstat            - Network connections and routing
  ss                 - Socket statistics
  tcpdump            - Packet capture and analysis

Security Tools:
  Available tools will be loaded based on your selected mode:
  - Default: Basic security toolkit
  - Forensics: Digital forensics tools
  - Penetration Testing: Ethical hacking tools
  - Network Analysis: Network monitoring tools
  - Incident Response: Emergency response tools

For more information: https://bluejay-linux.org/docs
Support: https://bluejay-linux.org/support

Last login information available in /var/log/lastlog
System logs available in /var/log/

EOF
    
    # Create profile for all users
    cat > "${ROOTFS}/etc/profile" << 'EOF'
# BluejayLinux System Profile

# Set PATH
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/bluejay/tools/bin"

# Set default editor
export EDITOR="vi"

# Set less options
export LESS="-R -M --shift 5"

# Set history options
export HISTSIZE=1000
export HISTFILESIZE=2000

# Set prompt for root
if [ "$UID" = "0" ]; then
    export PS1="\[\033[01;31m\]bluejay\[\033[01;34m\]@\[\033[01;31m\]\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]# "
else
    export PS1="\[\033[01;32m\]bluejay\[\033[01;34m\]@\[\033[01;32m\]\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "
fi

# Useful aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Security aliases
alias nmap-quick='nmap -T4 -F'
alias nmap-full='nmap -T4 -A -v'
alias netstat-listen='netstat -tlnp'
alias ports='ss -tuln'
alias listen='ss -tlnp'

# System aliases
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias mount='mount | column -t'
alias ps='ps auxf'
alias psg='ps aux | grep'

# Load user profile if it exists
if [ -f "$HOME/.profile" ]; then
    . "$HOME/.profile"
fi

# Load bash-specific settings
if [ -n "$BASH_VERSION" ]; then
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi

# Initialize BluejayLinux environment
if [ -f "/opt/bluejay/init-environment.sh" ]; then
    . "/opt/bluejay/init-environment.sh"
fi

EOF
    
    # Create root's bashrc
    mkdir -p "${ROOTFS}/root"
    cat > "${ROOTFS}/root/.bashrc" << 'EOF'
# BluejayLinux Root User Configuration

# Source global definitions
if [ -f /etc/profile ]; then
    . /etc/profile
fi

# Root-specific settings
export PS1="\[\033[01;31m\]root\[\033[01;34m\]@\[\033[01;31m\]bluejay\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]# "

# Enhanced history for security auditing
export HISTCONTROL=ignoredups:erasedups
export HISTSIZE=10000
export HISTFILESIZE=10000
export HISTTIMEFORMAT="%F %T "

# Security-focused aliases for root
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Network security shortcuts
alias portscan='nmap -sS -O'
alias vulnscan='nmap --script vuln'
alias netmon='netstat -tuln | grep LISTEN'
alias conntrack='ss -tuln'

# Log analysis shortcuts
alias logs='tail -f /var/log/messages'
alias authlog='tail -f /var/log/auth.log'
alias syslog='tail -f /var/log/syslog'

# System monitoring
alias cpuinfo='lscpu'
alias meminfo='free -h && cat /proc/meminfo | head'
alias diskinfo='df -h && lsblk'

# Security status
alias selinux-status='sestatus'
alias apparmor-status='aa-status'
alias firewall-status='iptables -L -n'

EOF
    
    # Create sysctl configuration
    cat > "${ROOTFS}/etc/sysctl.conf" << 'EOF'
# BluejayLinux Kernel Parameters
# Security-focused sysctl configuration

# Network security
net.ipv4.ip_forward = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_rfc1337 = 1

# IPv6 security
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Memory protection
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 1
kernel.randomize_va_space = 2

# Process restrictions
fs.suid_dumpable = 0
kernel.core_uses_pid = 1

# Network limits
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10

# File system security
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.protected_fifos = 2
fs.protected_regular = 2

# Kernel security
kernel.exec-shield = 1
kernel.kexec_load_disabled = 1

EOF
    
    log_success "System files created"
}

create_bluejay_tools() {
    log_info "Creating BluejayLinux specific tools and configurations..."
    
    mkdir -p "${ROOTFS}/opt/bluejay/tools/bin"
    mkdir -p "${ROOTFS}/opt/bluejay/configs"
    mkdir -p "${ROOTFS}/opt/bluejay/reports"
    mkdir -p "${ROOTFS}/opt/bluejay/scripts"
    
    # Create bluejay-tools command
    cat > "${ROOTFS}/usr/bin/bluejay-tools" << 'EOF'
#!/bin/sh
# BluejayLinux Security Tools Launcher

echo "BluejayLinux Security Tools:"
echo "================================"
echo
echo "Network Analysis:"
echo "  nmap           - Network mapper and port scanner"
echo "  netcat (nc)    - Network swiss army knife"
echo "  tcpdump        - Packet capture and analysis"
echo "  wireshark      - GUI network protocol analyzer"
echo "  ettercap       - Network sniffer and MITM tool"
echo "  aircrack-ng    - WiFi security testing suite"
echo
echo "Web Security:"
echo "  curl           - URL transfer tool"
echo "  wget           - Web downloader"
echo "  nikto          - Web vulnerability scanner"
echo "  dirb           - Web directory scanner"
echo "  sqlmap         - SQL injection testing tool"
echo "  burpsuite      - Web application security testing"
echo
echo "System Analysis:"
echo "  ps             - Process list"
echo "  netstat        - Network connections"
echo "  ss             - Socket statistics"
echo "  lsof           - List open files"
echo "  strace         - System call tracer"
echo "  ltrace         - Library call tracer"
echo
echo "Forensics Tools:"
echo "  dd             - Data duplication and recovery"
echo "  file           - File type identification"
echo "  strings        - Extract strings from files"
echo "  hexdump        - Hexadecimal file viewer"
echo "  volatility     - Memory forensics framework"
echo "  autopsy        - Digital forensics platform"
echo
echo "Penetration Testing:"
echo "  metasploit     - Exploitation framework"
echo "  john           - Password cracker"
echo "  hashcat        - Advanced password recovery"
echo "  hydra          - Network login cracker"
echo "  gobuster       - Directory and subdomain scanner"
echo
echo "Incident Response:"
echo "  chkrootkit     - Rootkit detection"
echo "  rkhunter       - Rootkit hunter"
echo "  clamav         - Antivirus engine"
echo "  aide           - File integrity checker"
echo "  tripwire       - Intrusion detection system"
echo
echo "Additional Commands:"
echo "  bluejay-config - System configuration tool"
echo "  bluejay-help   - Help and documentation"
echo "  bluejay-update - Update security databases"
echo "  bluejay-report - Generate security reports"
echo
echo "Note: Tool availability depends on installed packages and selected mode."
EOF
    chmod +x "${ROOTFS}/usr/bin/bluejay-tools"
    
    # Create bluejay-help command
    cat > "${ROOTFS}/usr/bin/bluejay-help" << 'EOF'
#!/bin/sh
# BluejayLinux Help System

echo "BluejayLinux Help System"
echo "========================"
echo
echo "Getting Started:"
echo "  1. Type 'bluejay-tools' to see available security tools"
echo "  2. Type 'bluejay-config' to configure network and system settings"
echo "  3. Type 'bluejay-update' to update security tool databases"
echo
echo "Basic Commands:"
echo "  ls, cp, mv, rm  - File operations"
echo "  cat, less, grep - Text processing"
echo "  ps, kill        - Process management"
echo "  mount, umount   - Filesystem operations"
echo
echo "Network Commands:"
echo "  ip addr         - Show network interfaces"
echo "  ip route        - Show routing table"
echo "  ping            - Test network connectivity"
echo "  nslookup/dig    - DNS queries"
echo
echo "Security Best Practices:"
echo "  - Always run scans with proper authorization"
echo "  - Document your findings"
echo "  - Use BluejayLinux responsibly and ethically"
echo "  - Keep tools and databases updated"
echo
echo "Documentation:"
echo "  man [command]   - Manual pages for commands"
echo "  info [command]  - Info pages for commands"
echo "  /opt/bluejay/docs/ - BluejayLinux specific documentation"
echo
echo "Support:"
echo "  - Community forum: https://bluejay-linux.org/forum"
echo "  - Documentation: https://bluejay-linux.org/docs"
echo "  - Bug reports: https://bluejay-linux.org/bugs"
EOF
    chmod +x "${ROOTFS}/usr/bin/bluejay-help"
    
    # Create bluejay-config command
    cat > "${ROOTFS}/usr/bin/bluejay-config" << 'EOF'
#!/bin/sh
# BluejayLinux System Configuration Tool

echo "BluejayLinux System Configuration"
echo "================================="
echo
echo "Available configuration options:"
echo
echo "1) Network Configuration"
echo "2) Security Settings"
echo "3) Tool Preferences"
echo "4) System Information"
echo "5) Hardware Detection"
echo "q) Quit"
echo
read -p "Select option [1-5,q]: " choice

case $choice in
    1)
        echo "Network Configuration"
        echo "===================="
        ip addr show
        echo
        echo "Available interfaces:"
        ip link show | grep '^[0-9]:' | cut -d: -f2 | tr -d ' '
        ;;
    2)
        echo "Security Settings"
        echo "================"
        echo "SELinux Status:"
        if [ -f /selinux/enforce ]; then
            echo "  Enabled"
        else
            echo "  Not available"
        fi
        echo "AppArmor Status:"
        if [ -d /sys/kernel/security/apparmor ]; then
            echo "  Available"
        else
            echo "  Not available"
        fi
        ;;
    3)
        echo "Tool Preferences"
        echo "==============="
        echo "Default tools can be configured in /opt/bluejay/configs/"
        ;;
    4)
        echo "System Information"
        echo "=================="
        uname -a
        echo
        echo "Memory:"
        free -h
        echo
        echo "Disk Usage:"
        df -h
        ;;
    5)
        echo "Hardware Detection"
        echo "=================="
        lscpu | head -10
        echo
        lsblk
        ;;
    q|Q)
        echo "Goodbye!"
        ;;
    *)
        echo "Invalid option"
        ;;
esac
EOF
    chmod +x "${ROOTFS}/usr/bin/bluejay-config"
    
    # Create bluejay-update command
    cat > "${ROOTFS}/usr/bin/bluejay-update" << 'EOF'
#!/bin/sh
# BluejayLinux Update Tool

echo "BluejayLinux Security Database Update"
echo "===================================="
echo
echo "Updating security tool databases..."
echo

# Update locate database if available
if command -v updatedb >/dev/null 2>&1; then
    echo "Updating file location database..."
    updatedb 2>/dev/null &
fi

# Update ClamAV database if available
if command -v freshclam >/dev/null 2>&1; then
    echo "Updating ClamAV virus database..."
    freshclam 2>/dev/null &
fi

# Update CVE database if available
if [ -d "/opt/bluejay/cve-db" ]; then
    echo "Updating CVE database..."
    # CVE update would go here
fi

# Update nmap scripts if available
if [ -d "/usr/share/nmap/scripts" ]; then
    echo "Updating nmap script database..."
    nmap --script-updatedb 2>/dev/null &
fi

echo "Update initiated. Some updates may continue in background."
echo "Check /var/log/bluejay-update.log for details."
EOF
    chmod +x "${ROOTFS}/usr/bin/bluejay-update"
    
    # Create system information file
    cat > "${ROOTFS}/opt/bluejay/configs/system-info.conf" << 'EOF'
# BluejayLinux System Information
VERSION="1.0.0"
CODENAME="Reconnaissance"
BUILD_DATE="$(date '+%Y-%m-%d')"
DESCRIPTION="Cybersecurity Made Simple"
HOMEPAGE="https://bluejay-linux.org"
EOF
    
    log_success "BluejayLinux tools created"
}

main() {
    log_info "Setting up BluejayLinux device files and system integration..."
    
    # Ensure we're working in the right place
    if [ ! -d "${ROOTFS}" ]; then
        log_error "Rootfs directory not found: ${ROOTFS}"
        exit 1
    fi
    
    # Create device nodes
    create_device_nodes
    
    # Create essential system files
    create_system_files
    
    # Create BluejayLinux specific tools
    create_bluejay_tools
    
    log_success "BluejayLinux device files and system integration completed"
}

main "$@"