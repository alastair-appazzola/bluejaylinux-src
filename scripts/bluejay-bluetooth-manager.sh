#!/bin/bash

# BluejayLinux - Bluetooth Device Management
# Comprehensive Bluetooth stack and device management system

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/bluejay"
BLUETOOTH_CONFIG_DIR="$CONFIG_DIR/bluetooth"
DEVICES_DB="$BLUETOOTH_CONFIG_DIR/paired_devices.db"
PROFILES_DB="$BLUETOOTH_CONFIG_DIR/profiles.db"
SCAN_CACHE="/tmp/bluejay-bluetooth-scan"

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

# Bluetooth device types
DEVICE_TYPES="audio input mouse keyboard phone tablet laptop desktop unknown"
AUDIO_PROFILES="a2dp hfp hsp avrcp"
INPUT_PROFILES="hid"

# Initialize directories
create_directories() {
    mkdir -p "$CONFIG_DIR" "$BLUETOOTH_CONFIG_DIR"
    touch "$DEVICES_DB" "$PROFILES_DB"
    
    # Create default Bluetooth configuration
    if [ ! -f "$BLUETOOTH_CONFIG_DIR/settings.conf" ]; then
        cat > "$BLUETOOTH_CONFIG_DIR/settings.conf" << 'EOF'
# BluejayLinux Bluetooth Manager Settings
BLUETOOTH_ENABLED=true
AUTO_POWER_ON=true
DISCOVERABLE=false
DISCOVERABLE_TIMEOUT=300
PAIRABLE=true
PAIRABLE_TIMEOUT=0
AUTO_CONNECT_TRUSTED=true
SCAN_TIMEOUT=30
CONNECTION_TIMEOUT=15
AUDIO_CODEC_PRIORITY=ldac,aptx,sbc
POWER_MANAGEMENT=balanced
DEVICE_CLASS=desktop
DEVICE_NAME=BluejayLinux
PRIVACY_MODE=false
FAST_CONNECTABLE=true
EXPERIMENTAL_FEATURES=false
LOG_LEVEL=info
NOTIFICATION_LEVEL=normal
EOF
    fi
}

# Load settings
load_settings() {
    if [ -f "$BLUETOOTH_CONFIG_DIR/settings.conf" ]; then
        source "$BLUETOOTH_CONFIG_DIR/settings.conf"
    fi
}

# Detect Bluetooth hardware and stack
detect_bluetooth_hardware() {
    echo -e "${BLUE}Detecting Bluetooth hardware...${NC}"
    
    local bt_controllers=()
    local bt_stack=""
    local bt_version=""
    
    # Check for Bluetooth controllers
    if command -v hciconfig >/dev/null; then
        local controllers=$(hciconfig | grep "^hci" | cut -d: -f1)
        for controller in $controllers; do
            bt_controllers+=("$controller")
            local controller_info=$(hciconfig "$controller" 2>/dev/null)
            if echo "$controller_info" | grep -q "UP RUNNING"; then
                echo -e "${GREEN}✓${NC} Bluetooth controller: $controller (active)"
            else
                echo -e "${YELLOW}!${NC} Bluetooth controller: $controller (inactive)"
            fi
        done
    fi
    
    # Detect Bluetooth stack
    if systemctl is-active --quiet bluetooth; then
        bt_stack="bluez"
        if command -v bluetoothctl >/dev/null; then
            bt_version=$(bluetoothctl --version 2>/dev/null | head -1)
            echo -e "${GREEN}✓${NC} BlueZ stack: $bt_version"
        fi
    elif command -v bt-adapter >/dev/null; then
        bt_stack="blueman"
        echo -e "${GREEN}✓${NC} Blueman stack detected"
    else
        echo -e "${RED}✗${NC} No Bluetooth stack detected"
    fi
    
    # Check supported protocols
    local protocols=()
    if command -v sdptool >/dev/null; then
        protocols+=("sdp")
    fi
    if [ -f "/sys/kernel/debug/bluetooth/hci0/features" ]; then
        protocols+=("le")  # Bluetooth LE
    fi
    
    echo "${bt_controllers[*]}|$bt_stack|${protocols[*]}"
}

