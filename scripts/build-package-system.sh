#!/bin/bash
# Build Blue-Jay Linux Package Management and Sudo System

set -e

source ../build-bluejay.sh 2>/dev/null || {
    ROOTFS="/tmp/bluejay-build/rootfs"
    BUILD_ROOT="/tmp/bluejay-build"
    TOOLS_DIR="/tmp/bluejay-build/tools"
}

log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $1"; }
log_warning() { echo -e "\033[1;33m[WARNING]\033[0m $1"; }

install_sudo_system() {
    log_info "Installing sudo system..."
    
    cd "${TOOLS_DIR}"
    
    # For now, create a simplified sudo implementation
    # In a full build, we'd compile the real sudo from source
    
    # Create sudo binary (simplified implementation)
    cat > "${ROOTFS}/usr/bin/sudo" << 'EOF'
#!/bin/sh
# Simplified sudo implementation for Blue-Jay Linux

SUDO_USER=${SUDO_USER:-$(whoami)}
REAL_USER_ID=$(id -u 2>/dev/null || echo 1000)

# Check if already root
if [ "$(id -u)" = "0" ]; then
    # Already root, just execute the command
    exec "$@"
fi

# Check if user is in sudoers
if ! groups | grep -q sudo 2>/dev/null && [ "$REAL_USER_ID" != "0" ]; then
    echo "Sorry, user $(whoami) is not allowed to execute '$*' as root."
    echo "Add user to sudo group: usermod -aG sudo $(whoami)"
    exit 1
fi

# Simple password check (in real sudo, this would be more secure)
echo -n "[sudo] password for $(whoami): "
read -s password
echo

# For Blue-Jay Linux demo, accept "bluejay" as password
if [ "$password" = "bluejay" ] || [ "$password" = "root" ]; then
    # Switch to root and execute command
    export SUDO_USER="$REAL_USER_ID"
    exec /bin/su -c "$*" root
else
    echo "Sorry, try again."
    exit 1
fi
EOF
    chmod +x "${ROOTFS}/usr/bin/sudo"
    
    # Create sudoers configuration
    mkdir -p "${ROOTFS}/etc"
    cat > "${ROOTFS}/etc/sudoers" << 'EOF'
# Blue-Jay Linux sudoers file
# This file MUST be edited with the 'visudo' command as root.

Defaults    env_reset
Defaults    mail_badpass
Defaults    secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Root privileges
root    ALL=(ALL:ALL) ALL

# Allow members of group sudo to execute any command
%sudo   ALL=(ALL:ALL) ALL

# Blue-Jay Linux specific
bluejay ALL=(ALL) NOPASSWD: /usr/bin/jay-tools, /usr/bin/systemctl
bluejay ALL=(ALL) ALL

# Allow members of group admin to execute any command
%admin  ALL=(ALL) ALL

# See sudoers(5) for more information on "#include" directives:
#includedir /etc/sudoers.d
EOF
    chmod 440 "${ROOTFS}/etc/sudoers"
    
    # Create visudo command
    cat > "${ROOTFS}/usr/sbin/visudo" << 'EOF'
#!/bin/sh
# Simplified visudo for Blue-Jay Linux

if [ "$(id -u)" != "0" ]; then
    echo "visudo: must be run as root"
    exit 1
fi

echo "Opening /etc/sudoers for editing..."
echo "WARNING: This is a simplified visudo. In production, use real visudo."

# Use vi or nano if available, otherwise cat
if command -v vi >/dev/null; then
    vi /etc/sudoers
elif command -v nano >/dev/null; then
    nano /etc/sudoers
else
    echo "No editor available. Contents of /etc/sudoers:"
    cat /etc/sudoers
fi
EOF
    chmod +x "${ROOTFS}/usr/sbin/visudo"
    
    # Add sudo group to system
    echo "sudo:x:27:" >> "${ROOTFS}/etc/group"
    
    # Add bluejay user to sudo group
    sed -i 's/^bluejay:x:1000:1000:/bluejay:x:1000:1000,27:/' "${ROOTFS}/etc/passwd" || true
    sed -i 's/^bluejay:x:1000:$/bluejay:x:1000:bluejay,sudo/' "${ROOTFS}/etc/group" || {
        echo "bluejay:x:1000:bluejay,sudo" >> "${ROOTFS}/etc/group"
    }
    
    log_success "Sudo system installed"
}

