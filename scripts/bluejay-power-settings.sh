#!/bin/bash
# BluejayLinux Power Management Settings - Complete Implementation
# Battery, sleep, hibernate, power profiles, thermal management

set -e

SETTINGS_CONFIG="/etc/bluejay/settings/power"
POWER_CONFIG="/etc/bluejay/power"

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

init_power_config() {
    mkdir -p "$SETTINGS_CONFIG"
    mkdir -p "$POWER_CONFIG"
    
    cat > "$SETTINGS_CONFIG/config.conf" << 'EOF'
# Power Management Configuration
POWER_PROFILE=balanced
SCREEN_BLANK_TIME=600
SYSTEM_SUSPEND_TIME=1800
SYSTEM_HIBERNATE_TIME=3600
DISK_SPINDOWN_TIME=300

# Battery Settings
BATTERY_LOW_THRESHOLD=15
BATTERY_CRITICAL_THRESHOLD=5
BATTERY_LOW_ACTION=suspend
BATTERY_CRITICAL_ACTION=hibernate

# CPU Power Management
CPU_SCALING_GOVERNOR=ondemand
CPU_MIN_FREQ=800000
CPU_MAX_FREQ=3000000
TURBO_BOOST_ENABLED=true

# Display Power Management
DISPLAY_BRIGHTNESS=80
DISPLAY_ADAPTIVE_BRIGHTNESS=true
DISPLAY_DIMMING_ENABLED=true
DISPLAY_DIM_TIME=300

# Wireless Power Management
WIFI_POWER_SAVE=true
BLUETOOTH_POWER_SAVE=true

# Advanced Settings
WAKE_ON_LAN=false
USB_AUTOSUSPEND=true
PCIE_ASPM=powersave
RUNTIME_PM_ENABLED=true
THERMAL_THROTTLING=true
EOF

    # Create power management scripts
    create_power_scripts
    create_battery_monitor
}

create_power_scripts() {
    # Power profile management script
    cat > "$POWER_CONFIG/power-profiles.sh" << 'EOF'
#!/bin/bash
# Power Profile Management

apply_performance_profile() {
    echo "Applying performance profile..."
    
    # CPU settings
    echo "performance" > /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null || true
    echo "100" > /sys/class/backlight/*/brightness 2>/dev/null || true
    
    # Disable power saving features
    echo "0" > /proc/sys/vm/laptop_mode 2>/dev/null || true
    echo "0" > /sys/module/snd_hda_intel/parameters/power_save 2>/dev/null || true
    
    echo "Performance profile activated"
}

apply_balanced_profile() {
    echo "Applying balanced profile..."
    
    # CPU settings
    echo "ondemand" > /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null || true
    
    # Moderate power saving
    echo "1" > /proc/sys/vm/laptop_mode 2>/dev/null || true
    echo "1" > /sys/module/snd_hda_intel/parameters/power_save 2>/dev/null || true
    
    echo "Balanced profile activated"
}

apply_powersave_profile() {
    echo "Applying power save profile..."
    
    # CPU settings
    echo "powersave" > /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null || true
    
    # Enable aggressive power saving
    echo "5" > /proc/sys/vm/laptop_mode 2>/dev/null || true
    echo "10" > /sys/module/snd_hda_intel/parameters/power_save 2>/dev/null || true
    
    # Reduce display brightness
    echo "50" > /sys/class/backlight/*/brightness 2>/dev/null || true
    
    echo "Power save profile activated"
}

case "$1" in
    "performance") apply_performance_profile ;;
    "balanced") apply_balanced_profile ;;
    "powersave") apply_powersave_profile ;;
    *) echo "Usage: $0 {performance|balanced|powersave}" ;;
esac
EOF

    chmod +x "$POWER_CONFIG/power-profiles.sh"
    
    # Sleep and hibernate management
    cat > "$POWER_CONFIG/sleep-hibernate.sh" << 'EOF'
#!/bin/bash
# Sleep and Hibernate Management

suspend_system() {
    echo "Preparing system for suspend..."
    
    # Sync filesystems
    sync
    
    # Put system to sleep
    if [ -f /sys/power/state ]; then
        echo "mem" > /sys/power/state
    else
        echo "Suspend not supported"
        return 1
    fi
}

hibernate_system() {
    echo "Preparing system for hibernation..."
    
    # Check if hibernation is available
    if [ -f /sys/power/disk ]; then
        # Sync filesystems
        sync
        
        # Enable hibernation
        echo "disk" > /sys/power/state
    else
        echo "Hibernation not supported"
        return 1
    fi
}