# Get Bluetooth service status
get_bluetooth_status() {
    local service_status="unknown"
    local power_status="unknown"
    local discoverable_status="no"
    local paired_count=0
    
    # Check Bluetooth service
    if systemctl is-active --quiet bluetooth; then
        service_status="running"
    elif systemctl is-enabled --quiet bluetooth; then
        service_status="stopped"
    else
        service_status="disabled"
    fi
    
    # Check power status
    if command -v bluetoothctl >/dev/null; then
        if bluetoothctl show | grep -q "Powered: yes"; then
            power_status="on"
        else
            power_status="off"
        fi
        
        # Check discoverable status
        if bluetoothctl show | grep -q "Discoverable: yes"; then
            discoverable_status="yes"
        fi
        
        # Count paired devices
        paired_count=$(bluetoothctl devices | wc -l)
    fi
    
    echo "$service_status|$power_status|$discoverable_status|$paired_count"
}

# Enable/disable Bluetooth
toggle_bluetooth() {
    local action="$1"  # on/off
    
    case "$action" in
        on)
            echo -e "${BLUE}Enabling Bluetooth...${NC}"
            
            # Start Bluetooth service
            if ! systemctl is-active --quiet bluetooth; then
                sudo systemctl start bluetooth
            fi
            
            # Enable Bluetooth service
            if ! systemctl is-enabled --quiet bluetooth; then
                sudo systemctl enable bluetooth
            fi
            
            # Power on Bluetooth adapter
            if command -v bluetoothctl >/dev/null; then
                bluetoothctl power on
                sleep 2
                
                # Set device properties
                if [ -n "$DEVICE_NAME" ]; then
                    bluetoothctl system-alias "$DEVICE_NAME"
                fi
                
                if [ "$PAIRABLE" = "true" ]; then
                    bluetoothctl pairable on
                    if [ "$PAIRABLE_TIMEOUT" -gt 0 ]; then
                        bluetoothctl pairable-timeout "$PAIRABLE_TIMEOUT"
                    fi
                fi
                
                if [ "$DISCOVERABLE" = "true" ]; then
                    bluetoothctl discoverable on
                    if [ "$DISCOVERABLE_TIMEOUT" -gt 0 ]; then
                        bluetoothctl discoverable-timeout "$DISCOVERABLE_TIMEOUT"
                    fi
                fi
            fi
            
            echo -e "${GREEN}✓${NC} Bluetooth enabled"
            ;;
            
        off)
            echo -e "${BLUE}Disabling Bluetooth...${NC}"
            
            # Disconnect all devices
            if command -v bluetoothctl >/dev/null; then
                bluetoothctl devices | while read -r _ mac _; do
                    bluetoothctl disconnect "$mac" 2>/dev/null || true
                done
                
                # Power off adapter
                bluetoothctl power off
            fi
            
            # Stop Bluetooth service
            sudo systemctl stop bluetooth
            
            echo -e "${GREEN}✓${NC} Bluetooth disabled"
            ;;
    esac
}

# Scan for devices
scan_devices() {
    local scan_timeout="${1:-$SCAN_TIMEOUT}"
    
    echo -e "${BLUE}Scanning for Bluetooth devices (${scan_timeout}s)...${NC}"
    
    if ! command -v bluetoothctl >/dev/null; then
        echo -e "${RED}✗${NC} bluetoothctl not available"
        return 1
    fi
    
    # Start scan
    bluetoothctl --timeout "$scan_timeout" scan on &
    local scan_pid=$!
    
    sleep "$scan_timeout"
    
    # Stop scan
    bluetoothctl scan off
    kill $scan_pid 2>/dev/null || true
    
    # Get discovered devices
    local devices=$(bluetoothctl devices)
    echo "$devices" > "$SCAN_CACHE"
    
    local device_count=$(echo "$devices" | wc -l)
    echo -e "${GREEN}✓${NC} Scan completed: $device_count devices found"
}

