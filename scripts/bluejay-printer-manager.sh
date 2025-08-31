#!/bin/bash

# BluejayLinux - Printer Detection & Management System
# Professional printing system with automatic driver installation

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/bluejay"
PRINTER_CONFIG_DIR="$CONFIG_DIR/printing"
PRINTERS_DB="$PRINTER_CONFIG_DIR/printers.db"
QUEUE_DIR="$PRINTER_CONFIG_DIR/print_queue"
DRIVERS_DIR="$PRINTER_CONFIG_DIR/drivers"

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

# Printer connection types
CONNECTION_TYPES="usb network parallel bluetooth wifi"
PRINTER_PROTOCOLS="ipp lpd socket jetdirect"

# Initialize directories
create_directories() {
    mkdir -p "$CONFIG_DIR" "$PRINTER_CONFIG_DIR" "$QUEUE_DIR" "$DRIVERS_DIR"
    
    # Create default printer configuration
    if [ ! -f "$PRINTER_CONFIG_DIR/settings.conf" ]; then
        cat > "$PRINTER_CONFIG_DIR/settings.conf" << 'EOF'
# BluejayLinux Printer Manager Settings
AUTO_DETECT_PRINTERS=true
AUTO_INSTALL_DRIVERS=true
DEFAULT_PAPER_SIZE=letter
DEFAULT_QUALITY=normal
DUPLEX_ENABLED=true
COLOR_MANAGEMENT=auto
NETWORK_DISCOVERY=true
SHARED_PRINTING=false
PRINT_SPOOLING=true
JOB_HISTORY=true
DRIVER_UPDATE_CHECK=true
NOTIFICATION_LEVEL=normal
DEFAULT_CUPS_SERVER=localhost:631
IPP_EVERYWHERE=true
DRIVERLESS_PRINTING=true
AUTOMATIC_MAINTENANCE=true
INK_LEVEL_MONITORING=true
EOF
    fi
    
    touch "$PRINTERS_DB"
}

# Load settings
load_settings() {
    if [ -f "$PRINTER_CONFIG_DIR/settings.conf" ]; then
        source "$PRINTER_CONFIG_DIR/settings.conf"
    fi
}

# Detect printing system
detect_printing_system() {
    echo -e "${BLUE}Detecting printing system...${NC}"
    
    local print_systems=()
    
    # CUPS (Common Unix Printing System)
    if command -v cupsd >/dev/null; then
        print_systems+=("cups")
        local cups_version=$(cups-config --version 2>/dev/null)
        echo -e "${GREEN}✓${NC} CUPS: ${cups_version:-unknown version}"
        
        if systemctl is-active --quiet cups; then
            echo -e "${GREEN}✓${NC} CUPS service running"
        else
            echo -e "${YELLOW}!${NC} CUPS service not running"
        fi
    fi
    
    # LPD (Line Printer Daemon)
    if command -v lpd >/dev/null; then
        print_systems+=("lpd")
        echo -e "${GREEN}✓${NC} LPD available"
    fi
    
    # System V printing
    if command -v lp >/dev/null; then
        print_systems+=("sysv")
        echo -e "${GREEN}✓${NC} System V printing tools"
    fi
    
    echo "${print_systems[@]}"
}

# Start printing services
start_printing_services() {
    echo -e "${BLUE}Starting printing services...${NC}"
    
    # Start CUPS
    if command -v cupsd >/dev/null; then
        if ! systemctl is-active --quiet cups; then
            sudo systemctl start cups
            echo -e "${GREEN}✓${NC} CUPS service started"
        fi
        
        if ! systemctl is-enabled --quiet cups; then
            sudo systemctl enable cups
            echo -e "${GREEN}✓${NC} CUPS service enabled"
        fi
    fi
    
    # Start Avahi for network printer discovery
    if command -v avahi-daemon >/dev/null; then
        if ! systemctl is-active --quiet avahi-daemon; then
            sudo systemctl start avahi-daemon
            echo -e "${GREEN}✓${NC} Avahi service started for network discovery"
        fi
    fi
}

