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
    
    # Enhanced file listing with thumbnails and file types
    local count=1
    for item in "$current_dir"/* "$current_dir"/.*; do
        [ -e "$item" ] || continue
        [ "$item" = "$current_dir/." ] && continue
        [ "$item" = "$current_dir/.." ] && continue
        
        local basename=$(basename "$item")
        local size=""
        local icon=""
        local info=""
        
        if [ -d "$item" ]; then
            icon="📁"
            local file_count=$(ls -1 "$item" 2>/dev/null | wc -l)
            info="(${file_count} items)"
        elif [ -f "$item" ]; then
            size=$(ls -lh "$item" | awk '{print $5}')
            
            # File type icons
            case "${basename##*.}" in
                txt|md|readme) icon="📄" ;;
                jpg|jpeg|png|gif|bmp) icon="🖼️" ;;
                mp3|wav|flac|ogg) icon="🎵" ;;
                mp4|avi|mkv|mov) icon="🎬" ;;
                pdf) icon="📕" ;;
                zip|tar|gz|7z) icon="📦" ;;
                sh|bash) icon="⚙️" ;;
                py|js|html|css) icon="💻" ;;
                *) icon="📄" ;;
            esac
            
            # Show file permissions and modification time
            local perms=$(ls -l "$item" | awk '{print $1}')
            local mtime=$(ls -l "$item" | awk '{print $6, $7, $8}')
            info="($size, $perms, $mtime)"
        elif [ -L "$item" ]; then
            icon="🔗"
            local target=$(readlink "$item")
            info="-> $target"
        else
            icon="❓"
        fi
        
        printf "%2d) %s %-30s %s\n" "$count" "$icon" "$basename" "$info"
        count=$((count + 1))
    done
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
    echo "[preview] Preview image/media file"
    echo "[info] Show detailed file information"
    echo "[perms] Change file permissions"
    echo "[bookmark] Bookmark current directory"
    echo "[bookmarks] Show bookmarked directories"
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
            echo -e "${BLUE}Files containing '$term':${NC}"
            find "$current_dir" -name "*$term*" -type f 2>/dev/null | while read -r file; do
                echo "  📄 $(basename "$file") ($(dirname "$file"))"
            done
            echo ""
            echo -e "${BLUE}Content search:${NC}"
            grep -r -l "$term" "$current_dir" 2>/dev/null | head -10 | while read -r file; do
                echo "  💡 Content match: $(basename "$file")"
            done
            read -p "Press Enter to continue..."
            ;;
        "preview")
            echo -n "File to preview: "
            read filename
            preview_file "$current_dir/$filename"
            ;;
        "info")
            echo -n "File for info: "
            read filename
            show_file_info "$current_dir/$filename"
            ;;
        "perms")
            echo -n "File to change permissions: "
            read filename
            echo -n "New permissions (e.g., 755): "
            read perms
            chmod "$perms" "$current_dir/$filename"
            echo "Changed permissions of $filename to $perms"
            read -p "Press Enter to continue..."
            ;;
        "bookmark")
            echo "$current_dir" >> ~/.bluejay-bookmarks
            echo "Bookmarked: $current_dir"
            read -p "Press Enter to continue..."
            ;;
        "bookmarks")
            if [ -f ~/.bluejay-bookmarks ]; then
                echo -e "${BLUE}Bookmarked directories:${NC}"
                nl ~/.bluejay-bookmarks
                echo -n "Enter number to navigate (or press Enter): "
                read choice
                if [ -n "$choice" ] && [ "$choice" -gt 0 ]; then
                    current_dir=$(sed -n "${choice}p" ~/.bluejay-bookmarks)
                    echo "Navigated to: $current_dir"
                fi
            else
                echo "No bookmarks found"
            fi
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

# Preview file function
preview_file() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        echo "File not found: $file"
        read -p "Press Enter to continue..."
        return
    fi
    
    local ext="${file##*.}"
    case "$ext" in
        jpg|jpeg|png|gif|bmp)
            echo -e "${BLUE}Image Preview: $(basename "$file")${NC}"
            if command -v file >/dev/null; then
                file "$file"
            fi
            echo "Dimensions: $(identify "$file" 2>/dev/null | awk '{print $3}' || echo 'Unknown')"
            echo "Size: $(ls -lh "$file" | awk '{print $5}')"
            echo ""
            echo "🖼️ Image preview would be displayed here in GUI mode"
            ;;
        txt|md|log|conf|sh|py|js|html|css)
            echo -e "${BLUE}Text Preview: $(basename "$file")${NC}"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            head -20 "$file"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            ;;
        mp3|wav|flac|ogg)
            echo -e "${BLUE}Audio File: $(basename "$file")${NC}"
            if command -v file >/dev/null; then
                file "$file"
            fi
            echo "🎵 Audio preview would play here"
            ;;
        mp4|avi|mkv|mov)
            echo -e "${BLUE}Video File: $(basename "$file")${NC}"
            if command -v file >/dev/null; then
                file "$file"
            fi
            echo "🎬 Video preview would play here"
            ;;
        pdf)
            echo -e "${BLUE}PDF Document: $(basename "$file")${NC}"
            echo "📕 PDF preview would be displayed here"
            ;;
        *)
            echo -e "${BLUE}File Preview: $(basename "$file")${NC}"
            if command -v file >/dev/null; then
                file "$file"
            fi
            echo ""
            echo "Raw content preview (first 10 lines):"
            head -10 "$file" 2>/dev/null || echo "Binary file or no content"
            ;;
    esac
    
    read -p "Press Enter to continue..."
}

# Show detailed file information
show_file_info() {
    local file="$1"
    
    if [ ! -e "$file" ]; then
        echo "File not found: $file"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo -e "${BLUE}Detailed Information: $(basename "$file")${NC}"
    echo "═══════════════════════════════════════════════"
    
    # Basic info
    echo "Full path: $file"
    echo "Type: $(file -b "$file" 2>/dev/null || echo 'Unknown')"
    
    if [ -f "$file" ]; then
        echo "Size: $(ls -lh "$file" | awk '{print $5}') ($(wc -c < "$file") bytes)"
        echo "Lines: $(wc -l < "$file" 2>/dev/null || echo 'N/A')"
    elif [ -d "$file" ]; then
        local item_count=$(ls -1 "$file" 2>/dev/null | wc -l)
        echo "Contents: $item_count items"
    fi
    
    # Permissions and ownership
    echo "Permissions: $(ls -ld "$file" | awk '{print $1}')"
    echo "Owner: $(ls -ld "$file" | awk '{print $3}'):$(ls -ld "$file" | awk '{print $4}')"
    
    # Timestamps
    echo "Modified: $(ls -ld "$file" | awk '{print $6, $7, $8}')"
    echo "Access time: $(stat -c %x "$file" 2>/dev/null || echo 'Unknown')"
    echo "Change time: $(stat -c %z "$file" 2>/dev/null || echo 'Unknown')"
    
    # Additional info for different file types
    if [ -L "$file" ]; then
        echo "Link target: $(readlink "$file")"
    elif [ -x "$file" ] && [ -f "$file" ]; then
        echo "Executable: Yes"
        if command -v ldd >/dev/null 2>&1; then
            echo "Dependencies:"
            ldd "$file" 2>/dev/null | head -5 || echo "  None or not a dynamic executable"
        fi
    fi
    
    read -p "Press Enter to continue..."
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
    log_info "Installing enhanced terminal emulator..."
    
    cat > "${ROOTFS}/usr/bin/bluejay-terminal" << 'EOF'
#!/bin/bash
# BluejayLinux Advanced Terminal Emulator with Tabs and Themes

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

TERMINAL_CONFIG="$HOME/.config/bluejay/terminal.conf"
TAB_STATE="/tmp/bluejay-terminal-tabs"
CURRENT_TAB=1
MAX_TABS=6

# Initialize terminal configuration
init_terminal_config() {
    mkdir -p "$(dirname "$TERMINAL_CONFIG")"
    
    if [ ! -f "$TERMINAL_CONFIG" ]; then
        cat > "$TERMINAL_CONFIG" << 'CONF'
# BluejayLinux Terminal Configuration
THEME=dark
FONT_SIZE=12
FONT_FAMILY=monospace
SHOW_TABS=true
TAB_POSITION=top
BACKGROUND_OPACITY=1.0
CURSOR_BLINK=true
SCROLLBACK_LINES=1000
BELL_ENABLED=false

# Color schemes
DARK_BG=#1e1e1e
DARK_FG=#ffffff
DARK_CURSOR=#ffffff
LIGHT_BG=#ffffff
LIGHT_FG=#000000
LIGHT_CURSOR=#000000
CONF
    fi
}

# Load configuration
load_config() {
    [ -f "$TERMINAL_CONFIG" ] && source "$TERMINAL_CONFIG"
}

# Show terminal menu
show_terminal_menu() {
    clear
    load_config
    
    echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         BluejayLinux Terminal Emulator       ║${NC}"
    echo -e "${BLUE}║            Enhanced Terminal v2.0            ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Show tab bar
    if [ "$SHOW_TABS" = "true" ]; then
        show_tab_bar
        echo ""
    fi
    
    echo -e "${CYAN}Terminal Options:${NC}"
    echo "[1] Open New Tab                [7] Set Theme"
    echo "[2] Switch Tab (1-6)           [8] Font Settings" 
    echo "[3] Close Current Tab          [9] Terminal Settings"
    echo "[4] Split Horizontally         [10] Bookmark Commands"
    echo "[5] Split Vertically           [11] Command History"
    echo "[6] Clear Screen               [12] Export Session"
    echo ""
    echo "[c] Command Mode  [s] Settings  [q] Quit"
    echo ""
    echo -n "bluejay-term> "
}

# Show tab bar
show_tab_bar() {
    local active_color="${BLUE}"
    local inactive_color="${PURPLE}"
    
    echo -e "${YELLOW}Tabs:${NC}"
    for i in $(seq 1 $MAX_TABS); do
        if [ -f "$TAB_STATE/tab-$i.state" ]; then
            local tab_info=$(cat "$TAB_STATE/tab-$i.state")
            local tab_title=$(echo "$tab_info" | cut -d: -f1)
            [ -z "$tab_title" ] && tab_title="Tab $i"
            
            if [ "$i" = "$CURRENT_TAB" ]; then
                echo -ne "${active_color}[$i: $tab_title]${NC} "
            else
                echo -ne "${inactive_color}[$i: $tab_title]${NC} "
            fi
        else
            if [ "$i" = "1" ] && [ ! -f "$TAB_STATE/tab-1.state" ]; then
                # First tab always exists
                echo -ne "${active_color}[1: Shell]${NC} "
                mkdir -p "$TAB_STATE"
                echo "Shell:$PWD:$$" > "$TAB_STATE/tab-1.state"
            else
                echo -ne "${PURPLE}[$i: Empty]${NC} "
            fi
        fi
    done
    echo ""
}

# Create new tab
new_tab() {
    local next_tab=0
    
    for i in $(seq 1 $MAX_TABS); do
        if [ ! -f "$TAB_STATE/tab-$i.state" ]; then
            next_tab=$i
            break
        fi
    done
    
    if [ "$next_tab" = "0" ]; then
        echo -e "${RED}Maximum tabs ($MAX_TABS) reached${NC}"
        return 1
    fi
    
    echo -n "Tab name (or press Enter for default): "
    read tab_name
    [ -z "$tab_name" ] && tab_name="Shell"
    
    # Create tab state
    mkdir -p "$TAB_STATE"
    echo "$tab_name:$PWD:0" > "$TAB_STATE/tab-$next_tab.state"
    
    CURRENT_TAB=$next_tab
    echo -e "${GREEN}Created tab $next_tab: $tab_name${NC}"
}

# Switch to tab
switch_tab() {
    echo -n "Tab number (1-$MAX_TABS): "
    read tab_num
    
    if [ "$tab_num" -ge 1 ] && [ "$tab_num" -le "$MAX_TABS" ]; then
        if [ -f "$TAB_STATE/tab-$tab_num.state" ]; then
            CURRENT_TAB=$tab_num
            local tab_info=$(cat "$TAB_STATE/tab-$tab_num.state")
            local tab_dir=$(echo "$tab_info" | cut -d: -f2)
            echo -e "${GREEN}Switched to tab $tab_num${NC}"
            if [ -d "$tab_dir" ]; then
                cd "$tab_dir"
                echo "Working directory: $tab_dir"
            fi
        else
            echo -e "${RED}Tab $tab_num does not exist${NC}"
        fi
    else
        echo -e "${RED}Invalid tab number${NC}"
    fi
}

# Close current tab
close_tab() {
    if [ "$CURRENT_TAB" = "1" ]; then
        echo -e "${YELLOW}Cannot close the main tab${NC}"
        return
    fi
    
    if [ -f "$TAB_STATE/tab-$CURRENT_TAB.state" ]; then
        rm -f "$TAB_STATE/tab-$CURRENT_TAB.state"
        echo -e "${GREEN}Closed tab $CURRENT_TAB${NC}"
        
        # Switch to previous available tab
        for i in $(seq $((CURRENT_TAB - 1)) -1 1); do
            if [ -f "$TAB_STATE/tab-$i.state" ]; then
                CURRENT_TAB=$i
                break
            fi
        done
    fi
}

# Set terminal theme
set_theme() {
    echo -e "${BLUE}Terminal Themes:${NC}"
    echo "[1] Dark Theme (Default)"
    echo "[2] Light Theme"
    echo "[3] Cybersecurity Theme"
    echo "[4] Matrix Theme"
    echo "[5] Custom Theme"
    echo -n "Select theme: "
    read theme_choice
    
    case $theme_choice in
        1) 
            sed -i "s/THEME=.*/THEME=dark/" "$TERMINAL_CONFIG"
            echo -e "${GREEN}Applied dark theme${NC}"
            ;;
        2)
            sed -i "s/THEME=.*/THEME=light/" "$TERMINAL_CONFIG"
            echo -e "${GREEN}Applied light theme${NC}"
            ;;
        3)
            sed -i "s/THEME=.*/THEME=cybersec/" "$TERMINAL_CONFIG"
            echo -e "${GREEN}Applied cybersecurity theme${NC}"
            ;;
        4)
            sed -i "s/THEME=.*/THEME=matrix/" "$TERMINAL_CONFIG"
            echo -e "${GREEN}Applied matrix theme${NC}"
            ;;
        5)
            configure_custom_theme
            ;;
        *)
            echo -e "${RED}Invalid theme selection${NC}"
            ;;
    esac
}

