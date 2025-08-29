#!/bin/bash
# BluejayLinux Hotplug Manager - Dynamic device management and hotplug support
# Handles USB devices, network interfaces, and hardware changes

set -e

HOTPLUG_CONFIG="/etc/bluejay/hotplug.conf"
HOTPLUG_STATE="/run/bluejay-hotplug"
DEVICES_DIR="/run/bluejay-devices"
UDEV_RULES_DIR="/etc/udev/rules.d"

log_hotplug() {
    echo "[$(date '+%H:%M:%S')] HOTPLUG: $1" | tee -a /var/log/bluejay-hotplug.log
}

log_error() {
    echo "[$(date '+%H:%M:%S')] ERROR: $1" | tee -a /var/log/bluejay-hotplug.log >&2
}

log_success() {
    echo "[$(date '+%H:%M:%S')] SUCCESS: $1" | tee -a /var/log/bluejay-hotplug.log
}

init_hotplug_manager() {
    log_hotplug "Initializing BluejayLinux Hotplug Manager..."
    
    mkdir -p "$(dirname "$HOTPLUG_CONFIG")"
    mkdir -p "$(dirname "$HOTPLUG_STATE")"
    mkdir -p "$DEVICES_DIR"
    mkdir -p "$UDEV_RULES_DIR"
    mkdir -p /var/log
    mkdir -p /opt/bluejay/bin
    
    create_hotplug_config
    init_hotplug_state
    setup_udev_rules
    setup_hotplug_handlers
    
    log_success "Hotplug Manager initialized"
}

create_hotplug_config() {
    cat > "$HOTPLUG_CONFIG" << 'EOF'
# BluejayLinux Hotplug Configuration

# General settings
ENABLE_HOTPLUG=true
AUTO_MOUNT_USB=true
AUTO_CONFIGURE_NETWORK=true
SCAN_INTERVAL=2

# USB device settings
USB_MOUNT_POINT=/media
USB_FILESYSTEM_TYPES=vfat,ext2,ext3,ext4,ntfs
ENABLE_USB_STORAGE=true
ENABLE_USB_INPUT=true

# Network settings
AUTO_DHCP_INTERFACES=true
NETWORK_MANAGER_INTEGRATION=true
WIFI_SCAN_ON_CONNECT=true

# Security settings
REQUIRE_USER_APPROVAL=false
WHITELIST_MODE=false
ENABLE_DEVICE_ENCRYPTION=false
LOG_ALL_EVENTS=true
EOF
    
    log_success "Hotplug configuration created"
}

init_hotplug_state() {
    cat > "$HOTPLUG_STATE" << 'EOF'
hotplug_manager_running=false
device_scan_running=false
connected_devices=0
usb_devices=0
network_interfaces=0
EOF
    
    log_success "Hotplug state initialized"
}