# Detect connected printers
detect_printers() {
    echo -e "${BLUE}Detecting connected printers...${NC}"
    
    local detected_printers=()
    
    # USB printers
    echo -e "${CYAN}Scanning USB printers...${NC}"
    if command -v lsusb >/dev/null; then
        local usb_printers=$(lsusb | grep -i "printer\|canon\|hp\|epson\|brother\|lexmark")
        if [ -n "$usb_printers" ]; then
            echo "$usb_printers" | while read -r line; do
                echo -e "${GREEN}✓${NC} USB: $line"
                detected_printers+=("usb:$line")
            done
        fi
    fi
    
    # Network printers via CUPS
    echo -e "${CYAN}Scanning network printers...${NC}"
    if command -v lpinfo >/dev/null; then
        local network_printers=$(lpinfo -v | grep -E "network\|socket\|ipp\|lpd")
        if [ -n "$network_printers" ]; then
            echo "$network_printers" | while read -r line; do
                echo -e "${GREEN}✓${NC} Network: $line"
                detected_printers+=("network:$line")
            done
        fi
    fi
    
    # Bluetooth printers
    if command -v bluetoothctl >/dev/null && bluetoothctl show | grep -q "Powered: yes"; then
        echo -e "${CYAN}Scanning Bluetooth printers...${NC}"
        local bt_printers=$(bluetoothctl devices | grep -i "printer")
        if [ -n "$bt_printers" ]; then
            echo "$bt_printers" | while read -r line; do
                echo -e "${GREEN}✓${NC} Bluetooth: $line"
                detected_printers+=("bluetooth:$line")
            done
        fi
    fi
    
    # IPP Everywhere / Driverless printers
    if command -v ippfind >/dev/null; then
        echo -e "${CYAN}Scanning IPP printers...${NC}"
        local ipp_printers=$(ippfind -T 5 2>/dev/null)
        if [ -n "$ipp_printers" ]; then
            echo "$ipp_printers" | while read -r line; do
                echo -e "${GREEN}✓${NC} IPP: $line"
                detected_printers+=("ipp:$line")
            done
        fi
    fi
    
    echo "${detected_printers[@]}"
}

# Add printer automatically
add_printer_auto() {
    local printer_info="$1"
    local connection_type=$(echo "$printer_info" | cut -d: -f1)
    local printer_details=$(echo "$printer_info" | cut -d: -f2-)
    
    echo -e "${BLUE}Adding printer automatically...${NC}"
    
    case "$connection_type" in
        usb)
            add_usb_printer "$printer_details"
            ;;
        network)
            add_network_printer "$printer_details"
            ;;
        ipp)
            add_ipp_printer "$printer_details"
            ;;
        bluetooth)
            add_bluetooth_printer "$printer_details"
            ;;
    esac
}

# Add USB printer
add_usb_printer() {
    local printer_details="$1"
    
    # Extract manufacturer and model from lsusb output
    local manufacturer=$(echo "$printer_details" | grep -o -E "(HP|Canon|Epson|Brother|Lexmark)" | head -1)
    local model=$(echo "$printer_details" | sed 's/.*ID [0-9a-f]*:[0-9a-f]* //' | cut -d' ' -f1-3)
    
    if [ -z "$manufacturer" ]; then
        manufacturer="Generic"
    fi
    
    local printer_name="${manufacturer}_${model// /_}"
    
    echo -e "${CYAN}Adding USB printer: $printer_name${NC}"
    
    # Try to add printer with CUPS
    if command -v lpadmin >/dev/null; then
        # Find USB device URI
        local device_uri=$(lpinfo -v | grep usb | head -1 | cut -d' ' -f2)
        
        if [ -n "$device_uri" ]; then
            # Install driver if needed
            install_printer_driver "$manufacturer" "$model"
            
            # Add printer
            sudo lpadmin -p "$printer_name" -v "$device_uri" -E
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓${NC} USB printer added: $printer_name"
                
                # Save to database
                echo "$printer_name:usb:$device_uri:$manufacturer:$model:$(date +%s)" >> "$PRINTERS_DB"
                return 0
            fi
        fi
    fi
    
    echo -e "${RED}✗${NC} Failed to add USB printer"
    return 1
}