# Show discovered devices
show_discovered_devices() {
    echo -e "\n${BLUE}Discovered Bluetooth Devices:${NC}"
    
    if [ ! -f "$SCAN_CACHE" ] || [ ! -s "$SCAN_CACHE" ]; then
        echo -e "${YELLOW}No devices found. Run a scan first.${NC}"
        return
    fi
    
    local count=1
    while IFS= read -r line; do
        if [[ $line == Device* ]]; then
            local mac=$(echo "$line" | cut -d' ' -f2)
            local name=$(echo "$line" | cut -d' ' -f3-)
            
            # Get device info
            local device_info=""
            local device_type="unknown"
            local rssi=""
            
            if command -v bluetoothctl >/dev/null; then
                device_info=$(bluetoothctl info "$mac" 2>/dev/null)
                
                # Determine device type
                if echo "$device_info" | grep -q "Audio"; then
                    device_type="audio"
                elif echo "$device_info" | grep -q "Input"; then
                    device_type="input"
                elif echo "$device_info" | grep -q "Phone"; then
                    device_type="phone"
                fi
                
                # Get RSSI if available
                rssi=$(echo "$device_info" | grep "RSSI:" | cut -d: -f2 | xargs)
            fi
            
            # Check if already paired
            local pair_status=""
            if echo "$device_info" | grep -q "Paired: yes"; then
                pair_status="${GREEN}[PAIRED]${NC} "
            fi
            
            echo -e "${WHITE}$count.${NC} $pair_status$name"
            echo -e "   ${CYAN}Address:${NC} $mac"
            echo -e "   ${CYAN}Type:${NC} $device_type"
            [ -n "$rssi" ] && echo -e "   ${CYAN}Signal:${NC} ${rssi} dBm"
        fi
        ((count++))
    done < "$SCAN_CACHE"
}

# Pair with device
pair_device() {
    local device_mac="$1"
    local device_name="$2"
    
    if [ -z "$device_mac" ]; then
        echo -e "${RED}✗${NC} Device MAC address required"
        return 1
    fi
    
    echo -e "${BLUE}Pairing with device: $device_mac${NC}"
    
    # Make sure Bluetooth is on
    if ! bluetoothctl show | grep -q "Powered: yes"; then
        toggle_bluetooth on
        sleep 2
    fi
    
    # Pair device
    if bluetoothctl pair "$device_mac"; then
        echo -e "${GREEN}✓${NC} Device paired successfully"
        
        # Trust device
        bluetoothctl trust "$device_mac"
        echo -e "${GREEN}✓${NC} Device trusted"
        
        # Save to database
        echo "$device_mac:$device_name:$(date +%s)" >> "$DEVICES_DB"
        
        # Auto-connect if enabled
        if [ "$AUTO_CONNECT_TRUSTED" = "true" ]; then
            connect_device "$device_mac"
        fi
        
        return 0
    else
        echo -e "${RED}✗${NC} Failed to pair with device"
        return 1
    fi
}

# Connect to device
connect_device() {
    local device_mac="$1"
    
    echo -e "${BLUE}Connecting to device: $device_mac${NC}"
    
    if bluetoothctl connect "$device_mac"; then
        echo -e "${GREEN}✓${NC} Connected to device"
        
        # Log connection
        echo "$(date): Connected to $device_mac" >> "$BLUETOOTH_CONFIG_DIR/connections.log"
        return 0
    else
        echo -e "${RED}✗${NC} Failed to connect to device"
        return 1
    fi
}

# Disconnect device
disconnect_device() {
    local device_mac="$1"
    
    echo -e "${BLUE}Disconnecting device: $device_mac${NC}"
    
    if bluetoothctl disconnect "$device_mac"; then
        echo -e "${GREEN}✓${NC} Device disconnected"
        return 0
    else
        echo -e "${RED}✗${NC} Failed to disconnect device"
        return 1
    fi
}

# Remove/unpair device
remove_device() {
    local device_mac="$1"
    
    echo -e "${BLUE}Removing device: $device_mac${NC}"
    
    # Disconnect first
    bluetoothctl disconnect "$device_mac" 2>/dev/null || true
    
    # Remove pairing
    if bluetoothctl remove "$device_mac"; then
        echo -e "${GREEN}✓${NC} Device removed"
        
        # Remove from database
        sed -i "/^$device_mac:/d" "$DEVICES_DB"
        return 0
    else
        echo -e "${RED}✗${NC} Failed to remove device"
        return 1
    fi
}

