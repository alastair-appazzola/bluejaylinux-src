#!/bin/bash

# BluejayLinux - WiFi Configuration & Management
# Professional wireless network management with graphical interface

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/bluejay"
WIFI_CONFIG_DIR="$CONFIG_DIR/wifi"
NETWORKS_DB="$WIFI_CONFIG_DIR/saved_networks.db"
SCAN_CACHE="/tmp/bluejay-wifi-scan"
STATUS_FILE="/tmp/bluejay-wifi-status"

# Color scheme
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m'

# WiFi security types
SECURITY_TYPES="WPA WPA2 WPA3 WEP Open Enterprise"

# Initialize directories
create_directories() {
    mkdir -p "$CONFIG_DIR" "$WIFI_CONFIG_DIR"
    touch "$NETWORKS_DB"
    
    # Create default WiFi configuration
    if [ ! -f "$WIFI_CONFIG_DIR/settings.conf" ]; then
        cat > "$WIFI_CONFIG_DIR/settings.conf" << 'EOF'
# BluejayLinux WiFi Manager Settings
AUTO_CONNECT=true
PREFERRED_BAND=auto
POWER_MANAGEMENT=auto
SCAN_INTERVAL=30
CONNECT_TIMEOUT=15
ROAMING_ENABLED=true
BACKGROUND_SCAN=true
SHOW_HIDDEN_NETWORKS=false
SIGNAL_STRENGTH_UNITS=dBm
PREFERRED_SECURITY=WPA2
AUTO_RECONNECT=true
CONNECTION_PRIORITY=signal
NOTIFICATION_LEVEL=normal
COUNTRY_CODE=US
REGULATORY_DOMAIN=FCC
EOF
    fi
}

# Load settings
load_settings() {
    if [ -f "$WIFI_CONFIG_DIR/settings.conf" ]; then
        source "$WIFI_CONFIG_DIR/settings.conf"
    fi
}

# Detect WiFi interfaces and capabilities
detect_wifi_hardware() {
    echo -e "${BLUE}Detecting WiFi hardware...${NC}"
    
    local interfaces=()
    local capabilities=()
    
    # Get WiFi interfaces
    if command -v iw >/dev/null; then
        for interface in $(iw dev | awk '$1=="Interface"{print $2}'); do
            if [ -d "/sys/class/net/$interface/wireless" ]; then
                interfaces+=("$interface")
                echo -e "${GREEN}✓${NC} WiFi interface: $interface"
                
                # Get capabilities
                local info=$(iw dev "$interface" info 2>/dev/null)
                if echo "$info" | grep -q "type managed"; then
                    capabilities+=("station")
                fi
                if echo "$info" | grep -q "type AP"; then
                    capabilities+=("access_point")
                fi
            fi
        done
    elif command -v iwconfig >/dev/null; then
        for interface in $(iwconfig 2>/dev/null | grep "IEEE 802.11" | cut -d' ' -f1); do
            interfaces+=("$interface")
            echo -e "${GREEN}✓${NC} WiFi interface: $interface"
        done
    fi
    
    # Check for advanced features
    if command -v rfkill >/dev/null; then
        capabilities+=("rfkill")
        echo -e "${GREEN}✓${NC} RF kill switch support"
    fi
    
    if [ -d "/sys/class/net/wlan0/wireless" ]; then
        capabilities+=("power_management")
        echo -e "${GREEN}✓${NC} Power management support"
    fi
    
    echo "${interfaces[@]}|${capabilities[@]}"
}

# Get primary WiFi interface
get_wifi_interface() {
    local interfaces=($(detect_wifi_hardware | cut -d'|' -f1))
    echo "${interfaces[0]:-wlan0}"
}

# Scan for available networks
scan_networks() {
    local interface="${1:-$(get_wifi_interface)}"
    
    echo -e "${BLUE}Scanning for WiFi networks...${NC}"
    
    # Enable interface if down
    if ! ip link show "$interface" | grep -q "UP"; then
        sudo ip link set "$interface" up 2>/dev/null || true
    fi
    
    # Perform scan with different methods
    local scan_result=""
    
    if command -v nmcli >/dev/null; then
        # NetworkManager scan
        nmcli device wifi rescan 2>/dev/null || true
        sleep 2
        scan_result=$(nmcli -t -f SSID,BSSID,MODE,CHAN,FREQ,RATE,SIGNAL,BARS,SECURITY device wifi list 2>/dev/null)
    elif command -v iw >/dev/null; then
        # iw scan
        sudo iw dev "$interface" scan 2>/dev/null | parse_iw_scan
    elif command -v iwlist >/dev/null; then
        # iwlist scan
        sudo iwlist "$interface" scan 2>/dev/null | parse_iwlist_scan
    fi
    
    # Cache scan results
    echo "$scan_result" > "$SCAN_CACHE"
    echo -e "${GREEN}✓${NC} Scan completed"
}