# Add network printer
add_network_printer() {
    local printer_uri="$1"
    local printer_name="NetworkPrinter_$(date +%s)"
    
    echo -e "${CYAN}Adding network printer: $printer_uri${NC}"
    
    if command -v lpadmin >/dev/null; then
        # Try to determine printer make/model
        local make_model=""
        if command -v ippfind >/dev/null; then
            local ip=$(echo "$printer_uri" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+')
            if [ -n "$ip" ]; then
                make_model=$(ippget -d ipp://$ip/ipp/print printer-make-and-model 2>/dev/null)
            fi
        fi
        
        # Add printer
        sudo lpadmin -p "$printer_name" -v "$printer_uri" -E
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓${NC} Network printer added: $printer_name"
            
            # Save to database
            echo "$printer_name:network:$printer_uri::$make_model:$(date +%s)" >> "$PRINTERS_DB"
            return 0
        fi
    fi
    
    echo -e "${RED}✗${NC} Failed to add network printer"
    return 1
}

# Add IPP printer (driverless)
add_ipp_printer() {
    local ipp_uri="$1"
    local printer_name="IPP_$(basename "$ipp_uri")"
    
    echo -e "${CYAN}Adding IPP printer: $ipp_uri${NC}"
    
    if command -v lpadmin >/dev/null; then
        # Use IPP Everywhere driver
        sudo lpadmin -p "$printer_name" -v "$ipp_uri" -m everywhere -E
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓${NC} IPP printer added: $printer_name"
            echo "$printer_name:ipp:$ipp_uri:IPP:Everywhere:$(date +%s)" >> "$PRINTERS_DB"
            return 0
        fi
    fi
    
    echo -e "${RED}✗${NC} Failed to add IPP printer"
    return 1
}

# Install printer driver
install_printer_driver() {
    local manufacturer="$1"
    local model="$2"
    
    echo -e "${BLUE}Installing driver for $manufacturer $model...${NC}"
    
    case "${manufacturer,,}" in
        hp)
            # HP drivers
            if ! dpkg -l | grep -q hplip; then
                sudo apt update
                sudo apt install -y hplip hplip-gui
                echo -e "${GREEN}✓${NC} HPLIP drivers installed"
            fi
            ;;
        canon)
            # Canon drivers
            if ! dpkg -l | grep -q cups-backend-bjnp; then
                sudo apt update
                sudo apt install -y cups-backend-bjnp
                echo -e "${GREEN}✓${NC} Canon drivers installed"
            fi
            ;;
        epson)
            # Epson drivers
            if ! dpkg -l | grep -q printer-driver-escpr; then
                sudo apt update
                sudo apt install -y printer-driver-escpr printer-driver-epson
                echo -e "${GREEN}✓${NC} Epson drivers installed"
            fi
            ;;
        brother)
            # Brother drivers
            if ! dpkg -l | grep -q printer-driver-brlaser; then
                sudo apt update
                sudo apt install -y printer-driver-brlaser
                echo -e "${GREEN}✓${NC} Brother drivers installed"
            fi
            ;;
        *)
            # Generic PostScript/PCL drivers
            if ! dpkg -l | grep -q printer-driver-postscript-hp; then
                sudo apt update
                sudo apt install -y printer-driver-postscript-hp printer-driver-pxljr
                echo -e "${GREEN}✓${NC} Generic drivers installed"
            fi
            ;;
    esac
}

# List installed printers
list_printers() {
    echo -e "\n${BLUE}Installed Printers:${NC}"
    
    if command -v lpstat >/dev/null; then
        local printer_list=$(lpstat -p 2>/dev/null)
        
        if [ -z "$printer_list" ]; then
            echo -e "${YELLOW}No printers installed${NC}"
            return
        fi
        
        echo "$printer_list" | while read -r line; do
            if [[ $line == printer* ]]; then
                local printer_name=$(echo "$line" | cut -d' ' -f2)
                local status=$(echo "$line" | cut -d' ' -f3-)
                
                # Get more details
                local printer_info=""
                if [ -f "$PRINTERS_DB" ] && grep -q "^$printer_name:" "$PRINTERS_DB"; then
                    printer_info=$(grep "^$printer_name:" "$PRINTERS_DB" | head -1)
                    local connection=$(echo "$printer_info" | cut -d: -f2)
                    local manufacturer=$(echo "$printer_info" | cut -d: -f4)
                    local model=$(echo "$printer_info" | cut -d: -f5)
                    
                    echo -e "${WHITE}$printer_name${NC}"
                    echo -e "   ${CYAN}Status:${NC} $status"
                    echo -e "   ${CYAN}Connection:${NC} $connection"
                    [ -n "$manufacturer" ] && echo -e "   ${CYAN}Make/Model:${NC} $manufacturer $model"
                else
                    echo -e "${WHITE}$printer_name${NC} - $status"
                fi
            fi
        done
    else
        echo -e "${RED}✗${NC} CUPS tools not available"
    fi
}

