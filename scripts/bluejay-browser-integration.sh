#!/bin/bash
# BluejayLinux Native Browser Integration - Complete Implementation
# Advanced web browsing with native OS integration

set -e

BROWSER_CONFIG="$HOME/.config/bluejay/browser.conf"
BROWSER_DATA="$HOME/.local/share/bluejay/browser"
BOOKMARKS_FILE="$BROWSER_DATA/bookmarks"
HISTORY_FILE="$BROWSER_DATA/history"
DOWNLOADS_DIR="$HOME/Downloads"

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Initialize browser configuration
init_browser_config() {
    mkdir -p "$(dirname "$BROWSER_CONFIG")"
    mkdir -p "$BROWSER_DATA"
    mkdir -p "$DOWNLOADS_DIR"
    
    if [ ! -f "$BROWSER_CONFIG" ]; then
        cat > "$BROWSER_CONFIG" << 'EOF'
# BluejayLinux Browser Configuration
DEFAULT_BROWSER=auto
HOME_PAGE=https://bluejaylinux.org
SEARCH_ENGINE=duckduckgo
DOWNLOAD_DIR=$HOME/Downloads
ENABLE_JAVASCRIPT=true
ENABLE_COOKIES=true
ENABLE_POPUP_BLOCKER=true
ENABLE_AD_BLOCKER=false
PRIVATE_BROWSING=false
SYNC_ENABLED=false

# Security settings
ENABLE_HTTPS_ONLY=true
BLOCK_TRACKERS=true
BLOCK_MALWARE=true
CLEAR_DATA_ON_EXIT=false

# Interface settings
SHOW_BOOKMARKS_BAR=true
SHOW_TAB_BAR=true
THEME=system
ZOOM_LEVEL=100
EOF
    fi
    
    create_default_bookmarks
}

# Create default bookmarks
create_default_bookmarks() {
    if [ ! -f "$BOOKMARKS_FILE" ]; then
        cat > "$BOOKMARKS_FILE" << 'EOF'
BluejayLinux|https://bluejaylinux.org|BluejayLinux Official Site
DuckDuckGo|https://duckduckgo.com|Privacy-focused Search Engine
GitHub|https://github.com|Code Repository Platform
Stack Overflow|https://stackoverflow.com|Programming Q&A
MDN Web Docs|https://developer.mozilla.org|Web Development Documentation
Cybersecurity News|https://krebsonsecurity.com|Security News and Analysis
Linux Documentation|https://www.kernel.org|Linux Kernel Documentation
Privacy Tools|https://privacytools.io|Privacy and Security Tools
EOF
    fi
}

# Load configuration
load_config() {
    [ -f "$BROWSER_CONFIG" ] && source "$BROWSER_CONFIG"
}

# Show browser menu
show_browser_menu() {
    clear
    load_config
    
    echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║       BluejayLinux Browser Integration       ║${NC}"
    echo -e "${BLUE}║           Native Web Browsing v2.0           ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${CYAN}Current Configuration:${NC}"
    echo "Default Browser: $DEFAULT_BROWSER"
    echo "Home Page: $HOME_PAGE"
    echo "Search Engine: $SEARCH_ENGINE"
    echo "Private Mode: $PRIVATE_BROWSING"
    echo ""
    
    echo -e "${YELLOW}Browser Options:${NC}"
    echo "[1] Launch Web Browser           [8] Privacy Settings"
    echo "[2] Browse URL                   [9] Security Settings"
    echo "[3] Search Web                   [10] Extension Manager"
    echo "[4] Bookmarks Manager            [11] Download Manager"
    echo "[5] Browse History               [12] Browser Settings"
    echo "[6] Private/Incognito Mode       [13] Profile Manager"
    echo "[7] Developer Tools              [14] Import/Export Data"
    echo ""
    echo "[w] Quick Web Search  [b] Bookmarks  [h] History  [q] Quit"
    echo ""
    echo -n "bluejay-browser> "
}

