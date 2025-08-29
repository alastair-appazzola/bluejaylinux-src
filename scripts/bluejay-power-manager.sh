#!/bin/bash
# BluejayLinux Power Manager - Power management, suspend/resume, and ACPI
# Handles system power states and battery management

set -e

POWER_CONFIG="/etc/bluejay/power.conf"
POWER_STATE="/run/bluejay-power"

log_power() { echo "[$(date '+%H:%M:%S')] POWER: $1" | tee -a /var/log/bluejay-power.log; }
log_error() { echo "[$(date '+%H:%M:%S')] ERROR: $1" | tee -a /var/log/bluejay-power.log >&2; }
log_success() { echo "[$(date '+%H:%M:%S')] SUCCESS: $1" | tee -a /var/log/bluejay-power.log; }

init_power_manager() {
    log_power "Initializing BluejayLinux Power Manager..."
    mkdir -p "$(dirname "$POWER_CONFIG")" "$(dirname "$POWER_STATE")" /var/log /opt/bluejay/bin
    
    cat > "$POWER_CONFIG" << 'EOF'
SUSPEND_ON_IDLE=true
IDLE_TIMEOUT=1800
HIBERNATE_ON_LOW_BATTERY=true
LOW_BATTERY_THRESHOLD=10
CPU_GOVERNOR=ondemand
ENABLE_ACPI=true
EOF

    cat > "$POWER_STATE" << 'EOF'
power_manager_running=false
current_state=active
battery_level=100
ac_connected=true
EOF

    cat > /opt/bluejay/bin/bluejay-power-daemon << 'EOF'
#!/bin/bash
POWER_STATE="/run/bluejay-power"
LOG_FILE="/var/log/bluejay-power.log"

log_daemon() { echo "[$(date '+%H:%M:%S')] POWER_DAEMON: $1" >> "$LOG_FILE"; }

monitor_power() {
    while [ "$power_manager_running" = "true" ]; do
        # Check battery status
        if [ -d /sys/class/power_supply/BAT0 ]; then
            local battery_level=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 100)
            local ac_status=$(cat /sys/class/power_supply/ADP1/online 2>/dev/null || echo 1)
            
            sed -i "s/battery_level=.*/battery_level=$battery_level/" "$POWER_STATE"
            sed -i "s/ac_connected=.*/ac_connected=$ac_status/" "$POWER_STATE"
            
            if [ "$battery_level" -lt 10 ] && [ "$ac_status" = "0" ]; then
                log_daemon "Critical battery level: $battery_level%"
                echo "POWER_CRITICAL" > /run/bluejay-wm.fifo 2>/dev/null || true
            fi
        fi
        
        sleep 30
    done
}

. "$POWER_STATE"
power_manager_running=true
cat > "$POWER_STATE" << EOF
power_manager_running=$power_manager_running
current_state=$current_state
battery_level=$battery_level
ac_connected=$ac_connected
EOF

monitor_power
EOF
    chmod +x /opt/bluejay/bin/bluejay-power-daemon
    log_success "Power Manager initialized"
}

start_power_manager() {
    log_power "Starting Power Manager..."
    /opt/bluejay/bin/bluejay-power-daemon &
    echo $! > /run/bluejay-power-daemon.pid
    log_success "Power Manager started"
}

stop_power_manager() {
    log_power "Stopping Power Manager..."
    [ -f /run/bluejay-power-daemon.pid ] && kill $(cat /run/bluejay-power-daemon.pid) 2>/dev/null
    rm -f /run/bluejay-power-daemon.pid
    log_success "Power Manager stopped"
}

show_power_status() {
    echo "BluejayLinux Power Manager Status"
    echo "================================="
    [ -f "$POWER_STATE" ] && . "$POWER_STATE" && {
        echo "Power Manager Running: $power_manager_running"
        echo "Current State: $current_state"
        echo "Battery Level: $battery_level%"
        echo "AC Connected: $ac_connected"
    } || echo "Power manager not initialized"
}

main() {
    case "$1" in
        init) init_power_manager ;;
        start) start_power_manager ;;
        stop) stop_power_manager ;;
        status) show_power_status ;;
        suspend) echo mem > /sys/power/state 2>/dev/null || echo "Suspend not supported" ;;
        hibernate) echo disk > /sys/power/state 2>/dev/null || echo "Hibernate not supported" ;;
        *) echo "Usage: $0 {init|start|stop|status|suspend|hibernate}" ;;
    esac
}

main "$@"