# Parse iw scan output
parse_iw_scan() {
    awk '
    /^BSS / { 
        if (ssid != "") print ssid":"bssid":"freq":"signal":"security
        bssid = substr($2, 1, length($2)-1)
        ssid = ""
        freq = ""
        signal = ""
        security = "Open"
    }
    /SSID:/ { ssid = $2; for(i=3; i<=NF; i++) ssid = ssid " " $i }
    /freq:/ { freq = $2 }
    /signal:/ { signal = $2 " " $3 }
    /Privacy/ { security = "WEP" }
    /RSN:/ { security = "WPA2" }
    /WPA:/ { if (security == "Open") security = "WPA" }
    END { if (ssid != "") print ssid":"bssid":"freq":"signal":"security }
    '
}

# Parse iwlist scan output  
parse_iwlist_scan() {
    awk -F: '
    /Cell/ { 
        if (ssid != "") print ssid":"bssid":"freq":"signal":"security
        bssid = ""
        ssid = ""
        freq = ""
        signal = ""
        security = "Open"
    }
    /Address/ { bssid = $2; gsub(/ /, "", bssid) }
    /ESSID/ { 
        ssid = $2
        gsub(/^"/, "", ssid)
        gsub(/"$/, "", ssid)
    }
    /Frequency/ { freq = $2 }
    /Signal level/ { signal = $2 }
    /Encryption key:on/ { security = "WEP" }
    /WPA/ { security = "WPA" }
    /WPA2/ { security = "WPA2" }
    END { if (ssid != "") print ssid":"bssid":"freq":"signal":"security }
    '
}

# Get current WiFi status
get_wifi_status() {
    local interface="${1:-$(get_wifi_interface)}"
    local status="disconnected"
    local ssid=""
    local signal=""
    local ip=""
    
    if command -v nmcli >/dev/null; then
        # NetworkManager status
        local nm_status=$(nmcli -t -f DEVICE,STATE,CONNECTION device status | grep "^$interface:")
        if echo "$nm_status" | grep -q "connected"; then
            status="connected"
            ssid=$(nmcli -t -f ACTIVE,SSID device wifi | grep "^yes:" | cut -d: -f2)
            signal=$(nmcli -t -f ACTIVE,SIGNAL device wifi | grep "^yes:" | cut -d: -f2)
        fi
    elif command -v iwconfig >/dev/null; then
        # iwconfig status
        local iw_status=$(iwconfig "$interface" 2>/dev/null)
        if echo "$iw_status" | grep -q "ESSID:"; then
            status="connected"
            ssid=$(echo "$iw_status" | grep "ESSID:" | sed 's/.*ESSID:"\([^"]*\)".*/\1/')
            signal=$(echo "$iw_status" | grep "Signal level" | sed 's/.*Signal level=\([^ ]*\).*/\1/')
        fi
    fi
    
    # Get IP address
    if [ "$status" = "connected" ]; then
        ip=$(ip addr show "$interface" | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
    fi
    
    echo "$status|$ssid|$signal|$ip"
}

# Connect to WiFi network
connect_wifi() {
    local ssid="$1"
    local password="$2"
    local security="${3:-auto}"
    local interface="${4:-$(get_wifi_interface)}"
    
    echo -e "${BLUE}Connecting to WiFi network: $ssid${NC}"
    
    if command -v nmcli >/dev/null; then
        # Use NetworkManager
        if [ "$security" = "Open" ] || [ -z "$password" ]; then
            nmcli device wifi connect "$ssid" ifname "$interface"
        else
            nmcli device wifi connect "$ssid" password "$password" ifname "$interface"
        fi
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓${NC} Connected to $ssid"
            save_network "$ssid" "$password" "$security"
            return 0
        fi
    elif command -v wpa_cli >/dev/null; then
        # Use wpa_supplicant
        connect_wpa_supplicant "$ssid" "$password" "$security" "$interface"
    else
        # Use iwconfig (basic)
        connect_iwconfig "$ssid" "$password" "$security" "$interface"
    fi
}

# Connect using wpa_supplicant
connect_wpa_supplicant() {
    local ssid="$1"
    local password="$2"
    local security="$3"
    local interface="$4"
    
    # Create wpa_supplicant configuration
    local wpa_config="/tmp/wpa_supplicant_${interface}.conf"
    
    cat > "$wpa_config" << EOF
ctrl_interface=/var/run/wpa_supplicant
update_config=1
country=$COUNTRY_CODE

network={
    ssid="$ssid"
EOF
    
    case "$security" in
        "WPA"|"WPA2"|"WPA3")
            echo "    psk=\"$password\"" >> "$wpa_config"
            ;;
        "WEP")
            echo "    key_mgmt=NONE" >> "$wpa_config"
            echo "    wep_key0=\"$password\"" >> "$wpa_config"
            ;;
        "Open")
            echo "    key_mgmt=NONE" >> "$wpa_config"
            ;;
    esac
    
    echo "}" >> "$wpa_config"
    
    # Start wpa_supplicant
    sudo wpa_supplicant -B -i "$interface" -c "$wpa_config"
    
    # Get IP address
    sudo dhclient "$interface"
    
    # Check connection
    sleep 5
    if iwconfig "$interface" | grep -q "ESSID:\"$ssid\""; then
        echo -e "${GREEN}✓${NC} Connected to $ssid via wpa_supplicant"
        save_network "$ssid" "$password" "$security"
        return 0
    else
        echo -e "${RED}✗${NC} Connection failed"
        return 1
    fi
}

# Connect using iwconfig (basic WEP/Open)
connect_iwconfig() {
    local ssid="$1"
    local password="$2"
    local security="$3"
    local interface="$4"
    
    # Set ESSID
    sudo iwconfig "$interface" essid "$ssid"
    
    # Set key if needed
    if [ "$security" = "WEP" ] && [ -n "$password" ]; then
        sudo iwconfig "$interface" key "$password"
    fi
    
    # Get IP address
    sudo dhclient "$interface"
    
    # Check connection
    sleep 5
    if iwconfig "$interface" | grep -q "ESSID:\"$ssid\""; then
        echo -e "${GREEN}✓${NC} Connected to $ssid via iwconfig"
        save_network "$ssid" "$password" "$security"
        return 0
    else
        echo -e "${RED}✗${NC} Connection failed"
        return 1
    fi
}

# Disconnect from WiFi
disconnect_wifi() {
    local interface="${1:-$(get_wifi_interface)}"
    
    echo -e "${BLUE}Disconnecting WiFi...${NC}"
    
    if command -v nmcli >/dev/null; then
        nmcli device disconnect "$interface"
    elif command -v wpa_cli >/dev/null; then
        sudo killall wpa_supplicant 2>/dev/null || true
        sudo iwconfig "$interface" essid off
    else
        sudo iwconfig "$interface" essid off
    fi
    
    echo -e "${GREEN}✓${NC} WiFi disconnected"
}

# Save network configuration
save_network() {
    local ssid="$1"
    local password="$2"
    local security="$3"
    local timestamp=$(date +%s)
    
    # Check if network already exists
    if grep -q "^$ssid:" "$NETWORKS_DB"; then
        # Update existing network
        sed -i "/^$ssid:/d" "$NETWORKS_DB"
    fi
    
    # Add network to database
    echo "$ssid:$password:$security:$timestamp" >> "$NETWORKS_DB"
    echo -e "${GREEN}✓${NC} Network saved: $ssid"
}

# Remove saved network
remove_network() {
    local ssid="$1"
    
    if grep -q "^$ssid:" "$NETWORKS_DB"; then
        sed -i "/^$ssid:/d" "$NETWORKS_DB"
        echo -e "${GREEN}✓${NC} Network removed: $ssid"
        
        # Remove from NetworkManager if available
        if command -v nmcli >/dev/null; then
            nmcli connection delete "$ssid" 2>/dev/null || true
        fi
    else
        echo -e "${YELLOW}!${NC} Network not found: $ssid"
    fi
}

# List saved networks
list_saved_networks() {
    echo -e "\n${BLUE}Saved WiFi Networks:${NC}"
    
    if [ ! -s "$NETWORKS_DB" ]; then
        echo -e "${YELLOW}No saved networks${NC}"
        return
    fi
    
    local count=1
    while IFS=: read -r ssid password security timestamp; do
        local date_saved=$(date -d "@$timestamp" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "Unknown")
        echo -e "${WHITE}$count.${NC} $ssid"
        echo -e "   ${CYAN}Security:${NC} $security"
        echo -e "   ${CYAN}Saved:${NC} $date_saved"
        ((count++))
    done < "$NETWORKS_DB"
}

# Display available networks
show_available_networks() {
    echo -e "\n${BLUE}Available WiFi Networks:${NC}"
    
    if [ ! -f "$SCAN_CACHE" ] || [ ! -s "$SCAN_CACHE" ]; then
        echo -e "${YELLOW}No scan results. Run a scan first.${NC}"
        return
    fi
    
    local count=1
    local current_ssid=$(get_wifi_status | cut -d'|' -f2)
    
    # Sort by signal strength
    sort -t: -k4 -nr "$SCAN_CACHE" | while IFS=: read -r ssid bssid freq signal security; do
        if [ -n "$ssid" ] && [ "$ssid" != "(hidden)" ]; then
            local indicator=""
            if [ "$ssid" = "$current_ssid" ]; then
                indicator="${GREEN}[CONNECTED]${NC} "
            fi
            
            # Signal strength visualization
            local bars=""
            local signal_num=$(echo "$signal" | grep -o '[0-9-]*' | head -1)
            if [ -n "$signal_num" ]; then
                if [ "$signal_num" -gt -50 ]; then
                    bars="████"
                elif [ "$signal_num" -gt -60 ]; then
                    bars="███"
                elif [ "$signal_num" -gt -70 ]; then
                    bars="██"
                else
                    bars="█"
                fi
            fi
            
            echo -e "${WHITE}$count.${NC} $indicator$ssid"
            echo -e "   ${CYAN}Security:${NC} $security  ${CYAN}Signal:${NC} $signal $bars"
            echo -e "   ${GRAY}BSSID: $bssid  Freq: $freq${NC}"
            ((count++))
        fi
    done
}

# WiFi status display
show_wifi_status() {
    local interface=$(get_wifi_interface)
    local status_info=$(get_wifi_status "$interface")
    local status=$(echo "$status_info" | cut -d'|' -f1)
    local ssid=$(echo "$status_info" | cut -d'|' -f2)
    local signal=$(echo "$status_info" | cut -d'|' -f3)
    local ip=$(echo "$status_info" | cut -d'|' -f4)
    
    echo -e "\n${PURPLE}=== WiFi Status ===${NC}"
    echo -e "${CYAN}Interface:${NC} $interface"
    
    if [ "$status" = "connected" ]; then
        echo -e "${GREEN}Status: Connected${NC}"
        echo -e "${CYAN}Network: $ssid${NC}"
        echo -e "${CYAN}Signal: $signal${NC}"
        echo -e "${CYAN}IP Address: $ip${NC}"
        
        # Additional connection info
        if command -v nmcli >/dev/null; then
            local conn_info=$(nmcli -t -f ACTIVE,FREQ,RATE,SECURITY device wifi | grep "^yes:")
            if [ -n "$conn_info" ]; then
                local freq=$(echo "$conn_info" | cut -d: -f2)
                local rate=$(echo "$conn_info" | cut -d: -f3)
                local security=$(echo "$conn_info" | cut -d: -f4)
                echo -e "${CYAN}Frequency: ${freq} MHz${NC}"
                echo -e "${CYAN}Rate: ${rate} Mb/s${NC}"
                echo -e "${CYAN}Security: $security${NC}"
            fi
        fi
    else
        echo -e "${RED}Status: Disconnected${NC}"
    fi
    
    # Hardware info
    if command -v iw >/dev/null; then
        local hw_info=$(iw dev "$interface" info 2>/dev/null)
        if [ -n "$hw_info" ]; then
            local mac=$(echo "$hw_info" | grep "addr" | cut -d' ' -f2)
            local type=$(echo "$hw_info" | grep "type" | cut -d' ' -f2)
            echo -e "${CYAN}MAC Address: $mac${NC}"
            echo -e "${CYAN}Type: $type${NC}"
        fi
    fi
}

# RF kill management
manage_rfkill() {
    if ! command -v rfkill >/dev/null; then
        echo -e "${RED}✗${NC} rfkill not available"
        return 1
    fi
    
    echo -e "\n${BLUE}RF Kill Status:${NC}"
    rfkill list wifi
    
    echo -ne "\n${YELLOW}Action (block/unblock/toggle):${NC} "
    read -r action
    
    case "$action" in
        block)
            sudo rfkill block wifi
            echo -e "${GREEN}✓${NC} WiFi blocked"
            ;;
        unblock)
            sudo rfkill unblock wifi
            echo -e "${GREEN}✓${NC} WiFi unblocked"
            ;;
        toggle)
            sudo rfkill block wifi
            sleep 1
            sudo rfkill unblock wifi
            echo -e "${GREEN}✓${NC} WiFi toggled"
            ;;
    esac
}

