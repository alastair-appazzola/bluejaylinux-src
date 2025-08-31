#!/bin/bash
# BluejayLinux Advanced Settings - Performance, Security, and System Management
# Part 2 of comprehensive settings implementation

set -e

SETTINGS_CONFIG="/etc/bluejay/settings"

# 5. Performance and Resource Controls
init_performance_settings() {
    cat > "$SETTINGS_CONFIG/performance/config.conf" << 'EOF'
# Performance Configuration
CPU_GOVERNOR=ondemand
SWAPPINESS=10
DIRTY_RATIO=15
MEMORY_OVERCOMMIT=1
CPU_CORES_ENABLED=all
PROCESS_LIMIT=4096
MEMORY_LIMIT=80%
I/O_SCHEDULER=mq-deadline
EOF

    cat > /opt/bluejay/bin/bluejay-performance-settings << 'EOF'
#!/bin/bash
# Performance Settings Interface

SETTINGS_CONFIG="/etc/bluejay/settings/performance"
source "$SETTINGS_CONFIG/config.conf"

show_performance_menu() {
    clear
    echo -e "${CYAN}BluejayLinux Performance Settings${NC}"
    echo "================================="
    echo ""
    echo "Current Performance Status:"
    echo "CPU Governor: $CPU_GOVERNOR"
    echo "Swappiness: $SWAPPINESS"
    echo "Memory Usage: $(free -h | grep Mem | awk '{print $3 "/" $2}')"
    echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
    echo ""
    echo -e "${YELLOW}Performance Options:${NC}"
    echo "[1] CPU Governor Settings"
    echo "[2] Memory Management"
    echo "[3] Process Limits"
    echo "[4] I/O Performance"
    echo "[5] System Resource Monitor"
    echo "[6] Performance Profiles"
    echo "[0] Back to main menu"
    echo ""
    echo -n "Select option: "
}

configure_cpu_governor() {
    echo -e "${BLUE}CPU Governor Configuration${NC}"
    echo "Current governor: $CPU_GOVERNOR"
    echo ""
    echo "Available governors:"
    echo "[1] performance - Maximum performance"
    echo "[2] powersave - Power saving mode"
    echo "[3] ondemand - Dynamic frequency scaling"
    echo "[4] conservative - Gradual frequency changes"
    echo -n "Select governor: "
    read gov_choice
    
    local new_governor
    case $gov_choice in
        1) new_governor="performance" ;;
        2) new_governor="powersave" ;;
        3) new_governor="ondemand" ;;
        4) new_governor="conservative" ;;
        *) echo "Invalid choice"; return ;;
    esac
    
    # Apply CPU governor
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        if [ -w "$cpu" ]; then
            echo "$new_governor" > "$cpu" 2>/dev/null || true
        fi
    done
    
    # Update configuration
    sed -i "s/CPU_GOVERNOR=.*/CPU_GOVERNOR=$new_governor/" "$SETTINGS_CONFIG/config.conf"
    echo -e "${GREEN}CPU governor set to $new_governor${NC}"
    read -p "Press Enter to continue..."
}

configure_memory() {
    echo -e "${BLUE}Memory Management${NC}"
    echo "Current swappiness: $SWAPPINESS"
    echo -n "Enter new swappiness (0-100): "
    read swappiness
    
    if [ "$swappiness" -ge 0 ] && [ "$swappiness" -le 100 ]; then
        echo "$swappiness" > /proc/sys/vm/swappiness 2>/dev/null || true
        sed -i "s/SWAPPINESS=.*/SWAPPINESS=$swappiness/" "$SETTINGS_CONFIG/config.conf"
        echo -e "${GREEN}Swappiness set to $swappiness${NC}"
    else
        echo -e "${RED}Invalid swappiness value${NC}"
    fi
    
    echo ""
    echo "Current dirty ratio: $DIRTY_RATIO"
    echo -n "Enter new dirty ratio (1-100): "
    read dirty_ratio
    
    if [ "$dirty_ratio" -ge 1 ] && [ "$dirty_ratio" -le 100 ]; then
        echo "$dirty_ratio" > /proc/sys/vm/dirty_ratio 2>/dev/null || true
        sed -i "s/DIRTY_RATIO=.*/DIRTY_RATIO=$dirty_ratio/" "$SETTINGS_CONFIG/config.conf"
        echo -e "${GREEN}Dirty ratio set to $dirty_ratio${NC}"
    fi
    
    read -p "Press Enter to continue..."
}

show_resource_monitor() {
    echo -e "${BLUE}System Resource Monitor${NC}"
    echo "======================="
    echo ""
    echo "CPU Usage:"
    top -bn1 | head -5 | tail -2
    echo ""
    echo "Memory Usage:"
    free -h
    echo ""
    echo "Disk Usage:"
    df -h | head -5
    echo ""
    echo "Top Processes by CPU:"
    ps aux --sort=-%cpu | head -6
    echo ""
    echo "Top Processes by Memory:"
    ps aux --sort=-%mem | head -6
    echo ""
    read -p "Press Enter to continue..."
}