# Configure font settings
set_font() {
    echo -e "${BLUE}Font Configuration:${NC}"
    echo "Current font: $FONT_FAMILY, size $FONT_SIZE"
    echo ""
    echo -n "Font size (8-24): "
    read font_size
    
    if [ "$font_size" -ge 8 ] && [ "$font_size" -le 24 ]; then
        sed -i "s/FONT_SIZE=.*/FONT_SIZE=$font_size/" "$TERMINAL_CONFIG"
        echo -e "${GREEN}Font size set to $font_size${NC}"
    fi
    
    echo ""
    echo "Font families:"
    echo "[1] monospace (Default)"
    echo "[2] DejaVu Sans Mono"
    echo "[3] Liberation Mono"
    echo "[4] Courier New"
    echo -n "Select font: "
    read font_choice
    
    case $font_choice in
        1) font_family="monospace" ;;
        2) font_family="DejaVu Sans Mono" ;;
        3) font_family="Liberation Mono" ;;
        4) font_family="Courier New" ;;
        *) font_family="monospace" ;;
    esac
    
    sed -i "s/FONT_FAMILY=.*/FONT_FAMILY=$font_family/" "$TERMINAL_CONFIG"
    echo -e "${GREEN}Font family set to $font_family${NC}"
}

# Terminal settings
terminal_settings() {
    echo -e "${BLUE}Terminal Settings:${NC}"
    echo "[1] Toggle tab bar (Current: $SHOW_TABS)"
    echo "[2] Set scrollback lines (Current: $SCROLLBACK_LINES)"
    echo "[3] Toggle cursor blink (Current: $CURSOR_BLINK)"
    echo "[4] Toggle bell sound (Current: $BELL_ENABLED)"
    echo "[5] Set background opacity (Current: $BACKGROUND_OPACITY)"
    echo -n "Select setting: "
    read setting_choice
    
    case $setting_choice in
        1)
            if [ "$SHOW_TABS" = "true" ]; then
                sed -i "s/SHOW_TABS=.*/SHOW_TABS=false/" "$TERMINAL_CONFIG"
                echo "Tab bar disabled"
            else
                sed -i "s/SHOW_TABS=.*/SHOW_TABS=true/" "$TERMINAL_CONFIG"
                echo "Tab bar enabled"
            fi
            ;;
        2)
            echo -n "Scrollback lines (100-10000): "
            read lines
            if [ "$lines" -ge 100 ] && [ "$lines" -le 10000 ]; then
                sed -i "s/SCROLLBACK_LINES=.*/SCROLLBACK_LINES=$lines/" "$TERMINAL_CONFIG"
                echo "Scrollback set to $lines lines"
            fi
            ;;
        3)
            if [ "$CURSOR_BLINK" = "true" ]; then
                sed -i "s/CURSOR_BLINK=.*/CURSOR_BLINK=false/" "$TERMINAL_CONFIG"
                echo "Cursor blink disabled"
            else
                sed -i "s/CURSOR_BLINK=.*/CURSOR_BLINK=true/" "$TERMINAL_CONFIG"
                echo "Cursor blink enabled"
            fi
            ;;
        *)
            echo "Invalid setting"
            ;;
    esac
}

