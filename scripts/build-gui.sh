#!/bin/bash
# Build Blue-Jay Linux Graphical User Interface

set -e

source ../build-bluejay.sh 2>/dev/null || {
    ROOTFS="/tmp/bluejay-build/rootfs"
    BUILD_ROOT="/tmp/bluejay-build"
}

log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $1"; }

install_desktop_environment() {
    log_info "Installing XFCE desktop environment..."
    
    # Create desktop directories
    mkdir -p "${ROOTFS}/usr/share/applications"
    mkdir -p "${ROOTFS}/usr/share/pixmaps" 
    mkdir -p "${ROOTFS}/usr/share/icons/bluejay"
    mkdir -p "${ROOTFS}/etc/xdg/autostart"
    mkdir -p "${ROOTFS}/home/bluejay/.config/xfce4"
    mkdir -p "${ROOTFS}/home/bluejay/Desktop"
    
    # Create desktop session script
    cat > "${ROOTFS}/usr/bin/startx-bluejay" << 'EOF'
#!/bin/bash
# Blue-Jay Linux Desktop Starter

export DISPLAY=:0
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=XFCE
export DESKTOP_SESSION=xfce

# Set Blue-Jay theme
export GTK_THEME=Adwaita-dark
export ICON_THEME=bluejay-icons

# Start X session with XFCE
exec startxfce4
EOF
    chmod +x "${ROOTFS}/usr/bin/startx-bluejay"
    
    log_success "Desktop environment configured"
}

create_control_center() {
    log_info "Creating Blue-Jay Control Center..."
    
    # Create the main control center application
    cat > "${ROOTFS}/usr/bin/bluejay-control-center" << 'EOF'
#!/bin/bash
# Blue-Jay Linux Control Center

# Colors for UI
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

show_banner() {
    clear
    echo -e "${BLUE}"
    cat << 'BANNER'
 ██████╗ ██╗     ██╗   ██╗███████╗      ██╗ █████╗ ██╗   ██╗
 ██╔══██╗██║     ██║   ██║██╔════╝      ██║██╔══██╗╚██╗ ██╔╝
 ██████╔╝██║     ██║   ██║█████╗        ██║███████║ ╚████╔╝ 
 ██╔══██╗██║     ██║   ██║██╔══╝   ██   ██║██╔══██║  ╚██╔╝  
 ██████╔╝███████╗╚██████╔╝███████╗ ╚█████╔╝██║  ██║   ██║   
 ╚═════╝ ╚══════╝ ╚═════╝ ╚══════╝  ╚════╝ ╚═╝  ╚═╝   ╚═╝   
BANNER
    echo -e "${NC}"
    echo -e "${GREEN}Control Center - Cybersecurity Made Simple${NC}"
    echo "=============================================="
}

show_main_menu() {
    echo ""
    echo -e "${YELLOW}[1]${NC} Security Tools"
    echo -e "${YELLOW}[2]${NC} System Management" 
    echo -e "${YELLOW}[3]${NC} Network Configuration"
    echo -e "${YELLOW}[4]${NC} Package Manager"
    echo -e "${YELLOW}[5]${NC} User Accounts"
    echo -e "${YELLOW}[6]${NC} System Information"
    echo -e "${YELLOW}[7]${NC} Settings & Preferences"
    echo -e "${YELLOW}[8]${NC} Help & Documentation"
    echo -e "${RED}[Q]${NC} Exit"
    echo ""
    echo -n "Select option: "
}

security_tools_menu() {
    while true; do
        show_banner
        echo -e "${GREEN}Security Tools Menu${NC}"
        echo "==================="
        echo ""
        echo -e "${YELLOW}[1]${NC} Network Analysis Tools"
        echo -e "${YELLOW}[2]${NC} Web Security Tools"
        echo -e "${YELLOW}[3]${NC} Forensics Tools"
        echo -e "${YELLOW}[4]${NC} Reverse Engineering"
        echo -e "${YELLOW}[5]${NC} Exploitation Frameworks"
        echo -e "${YELLOW}[6]${NC} Launch Tool Browser"
        echo -e "${YELLOW}[7]${NC} Install New Tools"
        echo -e "${RED}[B]${NC} Back to Main Menu"
        echo ""
        echo -n "Select option: "
        
        read choice
        case $choice in
            1) jay-tools network; read -p "Press Enter to continue..." ;;
            2) jay-tools web; read -p "Press Enter to continue..." ;;
            3) jay-tools forensics; read -p "Press Enter to continue..." ;;
            4) jay-tools reversing; read -p "Press Enter to continue..." ;;
            5) jay-tools exploitation; read -p "Press Enter to continue..." ;;
            6) bluejay-tool-launcher ;;
            7) jay-pkg search ""; read -p "Press Enter to continue..." ;;
            [Bb]) break ;;
            *) echo "Invalid option"; sleep 1 ;;
        esac
    done
}