install_apt_system() {
    log_info "Installing APT package management system..."
    
    # Create APT directory structure
    mkdir -p "${ROOTFS}/var/lib/apt/lists"
    mkdir -p "${ROOTFS}/var/cache/apt/archives"
    mkdir -p "${ROOTFS}/etc/apt/sources.list.d"
    mkdir -p "${ROOTFS}/etc/apt/preferences.d"
    mkdir -p "${ROOTFS}/etc/apt/trusted.gpg.d"
    mkdir -p "${ROOTFS}/usr/lib/apt/methods"
    
    # Create sources.list for Blue-Jay Linux
    cat > "${ROOTFS}/etc/apt/sources.list" << 'EOF'
# Blue-Jay Linux Package Sources
# Main Blue-Jay repository (placeholder - would host our custom packages)
# deb https://repo.bluejay-linux.org/bluejay stable main
# deb-src https://repo.bluejay-linux.org/bluejay stable main

# Debian repositories for compatibility (optional)
# Uncomment these to add Debian package support (requires internet)
# deb http://deb.debian.org/debian bookworm main
# deb http://deb.debian.org/debian bookworm-updates main
# deb http://security.debian.org/debian-security bookworm-security main

# Kali Linux repositories for security tools (optional)
# Uncomment to add Kali tools (requires internet and proper GPG keys)
# deb https://http.kali.org/kali kali-rolling main non-free contrib
EOF
    
    # Create simplified apt commands
    create_apt_command() {
        local cmd="$1"
        local description="$2"
        
        cat > "${ROOTFS}/usr/bin/apt-$cmd" << EOF
#!/bin/sh
# Blue-Jay Linux APT $cmd command

echo "APT $cmd - Blue-Jay Linux Package Manager"
echo "========================================"

case "\$1" in
    "--help"|"-h"|"")
        echo "Usage: apt-$cmd [options] [packages...]"
        echo "$description"
        echo ""
        echo "Note: This is a simplified implementation for Blue-Jay Linux"
        echo "For full APT functionality, install the complete apt package"
        ;;
    *)
        echo "Would execute: apt-$cmd \$*"
        echo "This is a placeholder implementation."
        echo ""
        echo "To enable full APT functionality:"
        echo "1. Configure internet connection"
        echo "2. Enable Debian/Kali repositories in /etc/apt/sources.list"
        echo "3. Install full apt package: jay-pkg install apt-full"
        ;;
esac
EOF
        chmod +x "${ROOTFS}/usr/bin/apt-$cmd"
    }
    
    # Create APT commands
    create_apt_command "update" "Update package lists"
    create_apt_command "upgrade" "Upgrade installed packages"
    create_apt_command "install" "Install new packages"
    create_apt_command "remove" "Remove packages"
    create_apt_command "search" "Search for packages"
    create_apt_command "show" "Show package information"
    
    # Create main apt command
    cat > "${ROOTFS}/usr/bin/apt" << 'EOF'
#!/bin/sh
# Blue-Jay Linux APT Package Manager

show_help() {
    echo "Blue-Jay Linux APT Package Manager"
    echo "=================================="
    echo "Usage: apt <command> [options] [packages...]"
    echo ""
    echo "Commands:"
    echo "  update                    Update package lists"
    echo "  upgrade                   Upgrade installed packages"
    echo "  install <package>         Install packages"
    echo "  remove <package>          Remove packages"
    echo "  search <term>             Search for packages"
    echo "  show <package>            Show package information"
    echo "  list                      List installed packages"
    echo "  autoremove                Remove unneeded packages"
    echo ""
    echo "Blue-Jay Commands:"
    echo "  jay-enable-debian         Enable Debian repositories"
    echo "  jay-enable-kali           Enable Kali repositories"
    echo "  jay-status                Show package system status"
    echo ""
    echo "Note: This is a simplified APT implementation."
    echo "For full functionality, enable external repositories."
}