# Print test page
print_test_page() {
    local printer_name="$1"
    
    if [ -z "$printer_name" ]; then
        echo -e "${RED}✗${NC} Printer name required"
        return 1
    fi
    
    echo -e "${BLUE}Printing test page to: $printer_name${NC}"
    
    if command -v lp >/dev/null; then
        # Create test page content
        local test_file="/tmp/bluejay_test_page.txt"
        cat > "$test_file" << EOF
BluejayLinux Printer Test Page
==============================

Date: $(date)
Printer: $printer_name
System: $(uname -n)

Text Quality Test:
ABCDEFGHIJKLMNOPQRSTUVWXYZ
abcdefghijklmnopqrstuvwxyz
0123456789 !@#$%^&*()

This test page verifies that your printer is working correctly.

Print Quality Indicators:
• Text should be crisp and clear
• Lines should be straight
• No streaking or fading
• Proper margins

If this page prints correctly, your printer is configured properly.
EOF
        
        # Print test page
        if lp -d "$printer_name" "$test_file"; then
            echo -e "${GREEN}✓${NC} Test page sent to printer"
            rm -f "$test_file"
            return 0
        else
            echo -e "${RED}✗${NC} Failed to print test page"
            rm -f "$test_file"
            return 1
        fi
    else
        echo -e "${RED}✗${NC} Print command not available"
        return 1
    fi
}

# Set default printer
set_default_printer() {
    local printer_name="$1"
    
    if [ -z "$printer_name" ]; then
        echo -e "${RED}✗${NC} Printer name required"
        return 1
    fi
    
    echo -e "${BLUE}Setting default printer: $printer_name${NC}"
    
    if command -v lpoptions >/dev/null; then
        lpoptions -d "$printer_name"
        echo -e "${GREEN}✓${NC} Default printer set to: $printer_name"
        return 0
    else
        echo -e "${RED}✗${NC} lpoptions command not available"
        return 1
    fi
}

# Remove printer
remove_printer() {
    local printer_name="$1"
    
    if [ -z "$printer_name" ]; then
        echo -e "${RED}✗${NC} Printer name required"
        return 1
    fi
    
    echo -e "${BLUE}Removing printer: $printer_name${NC}"
    
    if command -v lpadmin >/dev/null; then
        sudo lpadmin -x "$printer_name"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓${NC} Printer removed: $printer_name"
            
            # Remove from database
            sed -i "/^$printer_name:/d" "$PRINTERS_DB"
            return 0
        else
            echo -e "${RED}✗${NC} Failed to remove printer"
            return 1
        fi
    else
        echo -e "${RED}✗${NC} lpadmin command not available"
        return 1
    fi
}

# Show print queue
show_print_queue() {
    local printer_name="$1"
    
    echo -e "\n${BLUE}Print Queue${NC}"
    if [ -n "$printer_name" ]; then
        echo -e "${CYAN}Printer: $printer_name${NC}"
    fi
    
    if command -v lpq >/dev/null; then
        local queue_output
        if [ -n "$printer_name" ]; then
            queue_output=$(lpq -P "$printer_name" 2>/dev/null)
        else
            queue_output=$(lpq 2>/dev/null)
        fi
        
        if [ -n "$queue_output" ] && [ "$queue_output" != "no entries" ]; then
            echo "$queue_output"
        else
            echo -e "${YELLOW}No print jobs in queue${NC}"
        fi
    else
        echo -e "${RED}✗${NC} lpq command not available"
    fi
}