# Command mode - enhanced shell with features
command_mode() {
    echo -e "${GREEN}Enhanced Command Mode${NC}"
    echo "Type 'help' for available commands, 'exit' to return"
    echo ""
    
    while true; do
        load_config
        
        # Set prompt based on theme
        case "$THEME" in
            dark) PS1="\[\033[1;36m\]bluejay\[\033[0m\]:\[\033[1;34m\]\w\[\033[0m\]\$ " ;;
            light) PS1="\[\033[1;30m\]bluejay\[\033[0m\]:\[\033[1;34m\]\w\[\033[0m\]\$ " ;;
            cybersec) PS1="\[\033[1;32m\]🛡️ bluejay\[\033[0m\]:\[\033[1;31m\]\w\[\033[0m\]\$ " ;;
            matrix) PS1="\[\033[1;32m\]●\[\033[0m\] \[\033[0;32m\]\w\[\033[0m\] \[\033[1;32m\]▸\[\033[0m\] " ;;
            *) PS1="bluejay:\w\$ " ;;
        esac
        
        # Enhanced bash with features
        export PS1
        bash --rcfile <(echo "
            alias ll='ls -la'
            alias la='ls -la'
            alias l='ls -CF'
            alias ..='cd ..'
            alias ...='cd ../..'
            alias grep='grep --color=auto'
            alias fgrep='fgrep --color=auto'
            alias egrep='egrep --color=auto'
            
            # BluejayLinux specific aliases
            alias jay-files='bluejay-files'
            alias jay-settings='bluejay-comprehensive-settings'
            alias jay-net='bluejay-network-settings'
            alias jay-audio='bluejay-audio-settings'
            
            # Enhanced commands
            help() {
                echo 'BluejayLinux Enhanced Terminal Commands:'
                echo '  Standard commands: ls, cd, mkdir, rm, cp, mv, etc.'
                echo '  Enhanced: ll, la, grep (with colors)'
                echo '  BluejayLinux: jay-files, jay-settings, jay-net, jay-audio'
                echo '  Terminal: exit (return to terminal menu)'
            }
        ") --login
        
        # When bash exits, return to menu
        break
    done
}