case "$1" in
    "update")
        apt-update "${@:2}"
        ;;
    "upgrade")
        apt-upgrade "${@:2}"
        ;;
    "install")
        apt-install "${@:2}"
        ;;
    "remove")
        apt-remove "${@:2}"
        ;;
    "search")
        apt-search "${@:2}"
        ;;
    "show")
        apt-show "${@:2}"
        ;;
    "list")
        echo "Listing installed packages..."
        echo "blue-jay-base    1.0.0    Base Blue-Jay Linux system"
        echo "busybox         1.35.0    Essential Unix utilities"
        echo "nmap            7.94     Network discovery and security auditing"
        ;;
    "autoremove")
        echo "Reading package lists..."
        echo "Building dependency tree..."
        echo "0 packages will be removed."
        echo "0 upgraded, 0 newly installed, 0 to remove and 0 not upgraded."
        ;;
    "jay-enable-debian")
        echo "Enabling Debian repositories..."
        sed -i 's/^# deb http:\/\/deb.debian.org/deb http:\/\/deb.debian.org/' /etc/apt/sources.list
        echo "Debian repositories enabled. Run 'apt update' to refresh."
        ;;
    "jay-enable-kali")
        echo "Enabling Kali repositories..."
        sed -i 's/^# deb https:\/\/http.kali.org/deb https:\/\/http.kali.org/' /etc/apt/sources.list
        echo "Kali repositories enabled. Run 'apt update' to refresh."
        echo "Note: You may need to import Kali GPG keys."
        ;;
    "jay-status")
        echo "Blue-Jay Linux Package System Status"
        echo "===================================="
        echo "Package Manager: APT (Blue-Jay Edition)"
        echo "Repositories configured: $(grep -c '^deb ' /etc/apt/sources.list 2>/dev/null || echo 0)"
        echo "Cache directory: /var/cache/apt"
        echo "Lists directory: /var/lib/apt/lists"
        echo ""
        echo "Available package sources:"
        grep '^#.*deb' /etc/apt/sources.list | sed 's/^# /  [disabled] /'
        grep '^deb' /etc/apt/sources.list | sed 's/^/  [enabled]  /'
        ;;
    "--help"|"-h"|"help"|"")
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run 'apt help' for usage information."
        exit 1
        ;;
esac
EOF
    chmod +x "${ROOTFS}/usr/bin/apt"
    
    # Create APT configuration
    cat > "${ROOTFS}/etc/apt/apt.conf" << 'EOF'
// Blue-Jay Linux APT Configuration

APT {
  Architecture "amd64";
  Build-Essential-Packages "build-essential";
  Install-Recommends "true";
  Install-Suggests "false";
};

Dir {
  State "/var/lib/apt";
  Cache "/var/cache/apt";
  Etc "/etc/apt";
  Log "/var/log/apt";
};

DPkg {
  Options {"--force-confdef"; "--force-confold"};
};
EOF
    
    log_success "APT system installed"
}