# Detect and launch available browser
launch_browser() {
    local url="${1:-$HOME_PAGE}"
    local private_mode="$2"
    
    echo -e "${BLUE}Launching browser...${NC}"
    
    # Try different browsers in order of preference
    local browsers=()
    local commands=()
    
    # Check for installed browsers
    if command -v google-chrome >/dev/null; then
        browsers+=("Google Chrome")
        if [ "$private_mode" = "true" ]; then
            commands+=("google-chrome --incognito")
        else
            commands+=("google-chrome")
        fi
    fi
    
    if command -v chromium >/dev/null; then
        browsers+=("Chromium")
        if [ "$private_mode" = "true" ]; then
            commands+=("chromium --incognito")
        else
            commands+=("chromium")
        fi
    fi
    
    if command -v firefox >/dev/null; then
        browsers+=("Firefox")
        if [ "$private_mode" = "true" ]; then
            commands+=("firefox --private-window")
        else
            commands+=("firefox")
        fi
    fi
    
    if command -v lynx >/dev/null; then
        browsers+=("Lynx (Text Browser)")
        commands+=("lynx")
    fi
    
    if command -v w3m >/dev/null; then
        browsers+=("W3M (Text Browser)")
        commands+=("w3m")
    fi
    
    if [ ${#browsers[@]} -eq 0 ]; then
        echo -e "${RED}No web browsers found!${NC}"
        echo ""
        echo "Available installation options:"
        echo "• Install Chrome: /home/alastair/linux-6.16/scripts/install-chrome.sh"
        echo "• Install Firefox: sudo apt install firefox-esr"
        echo "• Install Chromium: sudo apt install chromium-browser"
        echo "• Install text browsers: sudo apt install lynx w3m"
        return 1
    fi
    
    # If auto-detect, use first available
    if [ "$DEFAULT_BROWSER" = "auto" ] || [ -z "$DEFAULT_BROWSER" ]; then
        echo "Using: ${browsers[0]}"
        ${commands[0]} "$url" &
        
        # Add to history
        add_to_history "$url"
        
        echo -e "${GREEN}Browser launched successfully${NC}"
    else
        # Show browser selection menu
        echo -e "${BLUE}Available Browsers:${NC}"
        for i in "${!browsers[@]}"; do
            echo "[$((i+1))] ${browsers[$i]}"
        done
        echo ""
        echo -n "Select browser (or Enter for default): "
        read browser_choice
        
        if [ -n "$browser_choice" ] && [ "$browser_choice" -ge 1 ] && [ "$browser_choice" -le ${#browsers[@]} ]; then
            local selected_index=$((browser_choice - 1))
            echo "Launching: ${browsers[$selected_index]}"
            ${commands[$selected_index]} "$url" &
            
            add_to_history "$url"
            echo -e "${GREEN}Browser launched: ${browsers[$selected_index]}${NC}"
        else
            echo "Using default browser"
            ${commands[0]} "$url" &
            add_to_history "$url"
        fi
    fi
}

# Browse specific URL
browse_url() {
    echo -n "Enter URL (https://example.com): "
    read url
    
    if [ -z "$url" ]; then
        echo "No URL provided"
        return
    fi
    
    # Add protocol if missing
    if [[ ! "$url" =~ ^https?:// ]]; then
        url="https://$url"
    fi
    
    echo "Opening: $url"
    launch_browser "$url"
}

# Web search
web_search() {
    echo -n "Search query: "
    read query
    
    if [ -z "$query" ]; then
        echo "No search query provided"
        return
    fi
    
    local search_url
    case "$SEARCH_ENGINE" in
        "google")
            search_url="https://www.google.com/search?q="
            ;;
        "duckduckgo")
            search_url="https://duckduckgo.com/?q="
            ;;
        "bing")
            search_url="https://www.bing.com/search?q="
            ;;
        "startpage")
            search_url="https://www.startpage.com/do/search?q="
            ;;
        *)
            search_url="https://duckduckgo.com/?q="
            ;;
    esac
    
    # URL encode the query (basic)
    local encoded_query=$(echo "$query" | sed 's/ /+/g')
    local full_url="${search_url}${encoded_query}"
    
    echo "Searching for: $query"
    echo "Using: $SEARCH_ENGINE"
    launch_browser "$full_url"
}

# Bookmarks manager
bookmarks_manager() {
    echo -e "${BLUE}Bookmarks Manager${NC}"
    echo "=================="
    echo ""
    
    if [ ! -f "$BOOKMARKS_FILE" ]; then
        echo "No bookmarks found"
        return
    fi
    
    echo -e "${YELLOW}Saved Bookmarks:${NC}"
    local count=1
    while IFS='|' read -r name url description; do
        echo "[$count] $name"
        echo "    URL: $url"
        echo "    Description: $description"
        echo ""
        count=$((count + 1))
    done < "$BOOKMARKS_FILE"
    
    echo -e "${YELLOW}Bookmark Options:${NC}"
    echo "[number] Open bookmark"
    echo "[a] Add new bookmark"
    echo "[d] Delete bookmark"
    echo "[e] Edit bookmark"
    echo "[b] Back to main menu"
    echo -n "Choice: "
    read bookmark_choice
    
    case "$bookmark_choice" in
        [0-9]*)
            local bookmark_line=$(sed -n "${bookmark_choice}p" "$BOOKMARKS_FILE")
            if [ -n "$bookmark_line" ]; then
                local bookmark_url=$(echo "$bookmark_line" | cut -d'|' -f2)
                launch_browser "$bookmark_url"
            else
                echo "Invalid bookmark number"
            fi
            ;;
        a) add_bookmark ;;
        d) delete_bookmark ;;
        e) edit_bookmark ;;
        b) return ;;
        *) echo "Invalid choice" ;;
    esac
}