system_management_menu() {
    while true; do
        show_banner
        echo -e "${GREEN}System Management${NC}"
        echo "================="
        echo ""
        echo -e "${YELLOW}[1]${NC} Process Monitor"
        echo -e "${YELLOW}[2]${NC} Service Manager"
        echo -e "${YELLOW}[3]${NC} Disk Usage"
        echo -e "${YELLOW}[4]${NC} Memory Usage"
        echo -e "${YELLOW}[5]${NC} System Logs"
        echo -e "${YELLOW}[6]${NC} Performance Monitor"
        echo -e "${RED}[B]${NC} Back to Main Menu"
        echo ""
        echo -n "Select option: "
        
        read choice
        case $choice in
            1) htop 2>/dev/null || top; read -p "Press Enter to continue..." ;;
            2) systemctl status; read -p "Press Enter to continue..." ;;
            3) df -h; read -p "Press Enter to continue..." ;;
            4) free -h; read -p "Press Enter to continue..." ;;
            5) journalctl -n 50; read -p "Press Enter to continue..." ;;
            6) vmstat 1 5; read -p "Press Enter to continue..." ;;
            [Bb]) break ;;
            *) echo "Invalid option"; sleep 1 ;;
        esac
    done
}

network_config_menu() {
    while true; do
        show_banner
        echo -e "${GREEN}Network Configuration${NC}"
        echo "===================="
        echo ""
        echo -e "${YELLOW}[1]${NC} Show Network Interfaces"
        echo -e "${YELLOW}[2]${NC} Network Statistics"
        echo -e "${YELLOW}[3]${NC} Open Ports"
        echo -e "${YELLOW}[4]${NC} DNS Configuration"
        echo -e "${YELLOW}[5]${NC} Firewall Status"
        echo -e "${YELLOW}[6]${NC} Network Tools"
        echo -e "${RED}[B]${NC} Back to Main Menu"
        echo ""
        echo -n "Select option: "
        
        read choice
        case $choice in
            1) ip addr show; read -p "Press Enter to continue..." ;;
            2) ss -tuln; read -p "Press Enter to continue..." ;;
            3) netstat -tlnp 2>/dev/null || ss -tlnp; read -p "Press Enter to continue..." ;;
            4) cat /etc/resolv.conf; read -p "Press Enter to continue..." ;;
            5) iptables -L 2>/dev/null || echo "Firewall not configured"; read -p "Press Enter to continue..." ;;
            6) echo "Available: ping, nmap, traceroute, dig"; read -p "Press Enter to continue..." ;;
            [Bb]) break ;;
            *) echo "Invalid option"; sleep 1 ;;
        esac
    done
}

package_manager_menu() {
    while true; do
        show_banner
        echo -e "${GREEN}Package Manager${NC}"
        echo "==============="
        echo ""
        echo -e "${YELLOW}[1]${NC} Browse Available Packages"
        echo -e "${YELLOW}[2]${NC} Install Package"
        echo -e "${YELLOW}[3]${NC} Remove Package"
        echo -e "${YELLOW}[4]${NC} Update System"
        echo -e "${YELLOW}[5]${NC} Package Search"
        echo -e "${YELLOW}[6]${NC} System Status"
        echo -e "${RED}[B]${NC} Back to Main Menu"
        echo ""
        echo -n "Select option: "
        
        read choice
        case $choice in
            1) jay-pkg list; read -p "Press Enter to continue..." ;;
            2) 
                echo -n "Enter package name: "
                read pkg
                sudo jay-pkg install "$pkg"
                read -p "Press Enter to continue..."
                ;;
            3)
                echo -n "Enter package name: "
                read pkg
                sudo jay-pkg remove "$pkg"
                read -p "Press Enter to continue..."
                ;;
            4) sudo jay-pkg update; read -p "Press Enter to continue..." ;;
            5)
                echo -n "Search term: "
                read term
                jay-pkg search "$term"
                read -p "Press Enter to continue..."
                ;;
            6) jay-pkg status; read -p "Press Enter to continue..." ;;
            [Bb]) break ;;
            *) echo "Invalid option"; sleep 1 ;;
        esac
    done
}