while true; do
    source "$SETTINGS_CONFIG/config.conf"
    show_performance_menu
    read choice
    case $choice in
        1) configure_cpu_governor ;;
        2) configure_memory ;;
        3) echo "Process limits configuration not yet implemented" ;;
        4) echo "I/O performance settings not yet implemented" ;;
        5) show_resource_monitor ;;
        6) echo "Performance profiles not yet implemented" ;;
        0) exit 0 ;;
        *) echo "Invalid option" ;;
    esac
done
EOF
    chmod +x /opt/bluejay/bin/bluejay-performance-settings
}

# 6. Service Management Settings
init_service_management_settings() {
    cat > "$SETTINGS_CONFIG/services/config.conf" << 'EOF'
# Service Management Configuration
AUTO_START_DISPLAY=true
AUTO_START_AUDIO=true
AUTO_START_NETWORK=true
BOOT_SPLASH=true
VERBOSE_BOOT=false
EOF

    cat > /opt/bluejay/bin/bluejay-service-settings << 'EOF'
#!/bin/bash
# Service Management Settings Interface

SETTINGS_CONFIG="/etc/bluejay/settings/services"
source "$SETTINGS_CONFIG/config.conf"

show_service_menu() {
    clear
    echo -e "${CYAN}BluejayLinux Service Management${NC}"
    echo "==============================="
    echo ""
    echo "System Services Status:"
    /opt/bluejay/bin/bluejay-service-manager list | head -10
    echo ""
    echo -e "${YELLOW}Service Management Options:${NC}"
    echo "[1] Start/Stop Services"
    echo "[2] Enable/Disable Services"
    echo "[3] Service Dependencies"
    echo "[4] Boot Configuration"
    echo "[5] Service Logs"
    echo "[6] Custom Services"
    echo "[0] Back to main menu"
    echo ""
    echo -n "Select option: "
}

start_stop_services() {
    echo -e "${BLUE}Service Control${NC}"
    echo "Available services:"
    /opt/bluejay/bin/bluejay-service-manager list
    echo ""
    echo -n "Enter service name: "
    read service_name
    echo "[1] Start"
    echo "[2] Stop"
    echo "[3] Restart"
    echo -n "Select action: "
    read action
    
    case $action in
        1) /opt/bluejay/bin/bluejay-service-manager start "$service_name" ;;
        2) /opt/bluejay/bin/bluejay-service-manager stop "$service_name" ;;
        3) /opt/bluejay/bin/bluejay-service-manager restart "$service_name" ;;
        *) echo "Invalid action" ;;
    esac
    
    read -p "Press Enter to continue..."
}

view_service_logs() {
    echo -e "${BLUE}Service Logs${NC}"
    echo "Recent service activity:"
    tail -20 /var/log/bluejay-services.log 2>/dev/null || echo "No service logs found"
    read -p "Press Enter to continue..."
}

while true; do
    show_service_menu
    read choice
    case $choice in
        1) start_stop_services ;;
        2) echo "Enable/disable services not yet implemented" ;;
        3) echo "Service dependencies not yet implemented" ;;
        4) echo "Boot configuration not yet implemented" ;;
        5) view_service_logs ;;
        6) echo "Custom services not yet implemented" ;;
        0) exit 0 ;;
        *) echo "Invalid option" ;;
    esac
done
EOF
    chmod +x /opt/bluejay/bin/bluejay-service-settings
}

# 7. System Monitoring Settings
init_monitoring_settings() {
    cat > /opt/bluejay/bin/bluejay-monitoring-settings << 'EOF'
#!/bin/bash
# System Monitoring Settings Interface

show_monitoring_menu() {
    clear
    echo -e "${CYAN}BluejayLinux System Monitoring${NC}"
    echo "=============================="
    echo ""
    echo -e "${YELLOW}Monitoring Options:${NC}"
    echo "[1] Real-time System Monitor"
    echo "[2] System Logs Viewer"
    echo "[3] Network Monitoring"
    echo "[4] Process Monitor"
    echo "[5] Disk Usage Monitor"
    echo "[6] Security Events"
    echo "[0] Back to main menu"
    echo ""
    echo -n "Select option: "
}

realtime_monitor() {
    echo -e "${BLUE}Real-time System Monitor${NC}"
    echo "Press Ctrl+C to exit"
    echo ""
    
    while true; do
        clear
        echo -e "${BLUE}System Status - $(date)${NC}"
        echo "================================"
        echo ""
        echo "CPU Usage:"
        top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//'
        echo ""
        echo "Memory Usage:"
        free -h | grep Mem
        echo ""
        echo "Disk Usage:"
        df -h / | tail -1
        echo ""
        echo "Load Average:"
        uptime | awk -F'load average:' '{print $2}'
        echo ""
        echo "Network Activity:"
        cat /proc/net/dev | grep -E "(eth|wlan)" | head -2
        
        sleep 2
    done
}

view_system_logs() {
    echo -e "${BLUE}System Logs Viewer${NC}"
    echo "=================="
    echo ""
    echo "[1] System messages (dmesg)"
    echo "[2] Authentication logs"
    echo "[3] Service logs"
    echo "[4] Application logs"
    echo -n "Select log type: "
    read log_type
    
    case $log_type in
        1) dmesg | tail -20 ;;
        2) grep "authentication" /var/log/auth.log 2>/dev/null | tail -10 || echo "No auth logs" ;;
        3) tail -20 /var/log/bluejay-*.log 2>/dev/null || echo "No service logs" ;;
        4) ls /var/log/ | head -10 ;;
    esac
    
    read -p "Press Enter to continue..."
}