# Cancel print job
cancel_print_job() {
    local job_id="$1"
    local printer_name="$2"
    
    if [ -z "$job_id" ]; then
        echo -e "${RED}✗${NC} Job ID required"
        return 1
    fi
    
    echo -e "${BLUE}Canceling print job: $job_id${NC}"
    
    if command -v cancel >/dev/null; then
        if [ -n "$printer_name" ]; then
            cancel "$job_id" -P "$printer_name"
        else
            cancel "$job_id"
        fi
        
        echo -e "${GREEN}✓${NC} Print job canceled"
    else
        echo -e "${RED}✗${NC} cancel command not available"
    fi
}

# Check ink levels
check_ink_levels() {
    local printer_name="$1"
    
    echo -e "${BLUE}Checking ink levels...${NC}"
    
    # HP printers
    if command -v hp-levels >/dev/null; then
        local hp_levels=$(hp-levels 2>/dev/null)
        if [ -n "$hp_levels" ]; then
            echo -e "${CYAN}HP Printer Ink Levels:${NC}"
            echo "$hp_levels"
            return 0
        fi
    fi
    
    # Generic ink level checking
    if command -v escputil >/dev/null && [ -n "$printer_name" ]; then
        local ink_info=$(escputil -i -P "$printer_name" 2>/dev/null)
        if [ -n "$ink_info" ]; then
            echo -e "${CYAN}Ink Levels:${NC}"
            echo "$ink_info"
            return 0
        fi
    fi
    
    echo -e "${YELLOW}!${NC} Ink level information not available for this printer"
}

# Printer maintenance
printer_maintenance() {
    local printer_name="$1"
    local action="$2"
    
    echo -e "${BLUE}Printer maintenance: $action${NC}"
    
    case "$action" in
        clean)
            if command -v escputil >/dev/null; then
                escputil -c -P "$printer_name" 2>/dev/null && \
                echo -e "${GREEN}✓${NC} Print head cleaning started" || \
                echo -e "${YELLOW}!${NC} Cleaning not supported or failed"
            fi
            ;;
        align)
            if command -v escputil >/dev/null; then
                escputil -a -P "$printer_name" 2>/dev/null && \
                echo -e "${GREEN}✓${NC} Print head alignment started" || \
                echo -e "${YELLOW}!${NC} Alignment not supported or failed"
            fi
            ;;
        nozzle_check)
            if command -v escputil >/dev/null; then
                escputil -n -P "$printer_name" 2>/dev/null && \
                echo -e "${GREEN}✓${NC} Nozzle check pattern printed" || \
                echo -e "${YELLOW}!${NC} Nozzle check not supported or failed"
            fi
            ;;
    esac
}

# Settings menu
settings_menu() {
    echo -e "\n${PURPLE}=== Printer Manager Settings ===${NC}"
    echo -e "${WHITE}1.${NC} Auto-detect printers: ${AUTO_DETECT_PRINTERS}"
    echo -e "${WHITE}2.${NC} Auto-install drivers: ${AUTO_INSTALL_DRIVERS}"
    echo -e "${WHITE}3.${NC} Default paper size: ${DEFAULT_PAPER_SIZE}"
    echo -e "${WHITE}4.${NC} Default quality: ${DEFAULT_QUALITY}"
    echo -e "${WHITE}5.${NC} Network discovery: ${NETWORK_DISCOVERY}"
    echo -e "${WHITE}6.${NC} Shared printing: ${SHARED_PRINTING}"
    echo -e "${WHITE}7.${NC} IPP Everywhere: ${IPP_EVERYWHERE}"
    echo -e "${WHITE}8.${NC} Driverless printing: ${DRIVERLESS_PRINTING}"
    echo -e "${WHITE}s.${NC} Save settings"
    echo -e "${WHITE}q.${NC} Back to main menu"
    echo
    
    echo -ne "${YELLOW}Select option:${NC} "
    read -r choice
    
    case "$choice" in
        1)
            echo -ne "${CYAN}Auto-detect printers (true/false):${NC} "
            read -r AUTO_DETECT_PRINTERS
            ;;
        2)
            echo -ne "${CYAN}Auto-install drivers (true/false):${NC} "
            read -r AUTO_INSTALL_DRIVERS
            ;;
        3)
            echo -ne "${CYAN}Default paper size (letter/a4/legal):${NC} "
            read -r DEFAULT_PAPER_SIZE
            ;;
        4)
            echo -ne "${CYAN}Default quality (draft/normal/high):${NC} "
            read -r DEFAULT_QUALITY
            ;;
        5)
            echo -ne "${CYAN}Network discovery (true/false):${NC} "
            read -r NETWORK_DISCOVERY
            ;;
        6)
            echo -ne "${CYAN}Enable shared printing (true/false):${NC} "
            read -r SHARED_PRINTING
            ;;
        7)
            echo -ne "${CYAN}IPP Everywhere support (true/false):${NC} "
            read -r IPP_EVERYWHERE
            ;;
        8)
            echo -ne "${CYAN}Driverless printing (true/false):${NC} "
            read -r DRIVERLESS_PRINTING
            ;;
        s|S)
            cat > "$PRINTER_CONFIG_DIR/settings.conf" << EOF