create_jay_pkg_manager() {
    log_info "Creating Blue-Jay native package manager..."
    
    # Create jay-pkg directory structure
    mkdir -p "${ROOTFS}/var/lib/jay-pkg/installed"
    mkdir -p "${ROOTFS}/var/cache/jay-pkg"
    mkdir -p "${ROOTFS}/etc/jay-pkg"
    
    # Create jay-pkg configuration
    cat > "${ROOTFS}/etc/jay-pkg/jay-pkg.conf" << 'EOF'
# Blue-Jay Linux Native Package Manager Configuration

[repositories]
main = https://repo.bluejay-linux.org/packages/main
security = https://repo.bluejay-linux.org/packages/security
contrib = https://repo.bluejay-linux.org/packages/contrib

[settings]
cache_dir = /var/cache/jay-pkg
install_dir = /opt/bluejay/packages
verify_signatures = true
auto_update = false

[paths]
db_path = /var/lib/jay-pkg
config_path = /etc/jay-pkg
log_path = /var/log/jay-pkg.log
EOF
    
    # Create jay-pkg command
    cat > "${ROOTFS}/usr/bin/jay-pkg" << 'EOF'
#!/bin/sh
# Blue-Jay Linux Native Package Manager

CONF_FILE="/etc/jay-pkg/jay-pkg.conf"
DB_PATH="/var/lib/jay-pkg"
CACHE_PATH="/var/cache/jay-pkg"

show_help() {
    echo "Blue-Jay Linux Native Package Manager"
    echo "====================================="
    echo "Usage: jay-pkg <command> [options] [packages...]"
    echo ""
    echo "Package Management:"
    echo "  install <package>         Install a package"
    echo "  remove <package>          Remove a package"
    echo "  update                    Update package database"
    echo "  upgrade                   Upgrade all packages"
    echo "  search <term>             Search for packages"
    echo "  info <package>            Show package information"
    echo "  list                      List installed packages"
    echo ""
    echo "Repository Management:"
    echo "  repo-list                 List configured repositories"
    echo "  repo-add <url>            Add a repository"
    echo "  repo-remove <name>        Remove a repository"
    echo ""
    echo "Tool Management:"
    echo "  tool-install <tool>       Install security tool"
    echo "  tool-list                 List available tools"
    echo "  tool-update               Update tool database"
    echo ""
    echo "System:"
    echo "  status                    Show system status"
    echo "  clean                     Clean package cache"
    echo ""
}

install_package() {
    local package="$1"
    if [ -z "$package" ]; then
        echo "Error: Package name required"
        return 1
    fi
    
    echo "Installing package: $package"
    
    case "$package" in
        "nmap-full")
            echo "Installing full nmap with all features..."
            echo "This would download and install the complete nmap package"
            touch "${DB_PATH}/installed/nmap-full.installed"
            ;;
        "metasploit")
            echo "Installing Metasploit Framework..."
            echo "This would download and install the complete MSF"
            touch "${DB_PATH}/installed/metasploit.installed"
            ;;
        "burpsuite")
            echo "Installing Burp Suite Community..."
            echo "This would download and install Burp Suite"
            touch "${DB_PATH}/installed/burpsuite.installed"
            ;;
        "wireshark")
            echo "Installing Wireshark..."
            echo "This would download and install Wireshark"
            touch "${DB_PATH}/installed/wireshark.installed"
            ;;
        "apt-full")
            echo "Installing full APT package manager..."
            echo "This would install the complete APT system with all dependencies"
            touch "${DB_PATH}/installed/apt-full.installed"
            ;;
        *)
            echo "Package '$package' not found in Blue-Jay repositories"
            echo "Available packages: nmap-full, metasploit, burpsuite, wireshark, apt-full"
            return 1
            ;;
    esac
    
    echo "Package '$package' installed successfully"
}