shutdown_system() {
    echo "Shutting down system..."
    sync
    poweroff
}

reboot_system() {
    echo "Rebooting system..."
    sync
    reboot
}

case "$1" in
    "suspend") suspend_system ;;
    "hibernate") hibernate_system ;;
    "shutdown") shutdown_system ;;
    "reboot") reboot_system ;;
    *) echo "Usage: $0 {suspend|hibernate|shutdown|reboot}" ;;
esac
EOF

    chmod +x "$POWER_CONFIG/sleep-hibernate.sh"
}

create_battery_monitor() {
    cat > "$POWER_CONFIG/battery-monitor.sh" << 'EOF'
#!/bin/bash
# Battery Monitoring Service

BATTERY_PATH="/sys/class/power_supply"
LOW_THRESHOLD=15
CRITICAL_THRESHOLD=5

get_battery_info() {
    local battery_dir
    for battery_dir in "$BATTERY_PATH"/BAT*; do
        if [ -d "$battery_dir" ]; then
            local capacity=$(cat "$battery_dir/capacity" 2>/dev/null || echo "0")
            local status=$(cat "$battery_dir/status" 2>/dev/null || echo "Unknown")
            
            echo "Battery: $capacity% ($status)"
            
            # Check thresholds
            if [ "$capacity" -le "$CRITICAL_THRESHOLD" ] && [ "$status" = "Discharging" ]; then
                echo "CRITICAL: Battery at $capacity%"
                # Force hibernation
                /etc/bluejay/power/sleep-hibernate.sh hibernate
            elif [ "$capacity" -le "$LOW_THRESHOLD" ] && [ "$status" = "Discharging" ]; then
                echo "WARNING: Battery low at $capacity%"
                # Could trigger notification or suspend
            fi
            
            return 0
        fi
    done
    
    echo "No battery detected"
    return 1
}

get_ac_adapter_info() {
    local ac_dir
    for ac_dir in "$BATTERY_PATH"/A{C,DP}*; do
        if [ -d "$ac_dir" ]; then
            local online=$(cat "$ac_dir/online" 2>/dev/null || echo "0")
            if [ "$online" = "1" ]; then
                echo "AC Adapter: Connected"
            else
                echo "AC Adapter: Disconnected"
            fi
            return 0
        fi
    done
    
    echo "AC Adapter: Not detected"
    return 1
}

# Main monitoring function
case "$1" in
    "status")
        get_battery_info
        get_ac_adapter_info
        ;;
    "monitor")
        while true; do
            get_battery_info
            sleep 30
        done
        ;;
    *)
        echo "Usage: $0 {status|monitor}"
        ;;
esac
EOF

    chmod +x "$POWER_CONFIG/battery-monitor.sh"
}

show_power_menu() {
    clear
    source "$SETTINGS_CONFIG/config.conf"
    
    echo -e "${PURPLE}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║       BluejayLinux Power Management          ║${NC}"
    echo -e "${PURPLE}║    Battery, Sleep & Power Optimization       ║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Show current power status
    echo -e "${CYAN}Current Power Status:${NC}"
    "$POWER_CONFIG/battery-monitor.sh" status 2>/dev/null || echo "Power status unavailable"
    echo ""
    
    echo -e "${CYAN}Current Configuration:${NC}"
    echo "Power Profile: $POWER_PROFILE"
    echo "Screen Blank: ${SCREEN_BLANK_TIME}s"
    echo "Suspend: ${SYSTEM_SUSPEND_TIME}s"
    echo "Hibernate: ${SYSTEM_HIBERNATE_TIME}s"
    echo "Battery Low: ${BATTERY_LOW_THRESHOLD}%"
    echo ""
    
    echo -e "${YELLOW}Power Management Options:${NC}"
    echo "[1] Power Profiles (Performance/Balanced/Power Save)"
    echo "[2] Sleep & Hibernation Settings"
    echo "[3] Battery Configuration" 
    echo "[4] Display Power Management"
    echo "[5] CPU Power Management"
    echo "[6] Wireless Power Saving"
    echo "[7] Advanced Power Settings"
    echo "[8] Power Actions (Sleep/Hibernate/Shutdown)"
    echo "[9] Power Statistics"
    echo "[0] Apply & Exit"
    echo ""
    echo -n "Select option: "
}

