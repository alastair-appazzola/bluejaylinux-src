#!/bin/bash
# Build Blue-Jay Linux Essential GUI Applications

set -e

source ../build-bluejay.sh 2>/dev/null || {
    ROOTFS="/tmp/bluejay-build/rootfs"
    BUILD_ROOT="/tmp/bluejay-build"
}

log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $1"; }

install_display_server() {
    log_info "Installing X11 display server..."
    
    # Create X11 configuration
    mkdir -p "${ROOTFS}/etc/X11"
    mkdir -p "${ROOTFS}/usr/bin"
    
    # Create startx script
    cat > "${ROOTFS}/usr/bin/startx" << 'EOF'
#!/bin/bash
# Blue-Jay Linux X11 starter

export DISPLAY=:0
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=XFCE

# Start X server in background
X :0 -auth ~/.Xauth &
X_PID=$!

# Wait for X to start
sleep 2

# Set display
export DISPLAY=:0

# Start window manager
xfwm4 &

# Start panel
xfce4-panel &

# Start desktop
xfdesktop &

# Keep X running
wait $X_PID
EOF
    chmod +x "${ROOTFS}/usr/bin/startx"
    
    # Create simplified X server script (placeholder)
    cat > "${ROOTFS}/usr/bin/X" << 'EOF'
#!/bin/bash
echo "Starting Blue-Jay Linux Display Server..."
echo "X11 server would start here"
echo "In full build, this would be the real X11 server"
# Placeholder - real X11 server would go here
sleep infinity
EOF
    chmod +x "${ROOTFS}/usr/bin/X"
    
    log_success "Display server framework installed"
}