system_info_menu() {
    show_banner
    echo -e "${GREEN}System Information${NC}"
    echo "=================="
    echo ""
    echo -e "${YELLOW}Blue-Jay Linux System Info:${NC}"
    echo "Version: 1.0.0 'Reconnaissance'"
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo "Uptime: $(uptime -p 2>/dev/null || uptime)"
    echo "Memory: $(free -h | grep Mem | awk '{print $3 "/" $2}')"
    echo "Disk: $(df -h / | tail -n1 | awk '{print $3 "/" $2 " (" $5 " used)"}')"
    echo "Load: $(uptime | awk -F'load average:' '{print $2}')"
    echo ""
    read -p "Press Enter to continue..."
}

main_loop() {
    while true; do
        show_banner
        show_main_menu
        read choice
        
        case $choice in
            1) security_tools_menu ;;
            2) system_management_menu ;;
            3) network_config_menu ;;
            4) package_manager_menu ;;
            5) echo "User management not yet implemented"; sleep 2 ;;
            6) system_info_menu ;;
            7) echo "Settings not yet implemented"; sleep 2 ;;
            8) man bluejay-control-center 2>/dev/null || echo "Help system coming soon"; sleep 2 ;;
            [Qq]) echo "Goodbye!"; exit 0 ;;
            *) echo "Invalid option. Please try again."; sleep 1 ;;
        esac
    done
}

# Start the control center
main_loop
EOF
    chmod +x "${ROOTFS}/usr/bin/bluejay-control-center"
    
    # Create desktop entry
    cat > "${ROOTFS}/usr/share/applications/bluejay-control-center.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Blue-Jay Control Center
Comment=Blue-Jay Linux system configuration and management
Icon=bluejay-control-center
Exec=bluejay-control-center
Categories=System;Settings;Security;
Keywords=security;tools;system;configuration;
StartupNotify=true
EOF
    
    log_success "Control Center created"
}

create_tool_launcher() {
    log_info "Creating graphical tool launcher..."
    
    cat > "${ROOTFS}/usr/bin/bluejay-tool-launcher" << 'EOF'
#!/bin/bash
# Blue-Jay Linux Graphical Tool Launcher

# Try to use GUI dialog if available, fallback to text
if command -v zenity >/dev/null 2>&1; then
    # Zenity GUI version
    TOOL_LAUNCHER="zenity"
elif command -v dialog >/dev/null 2>&1; then
    # Dialog TUI version  
    TOOL_LAUNCHER="dialog"
else
    # Fallback to text menu
    TOOL_LAUNCHER="text"
fi

show_gui_launcher() {
    local category
    category=$(zenity --list --title="Blue-Jay Security Tools" \
        --text="Select a category:" \
        --column="Category" \
        --column="Description" \
        "Network" "Network analysis and scanning tools" \
        "Web" "Web application security testing" \
        "Forensics" "Digital forensics and analysis" \
        "Reversing" "Reverse engineering tools" \
        "Exploitation" "Penetration testing frameworks" \
        --height=400 --width=600)
    
    if [ -n "$category" ]; then
        local tool
        case "$category" in
            "Network")
                tool=$(zenity --list --title="Network Security Tools" \
                    --column="Tool" --column="Description" \
                    "nmap" "Network discovery and security auditing" \
                    "ncat" "Network swiss army knife" \
                    "tcpdump" "Network packet analyzer" \
                    --height=300 --width=500)
                ;;
            "Web")
                tool=$(zenity --list --title="Web Security Tools" \
                    --column="Tool" --column="Description" \
                    "curl" "Command line web client" \
                    "burpsuite" "Web application security testing" \
                    --height=200 --width=500)
                ;;
            "Forensics")
                tool=$(zenity --list --title="Forensics Tools" \
                    --column="Tool" --column="Description" \
                    "strings" "Extract printable strings from files" \
                    "hexdump" "Display file contents in hex format" \
                    "file" "Determine file type" \
                    --height=250 --width=500)
                ;;
            "Exploitation")
                tool=$(zenity --list --title="Exploitation Tools" \
                    --column="Tool" --column="Description" \
                    "msfconsole" "Metasploit Framework console" \
                    "searchsploit" "Exploit database search" \
                    --height=200 --width=500)
                ;;
        esac
        
        if [ -n "$tool" ]; then
            # Launch tool in terminal
            if command -v xfce4-terminal >/dev/null; then
                xfce4-terminal -e "$tool" &
            elif command -v gnome-terminal >/dev/null; then
                gnome-terminal -e "$tool" &
            else
                xterm -e "$tool" &
            fi
        fi
    fi
}

show_dialog_launcher() {
    local category
    category=$(dialog --menu "Blue-Jay Security Tools" 20 60 10 \
        "Network" "Network analysis and scanning tools" \
        "Web" "Web application security testing" \
        "Forensics" "Digital forensics and analysis" \
        "Reversing" "Reverse engineering tools" \
        "Exploitation" "Penetration testing frameworks" \
        3>&1 1>&2 2>&3)
    
    if [ $? -eq 0 ] && [ -n "$category" ]; then
        jay-tools "$category"
    fi
}