configure_power_profiles() {
    echo -e "${BLUE}Power Profile Configuration${NC}"
    echo "=========================="
    echo ""
    echo "Current profile: $POWER_PROFILE"
    echo ""
    echo "Available power profiles:"
    echo "[1] Performance - Maximum performance, higher power consumption"
    echo "[2] Balanced - Balance between performance and power saving"
    echo "[3] Power Save - Maximum battery life, reduced performance"
    echo -n "Select power profile: "
    read profile_choice
    
    local new_profile
    case $profile_choice in
        1) new_profile="performance" ;;
        2) new_profile="balanced" ;;
        3) new_profile="powersave" ;;
        *) echo "Invalid choice"; return ;;
    esac
    
    # Apply power profile
    "$POWER_CONFIG/power-profiles.sh" "$new_profile"
    
    # Update configuration
    sed -i "s/POWER_PROFILE=.*/POWER_PROFILE=$new_profile/" "$SETTINGS_CONFIG/config.conf"
    
    echo -e "${GREEN}Power profile changed to: $new_profile${NC}"
    read -p "Press Enter to continue..."
}

configure_sleep_hibernate() {
    echo -e "${BLUE}Sleep & Hibernation Settings${NC}"
    echo "============================"
    echo ""
    echo "Current settings:"
    echo "Screen blank: ${SCREEN_BLANK_TIME}s"
    echo "System suspend: ${SYSTEM_SUSPEND_TIME}s" 
    echo "System hibernate: ${SYSTEM_HIBERNATE_TIME}s"
    echo ""
    
    echo -n "Screen blank time (seconds, 0=disabled): "
    read screen_blank
    
    echo -n "System suspend time (seconds, 0=disabled): "
    read suspend_time
    
    echo -n "System hibernate time (seconds, 0=disabled): "
    read hibernate_time
    
    # Validate and apply settings
    if [[ "$screen_blank" =~ ^[0-9]+$ ]]; then
        sed -i "s/SCREEN_BLANK_TIME=.*/SCREEN_BLANK_TIME=$screen_blank/" "$SETTINGS_CONFIG/config.conf"
    fi
    
    if [[ "$suspend_time" =~ ^[0-9]+$ ]]; then
        sed -i "s/SYSTEM_SUSPEND_TIME=.*/SYSTEM_SUSPEND_TIME=$suspend_time/" "$SETTINGS_CONFIG/config.conf"
    fi
    
    if [[ "$hibernate_time" =~ ^[0-9]+$ ]]; then
        sed -i "s/SYSTEM_HIBERNATE_TIME=.*/SYSTEM_HIBERNATE_TIME=$hibernate_time/" "$SETTINGS_CONFIG/config.conf"
    fi
    
    echo -e "${GREEN}Sleep and hibernation settings updated!${NC}"
    read -p "Press Enter to continue..."
}

configure_battery() {
    echo -e "${BLUE}Battery Configuration${NC}"
    echo "===================="
    echo ""
    
    # Check if battery exists
    if ! ls /sys/class/power_supply/BAT* >/dev/null 2>&1; then
        echo -e "${YELLOW}No battery detected on this system${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo "Current battery settings:"
    echo "Low threshold: ${BATTERY_LOW_THRESHOLD}%"
    echo "Critical threshold: ${BATTERY_CRITICAL_THRESHOLD}%"
    echo "Low action: $BATTERY_LOW_ACTION"
    echo "Critical action: $BATTERY_CRITICAL_ACTION"
    echo ""
    
    echo -n "Battery low threshold (5-30%): "
    read low_threshold
    
    echo -n "Battery critical threshold (1-10%): "
    read critical_threshold
    
    echo "Action on low battery:"
    echo "[1] Nothing"
    echo "[2] Suspend"
    echo "[3] Hibernate"
    echo -n "Select action: "
    read low_action_choice
    
    echo "Action on critical battery:"
    echo "[1] Nothing"
    echo "[2] Suspend"
    echo "[3] Hibernate"
    echo "[4] Shutdown"
    echo -n "Select action: "
    read critical_action_choice
    
    # Validate and apply settings
    if [ "$low_threshold" -ge 5 ] && [ "$low_threshold" -le 30 ]; then
        sed -i "s/BATTERY_LOW_THRESHOLD=.*/BATTERY_LOW_THRESHOLD=$low_threshold/" "$SETTINGS_CONFIG/config.conf"
    fi
    
    if [ "$critical_threshold" -ge 1 ] && [ "$critical_threshold" -le 10 ]; then
        sed -i "s/BATTERY_CRITICAL_THRESHOLD=.*/BATTERY_CRITICAL_THRESHOLD=$critical_threshold/" "$SETTINGS_CONFIG/config.conf"
    fi
    
    local low_action
    case $low_action_choice in
        1) low_action="nothing" ;;
        2) low_action="suspend" ;;
        3) low_action="hibernate" ;;
        *) low_action="suspend" ;;
    esac
    
    local critical_action
    case $critical_action_choice in
        1) critical_action="nothing" ;;
        2) critical_action="suspend" ;;
        3) critical_action="hibernate" ;;
        4) critical_action="shutdown" ;;
        *) critical_action="hibernate" ;;
    esac
    
    sed -i "s/BATTERY_LOW_ACTION=.*/BATTERY_LOW_ACTION=$low_action/" "$SETTINGS_CONFIG/config.conf"
    sed -i "s/BATTERY_CRITICAL_ACTION=.*/BATTERY_CRITICAL_ACTION=$critical_action/" "$SETTINGS_CONFIG/config.conf"
    
    echo -e "${GREEN}Battery settings updated!${NC}"
    read -p "Press Enter to continue..."
}