# BluejayLinux Printer Manager Settings
AUTO_DETECT_PRINTERS=$AUTO_DETECT_PRINTERS
AUTO_INSTALL_DRIVERS=$AUTO_INSTALL_DRIVERS
DEFAULT_PAPER_SIZE=$DEFAULT_PAPER_SIZE
DEFAULT_QUALITY=$DEFAULT_QUALITY
DUPLEX_ENABLED=$DUPLEX_ENABLED
COLOR_MANAGEMENT=$COLOR_MANAGEMENT
NETWORK_DISCOVERY=$NETWORK_DISCOVERY
SHARED_PRINTING=$SHARED_PRINTING
PRINT_SPOOLING=$PRINT_SPOOLING
JOB_HISTORY=$JOB_HISTORY
DRIVER_UPDATE_CHECK=$DRIVER_UPDATE_CHECK
NOTIFICATION_LEVEL=$NOTIFICATION_LEVEL
DEFAULT_CUPS_SERVER=$DEFAULT_CUPS_SERVER
IPP_EVERYWHERE=$IPP_EVERYWHERE
DRIVERLESS_PRINTING=$DRIVERLESS_PRINTING
AUTOMATIC_MAINTENANCE=$AUTOMATIC_MAINTENANCE
INK_LEVEL_MONITORING=$INK_LEVEL_MONITORING
EOF
            echo -e "${GREEN}✓${NC} Settings saved"
            ;;
    esac
}

# Main menu
main_menu() {
    echo -e "${PURPLE}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                 ${WHITE}BluejayLinux Printer Manager${PURPLE}                   ║${NC}"
    echo -e "${PURPLE}║              ${CYAN}Professional Printing System${PURPLE}                     ║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    local print_systems=($(detect_printing_system))
    echo -e "${WHITE}Print systems:${NC} ${print_systems[*]}"
    
    # Check if CUPS is running
    if systemctl is-active --quiet cups; then
        echo -e "${WHITE}CUPS status:${NC} ${GREEN}Running${NC}"
    else
        echo -e "${WHITE}CUPS status:${NC} ${RED}Stopped${NC}"
    fi
    echo
    
    echo -e "${WHITE}Printer Management:${NC}"
    echo -e "${WHITE}1.${NC} Start printing services"
    echo -e "${WHITE}2.${NC} Detect printers"
    echo -e "${WHITE}3.${NC} Add printer manually"
    echo -e "${WHITE}4.${NC} List printers"
    echo -e "${WHITE}5.${NC} Remove printer"
    echo -e "${WHITE}6.${NC} Set default printer"
    echo
    echo -e "${WHITE}Printing Operations:${NC}"
    echo -e "${WHITE}7.${NC} Print test page"
    echo -e "${WHITE}8.${NC} Show print queue"
    echo -e "${WHITE}9.${NC} Cancel print job"
    echo
    echo -e "${WHITE}Maintenance:${NC}"
    echo -e "${WHITE}10.${NC} Check ink levels"
    echo -e "${WHITE}11.${NC} Printer maintenance"
    echo -e "${WHITE}12.${NC} Settings"
    echo -e "${WHITE}q.${NC} Quit"
    echo
}