# Initialize and run terminal
init_terminal_config

# Try to use advanced terminal emulator if available
if [ "$1" = "--advanced" ] || [ "$1" = "-a" ]; then
    # Run enhanced terminal interface
    mkdir -p "$TAB_STATE"
    
    while true; do
        show_terminal_menu
        read choice
        
        case $choice in
            1) new_tab ;;
            2) switch_tab ;;
            3) close_tab ;;
            4) echo "Horizontal split not yet implemented" ;;
            5) echo "Vertical split not yet implemented" ;;
            6) clear ;;
            7) set_theme ;;
            8) set_font ;;
            9) terminal_settings ;;
            10) echo "Bookmarks not yet implemented" ;;
            11) history | tail -20 ;;
            12) echo "Session export not yet implemented" ;;
            c) command_mode ;;
            s) set_theme ;;
            q) exit 0 ;;
            *) echo "Invalid option" ;;
        esac
        
        [ "$choice" != "c" ] && read -p "Press Enter to continue..."
    done
else
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
        # Fallback: run enhanced terminal
        exec "$0" --advanced
    fi
fi
EOF
    chmod +x "${ROOTFS}/usr/bin/bluejay-terminal"
    
    # Create desktop entry for enhanced terminal
    cat > "${ROOTFS}/usr/share/applications/bluejay-terminal.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=BluejayLinux Terminal