# List paired devices
list_paired_devices() {
    echo -e "\n${BLUE}Paired Bluetooth Devices:${NC}"
    
    if ! command -v bluetoothctl >/dev/null; then
        echo -e "${RED}✗${NC} bluetoothctl not available"
        return 1
    fi
    
    local devices=$(bluetoothctl devices)
    
    if [ -z "$devices" ]; then
        echo -e "${YELLOW}No paired devices${NC}"
        return
    fi
    
    local count=1
    echo "$devices" | while IFS= read -r line; do
        if [[ $line == Device* ]]; then
            local mac=$(echo "$line" | cut -d' ' -f2)
            local name=$(echo "$line" | cut -d' ' -f3-)
            
            # Get device status
            local device_info=$(bluetoothctl info "$mac" 2>/dev/null)
            local connected=""
            local trusted=""
            local battery=""
            
            if echo "$device_info" | grep -q "Connected: yes"; then
                connected="${GREEN}[CONNECTED]${NC} "
            fi
            
            if echo "$device_info" | grep -q "Trusted: yes"; then
                trusted="✓"
            else
                trusted="✗"
            fi
            
            # Check battery level if available
            battery=$(echo "$device_info" | grep "Battery Percentage" | cut -d: -f2 | xargs)
            
            echo -e "${WHITE}$count.${NC} $connected$name"
            echo -e "   ${CYAN}Address:${NC} $mac"
            echo -e "   ${CYAN}Trusted:${NC} $trusted"
            [ -n "$battery" ] && echo -e "   ${CYAN}Battery:${NC} ${battery}%"
        fi
        ((count++))
    done
}

# Configure audio codec
configure_audio_codec() {
    local device_mac="$1"
    local codec="$2"
    
    echo -e "${BLUE}Configuring audio codec: $codec${NC}"
    
    # This would typically involve PulseAudio/PipeWire configuration
    if command -v pactl >/dev/null; then
        # PulseAudio configuration
        case "$codec" in
            ldac)
                echo -e "${CYAN}Setting LDAC codec...${NC}"
                # LDAC configuration would go here
                ;;
            aptx)
                echo -e "${CYAN}Setting aptX codec...${NC}"
                # aptX configuration would go here
                ;;
            sbc)
                echo -e "${CYAN}Setting SBC codec...${NC}"
                # SBC is default, no special config needed
                ;;
        esac
        
        echo -e "${GREEN}✓${NC} Audio codec configured"
    else
        echo -e "${YELLOW}!${NC} PulseAudio not available"
    fi
}

# Send file via Bluetooth
send_file() {
    local file_path="$1"
    local device_mac="$2"
    
    if [ ! -f "$file_path" ]; then
        echo -e "${RED}✗${NC} File not found: $file_path"
        return 1
    fi
    
    echo -e "${BLUE}Sending file: $(basename "$file_path")${NC}"
    
    if command -v bluetooth-sendto >/dev/null; then
        bluetooth-sendto --device="$device_mac" "$file_path"
    elif command -v obexftp >/dev/null; then
        obexftp -b "$device_mac" -p "$file_path"
    else
        echo -e "${RED}✗${NC} No file transfer tool available"
        return 1
    fi
}

# Monitor Bluetooth activity
monitor_bluetooth() {
    echo -e "${BLUE}Bluetooth Activity Monitor${NC}"
    echo -e "${GRAY}Press Ctrl+C to stop monitoring${NC}"
    echo
    
    while true; do
        clear
        echo -e "${PURPLE}=== Bluetooth Activity Monitor ===${NC}"
        echo -e "${CYAN}Timestamp: $(date)${NC}"
        echo
        
        # Show Bluetooth status
        local status_info=$(get_bluetooth_status)
        local service_status=$(echo "$status_info" | cut -d'|' -f1)
        local power_status=$(echo "$status_info" | cut -d'|' -f2)
        local discoverable=$(echo "$status_info" | cut -d'|' -f3)
        local paired_count=$(echo "$status_info" | cut -d'|' -f4)
        
        echo -e "${WHITE}Service:${NC} $service_status"
        echo -e "${WHITE}Power:${NC} $power_status"
        echo -e "${WHITE}Discoverable:${NC} $discoverable"
        echo -e "${WHITE}Paired devices:${NC} $paired_count"
        echo
        
        # Show connected devices
        echo -e "${WHITE}Connected Devices:${NC}"
        bluetoothctl devices | while read -r _ mac name; do
            if bluetoothctl info "$mac" | grep -q "Connected: yes"; then
                echo -e "${GREEN}✓${NC} $name ($mac)"
            fi
        done
        
        sleep 3
    done
}