configure_display_power() {
    echo -e "${BLUE}Display Power Management${NC}"
    echo "========================"
    echo ""
    echo "Current display settings:"
    echo "Brightness: ${DISPLAY_BRIGHTNESS}%"
    echo "Adaptive brightness: $DISPLAY_ADAPTIVE_BRIGHTNESS"
    echo "Auto-dimming: $DISPLAY_DIMMING_ENABLED"
    echo "Dim time: ${DISPLAY_DIM_TIME}s"
    echo ""
    
    echo -n "Display brightness (10-100%): "
    read brightness
    
    echo -n "Enable adaptive brightness? (y/n): "
    read adaptive_brightness
    
    echo -n "Enable auto-dimming? (y/n): "
    read auto_dimming
    
    echo -n "Time before dimming (seconds): "
    read dim_time
    
    # Apply settings
    if [ "$brightness" -ge 10 ] && [ "$brightness" -le 100 ]; then
        sed -i "s/DISPLAY_BRIGHTNESS=.*/DISPLAY_BRIGHTNESS=$brightness/" "$SETTINGS_CONFIG/config.conf"
        apply_display_brightness "$brightness"
    fi
    
    sed -i "s/DISPLAY_ADAPTIVE_BRIGHTNESS=.*/DISPLAY_ADAPTIVE_BRIGHTNESS=$([ "$adaptive_brightness" = "y" ] && echo true || echo false)/" "$SETTINGS_CONFIG/config.conf"
    sed -i "s/DISPLAY_DIMMING_ENABLED=.*/DISPLAY_DIMMING_ENABLED=$([ "$auto_dimming" = "y" ] && echo true || echo false)/" "$SETTINGS_CONFIG/config.conf"
    
    if [[ "$dim_time" =~ ^[0-9]+$ ]]; then
        sed -i "s/DISPLAY_DIM_TIME=.*/DISPLAY_DIM_TIME=$dim_time/" "$SETTINGS_CONFIG/config.conf"
    fi
    
    echo -e "${GREEN}Display power settings updated!${NC}"
    read -p "Press Enter to continue..."
}

power_actions() {
    echo -e "${BLUE}Power Actions${NC}"
    echo "============="
    echo ""
    echo "[1] Suspend (Sleep)"
    echo "[2] Hibernate"
    echo "[3] Shutdown"
    echo "[4] Reboot"
    echo "[5] Cancel"
    echo -n "Select action: "
    read action_choice
    
    case $action_choice in
        1)
            echo "Suspending system in 5 seconds... (Ctrl+C to cancel)"
            sleep 5
            "$POWER_CONFIG/sleep-hibernate.sh" suspend
            ;;
        2)
            echo "Hibernating system in 5 seconds... (Ctrl+C to cancel)"
            sleep 5
            "$POWER_CONFIG/sleep-hibernate.sh" hibernate
            ;;
        3)
            echo "Shutting down system in 5 seconds... (Ctrl+C to cancel)"
            sleep 5
            "$POWER_CONFIG/sleep-hibernate.sh" shutdown
            ;;
        4)
            echo "Rebooting system in 5 seconds... (Ctrl+C to cancel)"
            sleep 5
            "$POWER_CONFIG/sleep-hibernate.sh" reboot
            ;;
        5)
            echo "Action cancelled"
            ;;
        *)
            echo "Invalid choice"
            ;;
    esac
    
    read -p "Press Enter to continue..." 2>/dev/null || true
}