# Settings menu
settings_menu() {
    echo -e "\n${PURPLE}=== WiFi Manager Settings ===${NC}"
    echo -e "${WHITE}1.${NC} Auto connect: ${AUTO_CONNECT}"
    echo -e "${WHITE}2.${NC} Preferred band: ${PREFERRED_BAND}"
    echo -e "${WHITE}3.${NC} Power management: ${POWER_MANAGEMENT}"
    echo -e "${WHITE}4.${NC} Scan interval: ${SCAN_INTERVAL}s"
    echo -e "${WHITE}5.${NC} Connection timeout: ${CONNECT_TIMEOUT}s"
    echo -e "${WHITE}6.${NC} Background scan: ${BACKGROUND_SCAN}"
    echo -e "${WHITE}7.${NC} Show hidden networks: ${SHOW_HIDDEN_NETWORKS}"
    echo -e "${WHITE}8.${NC} Country code: ${COUNTRY_CODE}"
    echo -e "${WHITE}s.${NC} Save settings"
    echo -e "${WHITE}q.${NC} Back to main menu"
    echo
    
    echo -ne "${YELLOW}Select option:${NC} "
    read -r choice
    
    case "$choice" in
        1)
            echo -ne "${CYAN}Auto connect to known networks (true/false):${NC} "
            read -r AUTO_CONNECT
            ;;
        2)
            echo -ne "${CYAN}Preferred band (auto/2.4GHz/5GHz):${NC} "
            read -r PREFERRED_BAND
            ;;
        3)
            echo -ne "${CYAN}Power management (auto/on/off):${NC} "
            read -r POWER_MANAGEMENT
            ;;
        4)
            echo -ne "${CYAN}Scan interval (seconds):${NC} "
            read -r SCAN_INTERVAL
            ;;
        5)
            echo -ne "${CYAN}Connection timeout (seconds):${NC} "
            read -r CONNECT_TIMEOUT
            ;;
        6)
            echo -ne "${CYAN}Background scanning (true/false):${NC} "
            read -r BACKGROUND_SCAN
            ;;
        7)
            echo -ne "${CYAN}Show hidden networks (true/false):${NC} "
            read -r SHOW_HIDDEN_NETWORKS
            ;;
        8)
            echo -ne "${CYAN}Country code (US/EU/JP/etc):${NC} "
            read -r COUNTRY_CODE
            ;;
        s|S)
            cat > "$WIFI_CONFIG_DIR/settings.conf" << EOF