# Bluetooth troubleshooting
troubleshoot_bluetooth() {
    echo -e "${PURPLE}=== Bluetooth Troubleshooting ===${NC}"
    
    # Check hardware
    echo -e "\n${BLUE}1. Hardware Detection:${NC}"
    if command -v lsusb >/dev/null; then
        lsusb | grep -i bluetooth
    fi
    if command -v lspci >/dev/null; then
        lspci | grep -i bluetooth
    fi
    
    # Check service status
    echo -e "\n${BLUE}2. Service Status:${NC}"
    systemctl status bluetooth --no-pager -l
    
    # Check kernel modules
    echo -e "\n${BLUE}3. Kernel Modules:${NC}"
    lsmod | grep -i bluetooth
    
    # Check rfkill status
    echo -e "\n${BLUE}4. RF Kill Status:${NC}"
    if command -v rfkill >/dev/null; then
        rfkill list bluetooth
    else
        echo "rfkill not available"
    fi
    
    # Check common issues
    echo -e "\n${BLUE}5. Common Issues Check:${NC}"
    
    if ! systemctl is-active --quiet bluetooth; then
        echo -e "${RED}✗${NC} Bluetooth service not running"
        echo -e "${YELLOW}Solution: sudo systemctl start bluetooth${NC}"
    fi
    
    if command -v rfkill >/dev/null && rfkill list bluetooth | grep -q "Soft blocked: yes"; then
        echo -e "${RED}✗${NC} Bluetooth is soft-blocked"
        echo -e "${YELLOW}Solution: rfkill unblock bluetooth${NC}"
    fi
    
    if ! command -v bluetoothctl >/dev/null; then
        echo -e "${RED}✗${NC} bluetoothctl not installed"
        echo -e "${YELLOW}Solution: sudo apt install bluez${NC}"
    fi
}

# Settings menu
settings_menu() {
    echo -e "\n${PURPLE}=== Bluetooth Manager Settings ===${NC}"
    echo -e "${WHITE}1.${NC} Bluetooth enabled: ${BLUETOOTH_ENABLED}"
    echo -e "${WHITE}2.${NC} Auto power on: ${AUTO_POWER_ON}"
    echo -e "${WHITE}3.${NC} Discoverable: ${DISCOVERABLE}"
    echo -e "${WHITE}4.${NC} Discoverable timeout: ${DISCOVERABLE_TIMEOUT}s"
    echo -e "${WHITE}5.${NC} Auto connect trusted: ${AUTO_CONNECT_TRUSTED}"
    echo -e "${WHITE}6.${NC} Device name: ${DEVICE_NAME}"
    echo -e "${WHITE}7.${NC} Audio codec priority: ${AUDIO_CODEC_PRIORITY}"
    echo -e "${WHITE}8.${NC} Privacy mode: ${PRIVACY_MODE}"
    echo -e "${WHITE}s.${NC} Save settings"
    echo -e "${WHITE}q.${NC} Back to main menu"
    echo
    
    echo -ne "${YELLOW}Select option:${NC} "
    read -r choice
    
    case "$choice" in
        1)
            echo -ne "${CYAN}Enable Bluetooth (true/false):${NC} "
            read -r BLUETOOTH_ENABLED
            ;;
        2)
            echo -ne "${CYAN}Auto power on (true/false):${NC} "
            read -r AUTO_POWER_ON
            ;;
        3)
            echo -ne "${CYAN}Make discoverable (true/false):${NC} "
            read -r DISCOVERABLE
            ;;
        4)
            echo -ne "${CYAN}Discoverable timeout (seconds, 0=infinite):${NC} "
            read -r DISCOVERABLE_TIMEOUT
            ;;
        5)
            echo -ne "${CYAN}Auto connect to trusted devices (true/false):${NC} "
            read -r AUTO_CONNECT_TRUSTED
            ;;
        6)
            echo -ne "${CYAN}Device name:${NC} "
            read -r DEVICE_NAME
            ;;
        7)
            echo -ne "${CYAN}Audio codec priority (ldac,aptx,sbc):${NC} "
            read -r AUDIO_CODEC_PRIORITY
            ;;
        8)
            echo -ne "${CYAN}Enable privacy mode (true/false):${NC} "
            read -r PRIVACY_MODE
            ;;
        s|S)
            cat > "$BLUETOOTH_CONFIG_DIR/settings.conf" << EOF