network_monitor() {
    echo -e "${BLUE}Network Monitoring${NC}"
    echo "=================="
    echo ""
    echo "Network interfaces:"
    ip addr show
    echo ""
    echo "Network connections:"
    netstat -tuln | head -10
    echo ""
    echo "Network statistics:"
    cat /proc/net/dev
    read -p "Press Enter to continue..."
}

while true; do
    show_monitoring_menu
    read choice
    case $choice in
        1) realtime_monitor ;;
        2) view_system_logs ;;
        3) network_monitor ;;
        4) echo "Process monitor launching..."; top ;;
        5) echo "Disk usage:"; df -h; read -p "Press Enter..." ;;
        6) echo "Security events not yet implemented" ;;
        0) exit 0 ;;
        *) echo "Invalid option" ;;
    esac
done
EOF
    chmod +x /opt/bluejay/bin/bluejay-monitoring-settings
}

# 8. Package Management Settings
init_package_settings() {
    cat > /opt/bluejay/bin/bluejay-package-settings << 'EOF'
#!/bin/bash
# Package Management Settings Interface

show_package_menu() {
    clear
    echo -e "${CYAN}BluejayLinux Package Management${NC}"
    echo "==============================="
    echo ""
    echo "Installed Applications:"
    ls /usr/bin/bluejay-* 2>/dev/null | sed 's|/usr/bin/||' | head -10
    echo ""
    echo -e "${YELLOW}Package Options:${NC}"
    echo "[1] Install Package"
    echo "[2] Remove Package"
    echo "[3] Update System"
    echo "[4] Search Packages"
    echo "[5] Package Information"
    echo "[6] Repository Management"
    echo "[0] Back to main menu"
    echo ""
    echo -n "Select option: "
}

install_package() {
    echo -e "${BLUE}Package Installation${NC}"
    echo "Available packages for installation:"
    echo "  - chrome (Google Chrome browser)"
    echo "  - development-tools (GCC, make, git)"
    echo "  - security-tools (nmap, wireshark)"
    echo "  - media-tools (ffmpeg, vlc)"
    echo ""
    echo -n "Enter package name: "
    read package
    
    case $package in
        "chrome")
            echo "Installing Google Chrome..."
            /home/alastair/linux-6.16/scripts/install-chrome.sh
            ;;
        "development-tools")
            echo "Installing development tools..."
            echo "Would install: gcc, make, git, vim"
            ;;
        "security-tools")
            echo "Installing security tools..."
            echo "Would install: nmap, wireshark, netcat"
            ;;
        *)
            echo "Package '$package' not found in repository"
            ;;
    esac
    
    read -p "Press Enter to continue..."
}

remove_package() {
    echo -e "${BLUE}Package Removal${NC}"
    echo "Installed packages:"
    ls /opt/bluejay/bin/ | head -10
    echo ""
    echo -n "Enter package name to remove: "
    read package
    
    if [ -f "/opt/bluejay/bin/$package" ]; then
        echo -n "Remove $package? (y/n): "
        read confirm
        if [ "$confirm" = "y" ]; then
            rm -f "/opt/bluejay/bin/$package"
            echo -e "${GREEN}Package $package removed${NC}"
        fi
    else
        echo -e "${RED}Package $package not found${NC}"
    fi
    
    read -p "Press Enter to continue..."
}

while true; do
    show_package_menu
    read choice
    case $choice in
        1) install_package ;;
        2) remove_package ;;
        3) echo "System update not yet implemented" ;;
        4) echo "Package search not yet implemented" ;;
        5) echo "Package information not yet implemented" ;;
        6) echo "Repository management not yet implemented" ;;
        0) exit 0 ;;
        *) echo "Invalid option" ;;
    esac
done
EOF
    chmod +x /opt/bluejay/bin/bluejay-package-settings
}

main() {
    echo "Installing Advanced Settings Categories..."
    mkdir -p "$SETTINGS_CONFIG"/{performance,services,monitoring,packages}
    
    init_performance_settings
    init_service_management_settings
    init_monitoring_settings
    init_package_settings
    
    echo "✅ Advanced Settings Categories Installed!"
    echo ""
    echo "New categories available:"
    echo "  • Performance Controls (CPU governor, memory tuning)"
    echo "  • Service Management (start/stop/monitor services)"
    echo "  • System Monitoring (real-time stats, logs)"
    echo "  • Package Management (install/remove software)"
}

main "$@"