setup_udev_rules() {
    log_hotplug "Setting up udev rules..."
    
    # USB storage devices
    cat > "$UDEV_RULES_DIR/80-bluejay-usb-storage.rules" << 'EOF'
# BluejayLinux USB Storage Rules

# USB storage devices
SUBSYSTEM=="block", KERNEL=="sd[a-z][0-9]", ACTION=="add", RUN+="/opt/bluejay/bin/bluejay-hotplug-handler usb-storage-add %k"
SUBSYSTEM=="block", KERNEL=="sd[a-z][0-9]", ACTION=="remove", RUN+="/opt/bluejay/bin/bluejay-hotplug-handler usb-storage-remove %k"

# USB mass storage
SUBSYSTEM=="usb", ATTR{bDeviceClass}=="08", ACTION=="add", RUN+="/opt/bluejay/bin/bluejay-hotplug-handler usb-mass-storage-add %k"
SUBSYSTEM=="usb", ATTR{bDeviceClass}=="08", ACTION=="remove", RUN+="/opt/bluejay/bin/bluejay-hotplug-handler usb-mass-storage-remove %k"
EOF

    # USB input devices
    cat > "$UDEV_RULES_DIR/80-bluejay-usb-input.rules" << 'EOF'
# BluejayLinux USB Input Rules

# USB HID devices
SUBSYSTEM=="usb", ATTR{bInterfaceClass}=="03", ACTION=="add", RUN+="/opt/bluejay/bin/bluejay-hotplug-handler usb-input-add %k"
SUBSYSTEM=="usb", ATTR{bInterfaceClass}=="03", ACTION=="remove", RUN+="/opt/bluejay/bin/bluejay-hotplug-handler usb-input-remove %k"

# USB keyboards
SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="*keyboard*", ACTION=="add", RUN+="/opt/bluejay/bin/bluejay-hotplug-handler keyboard-add %k"
SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="*keyboard*", ACTION=="remove", RUN+="/opt/bluejay/bin/bluejay-hotplug-handler keyboard-remove %k"

# USB mice
SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="*mouse*", ACTION=="add", RUN+="/opt/bluejay/bin/bluejay-hotplug-handler mouse-add %k"
SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="*mouse*", ACTION=="remove", RUN+="/opt/bluejay/bin/bluejay-hotplug-handler mouse-remove %k"
EOF

    # Network interfaces
    cat > "$UDEV_RULES_DIR/80-bluejay-network.rules" << 'EOF'
# BluejayLinux Network Interface Rules

# Ethernet interfaces
SUBSYSTEM=="net", KERNEL=="eth*", ACTION=="add", RUN+="/opt/bluejay/bin/bluejay-hotplug-handler network-add %k"
SUBSYSTEM=="net", KERNEL=="eth*", ACTION=="remove", RUN+="/opt/bluejay/bin/bluejay-hotplug-handler network-remove %k"

# WiFi interfaces
SUBSYSTEM=="net", KERNEL=="wlan*", ACTION=="add", RUN+="/opt/bluejay/bin/bluejay-hotplug-handler wifi-add %k"
SUBSYSTEM=="net", KERNEL=="wlan*", ACTION=="remove", RUN+="/opt/bluejay/bin/bluejay-hotplug-handler wifi-remove %k"

# USB network adapters
SUBSYSTEM=="net", KERNEL=="usb*", ACTION=="add", RUN+="/opt/bluejay/bin/bluejay-hotplug-handler usb-network-add %k"
SUBSYSTEM=="net", KERNEL=="usb*", ACTION=="remove", RUN+="/opt/bluejay/bin/bluejay-hotplug-handler usb-network-remove %k"
EOF
    
    log_success "Udev rules created"
}