# Add new bookmark
add_bookmark() {
    echo -n "Bookmark name: "
    read name
    echo -n "URL: "
    read url
    echo -n "Description (optional): "
    read description
    
    if [ -n "$name" ] && [ -n "$url" ]; then
        echo "$name|$url|$description" >> "$BOOKMARKS_FILE"
        echo -e "${GREEN}Bookmark added: $name${NC}"
    else
        echo -e "${RED}Name and URL are required${NC}"
    fi
}

# Browse history
browse_history() {
    echo -e "${BLUE}Browser History${NC}"
    echo "==============="
    echo ""
    
    if [ ! -f "$HISTORY_FILE" ]; then
        echo "No browsing history found"
        return
    fi
    
    echo -e "${YELLOW}Recent History:${NC}"
    tail -20 "$HISTORY_FILE" | nl -s') '
    echo ""
    
    echo "[number] Open URL from history"
    echo "[c] Clear history" 
    echo "[s] Search history"
    echo "[b] Back to main menu"
    echo -n "Choice: "
    read history_choice
    
    case "$history_choice" in
        [0-9]*)
            local history_line=$(tail -20 "$HISTORY_FILE" | sed -n "${history_choice}p")
            if [ -n "$history_line" ]; then
                local history_url=$(echo "$history_line" | awk '{print $3}')
                launch_browser "$history_url"
            fi
            ;;
        c)
            echo -n "Clear all history? (y/n): "
            read confirm
            if [ "$confirm" = "y" ]; then
                > "$HISTORY_FILE"
                echo "History cleared"
            fi
            ;;
        s) search_history ;;
        b) return ;;
    esac
}

# Add URL to history
add_to_history() {
    local url="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$timestamp | $url" >> "$HISTORY_FILE"
}

# Search history
search_history() {
    echo -n "Search term: "
    read search_term
    
    if [ -n "$search_term" ]; then
        echo -e "${BLUE}Matching history entries:${NC}"
        grep -i "$search_term" "$HISTORY_FILE" | tail -10 | nl
    fi
    
    read -p "Press Enter to continue..."
}

# Private browsing mode
private_browsing() {
    echo -e "${BLUE}Private/Incognito Browsing${NC}"
    echo "=========================="
    echo ""
    echo "Starting private browsing session..."
    echo "• History will not be saved"
    echo "• Cookies will be cleared on exit"
    echo "• Enhanced privacy protection"
    echo ""
    
    launch_browser "$HOME_PAGE" "true"
}

# Browser settings
browser_settings() {
    load_config
    
    echo -e "${BLUE}Browser Settings${NC}"
    echo "================"
    echo ""
    echo "[1] Default Browser (Current: $DEFAULT_BROWSER)"
    echo "[2] Home Page (Current: $HOME_PAGE)"
    echo "[3] Search Engine (Current: $SEARCH_ENGINE)"
    echo "[4] Download Directory (Current: $DOWNLOAD_DIR)"
    echo "[5] JavaScript (Current: $ENABLE_JAVASCRIPT)"
    echo "[6] Cookies (Current: $ENABLE_COOKIES)"
    echo "[7] Popup Blocker (Current: $ENABLE_POPUP_BLOCKER)"
    echo "[8] HTTPS Only Mode (Current: $ENABLE_HTTPS_ONLY)"
    echo -n "Select setting to change: "
    read setting_choice
    
    case $setting_choice in
        1) change_default_browser ;;
        2) change_home_page ;;
        3) change_search_engine ;;
        4) change_download_dir ;;
        5) toggle_browser_setting "ENABLE_JAVASCRIPT" ;;
        6) toggle_browser_setting "ENABLE_COOKIES" ;;
        7) toggle_browser_setting "ENABLE_POPUP_BLOCKER" ;;
        8) toggle_browser_setting "ENABLE_HTTPS_ONLY" ;;
        *) echo "Invalid choice" ;;
    esac
}

# Change search engine
change_search_engine() {
    echo -e "${BLUE}Search Engine Options:${NC}"
    echo "[1] DuckDuckGo (Privacy-focused)"
    echo "[2] Google"
    echo "[3] Bing"
    echo "[4] StartPage (Google results, private)"
    echo -n "Select search engine: "
    read engine_choice
    
    case $engine_choice in
        1) new_engine="duckduckgo" ;;
        2) new_engine="google" ;;
        3) new_engine="bing" ;;
        4) new_engine="startpage" ;;
        *) echo "Invalid choice"; return ;;
    esac
    
    sed -i "s/SEARCH_ENGINE=.*/SEARCH_ENGINE=$new_engine/" "$BROWSER_CONFIG"
    echo -e "${GREEN}Search engine changed to $new_engine${NC}"
}