install_file_manager() {
    log_info "Installing file manager..."
    
    cat > "${ROOTFS}/usr/bin/bluejay-files" << 'EOF'
#!/bin/bash
# Blue-Jay Linux File Manager

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

current_dir="${1:-$(pwd)}"

show_header() {
    clear
    echo -e "${BLUE}Blue-Jay File Manager${NC}"
    echo "===================="
    echo -e "Current Directory: ${GREEN}$current_dir${NC}"
    echo ""
}

list_files() {
    echo -e "${YELLOW}Files and Directories:${NC}"
    echo ""
    
    # List directories first
    if ls -d "$current_dir"/*/ 2>/dev/null; then
        echo ""
    fi
    
    # List files
    ls -la "$current_dir" | grep -v "^d" | nl -w2 -s") "
    echo ""
}

show_menu() {
    echo -e "${YELLOW}Commands:${NC}"
    echo "[number] View/Enter file/directory"
    echo "[..] Go to parent directory" 
    echo "[/] Change to root directory"
    echo "[~] Go to home directory"
    echo "[mkdir] Create directory"
    echo "[touch] Create file"
    echo "[rm] Remove file/directory"
    echo "[cp] Copy file"
    echo "[mv] Move/rename file"
    echo "[edit] Edit file"
    echo "[search] Search files"
    echo "[q] Quit"
    echo ""
    echo -n "bluejay-files> "
}

handle_command() {
    local cmd="$1"
    
    case "$cmd" in
        "..")
            current_dir=$(dirname "$current_dir")
            ;;
        "/")
            current_dir="/"
            ;;
        "~")
            current_dir="$HOME"
            ;;
        "mkdir")
            echo -n "Directory name: "
            read dirname
            mkdir -p "$current_dir/$dirname"
            echo "Directory created: $dirname"
            read -p "Press Enter to continue..."
            ;;
        "touch")
            echo -n "File name: "
            read filename
            touch "$current_dir/$filename"
            echo "File created: $filename"
            read -p "Press Enter to continue..."
            ;;
        "rm")
            echo -n "File/directory to remove: "
            read target
            rm -rf "$current_dir/$target"
            echo "Removed: $target"
            read -p "Press Enter to continue..."
            ;;
        "cp")
            echo -n "Source file: "
            read source
            echo -n "Destination: "
            read dest
            cp -r "$current_dir/$source" "$current_dir/$dest"
            echo "Copied $source to $dest"
            read -p "Press Enter to continue..."
            ;;
        "mv")
            echo -n "Source file: "
            read source
            echo -n "Destination: "
            read dest
            mv "$current_dir/$source" "$current_dir/$dest"
            echo "Moved $source to $dest"
            read -p "Press Enter to continue..."
            ;;
        "edit")
            echo -n "File to edit: "
            read filename
            if command -v nano >/dev/null; then
                nano "$current_dir/$filename"
            elif command -v vi >/dev/null; then
                vi "$current_dir/$filename"
            else
                echo "No editor available"
            fi
            ;;
        "search")
            echo -n "Search term: "
            read term
            echo "Searching for: $term"
            find "$current_dir" -name "*$term*" -type f 2>/dev/null
            read -p "Press Enter to continue..."
            ;;
        [0-9]*)
            local files=($(ls -A "$current_dir"))
            local index=$((cmd - 1))
            if [ $index -ge 0 ] && [ $index -lt ${#files[@]} ]; then
                local selected="${files[$index]}"
                local full_path="$current_dir/$selected"
                
                if [ -d "$full_path" ]; then
                    current_dir="$full_path"
                elif [ -f "$full_path" ]; then
                    echo "File: $selected"
                    file "$full_path"
                    echo ""
                    echo "Contents (first 20 lines):"
                    head -20 "$full_path"
                    read -p "Press Enter to continue..."
                fi
            else
                echo "Invalid selection"
                read -p "Press Enter to continue..."
            fi
            ;;
        "q"|"quit"|"exit")
            exit 0
            ;;
        *)
            echo "Unknown command: $cmd"
            read -p "Press Enter to continue..."
            ;;
    esac
}

main() {
    while true; do
        show_header
        list_files
        show_menu
        read cmd
        handle_command "$cmd"
    done
}

main
EOF
    chmod +x "${ROOTFS}/usr/bin/bluejay-files"
    
    # Create desktop entry
    cat > "${ROOTFS}/usr/share/applications/bluejay-files.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Blue-Jay Files
Comment=Blue-Jay Linux file manager
Icon=folder
Exec=xfce4-terminal -e bluejay-files
Categories=System;FileManager;
Keywords=files;folders;browser;
StartupNotify=true
EOF
    
    log_success "File manager installed"
}

install_terminal_emulator() {
    log_info "Installing terminal emulator..."
    
    cat > "${ROOTFS}/usr/bin/bluejay-terminal" << 'EOF'
#!/bin/bash
# Blue-Jay Linux Terminal Emulator

# Try to use available terminal emulators
if command -v xfce4-terminal >/dev/null; then
    exec xfce4-terminal "$@"
elif command -v gnome-terminal >/dev/null; then
    exec gnome-terminal "$@"  
elif command -v konsole >/dev/null; then
    exec konsole "$@"
elif command -v xterm >/dev/null; then
    exec xterm "$@"
else
    # Fallback: just start a shell
    echo "Blue-Jay Linux Terminal"
    echo "======================"
    exec bash --login
fi
EOF
    chmod +x "${ROOTFS}/usr/bin/bluejay-terminal"
    
    # Create desktop entry
    cat > "${ROOTFS}/usr/share/applications/bluejay-terminal.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Terminal
Comment=Blue-Jay Linux terminal emulator
Icon=terminal
Exec=bluejay-terminal
Categories=System;TerminalEmulator;
Keywords=terminal;shell;command;
StartupNotify=true
EOF
    
    log_success "Terminal emulator installed"
}

install_web_browser() {
    log_info "Installing web browser..."
    
    cat > "${ROOTFS}/usr/bin/bluejay-browser" << 'EOF'
#!/bin/bash
# Blue-Jay Linux Web Browser

BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m'

show_browser_menu() {
    clear
    echo -e "${BLUE}Blue-Jay Web Browser${NC}"
    echo "==================="
    echo ""
    echo -e "${GREEN}Available browsers:${NC}"
    
    local browsers=()
    local commands=()
    
    if command -v firefox >/dev/null; then
        browsers+=("Firefox")
        commands+=("firefox")
    fi
    
    if command -v chromium >/dev/null; then
        browsers+=("Chromium")
        commands+=("chromium")
    fi
    
    if command -v google-chrome >/dev/null; then
        browsers+=("Google Chrome")
        commands+=("google-chrome")
    fi
    
    if command -v lynx >/dev/null; then
        browsers+=("Lynx (Text Browser)")
        commands+=("lynx")
    fi
    
    if command -v w3m >/dev/null; then
        browsers+=("w3m (Text Browser)")
        commands+=("w3m")
    fi
    
    if [ ${#browsers[@]} -eq 0 ]; then
        echo "No web browsers installed."
        echo ""
        echo "Install options:"
        echo "  sudo jay-pkg install firefox"
        echo "  sudo apt install firefox-esr"
        echo "  sudo apt install chromium-browser"
        echo "  sudo apt install lynx"
        echo ""
        echo "For security testing:"
        echo "  sudo jay-pkg install burpsuite"
        exit 1
    fi
    
    echo ""
    for i in "${!browsers[@]}"; do
        echo "[$((i+1))] ${browsers[$i]}"
    done
    
    echo ""
    echo -n "Select browser (1-${#browsers[@]}): "
    read choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#browsers[@]} ]; then
        local selected_cmd="${commands[$((choice-1))]}"
        echo "Starting ${browsers[$((choice-1))]}..."
        exec "$selected_cmd" "$@"
    else
        echo "Invalid selection"
        exit 1
    fi
}

show_browser_menu "$@"
EOF
    chmod +x "${ROOTFS}/usr/bin/bluejay-browser"
    
    # Create desktop entry
    cat > "${ROOTFS}/usr/share/applications/bluejay-browser.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Web Browser
Comment=Blue-Jay Linux web browser launcher
Icon=web-browser
Exec=bluejay-browser
Categories=Network;WebBrowser;
Keywords=web;browser;internet;
StartupNotify=true
EOF
    
    log_success "Web browser launcher installed"
}

install_text_editor() {
    log_info "Installing text editor..."
    
    cat > "${ROOTFS}/usr/bin/bluejay-editor" << 'EOF'
#!/bin/bash
# Blue-Jay Linux Text Editor

file_to_edit="$1"

echo "Blue-Jay Linux Text Editor"
echo "========================="
echo ""

# Try GUI editors first, then fall back to CLI
if command -v gedit >/dev/null; then
    echo "Using gedit..."
    exec gedit "$file_to_edit"
elif command -v mousepad >/dev/null; then
    echo "Using mousepad..."
    exec mousepad "$file_to_edit"
elif command -v nano >/dev/null; then
    echo "Using nano..."
    exec nano "$file_to_edit"
elif command -v vi >/dev/null; then
    echo "Using vi..."
    exec vi "$file_to_edit"
else
    echo "No text editor available!"
    echo "Install with: sudo jay-pkg install text-editor"
    exit 1
fi
EOF
    chmod +x "${ROOTFS}/usr/bin/bluejay-editor"
    
    # Create desktop entry
    cat > "${ROOTFS}/usr/share/applications/bluejay-editor.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Text Editor
Comment=Blue-Jay Linux text editor
Icon=text-editor
Exec=bluejay-editor
Categories=Development;TextEditor;
Keywords=text;editor;code;
StartupNotify=true
EOF
    
    log_success "Text editor installed"
}

install_system_settings() {
    log_info "Installing system settings GUI..."
    
    cat > "${ROOTFS}/usr/bin/bluejay-settings" << 'EOF'
#!/bin/bash
# Blue-Jay Linux System Settings GUI

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

show_settings_menu() {
    while true; do
        clear
        echo -e "${BLUE}Blue-Jay System Settings${NC}"
        echo "======================="
        echo ""
        echo -e "${YELLOW}Categories:${NC}"
        echo ""
        echo -e "${GREEN}[1]${NC} Display & Desktop"
        echo -e "${GREEN}[2]${NC} Network Settings"
        echo -e "${GREEN}[3]${NC} Security Settings"
        echo -e "${GREEN}[4]${NC} User Accounts"
        echo -e "${GREEN}[5]${NC} Software & Updates"
        echo -e "${GREEN}[6]${NC} System Information"
        echo -e "${GREEN}[7]${NC} Power Management"
        echo -e "${GREEN}[8]${NC} Sound Settings"
        echo -e "${GREEN}[q]${NC} Exit"
        echo ""
        echo -n "Select category: "
        
        read choice
        case "$choice" in
            1) display_settings ;;
            2) network_settings ;;
            3) security_settings ;;
            4) user_settings ;;
            5) software_settings ;;
            6) system_info ;;
            7) power_settings ;;
            8) sound_settings ;;
            [Qq]) exit 0 ;;
            *) echo "Invalid option"; sleep 1 ;;
        esac
    done
}

display_settings() {
    clear
    echo -e "${GREEN}Display & Desktop Settings${NC}"
    echo "========================="
    echo ""
    echo "Current display information:"
    echo "Resolution: $(xrandr 2>/dev/null | grep '*' | awk '{print $1}' || echo 'Unknown')"
    echo "Desktop: XFCE"
    echo ""
    echo "[1] Set wallpaper"
    echo "[2] Screen resolution"
    echo "[3] Theme settings"
    echo "[b] Back"
    echo ""
    echo -n "Choose option: "
    read opt
    
    case "$opt" in
        1) set-bluejay-theme; echo "Theme applied"; sleep 2 ;;
        2) echo "Resolution settings not yet implemented"; sleep 2 ;;
        3) echo "Theme settings not yet implemented"; sleep 2 ;;
    esac
}

network_settings() {
    clear
    echo -e "${GREEN}Network Settings${NC}"
    echo "================"
    echo ""
    ip addr show 2>/dev/null || ifconfig
    echo ""
    read -p "Press Enter to continue..."
}

security_settings() {
    clear
    echo -e "${GREEN}Security Settings${NC}"
    echo "================"
    echo ""
    echo "Firewall status:"
    iptables -L 2>/dev/null || echo "Firewall not configured"
    echo ""
    echo "Security tools:"
    jay-tools
    read -p "Press Enter to continue..."
}

user_settings() {
    clear
    echo -e "${GREEN}User Account Settings${NC}"
    echo "===================="
    echo ""
    echo "Current user: $(whoami)"
    echo "Groups: $(groups)"
    echo ""
    echo "[1] Change password"
    echo "[2] View user info"
    echo "[b] Back"
    echo ""
    echo -n "Choose option: "
    read opt
    
    case "$opt" in
        1) passwd ;;
        2) id; read -p "Press Enter to continue..." ;;
    esac
}

software_settings() {
    clear
    echo -e "${GREEN}Software & Updates${NC}"
    echo "=================="
    echo ""
    jay-pkg status
    echo ""
    echo "[1] Update system"
    echo "[2] Install software"
    echo "[3] Remove software" 
    echo "[b] Back"
    echo ""
    echo -n "Choose option: "
    read opt
    
    case "$opt" in
        1) sudo jay-pkg update; read -p "Press Enter to continue..." ;;
        2) 
            echo -n "Package name: "
            read pkg
            sudo jay-pkg install "$pkg"
            read -p "Press Enter to continue..."
            ;;
        3)
            echo -n "Package name: "
            read pkg
            sudo jay-pkg remove "$pkg"
            read -p "Press Enter to continue..."
            ;;
    esac
}

system_info() {
    clear
    echo -e "${GREEN}System Information${NC}"
    echo "=================="
    echo ""
    echo "OS: Blue-Jay Linux 1.0.0"
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo "Uptime: $(uptime -p 2>/dev/null || uptime)"
    echo "Memory: $(free -h | grep Mem | awk '{print $3 "/" $2}')"
    echo "Disk: $(df -h / | tail -n1 | awk '{print $3 "/" $2 " (" $5 " used)"}')"
    echo ""
    read -p "Press Enter to continue..."
}

power_settings() {
    clear
    echo -e "${GREEN}Power Management${NC}"
    echo "================"
    echo "Power management settings not yet implemented"
    read -p "Press Enter to continue..."
}

sound_settings() {
    clear
    echo -e "${GREEN}Sound Settings${NC}"
    echo "=============="
    echo "Sound settings not yet implemented"
    read -p "Press Enter to continue..."
}

show_settings_menu
EOF
    chmod +x "${ROOTFS}/usr/bin/bluejay-settings"
    
    # Create desktop entry
    cat > "${ROOTFS}/usr/share/applications/bluejay-settings.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Settings
Comment=Blue-Jay Linux system settings
Icon=preferences-system
Exec=xfce4-terminal -e bluejay-settings
Categories=Settings;System;
Keywords=settings;preferences;configuration;
StartupNotify=true
EOF
    
    log_success "System settings installed"
}

create_desktop_shortcuts() {
    log_info "Creating desktop shortcuts..."
    
    # Update desktop shortcuts
    cat > "${ROOTFS}/home/bluejay/Desktop/File Manager.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=File Manager
Comment=Browse files and folders
Icon=folder
Exec=bluejay-files
StartupNotify=true
EOF
    
    cat > "${ROOTFS}/home/bluejay/Desktop/Terminal.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Terminal
Comment=Open terminal
Icon=terminal
Exec=bluejay-terminal
StartupNotify=true
EOF
    
    cat > "${ROOTFS}/home/bluejay/Desktop/Web Browser.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Web Browser
Comment=Browse the web
Icon=web-browser
Exec=bluejay-browser
StartupNotify=true
EOF
    
    cat > "${ROOTFS}/home/bluejay/Desktop/Settings.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Settings
Comment=System settings and configuration
Icon=preferences-system
Exec=bluejay-settings
StartupNotify=true
EOF
    
    chmod +x "${ROOTFS}/home/bluejay/Desktop"/*.desktop
    
    log_success "Desktop shortcuts created"
}

main() {
    log_info "Installing Blue-Jay Linux Essential GUI Applications..."
    
    install_display_server
    install_file_manager
    install_terminal_emulator
    install_web_browser
    install_text_editor
    install_system_settings
    create_desktop_shortcuts
    
    log_success "Essential GUI applications installed!"
    echo ""
    echo "Blue-Jay Linux now includes:"
    echo "  ✓ X11 Display Server Framework"
    echo "  ✓ File Manager (bluejay-files)"
    echo "  ✓ Terminal Emulator (bluejay-terminal)"
    echo "  ✓ Web Browser Launcher (bluejay-browser)"
    echo "  ✓ Text Editor (bluejay-editor)"
    echo "  ✓ System Settings GUI (bluejay-settings)"
    echo "  ✓ Desktop Shortcuts"
    echo ""
    echo "Your Blue-Jay Linux now has Ubuntu-like functionality"
    echo "while maintaining its cybersecurity focus!"
}

main "$@"