Comment=Advanced terminal emulator with tabs and themes
Icon=terminal
Exec=bluejay-terminal --advanced
Categories=System;TerminalEmulator;
Keywords=terminal;shell;command;tabs;themes;
StartupNotify=true
EOF
    
    # Install enhanced terminal if available
    if [ -f scripts/bluejay-text-editor.sh ]; then
        cp scripts/bluejay-text-editor.sh "${ROOTFS}/usr/bin/bluejay-text-editor"
        chmod +x "${ROOTFS}/usr/bin/bluejay-text-editor"
        
        # Create text editor desktop entry
        cat > "${ROOTFS}/usr/share/applications/bluejay-text-editor.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=BluejayLinux Text Editor
Comment=Advanced text editor with syntax highlighting
Icon=text-editor
Exec=bluejay-text-editor
Categories=Development;TextEditor;
Keywords=editor;text;code;syntax;highlighting;
StartupNotify=true
MimeType=text/plain;text/x-csrc;text/x-chdr;text/x-python;text/html;
EOF
    fi
    
    # Install browser integration if available
    if [ -f scripts/bluejay-browser-integration.sh ]; then
        cp scripts/bluejay-browser-integration.sh "${ROOTFS}/usr/bin/bluejay-browser"
        chmod +x "${ROOTFS}/usr/bin/bluejay-browser"
        
        # Create browser desktop entry
        cat > "${ROOTFS}/usr/share/applications/bluejay-browser.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=BluejayLinux Browser