# BluejayLinux WiFi Manager Settings
AUTO_CONNECT=$AUTO_CONNECT
PREFERRED_BAND=$PREFERRED_BAND
POWER_MANAGEMENT=$POWER_MANAGEMENT
SCAN_INTERVAL=$SCAN_INTERVAL
CONNECT_TIMEOUT=$CONNECT_TIMEOUT
ROAMING_ENABLED=$ROAMING_ENABLED
BACKGROUND_SCAN=$BACKGROUND_SCAN
SHOW_HIDDEN_NETWORKS=$SHOW_HIDDEN_NETWORKS
SIGNAL_STRENGTH_UNITS=$SIGNAL_STRENGTH_UNITS
PREFERRED_SECURITY=$PREFERRED_SECURITY
AUTO_RECONNECT=$AUTO_RECONNECT
CONNECTION_PRIORITY=$CONNECTION_PRIORITY
NOTIFICATION_LEVEL=$NOTIFICATION_LEVEL
COUNTRY_CODE=$COUNTRY_CODE
REGULATORY_DOMAIN=$REGULATORY_DOMAIN
EOF
            echo -e "${GREEN}✓${NC} Settings saved"
            ;;
    esac
}

# Main menu
main_menu() {
    echo -e "${PURPLE}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                   ${WHITE}BluejayLinux WiFi Manager${PURPLE}                      ║${NC}"
    echo -e "${PURPLE}║                ${CYAN}Professional Wireless Networking${PURPLE}                 ║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    local hw_info=($(detect_wifi_hardware))
    local interfaces=($(echo "${hw_info}" | cut -d'|' -f1))
    echo -e "${WHITE}WiFi interfaces:${NC} ${interfaces[*]}"
    echo
    
    echo -e "${WHITE}1.${NC} Show WiFi status"
    echo -e "${WHITE}2.${NC} Scan networks"
    echo -e "${WHITE}3.${NC} Show available networks"
    echo -e "${WHITE}4.${NC} Connect to network"
    echo -e "${WHITE}5.${NC} Disconnect"
    echo -e "${WHITE}6.${NC} Saved networks"
    echo -e "${WHITE}7.${NC} Remove saved network"
    echo -e "${WHITE}8.${NC} RF kill management"
    echo -e "${WHITE}9.${NC} Settings"
    echo -e "${WHITE}q.${NC} Quit"
    echo
}