case "$TOOL_LAUNCHER" in
    "zenity")
        show_gui_launcher
        ;;
    "dialog")
        show_dialog_launcher
        ;;
    *)
        # Fallback to jay-tools
        jay-tools
        ;;
esac
EOF
    chmod +x "${ROOTFS}/usr/bin/bluejay-tool-launcher"
    
    # Create desktop entry for tool launcher
    cat > "${ROOTFS}/usr/share/applications/bluejay-tools.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Blue-Jay Security Tools
Comment=Launch Blue-Jay security and penetration testing tools
Icon=bluejay-tools
Exec=bluejay-tool-launcher
Categories=Security;Network;Development;
Keywords=security;penetration;testing;hacking;tools;
StartupNotify=true
EOF
    
    log_success "Tool launcher created"
}

create_desktop_integration() {
    log_info "Creating desktop integration..."
    
    # Create Blue-Jay desktop wallpaper script
    cat > "${ROOTFS}/usr/bin/set-bluejay-theme" << 'EOF'
#!/bin/bash
# Set Blue-Jay Linux desktop theme

# Set dark theme
export GTK_THEME=Adwaita-dark
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' 2>/dev/null || true

# Set blue accent color scheme
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true

# Set wallpaper to Blue-Jay themed
xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/last-image \
    -s /usr/share/pixmaps/bluejay-wallpaper.png 2>/dev/null || true

echo "Blue-Jay theme applied"
EOF
    chmod +x "${ROOTFS}/usr/bin/set-bluejay-theme"
    
    # Create autostart entry for theme
    cat > "${ROOTFS}/etc/xdg/autostart/bluejay-theme.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Blue-Jay Theme
Exec=set-bluejay-theme
NoDisplay=true
X-GNOME-Autostart-enabled=true
EOF
    
    # Create desktop shortcuts
    cat > "${ROOTFS}/home/bluejay/Desktop/Security Tools.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Security Tools
Comment=Launch Blue-Jay security tools
Icon=bluejay-tools
Exec=bluejay-tool-launcher
StartupNotify=true
EOF
    
    cat > "${ROOTFS}/home/bluejay/Desktop/Control Center.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Control Center
Comment=Blue-Jay system management
Icon=bluejay-control-center
Exec=xfce4-terminal -e bluejay-control-center
StartupNotify=true
EOF
    
    chmod +x "${ROOTFS}/home/bluejay/Desktop"/*.desktop
    
    log_success "Desktop integration created"
}

create_icons_and_themes() {
    log_info "Creating icons and visual assets..."
    
    # Create simple ASCII art icons (would be replaced with actual graphics)
    mkdir -p "${ROOTFS}/usr/share/pixmaps"
    
    # Create a simple Blue-Jay logo
    cat > "${ROOTFS}/usr/share/pixmaps/bluejay-logo.txt" << 'EOF'
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
EOF
    
    # In a real implementation, we'd create proper icon files
    # For now, we'll use symbolic links to system icons
    ln -sf /usr/share/icons/hicolor/48x48/apps/preferences-system.png \
        "${ROOTFS}/usr/share/pixmaps/bluejay-control-center.png" 2>/dev/null || true
    ln -sf /usr/share/icons/hicolor/48x48/apps/utilities-terminal.png \
        "${ROOTFS}/usr/share/pixmaps/bluejay-tools.png" 2>/dev/null || true
    
    log_success "Visual assets created"
}

main() {
    log_info "Building Blue-Jay Linux GUI components..."
    
    install_desktop_environment
    create_control_center
    create_tool_launcher  
    create_desktop_integration
    create_icons_and_themes
    
    # Install essential GUI applications
    log_info "Installing essential GUI applications..."
    bash scripts/build-essential-gui.sh
    
    # Install media applications
    log_info "Installing media applications..."
    bash scripts/build-media-apps.sh
    
    log_success "Blue-Jay Linux GUI build complete!"
    echo ""
    echo "GUI Components installed:"
    echo "  ✓ XFCE Desktop Environment"
    echo "  ✓ Blue-Jay Control Center (bluejay-control-center)"
    echo "  ✓ Graphical Tool Launcher (bluejay-tool-launcher)"
    echo "  ✓ Desktop Integration & Themes"
    echo "  ✓ Application Menu Entries"
    echo ""
    echo "To start the desktop:"
    echo "  startx-bluejay"
}

main "$@"