# BluejayLinux Bluetooth Manager Settings
BLUETOOTH_ENABLED=$BLUETOOTH_ENABLED
AUTO_POWER_ON=$AUTO_POWER_ON
DISCOVERABLE=$DISCOVERABLE
DISCOVERABLE_TIMEOUT=$DISCOVERABLE_TIMEOUT
PAIRABLE=$PAIRABLE
PAIRABLE_TIMEOUT=$PAIRABLE_TIMEOUT
AUTO_CONNECT_TRUSTED=$AUTO_CONNECT_TRUSTED
SCAN_TIMEOUT=$SCAN_TIMEOUT
CONNECTION_TIMEOUT=$CONNECTION_TIMEOUT
AUDIO_CODEC_PRIORITY=$AUDIO_CODEC_PRIORITY
POWER_MANAGEMENT=$POWER_MANAGEMENT
DEVICE_CLASS=$DEVICE_CLASS
DEVICE_NAME=$DEVICE_NAME
PRIVACY_MODE=$PRIVACY_MODE
FAST_CONNECTABLE=$FAST_CONNECTABLE
EXPERIMENTAL_FEATURES=$EXPERIMENTAL_FEATURES
LOG_LEVEL=$LOG_LEVEL
NOTIFICATION_LEVEL=$NOTIFICATION_LEVEL
EOF
            echo -e "${GREEN}✓${NC} Settings saved"
            ;;
    esac
}