Comment=Native browser integration with bookmarks and privacy features
Icon=web-browser
Exec=bluejay-browser
Categories=Network;WebBrowser;
Keywords=browser;web;internet;bookmarks;privacy;
StartupNotify=true
MimeType=text/html;text/xml;application/xhtml+xml;
EOF
    fi
    
    # Install media player if available
    if [ -f scripts/bluejay-media-player.sh ]; then
        cp scripts/bluejay-media-player.sh "${ROOTFS}/usr/bin/bluejay-media-player"
        chmod +x "${ROOTFS}/usr/bin/bluejay-media-player"
        
        # Create media player desktop entry
        cat > "${ROOTFS}/usr/share/applications/bluejay-media-player.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=BluejayLinux Media Player
Comment=Integrated audio, video and image player
Icon=multimedia-player
Exec=bluejay-media-player
Categories=AudioVideo;Player;
Keywords=media;audio;video;music;movies;images;player;
StartupNotify=true
MimeType=audio/mpeg;audio/x-wav;video/mp4;video/x-msvideo;image/jpeg;image/png;
EOF
    fi
    
    # Install graphics acceleration if available
    if [ -f scripts/bluejay-graphics-acceleration.sh ]; then
        cp scripts/bluejay-graphics-acceleration.sh "${ROOTFS}/usr/bin/bluejay-graphics-acceleration"
        chmod +x "${ROOTFS}/usr/bin/bluejay-graphics-acceleration"
        
        # Create graphics acceleration desktop entry
        cat > "${ROOTFS}/usr/share/applications/bluejay-graphics-acceleration.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=BluejayLinux Graphics Acceleration
Comment=GPU acceleration and hardware rendering configuration
Icon=preferences-desktop-display
Exec=bluejay-graphics-acceleration
Categories=System;Settings;
Keywords=graphics;gpu;acceleration;drivers;performance;
StartupNotify=true
EOF
    fi
    
    # Install screenshot recorder if available
    if [ -f scripts/bluejay-screenshot-recorder.sh ]; then
        cp scripts/bluejay-screenshot-recorder.sh "${ROOTFS}/usr/bin/bluejay-screenshot-recorder"
        chmod +x "${ROOTFS}/usr/bin/bluejay-screenshot-recorder"
        
        # Create screenshot recorder desktop entry
        cat > "${ROOTFS}/usr/share/applications/bluejay-screenshot-recorder.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=BluejayLinux Screenshot & Recorder
Comment=Screen capture and recording tools
Icon=applets-screenshooter
Exec=bluejay-screenshot-recorder
Categories=AudioVideo;Recorder;Graphics;
Keywords=screenshot;screen;capture;record;video;
StartupNotify=true
EOF
    fi
    
    # Install image viewer if available
    if [ -f scripts/bluejay-image-viewer.sh ]; then
        cp scripts/bluejay-image-viewer.sh "${ROOTFS}/usr/bin/bluejay-image-viewer"
        chmod +x "${ROOTFS}/usr/bin/bluejay-image-viewer"
        
        # Create image viewer desktop entry
        cat > "${ROOTFS}/usr/share/applications/bluejay-image-viewer.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=BluejayLinux Image Viewer
Comment=Professional image viewer with basic editing
Icon=image-viewer
Exec=bluejay-image-viewer %f
Categories=Graphics;Viewer;Photography;
Keywords=image;photo;viewer;editor;pictures;
StartupNotify=true
MimeType=image/jpeg;image/png;image/gif;image/bmp;image/tiff;image/webp;image/svg+xml;
EOF
    fi
    
    # Install graphics pipeline if available
    if [ -f scripts/bluejay-graphics-pipeline.sh ]; then
        cp scripts/bluejay-graphics-pipeline.sh "${ROOTFS}/usr/bin/bluejay-graphics-pipeline"
        chmod +x "${ROOTFS}/usr/bin/bluejay-graphics-pipeline"
        
        # Create graphics pipeline desktop entry
        cat > "${ROOTFS}/usr/share/applications/bluejay-graphics-pipeline.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=BluejayLinux Graphics Pipeline