# Main function
main() {
    create_directories
    load_settings
    
    if [ $# -gt 0 ]; then
        case "$1" in
            --scan|-s)
                scan_networks "${2:-$(get_wifi_interface)}"
                ;;
            --connect|-c)
                connect_wifi "$2" "$3" "$4" "$5"
                ;;
            --disconnect|-d)
                disconnect_wifi "${2:-$(get_wifi_interface)}"
                ;;
            --status)
                show_wifi_status
                ;;
            --list|-l)
                show_available_networks
                ;;
            --saved)
                list_saved_networks
                ;;
            --remove)
                remove_network "$2"
                ;;
            --help|-h)
                echo "BluejayLinux WiFi Manager"
                echo "Usage: $0 [options] [parameters]"
                echo "  --scan, -s [interface]         Scan for networks"
                echo "  --connect, -c <ssid> [pass] [security] [interface]"
                echo "  --disconnect, -d [interface]   Disconnect WiFi"
                echo "  --status                       Show WiFi status"
                echo "  --list, -l                     List available networks"
                echo "  --saved                        List saved networks"
                echo "  --remove <ssid>                Remove saved network"
                ;;
        esac
        return
    fi
    
    # Interactive mode
    while true; do
        main_menu
        echo -ne "${YELLOW}Select option:${NC} "
        read -r choice
        
        case "$choice" in
            1)
                show_wifi_status
                ;;
            2)
                scan_networks
                ;;
            3)
                show_available_networks
                ;;
            4)
                show_available_networks
                echo -ne "\n${CYAN}Enter network SSID:${NC} "
                read -r ssid
                if [ -n "$ssid" ]; then
                    echo -ne "${CYAN}Enter password (leave blank for open networks):${NC} "
                    read -r -s password
                    echo
                    echo -ne "${CYAN}Security type (auto/WPA/WPA2/WEP/Open):${NC} "
                    read -r security
                    security="${security:-auto}"
                    connect_wifi "$ssid" "$password" "$security"
                fi
                ;;
            5)
                disconnect_wifi
                ;;
            6)
                list_saved_networks
                ;;
            7)
                list_saved_networks
                echo -ne "\n${CYAN}Enter SSID to remove:${NC} "
                read -r ssid
                if [ -n "$ssid" ]; then
                    remove_network "$ssid"
                fi
                ;;
            8)
                manage_rfkill
                ;;
            9)
                settings_menu
                ;;
            q|Q)
                echo -e "${GREEN}WiFi Manager configuration saved${NC}"
                break
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                ;;
        esac
        echo
        echo -ne "${GRAY}Press Enter to continue...${NC}"
        read -r
        clear
    done
}

# Run main function
main "$@"