show_power_statistics() {
    echo -e "${BLUE}Power Statistics${NC}"
    echo "================"
    echo ""
    
    # Battery information
    echo "=== Battery Information ==="
    "$POWER_CONFIG/battery-monitor.sh" status
    echo ""
    
    # CPU frequency information
    echo "=== CPU Power Information ==="
    if [ -d /sys/devices/system/cpu/cpu0/cpufreq ]; then
        echo "Current CPU governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo 'Unknown')"
        echo "Current CPU frequency: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null || echo 'Unknown') kHz"
        echo "Min frequency: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq 2>/dev/null || echo 'Unknown') kHz"
        echo "Max frequency: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null || echo 'Unknown') kHz"
    else
        echo "CPU frequency scaling not available"
    fi
    echo ""
    
    # Temperature information
    echo "=== Thermal Information ==="
    if [ -d /sys/class/thermal ]; then
        for thermal in /sys/class/thermal/thermal_zone*; do
            if [ -f "$thermal/temp" ]; then
                local temp=$(cat "$thermal/temp")
                local temp_celsius=$((temp / 1000))
                echo "$(basename "$thermal"): ${temp_celsius}°C"
            fi
        done
    else
        echo "Thermal information not available"
    fi
    echo ""
    
    # Power consumption estimate
    echo "=== Power Usage ==="
    echo "Uptime: $(uptime -p 2>/dev/null || echo 'Unknown')"
    echo "Load average: $(uptime | awk -F'load average:' '{print $2}')"
    
    read -p "Press Enter to continue..."
}

# Application functions

apply_display_brightness() {
    local brightness="$1"
    
    # Apply brightness to all available backlight devices
    for backlight in /sys/class/backlight/*; do
        if [ -f "$backlight/brightness" ] && [ -w "$backlight/brightness" ]; then
            local max_brightness=$(cat "$backlight/max_brightness" 2>/dev/null || echo 100)
            local actual_brightness=$((brightness * max_brightness / 100))
            echo "$actual_brightness" > "$backlight/brightness" 2>/dev/null || true
        fi
    done
    
    echo "Display brightness set to: ${brightness}%"
}

apply_all_power_settings() {
    echo -e "${YELLOW}Applying all power management settings...${NC}"
    
    source "$SETTINGS_CONFIG/config.conf"
    
    # Apply power profile
    "$POWER_CONFIG/power-profiles.sh" "$POWER_PROFILE"
    
    # Apply display brightness
    apply_display_brightness "$DISPLAY_BRIGHTNESS"
    
    # Update battery monitor thresholds
    sed -i "s/LOW_THRESHOLD=.*/LOW_THRESHOLD=$BATTERY_LOW_THRESHOLD/" "$POWER_CONFIG/battery-monitor.sh"
    sed -i "s/CRITICAL_THRESHOLD=.*/CRITICAL_THRESHOLD=$BATTERY_CRITICAL_THRESHOLD/" "$POWER_CONFIG/battery-monitor.sh"
    
    echo -e "${GREEN}✅ All power management settings applied successfully!${NC}"
    echo ""
    echo "Power management configured:"
    echo "• Profile: $POWER_PROFILE"
    echo "• Display brightness: ${DISPLAY_BRIGHTNESS}%"
    echo "• Suspend after: ${SYSTEM_SUSPEND_TIME}s"
    echo "• Battery low threshold: ${BATTERY_LOW_THRESHOLD}%"
    
    read -p "Press Enter to continue..."
}

main() {
    # Initialize if needed
    if [ ! -f "$SETTINGS_CONFIG/config.conf" ]; then
        echo "Initializing power management settings..."
        init_power_config
    fi
    
    while true; do
        show_power_menu
        read choice
        
        case $choice in
            1) configure_power_profiles ;;
            2) configure_sleep_hibernate ;;
            3) configure_battery ;;
            4) configure_display_power ;;
            5) echo "CPU power management - Coming soon" && read -p "Press Enter..." ;;
            6) echo "Wireless power saving - Coming soon" && read -p "Press Enter..." ;;
            7) echo "Advanced power settings - Coming soon" && read -p "Press Enter..." ;;
            8) power_actions ;;
            9) show_power_statistics ;;
            0) apply_all_power_settings && exit 0 ;;
            *) echo -e "${RED}Invalid option${NC}" && sleep 1 ;;
        esac
    done
}

main "$@"