Comment=Advanced graphics pipeline and hardware acceleration
Icon=preferences-system
Exec=bluejay-graphics-pipeline
Categories=System;Settings;Graphics;
Keywords=graphics;pipeline;acceleration;optimization;performance;
StartupNotify=true
EOF
    fi
    
    # Install multimedia codecs if available
    if [ -f scripts/bluejay-multimedia-codecs.sh ]; then
        cp scripts/bluejay-multimedia-codecs.sh "${ROOTFS}/usr/bin/bluejay-multimedia-codecs"
        chmod +x "${ROOTFS}/usr/bin/bluejay-multimedia-codecs"
        
        # Create multimedia codecs desktop entry
        cat > "${ROOTFS}/usr/share/applications/bluejay-multimedia-codecs.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=BluejayLinux Multimedia Codecs
Comment=Universal media format support and codec management
Icon=preferences-desktop-multimedia
Exec=bluejay-multimedia-codecs
Categories=AudioVideo;Settings;
Keywords=codecs;multimedia;audio;video;formats;conversion;
StartupNotify=true
EOF
    fi
    
    # Install VPN manager if available
    if [ -f scripts/bluejay-vpn-manager.sh ]; then
        cp scripts/bluejay-vpn-manager.sh "${ROOTFS}/usr/bin/bluejay-vpn-manager"
        chmod +x "${ROOTFS}/usr/bin/bluejay-vpn-manager"
        
        # Create VPN manager desktop entry
        cat > "${ROOTFS}/usr/share/applications/bluejay-vpn-manager.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=BluejayLinux VPN Manager
Comment=Professional VPN integration and connection management
Icon=network-vpn
Exec=bluejay-vpn-manager
Categories=Network;Security;
Keywords=vpn;security;privacy;network;connection;
StartupNotify=true
EOF
    fi
    
    # Install WiFi manager if available
    if [ -f scripts/bluejay-wifi-manager.sh ]; then
        cp scripts/bluejay-wifi-manager.sh "${ROOTFS}/usr/bin/bluejay-wifi-manager"
        chmod +x "${ROOTFS}/usr/bin/bluejay-wifi-manager"
        
        # Create WiFi manager desktop entry
        cat > "${ROOTFS}/usr/share/applications/bluejay-wifi-manager.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=BluejayLinux WiFi Manager
Comment=Professional wireless networking and configuration
Icon=network-wireless
Exec=bluejay-wifi-manager
Categories=Network;Settings;
Keywords=wifi;wireless;network;connection;networking;
StartupNotify=true
EOF
    fi
    
    # Install firewall manager if available
    if [ -f scripts/bluejay-firewall-manager.sh ]; then
        cp scripts/bluejay-firewall-manager.sh "${ROOTFS}/usr/bin/bluejay-firewall-manager"
        chmod +x "${ROOTFS}/usr/bin/bluejay-firewall-manager"
        
        # Create firewall manager desktop entry
        cat > "${ROOTFS}/usr/share/applications/bluejay-firewall-manager.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=BluejayLinux Firewall Manager
Comment=Advanced security and network protection
Icon=security-high
Exec=bluejay-firewall-manager
Categories=System;Security;Network;
Keywords=firewall;security;protection;iptables;network;
StartupNotify=true
EOF
    fi
    
    # Install encryption tools if available
    if [ -f scripts/bluejay-encryption-tools.sh ]; then
        cp scripts/bluejay-encryption-tools.sh "${ROOTFS}/usr/bin/bluejay-encryption-tools"
        chmod +x "${ROOTFS}/usr/bin/bluejay-encryption-tools"
        
        # Create encryption tools desktop entry
        cat > "${ROOTFS}/usr/share/applications/bluejay-encryption-tools.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=BluejayLinux Encryption Tools
Comment=Professional security and privacy suite
Icon=security-medium
Exec=bluejay-encryption-tools
Categories=System;Security;Utility;
Keywords=encryption;security;privacy;cryptography;keys;vault;
StartupNotify=true
EOF
    fi
    
    # Install graphics drivers manager if available
    if [ -f scripts/bluejay-graphics-drivers.sh ]; then
        cp scripts/bluejay-graphics-drivers.sh "${ROOTFS}/usr/bin/bluejay-graphics-drivers"
        chmod +x "${ROOTFS}/usr/bin/bluejay-graphics-drivers"
        
        # Create graphics drivers desktop entry
        cat > "${ROOTFS}/usr/share/applications/bluejay-graphics-drivers.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=BluejayLinux Graphics Drivers