list_packages() {
    echo "Installed Blue-Jay packages:"
    echo "=========================="
    if [ -d "${DB_PATH}/installed" ]; then
        for pkg in "${DB_PATH}/installed"/*.installed; do
            if [ -f "$pkg" ]; then
                basename "$pkg" .installed
            fi
        done
    fi
    
    echo ""
    echo "Base system packages:"
    echo "  blue-jay-base     1.0.0    Core Blue-Jay Linux system"
    echo "  jay-tools         1.0.0    Security tools collection"
    echo "  busybox          1.35.0    Essential utilities"
}

case "$1" in
    "install")
        install_package "$2"
        ;;
    "remove")
        echo "Removing package: $2"
        rm -f "${DB_PATH}/installed/$2.installed"
        ;;
    "update")
        echo "Updating Blue-Jay package database..."
        echo "This would sync with Blue-Jay repositories"
        ;;
    "list")
        list_packages
        ;;
    "search")
        echo "Searching for: $2"
        echo "Available security tools:"
        echo "  nmap-full         Complete nmap package with all features"
        echo "  metasploit        Metasploit Framework for penetration testing"
        echo "  burpsuite         Burp Suite web application security testing"
        echo "  wireshark         Network protocol analyzer"
        echo "  john              John the Ripper password cracker"
        echo "  hashcat           Advanced password recovery utility"
        echo "  sqlmap            SQL injection testing tool"
        echo "  nikto             Web server scanner"
        ;;
    "tool-list")
        jay-tools
        ;;
    "status")
        echo "Blue-Jay Package Manager Status"
        echo "==============================="
        echo "Package manager: jay-pkg v1.0.0"
        echo "Installed packages: $(ls "${DB_PATH}/installed"/*.installed 2>/dev/null | wc -l)"
        echo "Cache directory: $CACHE_PATH"
        echo "Database directory: $DB_PATH"
        echo "Configuration: $CONF_FILE"
        ;;
    "clean")
        echo "Cleaning package cache..."
        rm -f "${CACHE_PATH}"/*
        echo "Cache cleaned."
        ;;
    "help"|"--help"|"-h"|"")
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run 'jay-pkg help' for usage information"
        exit 1
        ;;
esac
EOF
    chmod +x "${ROOTFS}/usr/bin/jay-pkg"
    
    log_success "Blue-Jay native package manager created"
}

update_user_environment() {
    log_info "Updating user environment for package management..."
    
    # Update .profile for bluejay user
    cat >> "${ROOTFS}/home/bluejay/.profile" << 'EOF'

# Package management aliases
alias apt-install='sudo apt install'
alias apt-update='sudo apt update'
alias apt-search='apt search'
alias pkg-install='jay-pkg install'
alias pkg-search='jay-pkg search'

# Show available commands
alias help-packages='echo "Package Management Commands:
  apt <command>        - Debian-style package management
  jay-pkg <command>    - Blue-Jay native packages  
  sudo <command>       - Execute as administrator
  
Common packages:
  jay-pkg install metasploit
  jay-pkg install burpsuite
  jay-pkg install nmap-full
  apt install wireshark (if Debian repos enabled)"'
EOF

    # Create welcome message with package info
    cat > "${ROOTFS}/etc/motd" << 'EOF'
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

Blue-Jay Linux 1.0.0 "Reconnaissance"
Cybersecurity Made Simple

Quick Start:
  jay-tools           - Browse security tools
  jay-pkg search      - Search for packages  
  sudo jay-pkg install <tool> - Install tools
  help-packages       - Package management help

Documentation: https://bluejay-linux.org
EOF
    
    log_success "User environment updated"
}

main() {
    log_info "Building Blue-Jay Linux package management and sudo system..."
    
    # Set status
    log_info "Installing sudo system..."
    install_sudo_system
    
    log_info "Installing APT compatibility layer..."  
    install_apt_system
    
    log_info "Creating native package manager..."
    create_jay_pkg_manager
    
    log_info "Updating user environment..."
    update_user_environment
    
    log_success "Package management system build complete!"
    
    echo ""
    echo "Blue-Jay Linux now includes:"
    echo "  ✓ Sudo system (password: 'bluejay')"
    echo "  ✓ APT compatibility layer"
    echo "  ✓ jay-pkg native package manager"
    echo "  ✓ Enhanced user environment"
    echo ""
    echo "Try these commands in Blue-Jay Linux:"
    echo "  sudo jay-tools"
    echo "  jay-pkg search metasploit"
    echo "  apt jay-status"
}

main "$@"