setup_hotplug_handlers() {
    # Main hotplug event handler
    cat > /opt/bluejay/bin/bluejay-hotplug-handler << 'EOF'
#!/bin/bash
# BluejayLinux Hotplug Event Handler

EVENT_TYPE="$1"
DEVICE="$2"
DEVICES_DIR="/run/bluejay-devices"
LOG_FILE="/var/log/bluejay-hotplug.log"

log_handler() {
    echo "[$(date '+%H:%M:%S')] HOTPLUG_HANDLER: $1" >> "$LOG_FILE"
}

# Handle USB storage device addition
handle_usb_storage_add() {
    local device="$1"
    
    log_handler "USB storage device added: $device"
    
    # Create device info
    cat > "$DEVICES_DIR/$device" << EOF
device_name=$device
device_type=usb_storage
status=connected
mount_point=
filesystem=
connect_time=$(date '+%s')
EOF
    
    # Auto-mount if enabled
    if grep -q "AUTO_MOUNT_USB=true" /etc/bluejay/hotplug.conf 2>/dev/null; then
        mount_usb_device "$device"
    fi
    
    # Notify display manager
    echo "DEVICE_CONNECTED:USB_STORAGE:$device" > /run/bluejay-wm.fifo 2>/dev/null || true
}

# Handle USB storage device removal
handle_usb_storage_remove() {
    local device="$1"
    
    log_handler "USB storage device removed: $device"
    
    # Unmount if mounted
    if [ -f "$DEVICES_DIR/$device" ]; then
        . "$DEVICES_DIR/$device"
        if [ -n "$mount_point" ] && mountpoint -q "$mount_point"; then
            umount "$mount_point" 2>/dev/null || true
            rmdir "$mount_point" 2>/dev/null || true
        fi
    fi
    
    # Remove device info
    rm -f "$DEVICES_DIR/$device"
    
    # Notify display manager
    echo "DEVICE_DISCONNECTED:USB_STORAGE:$device" > /run/bluejay-wm.fifo 2>/dev/null || true
}

# Mount USB device
mount_usb_device() {
    local device="$1"
    local dev_path="/dev/$device"
    
    if [ ! -b "$dev_path" ]; then
        log_handler "Block device not found: $dev_path"
        return 1
    fi
    
    # Detect filesystem
    local filesystem=""
    if command -v blkid >/dev/null; then
        filesystem=$(blkid -o value -s TYPE "$dev_path" 2>/dev/null || echo "")
    fi
    
    if [ -z "$filesystem" ]; then
        filesystem="vfat"  # Default assumption
    fi
    
    # Create mount point
    local mount_point="/media/$device"
    mkdir -p "$mount_point"
    
    # Mount device
    if mount -t "$filesystem" "$dev_path" "$mount_point" 2>/dev/null; then
        # Update device info
        sed -i "s|mount_point=.*|mount_point=$mount_point|" "$DEVICES_DIR/$device"
        sed -i "s|filesystem=.*|filesystem=$filesystem|" "$DEVICES_DIR/$device"
        
        log_handler "Mounted $device at $mount_point ($filesystem)"
        
        # Set appropriate permissions
        chmod 755 "$mount_point"
        
        return 0
    else
        rmdir "$mount_point" 2>/dev/null || true
        log_handler "Failed to mount $device"
        return 1
    fi
}

# Handle network interface addition
handle_network_add() {
    local interface="$1"
    
    log_handler "Network interface added: $interface"
    
    # Create device info
    cat > "$DEVICES_DIR/$interface" << EOF
device_name=$interface
device_type=network
status=connected
ip_address=
mac_address=
connect_time=$(date '+%s')
EOF
    
    # Get MAC address
    local mac_address=""
    if [ -f "/sys/class/net/$interface/address" ]; then
        mac_address=$(cat "/sys/class/net/$interface/address")
        sed -i "s|mac_address=.*|mac_address=$mac_address|" "$DEVICES_DIR/$interface"
    fi
    
    # Auto-configure if enabled
    if grep -q "AUTO_CONFIGURE_NETWORK=true" /etc/bluejay/hotplug.conf 2>/dev/null; then
        configure_network_interface "$interface"
    fi
}

# Handle network interface removal
handle_network_remove() {
    local interface="$1"
    
    log_handler "Network interface removed: $interface"
    
    # Remove device info
    rm -f "$DEVICES_DIR/$interface"
}

# Configure network interface
configure_network_interface() {
    local interface="$1"
    
    # Bring interface up
    if ip link set "$interface" up 2>/dev/null; then
        log_handler "Brought up interface: $interface"
        
        # Try DHCP
        if grep -q "AUTO_DHCP_INTERFACES=true" /etc/bluejay/hotplug.conf 2>/dev/null; then
            if command -v dhclient >/dev/null; then
                dhclient "$interface" -timeout 10 2>/dev/null &
                log_handler "Started DHCP client for $interface"
            fi
        fi
    fi
}

# Handle input device addition
handle_input_add() {
    local device="$1"
    local device_type="$2"
    
    log_handler "Input device added: $device ($device_type)"
    
    # Create device info
    cat > "$DEVICES_DIR/$device" << EOF
device_name=$device
device_type=$device_type
status=connected
connect_time=$(date '+%s')
EOF
    
    # Restart input manager if running
    if pgrep bluejay-input-processor >/dev/null; then
        /opt/bluejay/bin/bluejay-input-manager detect
    fi
}

# Handle input device removal
handle_input_remove() {
    local device="$1"
    
    log_handler "Input device removed: $device"
    
    # Remove device info
    rm -f "$DEVICES_DIR/$device"
}

# Main event handler
case "$EVENT_TYPE" in
    usb-storage-add) handle_usb_storage_add "$DEVICE" ;;
    usb-storage-remove) handle_usb_storage_remove "$DEVICE" ;;
    network-add) handle_network_add "$DEVICE" ;;
    network-remove) handle_network_remove "$DEVICE" ;;
    wifi-add) handle_network_add "$DEVICE" ;;
    wifi-remove) handle_network_remove "$DEVICE" ;;
    usb-network-add) handle_network_add "$DEVICE" ;;
    usb-network-remove) handle_network_remove "$DEVICE" ;;
    keyboard-add) handle_input_add "$DEVICE" "keyboard" ;;
    keyboard-remove) handle_input_remove "$DEVICE" ;;
    mouse-add) handle_input_add "$DEVICE" "mouse" ;;
    mouse-remove) handle_input_remove "$DEVICE" ;;
    usb-input-add) handle_input_add "$DEVICE" "usb_input" ;;
    usb-input-remove) handle_input_remove "$DEVICE" ;;
    *)
        log_handler "Unknown event type: $EVENT_TYPE"
        ;;