# Main function
main() {
    create_directories
    load_settings
    
    if [ $# -gt 0 ]; then
        case "$1" in
            --detect)
                detect_printers
                ;;
            --add)
                add_printer_auto "$2"
                ;;
            --list)
                list_printers
                ;;
            --test)
                print_test_page "$2"
                ;;
            --remove)
                remove_printer "$2"
                ;;
            --queue)
                show_print_queue "$2"
                ;;
            --start)
                start_printing_services
                ;;
            --help|-h)
                echo "BluejayLinux Printer Manager"
                echo "Usage: $0 [options] [parameters]"
                echo "  --detect                Detect connected printers"
                echo "  --add <printer_info>    Add printer"
                echo "  --list                  List installed printers"
                echo "  --test <printer>        Print test page"
                echo "  --remove <printer>      Remove printer"
                echo "  --queue [printer]       Show print queue"
                echo "  --start                 Start printing services"
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
                start_printing_services
                ;;
            2)
                local printers=($(detect_printers))
                echo -e "\n${GREEN}✓${NC} Found ${#printers[@]} printer(s)"
                
                if [ ${#printers[@]} -gt 0 ] && [ "$AUTO_DETECT_PRINTERS" = "true" ]; then
                    echo -e "${BLUE}Auto-adding detected printers...${NC}"
                    for printer in "${printers[@]}"; do
                        add_printer_auto "$printer"
                    done
                fi
                ;;
            3)
                echo -e "${CYAN}Manual printer addition:${NC}"
                echo -e "${WHITE}1.${NC} USB printer"
                echo -e "${WHITE}2.${NC} Network printer"
                echo -e "${WHITE}3.${NC} IPP printer"
                echo -ne "${YELLOW}Select type:${NC} "
                read -r printer_type
                
                case "$printer_type" in
                    1)
                        echo -ne "${CYAN}USB printer details:${NC} "
                        read -r usb_details
                        add_usb_printer "$usb_details"
                        ;;
                    2)
                        echo -ne "${CYAN}Network printer URI:${NC} "
                        read -r network_uri
                        add_network_printer "$network_uri"
                        ;;
                    3)
                        echo -ne "${CYAN}IPP printer URI:${NC} "
                        read -r ipp_uri
                        add_ipp_printer "$ipp_uri"
                        ;;
                esac
                ;;
            4)
                list_printers
                ;;
            5)
                list_printers
                echo -ne "\n${CYAN}Enter printer name to remove:${NC} "
                read -r printer_name
                if [ -n "$printer_name" ]; then
                    remove_printer "$printer_name"
                fi
                ;;
            6)
                list_printers
                echo -ne "\n${CYAN}Enter printer name to set as default:${NC} "
                read -r printer_name
                if [ -n "$printer_name" ]; then
                    set_default_printer "$printer_name"
                fi
                ;;
            7)
                list_printers
                echo -ne "\n${CYAN}Enter printer name for test page:${NC} "
                read -r printer_name
                if [ -n "$printer_name" ]; then
                    print_test_page "$printer_name"
                fi
                ;;
            8)
                echo -ne "${CYAN}Enter printer name (or press Enter for all):${NC} "
                read -r printer_name
                show_print_queue "$printer_name"
                ;;
            9)
                show_print_queue
                echo -ne "\n${CYAN}Enter job ID to cancel:${NC} "
                read -r job_id
                if [ -n "$job_id" ]; then
                    cancel_print_job "$job_id"
                fi
                ;;
            10)
                list_printers
                echo -ne "\n${CYAN}Enter printer name:${NC} "
                read -r printer_name
                if [ -n "$printer_name" ]; then
                    check_ink_levels "$printer_name"
                fi
                ;;
            11)
                list_printers
                echo -ne "\n${CYAN}Enter printer name:${NC} "
                read -r printer_name
                echo -ne "${CYAN}Maintenance action (clean/align/nozzle_check):${NC} "
                read -r action
                if [ -n "$printer_name" ] && [ -n "$action" ]; then
                    printer_maintenance "$printer_name" "$action"
                fi
                ;;
            12)
                settings_menu
                ;;
            q|Q)
                echo -e "${GREEN}Printer Manager configuration saved${NC}"
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