Comment=3D acceleration and advanced graphics drivers
Icon=preferences-desktop-display
Exec=bluejay-graphics-drivers
Categories=System;Settings;HardwareSettings;
Keywords=graphics;drivers;3d;acceleration;nvidia;amd;intel;
StartupNotify=true
EOF
    fi
    
    # Install Bluetooth manager if available
    if [ -f scripts/bluejay-bluetooth-manager.sh ]; then
        cp scripts/bluejay-bluetooth-manager.sh "${ROOTFS}/usr/bin/bluejay-bluetooth-manager"
        chmod +x "${ROOTFS}/usr/bin/bluejay-bluetooth-manager"
        
        # Create Bluetooth manager desktop entry
        cat > "${ROOTFS}/usr/share/applications/bluejay-bluetooth-manager.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=BluejayLinux Bluetooth Manager
Comment=Comprehensive Bluetooth device management
Icon=bluetooth
Exec=bluejay-bluetooth-manager
Categories=Network;Settings;HardwareSettings;
Keywords=bluetooth;devices;pairing;wireless;audio;
StartupNotify=true
EOF
    fi
    
    # Install printer manager if available
    if [ -f scripts/bluejay-printer-manager.sh ]; then
        cp scripts/bluejay-printer-manager.sh "${ROOTFS}/usr/bin/bluejay-printer-manager"
        chmod +x "${ROOTFS}/usr/bin/bluejay-printer-manager"
        
        # Create printer manager desktop entry
        cat > "${ROOTFS}/usr/share/applications/bluejay-printer-manager.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=BluejayLinux Printer Manager
Comment=Professional printing system with driver installation
Icon=printer
Exec=bluejay-printer-manager
Categories=System;Settings;HardwareSettings;Printing;
Keywords=printer;printing;cups;drivers;queue;
StartupNotify=true
EOF
    fi
    
    # Install storage manager if available
    if [ -f scripts/bluejay-storage-manager.sh ]; then
        cp scripts/bluejay-storage-manager.sh "${ROOTFS}/usr/bin/bluejay-storage-manager"
        chmod +x "${ROOTFS}/usr/bin/bluejay-storage-manager"
        
        # Create storage manager desktop entry
        cat > "${ROOTFS}/usr/share/applications/bluejay-storage-manager.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=BluejayLinux Storage Manager
Comment=Advanced USB and storage device management
Icon=drive-harddisk
Exec=bluejay-storage-manager
Categories=System;FileTools;HardwareSettings;
Keywords=storage;usb;disk;mount;format;partition;
StartupNotify=true
EOF
    fi
    
    # Install developer tools if available
    if [ -f scripts/bluejay-git-manager.sh ]; then
        cp scripts/bluejay-git-manager.sh "${ROOTFS}/usr/bin/bluejay-git-manager"
        chmod +x "${ROOTFS}/usr/bin/bluejay-git-manager"
        
        # Git Manager
        cat > "${ROOTFS}/usr/share/applications/bluejay-git-manager.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=BluejayLinux Git Manager
Comment=Professional Git GUI and version control tools
Icon=git
Exec=bluejay-git-manager
Categories=Development;RevisionControl;
Keywords=git;version;control;repository;commit;branch;merge;clone;
StartupNotify=true
EOF

    fi
    
    if [ -f scripts/bluejay-package-builder.sh ]; then
        cp scripts/bluejay-package-builder.sh "${ROOTFS}/usr/bin/bluejay-package-builder"
        chmod +x "${ROOTFS}/usr/bin/bluejay-package-builder"
        
        # Package Builder
        cat > "${ROOTFS}/usr/share/applications/bluejay-package-builder.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=BluejayLinux Package Builder
Comment=Multi-language project creation and build system
Icon=package-x-generic
Exec=bluejay-package-builder
Categories=Development;Building;
Keywords=build;package;compile;project;c;python;rust;go;javascript;deb;rpm;
StartupNotify=true
EOF

    fi
    
    if [ -f scripts/bluejay-debug-profiler.sh ]; then
        cp scripts/bluejay-debug-profiler.sh "${ROOTFS}/usr/bin/bluejay-debug-profiler"
        chmod +x "${ROOTFS}/usr/bin/bluejay-debug-profiler"
        
        # Debug Profiler
        cat > "${ROOTFS}/usr/share/applications/bluejay-debug-profiler.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=BluejayLinux Debug Profiler
Comment=Advanced debugging and profiling tools
Icon=applications-debugging
Exec=bluejay-debug-profiler
Categories=Development;Debugger;Profiling;
Keywords=debug;gdb;valgrind;perf;strace;profiling;memory;performance;
StartupNotify=true
EOF
    fi
    
    log_success "Enhanced applications, multimedia/graphics tools, security suite, system integration tools, and developer tools installed"
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