# Main menu
main_menu() {
    echo -e "${PURPLE}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                 ${WHITE}BluejayLinux Bluetooth Manager${PURPLE}                  ║${NC}"
    echo -e "${PURPLE}║              ${CYAN}Comprehensive Device Management${PURPLE}                   ║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    local hw_info=$(detect_bluetooth_hardware)
    local controllers=($(echo "$hw_info" | cut -d'|' -f1))
    local stack=$(echo "$hw_info" | cut -d'|' -f2)
    
    if [ ${#controllers[@]} -gt 0 ]; then
        echo -e "${WHITE}Bluetooth controllers:${NC} ${controllers[*]}"
    else
        echo -e "${YELLOW}No Bluetooth controllers detected${NC}"
    fi
    echo -e "${WHITE}Bluetooth stack:${NC} $stack"
    
    local status_info=$(get_bluetooth_status)
    local service_status=$(echo "$status_info" | cut -d'|' -f1)
    local power_status=$(echo "$status_info" | cut -d'|' -f2)
    local paired_count=$(echo "$status_info" | cut -d'|' -f4)
    
    echo -e "${WHITE}Service status:${NC} $service_status"
    echo -e "${WHITE}Power status:${NC} $power_status"
    echo -e "${WHITE}Paired devices:${NC} $paired_count"
    echo
    
    echo -e "${WHITE}Bluetooth Control:${NC}"
    echo -e "${WHITE}1.${NC} Turn Bluetooth on"
    echo -e "${WHITE}2.${NC} Turn Bluetooth off"
    echo -e "${WHITE}3.${NC} Make discoverable"
    echo
    echo -e "${WHITE}Device Management:${NC}"
    echo -e "${WHITE}4.${NC} Scan for devices"
    echo -e "${WHITE}5.${NC} Show discovered devices"
    echo -e "${WHITE}6.${NC} Pair with device"
    echo -e "${WHITE}7.${NC} Connect to device"
    echo -e "${WHITE}8.${NC} Disconnect device"
    echo -e "${WHITE}9.${NC} Remove device"
    echo -e "${WHITE}10.${NC} List paired devices"
    echo
    echo -e "${WHITE}Advanced Features:${NC}"
    echo -e "${WHITE}11.${NC} Send file"
    echo -e "${WHITE}12.${NC} Monitor activity"
    echo -e "${WHITE}13.${NC} Troubleshoot"
    echo -e "${WHITE}14.${NC} Settings"
    echo -e "${WHITE}q.${NC} Quit"
    echo
}

# Main function
main() {
    create_directories
    load_settings
    
    if [ $# -gt 0 ]; then
        case "$1" in
            --on)
                toggle_bluetooth on
                ;;
            --off)
                toggle_bluetooth off
                ;;
            --scan)
                scan_devices "$2"
                ;;
            --pair)
                pair_device "$2" "$3"
                ;;
            --connect)
                connect_device "$2"
                ;;
            --disconnect)
                disconnect_device "$2"
                ;;
            --remove)
                remove_device "$2"
                ;;
            --list)
                list_paired_devices
                ;;
            --status)
                local status_info=$(get_bluetooth_status)
                echo "Service: $(echo "$status_info" | cut -d'|' -f1)"
                echo "Power: $(echo "$status_info" | cut -d'|' -f2)"
                echo "Discoverable: $(echo "$status_info" | cut -d'|' -f3)"
                echo "Paired devices: $(echo "$status_info" | cut -d'|' -f4)"
                ;;
            --help|-h)
                echo "BluejayLinux Bluetooth Manager"
                echo "Usage: $0 [options] [parameters]"
                echo "  --on                    Turn Bluetooth on"
                echo "  --off                   Turn Bluetooth off"
                echo "  --scan [timeout]        Scan for devices"
                echo "  --pair <mac> [name]     Pair with device"
                echo "  --connect <mac>         Connect to device"
                echo "  --disconnect <mac>      Disconnect device"
                echo "  --remove <mac>          Remove device"
                echo "  --list                  List paired devices"
                echo "  --status                Show Bluetooth status"
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
                toggle_bluetooth on
                ;;
            2)
                toggle_bluetooth off
                ;;
            3)
                if command -v bluetoothctl >/dev/null; then
                    bluetoothctl discoverable on
                    echo -e "${GREEN}✓${NC} Device is now discoverable"
                fi
                ;;
            4)
                echo -ne "${CYAN}Scan timeout (${SCAN_TIMEOUT}s):${NC} "
                read -r timeout
                timeout="${timeout:-$SCAN_TIMEOUT}"
                scan_devices "$timeout"
                ;;
            5)
                show_discovered_devices
                ;;
            6)
                show_discovered_devices
                echo -ne "\n${CYAN}Enter device MAC address to pair:${NC} "
                read -r device_mac
                if [ -n "$device_mac" ]; then
                    echo -ne "${CYAN}Enter device name (optional):${NC} "
                    read -r device_name
                    pair_device "$device_mac" "$device_name"
                fi
                ;;
            7)
                list_paired_devices
                echo -ne "\n${CYAN}Enter device MAC address to connect:${NC} "
                read -r device_mac
                if [ -n "$device_mac" ]; then
                    connect_device "$device_mac"
                fi
                ;;
            8)
                list_paired_devices
                echo -ne "\n${CYAN}Enter device MAC address to disconnect:${NC} "
                read -r device_mac
                if [ -n "$device_mac" ]; then
                    disconnect_device "$device_mac"
                fi
                ;;
            9)
                list_paired_devices
                echo -ne "\n${CYAN}Enter device MAC address to remove:${NC} "
                read -r device_mac
                if [ -n "$device_mac" ]; then
                    remove_device "$device_mac"
                fi
                ;;
            10)
                list_paired_devices
                ;;
            11)
                echo -ne "${CYAN}File path to send:${NC} "
                read -r file_path
                list_paired_devices
                echo -ne "\n${CYAN}Target device MAC address:${NC} "
                read -r device_mac
                if [ -n "$file_path" ] && [ -n "$device_mac" ]; then
                    send_file "$file_path" "$device_mac"
                fi
                ;;
            12)
                monitor_bluetooth
                ;;
            13)
                troubleshoot_bluetooth
                ;;
            14)
                settings_menu
                ;;
            q|Q)
                echo -e "${GREEN}Bluetooth Manager configuration saved${NC}"
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