esac
EOF
    chmod +x /opt/bluejay/bin/bluejay-hotplug-handler

    # Device scanner daemon
    cat > /opt/bluejay/bin/bluejay-device-scanner << 'EOF'
#!/bin/bash
# BluejayLinux Device Scanner Daemon

HOTPLUG_STATE="/run/bluejay-hotplug"
DEVICES_DIR="/run/bluejay-devices"
LOG_FILE="/var/log/bluejay-hotplug.log"

log_scanner() {
    echo "[$(date '+%H:%M:%S')] DEVICE_SCANNER: $1" >> "$LOG_FILE"
}

load_hotplug_state() {
    if [ -f "$HOTPLUG_STATE" ]; then
        . "$HOTPLUG_STATE"
    fi
}

save_hotplug_state() {
    cat > "$HOTPLUG_STATE" << EOF
hotplug_manager_running=$hotplug_manager_running
device_scan_running=$device_scan_running
connected_devices=$connected_devices
usb_devices=$usb_devices
network_interfaces=$network_interfaces
EOF
}

scan_devices() {
    log_scanner "Scanning for devices..."
    
    local total_devices=0
    local usb_count=0
    local net_count=0
    
    # Scan USB devices
    if [ -d /sys/bus/usb/devices ]; then
        for usb_dev in /sys/bus/usb/devices/*; do
            if [ -d "$usb_dev" ] && [ -f "$usb_dev/idVendor" ]; then
                usb_count=$((usb_count + 1))
            fi
        done
    fi
    
    # Scan network interfaces
    if [ -d /sys/class/net ]; then
        for net_iface in /sys/class/net/*; do
            local iface_name=$(basename "$net_iface")
            if [ "$iface_name" != "lo" ]; then
                net_count=$((net_count + 1))
            fi
        done
    fi
    
    total_devices=$((usb_count + net_count))
    
    # Update state
    load_hotplug_state
    connected_devices=$total_devices
    usb_devices=$usb_count
    network_interfaces=$net_count
    save_hotplug_state
    
    log_scanner "Device scan completed: $total_devices total ($usb_count USB, $net_count network)"
}

main() {
    log_scanner "Device scanner daemon started"
    
    load_hotplug_state
    device_scan_running=true
    save_hotplug_state
    
    while [ "$device_scan_running" = "true" ]; do
        scan_devices
        sleep 5  # Scan every 5 seconds
    done
}

main "$@"
EOF
    chmod +x /opt/bluejay/bin/bluejay-device-scanner
    
    log_success "Hotplug handlers created"
}

start_hotplug_manager() {
    log_hotplug "Starting Hotplug Manager..."
    
    # Start udev if not running
    if ! pgrep udevd >/dev/null; then
        if command -v udevd >/dev/null; then
            udevd --daemon
            log_hotplug "Started udevd"
        fi
    fi
    
    # Trigger udev to process existing devices
    if command -v udevadm >/dev/null; then
        udevadm trigger --action=add
        udevadm settle
    fi
    
    # Start device scanner
    /opt/bluejay/bin/bluejay-device-scanner &
    local scanner_pid=$!
    echo "$scanner_pid" > /run/bluejay-device-scanner.pid
    
    # Update state
    . "$HOTPLUG_STATE"
    hotplug_manager_running=true
    cat > "$HOTPLUG_STATE" << EOF
hotplug_manager_running=$hotplug_manager_running
device_scan_running=$device_scan_running
connected_devices=$connected_devices
usb_devices=$usb_devices
network_interfaces=$network_interfaces
EOF
    
    log_success "Hotplug Manager started (Scanner PID: $scanner_pid)"
}

stop_hotplug_manager() {
    log_hotplug "Stopping Hotplug Manager..."
    
    if [ -f /run/bluejay-device-scanner.pid ]; then
        local pid=$(cat /run/bluejay-device-scanner.pid)
        kill "$pid" 2>/dev/null || true
        rm -f /run/bluejay-device-scanner.pid
    fi
    
    # Unmount all USB devices
    for device_file in "$DEVICES_DIR"/*; do
        if [ -f "$device_file" ]; then
            . "$device_file"
            if [ "$device_type" = "usb_storage" ] && [ -n "$mount_point" ]; then
                umount "$mount_point" 2>/dev/null || true
                rmdir "$mount_point" 2>/dev/null || true
            fi
            rm -f "$device_file"
        fi
    done
    
    # Update state
    . "$HOTPLUG_STATE"
    hotplug_manager_running=false
    device_scan_running=false
    connected_devices=0
    usb_devices=0
    network_interfaces=0
    cat > "$HOTPLUG_STATE" << EOF
hotplug_manager_running=$hotplug_manager_running
device_scan_running=$device_scan_running
connected_devices=$connected_devices
usb_devices=$usb_devices
network_interfaces=$network_interfaces
EOF
    
    log_success "Hotplug Manager stopped"
}

show_hotplug_status() {
    echo "BluejayLinux Hotplug Manager Status"
    echo "==================================="
    echo ""
    
    if [ -f "$HOTPLUG_STATE" ]; then
        . "$HOTPLUG_STATE"
        echo "Hotplug Manager Running: $hotplug_manager_running"
        echo "Device Scanner Running: $device_scan_running"
        echo "Connected Devices: $connected_devices"
        echo "USB Devices: $usb_devices"
        echo "Network Interfaces: $network_interfaces"
    else
        echo "Hotplug manager not initialized"
    fi
    echo ""
    
    echo "Connected Devices:"
    if [ -d "$DEVICES_DIR" ]; then
        for device_file in "$DEVICES_DIR"/*; do
            if [ -f "$device_file" ]; then
                . "$device_file"
                local duration=$(($(date '+%s') - connect_time))
                echo "  $device_name ($device_type) - connected ${duration}s ago"
                if [ -n "$mount_point" ]; then
                    echo "    Mounted at: $mount_point"
                fi
                if [ -n "$ip_address" ]; then
                    echo "    IP Address: $ip_address"
                fi
            fi
        done
    else
        echo "  No devices found"
    fi
}

main() {
    case "$1" in
        init) init_hotplug_manager ;;
        start) start_hotplug_manager ;;
        stop) stop_hotplug_manager ;;
        restart) stop_hotplug_manager; sleep 2; start_hotplug_manager ;;
        status) show_hotplug_status ;;
        help|*)
            echo "Usage: $0 {init|start|stop|restart|status|help}"
            echo ""
            echo "BluejayLinux Hotplug Manager - Dynamic device management"
            ;;
    esac
}

main "$@"