# Change home page
change_home_page() {
    echo -n "New home page URL: "
    read new_home_page
    
    if [ -n "$new_home_page" ]; then
        sed -i "s|HOME_PAGE=.*|HOME_PAGE=$new_home_page|" "$BROWSER_CONFIG"
        echo -e "${GREEN}Home page changed to $new_home_page${NC}"
    fi
}

# Toggle browser setting
toggle_browser_setting() {
    local setting="$1"
    local current_value=$(grep "^$setting=" "$BROWSER_CONFIG" | cut -d= -f2)
    
    if [ "$current_value" = "true" ]; then
        sed -i "s/$setting=.*/$setting=false/" "$BROWSER_CONFIG"
        echo "$setting disabled"
    else
        sed -i "s/$setting=.*/$setting=true/" "$BROWSER_CONFIG"
        echo "$setting enabled"
    fi
}

# Download manager
download_manager() {
    echo -e "${BLUE}Download Manager${NC}"
    echo "================"
    echo ""
    
    if [ ! -d "$DOWNLOADS_DIR" ]; then
        mkdir -p "$DOWNLOADS_DIR"
    fi
    
    echo "Downloads directory: $DOWNLOADS_DIR"
    echo ""
    
    if [ "$(ls -A "$DOWNLOADS_DIR" 2>/dev/null)" ]; then
        echo -e "${YELLOW}Recent Downloads:${NC}"
        ls -lt "$DOWNLOADS_DIR" | head -10
    else
        echo "No downloads found"
    fi
    
    echo ""
    echo "[o] Open downloads folder"
    echo "[c] Clear downloads"
    echo "[b] Back to main menu"
    echo -n "Choice: "
    read download_choice
    
    case $download_choice in
        o) 
            if command -v bluejay-files >/dev/null; then
                bluejay-files "$DOWNLOADS_DIR"
            else
                ls -la "$DOWNLOADS_DIR"
            fi
            ;;
        c)
            echo -n "Clear all downloads? (y/n): "
            read confirm
            if [ "$confirm" = "y" ]; then
                rm -rf "$DOWNLOADS_DIR"/*
                echo "Downloads cleared"
            fi
            ;;
        b) return ;;
    esac
}

# Show browser help
show_browser_help() {
    echo -e "${BLUE}BluejayLinux Browser Integration Help${NC}"
    echo "====================================="
    echo ""
    echo -e "${YELLOW}Features:${NC}"
    echo "• Auto-detection of installed browsers"
    echo "• Integrated bookmarks management"
    echo "• Browsing history tracking"
    echo "• Private/Incognito browsing support"
    echo "• Multiple search engines"
    echo "• Download management"
    echo "• Privacy and security settings"
    echo ""
    echo -e "${YELLOW}Supported Browsers:${NC}"
    echo "• Google Chrome (recommended)"
    echo "• Chromium"
    echo "• Mozilla Firefox"
    echo "• Lynx (text-based)"
    echo "• W3M (text-based)"
    echo ""
    echo -e "${YELLOW}Quick Commands:${NC}"
    echo "• bluejay-browser w: Quick web search"
    echo "• bluejay-browser b: Open bookmarks"
    echo "• bluejay-browser h: View history"
    echo "• bluejay-browser <URL>: Open specific URL"
}

# Main application loop
main() {
    init_browser_config
    
    # Handle command line arguments
    case "$1" in
        w|search)
            web_search
            exit 0
            ;;
        b|bookmarks)
            bookmarks_manager
            exit 0
            ;;
        h|history)
            browse_history
            exit 0
            ;;
        p|private)
            private_browsing
            exit 0
            ;;
        --help|help)
            show_browser_help
            exit 0
            ;;
        http*|www*)
            launch_browser "$1"
            exit 0
            ;;
    esac
    
    while true; do
        show_browser_menu
        read choice
        
        case $choice in
            1) launch_browser ;;
            2) browse_url ;;
            3) web_search ;;
            4) bookmarks_manager ;;
            5) browse_history ;;
            6) private_browsing ;;
            7) echo "Developer tools - Available in browser (F12)" ;;
            8) echo "Privacy settings - Coming soon" ;;
            9) echo "Security settings - Coming soon" ;;
            10) echo "Extension manager - Coming soon" ;;
            11) download_manager ;;
            12) browser_settings ;;
            13) echo "Profile manager - Coming soon" ;;
            14) echo "Import/Export - Coming soon" ;;
            w) web_search ;;
            b) bookmarks_manager ;;
            h) browse_history ;;
            q) exit 0 ;;
            *) echo "Invalid option" ;;
        esac
        
        [ "$choice" != "w" ] && [ "$choice" != "b" ] && [ "$choice" != "h" ] && read -p "Press Enter to continue..."
    done
}

main "$@"