#!/bin/bash

# BluejayLinux - Advanced USB & Storage Management
# Professional storage device management and file system tools

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/bluejay"
STORAGE_CONFIG_DIR="$CONFIG_DIR/storage"
DEVICES_DB="$STORAGE_CONFIG_DIR/devices.db"
MOUNT_POINTS_DIR="$STORAGE_CONFIG_DIR/mount_points"
AUTO_MOUNT_DIR="/media/bluejay"

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

# Supported file systems
SUPPORTED_FILESYSTEMS="ext2 ext3 ext4 btrfs xfs ntfs fat32 exfat hfs+ zfs f2fs"
MOUNT_OPTIONS="defaults,nodev,nosuid,auto,user,exec,async,suid,dev"

# Initialize directories
create_directories() {
    mkdir -p "$CONFIG_DIR" "$STORAGE_CONFIG_DIR" "$MOUNT_POINTS_DIR"
    sudo mkdir -p "$AUTO_MOUNT_DIR"
    sudo chown "$USER:$USER" "$AUTO_MOUNT_DIR"
    
    # Create default storage configuration
    if [ ! -f "$STORAGE_CONFIG_DIR/settings.conf" ]; then
        cat > "$STORAGE_CONFIG_DIR/settings.conf" << 'EOF'
# BluejayLinux Storage Manager Settings
AUTO_MOUNT_USB=true
AUTO_MOUNT_EXTERNAL=true
SHOW_NOTIFICATIONS=true
SAFE_REMOVAL_REQUIRED=true
FORMAT_WARNING=true
FILESYSTEM_CHECK=true
SMART_MONITORING=true
DISK_USAGE_ALERTS=true
STORAGE_ENCRYPTION=false
DEFAULT_MOUNT_OPTIONS=defaults,user,exec
PREFERRED_FILESYSTEM=ext4
AUTO_FSCK=true
MOUNT_TIMEOUT=30
UNMOUNT_TIMEOUT=15
THUMBNAIL_GENERATION=true
INDEX_CONTENT=false
BACKUP_MBR=true
RAID_SUPPORT=true
LVM_SUPPORT=true
PARTITION_ALIGNMENT=true
EOF
    fi
    
    touch "$DEVICES_DB"
}

# Load settings
load_settings() {
    if [ -f "$STORAGE_CONFIG_DIR/settings.conf" ]; then
        source "$STORAGE_CONFIG_DIR/settings.conf"
    fi
}

# Detect storage devices
detect_storage_devices() {
    echo -e "${BLUE}Detecting storage devices...${NC}"
    
    local storage_devices=()
    
    # USB storage devices
    echo -e "${CYAN}USB Storage Devices:${NC}"
    if command -v lsusb >/dev/null; then
        local usb_storage=$(lsusb | grep -i "mass storage\|storage")
        if [ -n "$usb_storage" ]; then
            echo "$usb_storage" | while read -r line; do
                echo -e "${GREEN}✓${NC} $line"
                storage_devices+=("usb:$line")
            done
        fi
    fi
    
    # Block devices
    echo -e "${CYAN}Block Devices:${NC}"
    if command -v lsblk >/dev/null; then
        local block_devices=$(lsblk -d -o NAME,SIZE,TYPE,MODEL | grep -v "^loop")
        echo "$block_devices" | while read -r line; do
            if [[ $line != NAME* ]]; then
                echo -e "${GREEN}✓${NC} $line"
                storage_devices+=("block:$line")
            fi
        done
    fi
    
    # SCSI devices
    if command -v lscsi >/dev/null; then
        echo -e "${CYAN}SCSI Devices:${NC}"
        local scsi_devices=$(lscsi 2>/dev/null | grep -v "cd/dvd")
        if [ -n "$scsi_devices" ]; then
            echo "$scsi_devices" | while read -r line; do
                echo -e "${GREEN}✓${NC} $line"
                storage_devices+=("scsi:$line")
            done
        fi
    fi
    
    echo "${storage_devices[@]}"
}

# List mounted devices
list_mounted_devices() {
    echo -e "\n${BLUE}Mounted Storage Devices:${NC}"
    
    if command -v df >/dev/null; then
        local mounted=$(df -h | grep -E "^/dev/")
        
        if [ -z "$mounted" ]; then
            echo -e "${YELLOW}No mounted storage devices${NC}"
            return
        fi
        
        echo -e "${WHITE}Device${NC}\t${WHITE}Size${NC}\t${WHITE}Used${NC}\t${WHITE}Avail${NC}\t${WHITE}Use%${NC}\t${WHITE}Mounted on${NC}"
        echo "$mounted" | while read -r line; do
            local device=$(echo "$line" | awk '{print $1}')
            local size=$(echo "$line" | awk '{print $2}')
            local used=$(echo "$line" | awk '{print $3}')
            local avail=$(echo "$line" | awk '{print $4}')
            local use_percent=$(echo "$line" | awk '{print $5}')
            local mount_point=$(echo "$line" | awk '{print $6}')
            
            # Color code usage percentage
            local color=""
            local usage_num=$(echo "$use_percent" | tr -d '%')
            if [ "$usage_num" -gt 90 ]; then
                color="$RED"
            elif [ "$usage_num" -gt 75 ]; then
                color="$YELLOW"
            else
                color="$GREEN"
            fi
            
            echo -e "${device}\t${size}\t${used}\t${avail}\t${color}${use_percent}${NC}\t${mount_point}"
        done
    fi
}

# Show detailed device information
show_device_info() {
    local device="$1"
    
    if [ -z "$device" ]; then
        echo -e "${RED}✗${NC} Device path required"
        return 1
    fi
    
    echo -e "\n${BLUE}Device Information: $device${NC}"
    
    # Basic device info
    if command -v lsblk >/dev/null; then
        echo -e "\n${WHITE}Block Device Info:${NC}"
        lsblk -f "$device" 2>/dev/null || lsblk -f
    fi
    
    # File system info
    if command -v file >/dev/null; then
        echo -e "\n${WHITE}File System:${NC}"
        file -s "$device" 2>/dev/null | head -1
    fi
    
    # Partition information
    if command -v fdisk >/dev/null; then
        echo -e "\n${WHITE}Partition Table:${NC}"
        sudo fdisk -l "$device" 2>/dev/null | grep -E "^Disk|^Device"
    fi
    
    # SMART information for hard drives
    if command -v smartctl >/dev/null && [[ $device == *sd* ]] || [[ $device == *nvme* ]]; then
        echo -e "\n${WHITE}SMART Status:${NC}"
        sudo smartctl -H "$device" 2>/dev/null | grep -E "SMART overall|PASSED|FAILED"
    fi
    
    # Mount status
    echo -e "\n${WHITE}Mount Status:${NC}"
    if mount | grep -q "$device"; then
        local mount_info=$(mount | grep "$device")
        echo -e "${GREEN}Mounted:${NC} $mount_info"
    else
        echo -e "${YELLOW}Not mounted${NC}"
    fi
}

# Mount storage device
mount_device() {
    local device="$1"
    local mount_point="$2"
    local filesystem="$3"
    local options="$4"
    
    if [ -z "$device" ]; then
        echo -e "${RED}✗${NC} Device path required"
        return 1
    fi
    
    # Auto-generate mount point if not provided
    if [ -z "$mount_point" ]; then
        local device_name=$(basename "$device")
        mount_point="$AUTO_MOUNT_DIR/$device_name"
    fi
    
    echo -e "${BLUE}Mounting device: $device${NC}"
    echo -e "${CYAN}Mount point: $mount_point${NC}"
    
    # Create mount point
    sudo mkdir -p "$mount_point"
    
    # Detect filesystem if not provided
    if [ -z "$filesystem" ]; then
        filesystem=$(lsblk -f "$device" | tail -1 | awk '{print $2}')
        if [ -z "$filesystem" ]; then
            filesystem="auto"
        fi
    fi
    
    # Use default options if not provided
    if [ -z "$options" ]; then
        options="$DEFAULT_MOUNT_OPTIONS"
    fi
    
    # Check if already mounted
    if mount | grep -q "$device"; then
        echo -e "${YELLOW}!${NC} Device already mounted"
        mount | grep "$device"
        return 0
    fi
    
    # Perform filesystem check if enabled
    if [ "$AUTO_FSCK" = "true" ] && [ "$filesystem" != "auto" ]; then
        echo -e "${CYAN}Checking filesystem...${NC}"
        case "$filesystem" in
            ext2|ext3|ext4)
                sudo fsck.ext4 -f "$device" 2>/dev/null || true
                ;;
            ntfs)
                if command -v ntfsfix >/dev/null; then
                    sudo ntfsfix "$device" 2>/dev/null || true
                fi
                ;;
        esac
    fi
    
    # Mount device
    if sudo mount -t "$filesystem" -o "$options" "$device" "$mount_point"; then
        echo -e "${GREEN}✓${NC} Device mounted successfully"
        
        # Set proper permissions
        sudo chown "$USER:$USER" "$mount_point" 2>/dev/null || true
        sudo chmod 755 "$mount_point" 2>/dev/null || true
        
        # Log mount operation
        echo "$(date):MOUNT:$device:$mount_point:$filesystem" >> "$DEVICES_DB"
        
        # Show notification
        if [ "$SHOW_NOTIFICATIONS" = "true" ] && command -v notify-send >/dev/null; then
            notify-send "Storage Manager" "Device mounted at $mount_point"
        fi
        
        return 0
    else
        echo -e "${RED}✗${NC} Failed to mount device"
        sudo rmdir "$mount_point" 2>/dev/null || true
        return 1
    fi
}

# Unmount storage device
unmount_device() {
    local device_or_mount="$1"
    local force="$2"
    
    if [ -z "$device_or_mount" ]; then
        echo -e "${RED}✗${NC} Device or mount point required"
        return 1
    fi
    
    echo -e "${BLUE}Unmounting: $device_or_mount${NC}"
    
    # Check if device is mounted
    if ! mount | grep -q "$device_or_mount"; then
        echo -e "${YELLOW}!${NC} Device not mounted"
        return 0
    fi
    
    # Get mount point for notifications
    local mount_point=$(mount | grep "$device_or_mount" | awk '{print $3}')
    
    # Safe unmount with sync
    sync
    
    # Try normal unmount first
    if [ "$force" = "force" ]; then
        sudo umount -f "$device_or_mount"
    else
        sudo umount "$device_or_mount"
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} Device unmounted successfully"
        
        # Clean up empty mount point
        if [ -n "$mount_point" ] && [ -d "$mount_point" ]; then
            sudo rmdir "$mount_point" 2>/dev/null || true
        fi
        
        # Log unmount operation
        echo "$(date):UNMOUNT:$device_or_mount" >> "$DEVICES_DB"
        
        # Show notification
        if [ "$SHOW_NOTIFICATIONS" = "true" ] && command -v notify-send >/dev/null; then
            notify-send "Storage Manager" "Device safely unmounted"
        fi
        
        return 0
    else
        echo -e "${RED}✗${NC} Failed to unmount device"
        echo -e "${YELLOW}Try force unmount or check if files are in use${NC}"
        
        # Show processes using the mount
        if command -v lsof >/dev/null; then
            echo -e "\n${WHITE}Processes using the device:${NC}"
            sudo lsof +D "$mount_point" 2>/dev/null || true
        fi
        
        return 1
    fi
}

# Format storage device
format_device() {
    local device="$1"
    local filesystem="$2"
    local label="$3"
    local quick="$4"
    
    if [ -z "$device" ] || [ -z "$filesystem" ]; then
        echo -e "${RED}✗${NC} Device and filesystem required"
        return 1
    fi
    
    echo -e "${BLUE}Formatting device: $device${NC}"
    echo -e "${CYAN}Filesystem: $filesystem${NC}"
    
    # Safety warning
    if [ "$FORMAT_WARNING" = "true" ]; then
        echo -e "${RED}WARNING: This will erase all data on $device${NC}"
        echo -ne "${YELLOW}Type 'YES' to confirm:${NC} "
        read -r confirmation
        
        if [ "$confirmation" != "YES" ]; then
            echo -e "${YELLOW}Format operation cancelled${NC}"
            return 1
        fi
    fi
    
    # Unmount if mounted
    if mount | grep -q "$device"; then
        echo -e "${CYAN}Unmounting device first...${NC}"
        unmount_device "$device"
    fi
    
    # Format based on filesystem type
    echo -e "${CYAN}Formatting as $filesystem...${NC}"
    
    local format_cmd=""
    local format_opts=""
    
    # Quick format option
    if [ "$quick" = "quick" ]; then
        format_opts="-q"
    fi
    
    case "$filesystem" in
        ext2)
            format_cmd="sudo mkfs.ext2 $format_opts"
            [ -n "$label" ] && format_cmd="$format_cmd -L \"$label\""
            ;;
        ext3)
            format_cmd="sudo mkfs.ext3 $format_opts"
            [ -n "$label" ] && format_cmd="$format_cmd -L \"$label\""
            ;;
        ext4)
            format_cmd="sudo mkfs.ext4 $format_opts"
            [ -n "$label" ] && format_cmd="$format_cmd -L \"$label\""
            ;;
        ntfs)
            format_cmd="sudo mkfs.ntfs -f"
            [ -n "$label" ] && format_cmd="$format_cmd -L \"$label\""
            ;;
        fat32|vfat)
            format_cmd="sudo mkfs.vfat -F 32"
            [ -n "$label" ] && format_cmd="$format_cmd -n \"$label\""
            ;;
        exfat)
            format_cmd="sudo mkfs.exfat"
            [ -n "$label" ] && format_cmd="$format_cmd -n \"$label\""
            ;;
        btrfs)
            format_cmd="sudo mkfs.btrfs -f"
            [ -n "$label" ] && format_cmd="$format_cmd -L \"$label\""
            ;;
        xfs)
            format_cmd="sudo mkfs.xfs -f"
            [ -n "$label" ] && format_cmd="$format_cmd -L \"$label\""
            ;;
        *)
            echo -e "${RED}✗${NC} Unsupported filesystem: $filesystem"
            return 1
            ;;
    esac
    
    # Execute format command
    if eval "$format_cmd $device"; then
        echo -e "${GREEN}✓${NC} Device formatted successfully"
        
        # Log format operation
        echo "$(date):FORMAT:$device:$filesystem:$label" >> "$DEVICES_DB"
        
        return 0
    else
        echo -e "${RED}✗${NC} Failed to format device"
        return 1
    fi
}

# Create partition table
create_partition_table() {
    local device="$1"
    local table_type="${2:-gpt}"
    
    if [ -z "$device" ]; then
        echo -e "${RED}✗${NC} Device required"
        return 1
    fi
    
    echo -e "${BLUE}Creating $table_type partition table on: $device${NC}"
    
    # Safety warning
    echo -e "${RED}WARNING: This will destroy the existing partition table${NC}"
    echo -ne "${YELLOW}Type 'YES' to confirm:${NC} "
    read -r confirmation
    
    if [ "$confirmation" != "YES" ]; then
        echo -e "${YELLOW}Operation cancelled${NC}"
        return 1
    fi
    
    # Backup MBR if enabled
    if [ "$BACKUP_MBR" = "true" ]; then
        local backup_file="$STORAGE_CONFIG_DIR/mbr_backup_$(basename "$device")_$(date +%Y%m%d_%H%M%S)"
        sudo dd if="$device" of="$backup_file" bs=512 count=1 2>/dev/null
        echo -e "${GREEN}✓${NC} MBR backed up to: $backup_file"
    fi
    
    # Create partition table using parted
    if command -v parted >/dev/null; then
        if sudo parted "$device" mklabel "$table_type"; then
            echo -e "${GREEN}✓${NC} $table_type partition table created"
            return 0
        fi
    fi
    
    echo -e "${RED}✗${NC} Failed to create partition table"
    return 1
}

# Create partition
create_partition() {
    local device="$1"
    local start="$2"
    local end="$3"
    local filesystem="$4"
    
    if [ -z "$device" ] || [ -z "$start" ] || [ -z "$end" ]; then
        echo -e "${RED}✗${NC} Device, start, and end positions required"
        return 1
    fi
    
    echo -e "${BLUE}Creating partition on: $device${NC}"
    echo -e "${CYAN}Start: $start, End: $end${NC}"
    
    # Create partition using parted
    if command -v parted >/dev/null; then
        local parted_cmd="sudo parted $device mkpart primary"
        [ -n "$filesystem" ] && parted_cmd="$parted_cmd $filesystem"
        parted_cmd="$parted_cmd $start $end"
        
        if eval "$parted_cmd"; then
            echo -e "${GREEN}✓${NC} Partition created successfully"
            
            # Align partition if enabled
            if [ "$PARTITION_ALIGNMENT" = "true" ]; then
                sudo parted "$device" align-check optimal 1 2>/dev/null || true
            fi
            
            return 0
        fi
    fi
    
    echo -e "${RED}✗${NC} Failed to create partition"
    return 1
}

# Check disk health (SMART)
check_disk_health() {
    local device="$1"
    
    if [ -z "$device" ]; then
        echo -e "${RED}✗${NC} Device required"
        return 1
    fi
    
    echo -e "${BLUE}Checking disk health: $device${NC}"
    
    if ! command -v smartctl >/dev/null; then
        echo -e "${RED}✗${NC} smartctl not available. Install smartmontools package."
        return 1
    fi
    
    # Check if SMART is enabled
    echo -e "${CYAN}SMART Status:${NC}"
    local smart_status=$(sudo smartctl -H "$device" 2>/dev/null)
    echo "$smart_status"
    
    # Show basic disk information
    echo -e "\n${CYAN}Disk Information:${NC}"
    sudo smartctl -i "$device" 2>/dev/null | grep -E "Model|Serial|Capacity|Sector"
    
    # Show SMART attributes
    echo -e "\n${CYAN}Critical SMART Attributes:${NC}"
    sudo smartctl -A "$device" 2>/dev/null | grep -E "Reallocated_Sector|Current_Pending|Offline_Uncorrectable|Temperature|Power_On_Hours" | head -5
    
    # Show test results
    echo -e "\n${CYAN}Self-Test Results:${NC}"
    sudo smartctl -l selftest "$device" 2>/dev/null | head -10
}

# Monitor storage usage
monitor_storage_usage() {
    echo -e "${BLUE}Storage Usage Monitor${NC}"
    echo -e "${GRAY}Press Ctrl+C to stop monitoring${NC}"
    echo
    
    while true; do
        clear
        echo -e "${PURPLE}=== Storage Usage Monitor ===${NC}"
        echo -e "${CYAN}Timestamp: $(date)${NC}"
        echo
        
        # Disk usage summary
        echo -e "${WHITE}Disk Usage Summary:${NC}"
        df -h | head -1  # Header
        df -h | grep -E "^/dev/" | while read -r line; do
            local usage_percent=$(echo "$line" | awk '{print $5}' | tr -d '%')
            local color="$GREEN"
            
            if [ "$usage_percent" -gt 90 ]; then
                color="$RED"
            elif [ "$usage_percent" -gt 75 ]; then
                color="$YELLOW"
            fi
            
            echo -e "${color}$line${NC}"
        done
        
        echo
        
        # I/O statistics if available
        if command -v iostat >/dev/null; then
            echo -e "${WHITE}I/O Statistics:${NC}"
            iostat -d 1 1 | tail -n +4 | head -5
        fi
        
        sleep 5
    done
}

# Auto-mount management
manage_auto_mount() {
    echo -e "${BLUE}Auto-mount Management${NC}"
    echo
    
    # Show current auto-mount status
    echo -e "${WHITE}Current Settings:${NC}"
    echo -e "${CYAN}Auto-mount USB:${NC} $AUTO_MOUNT_USB"
    echo -e "${CYAN}Auto-mount External:${NC} $AUTO_MOUNT_EXTERNAL"
    echo
    
    # Show devices that would be auto-mounted
    echo -e "${WHITE}Detectable Storage Devices:${NC}"
    lsblk -f | grep -v "^loop"
    
    echo
    echo -e "${WHITE}Auto-mount Rules:${NC}"
    if [ -f "/etc/udev/rules.d/99-bluejay-automount.rules" ]; then
        echo -e "${GREEN}✓${NC} Custom udev rules active"
        cat /etc/udev/rules.d/99-bluejay-automount.rules
    else
        echo -e "${YELLOW}!${NC} No custom udev rules found"
        echo -e "${CYAN}Would you like to create auto-mount rules? (y/N):${NC}"
        read -r create_rules
        
        if [ "$create_rules" = "y" ] || [ "$create_rules" = "Y" ]; then
            create_auto_mount_rules
        fi
    fi
}

# Create auto-mount udev rules
create_auto_mount_rules() {
    echo -e "${BLUE}Creating auto-mount udev rules...${NC}"
    
    local rules_file="/tmp/99-bluejay-automount.rules"
    cat > "$rules_file" << 'EOF'
# BluejayLinux Auto-mount Rules
# USB storage devices
SUBSYSTEM=="block", ATTRS{removable}=="1", ACTION=="add", RUN+="/usr/local/bin/bluejay-auto-mount %k"
SUBSYSTEM=="block", ATTRS{removable}=="1", ACTION=="remove", RUN+="/usr/local/bin/bluejay-auto-unmount %k"

# External storage devices
SUBSYSTEM=="block", KERNEL=="sd*", ACTION=="add", ATTRS{removable}=="0", ENV{ID_BUS}=="usb", RUN+="/usr/local/bin/bluejay-auto-mount %k"
SUBSYSTEM=="block", KERNEL=="sd*", ACTION=="remove", ATTRS{removable}=="0", ENV{ID_BUS}=="usb", RUN+="/usr/local/bin/bluejay-auto-unmount %k"
EOF
    
    # Create auto-mount script
    local mount_script="/tmp/bluejay-auto-mount"
    cat > "$mount_script" << 'EOF'
#!/bin/bash
# Auto-mount script for BluejayLinux
DEVICE="/dev/$1"
MOUNT_POINT="/media/bluejay/$1"

if [ -b "$DEVICE" ]; then
    mkdir -p "$MOUNT_POINT"
    mount -o defaults,user "$DEVICE" "$MOUNT_POINT"
    chown $(logname):$(logname) "$MOUNT_POINT" 2>/dev/null || true
fi
EOF
    
    # Create auto-unmount script
    local unmount_script="/tmp/bluejay-auto-unmount"
    cat > "$unmount_script" << 'EOF'
#!/bin/bash
# Auto-unmount script for BluejayLinux
MOUNT_POINT="/media/bluejay/$1"

if mountpoint -q "$MOUNT_POINT"; then
    umount "$MOUNT_POINT"
    rmdir "$MOUNT_POINT" 2>/dev/null || true
fi
EOF
    
    # Install files
    sudo cp "$rules_file" /etc/udev/rules.d/
    sudo cp "$mount_script" /usr/local/bin/
    sudo cp "$unmount_script" /usr/local/bin/
    
    sudo chmod +x /usr/local/bin/bluejay-auto-mount
    sudo chmod +x /usr/local/bin/bluejay-auto-unmount
    
    # Reload udev rules
    sudo udevadm control --reload-rules
    
    echo -e "${GREEN}✓${NC} Auto-mount rules created and activated"
    
    # Clean up temp files
    rm -f "$rules_file" "$mount_script" "$unmount_script"
}

# Settings menu
settings_menu() {
    echo -e "\n${PURPLE}=== Storage Manager Settings ===${NC}"
    echo -e "${WHITE}1.${NC} Auto-mount USB: ${AUTO_MOUNT_USB}"
    echo -e "${WHITE}2.${NC} Auto-mount external: ${AUTO_MOUNT_EXTERNAL}"
    echo -e "${WHITE}3.${NC} Show notifications: ${SHOW_NOTIFICATIONS}"
    echo -e "${WHITE}4.${NC} Safe removal required: ${SAFE_REMOVAL_REQUIRED}"
    echo -e "${WHITE}5.${NC} Filesystem check: ${FILESYSTEM_CHECK}"
    echo -e "${WHITE}6.${NC} SMART monitoring: ${SMART_MONITORING}"
    echo -e "${WHITE}7.${NC} Preferred filesystem: ${PREFERRED_FILESYSTEM}"
    echo -e "${WHITE}8.${NC} Storage encryption: ${STORAGE_ENCRYPTION}"
    echo -e "${WHITE}s.${NC} Save settings"
    echo -e "${WHITE}q.${NC} Back to main menu"
    echo
    
    echo -ne "${YELLOW}Select option:${NC} "
    read -r choice
    
    case "$choice" in
        1)
            echo -ne "${CYAN}Auto-mount USB devices (true/false):${NC} "
            read -r AUTO_MOUNT_USB
            ;;
        2)
            echo -ne "${CYAN}Auto-mount external drives (true/false):${NC} "
            read -r AUTO_MOUNT_EXTERNAL
            ;;
        3)
            echo -ne "${CYAN}Show mount/unmount notifications (true/false):${NC} "
            read -r SHOW_NOTIFICATIONS
            ;;
        4)
            echo -ne "${CYAN}Require safe removal (true/false):${NC} "
            read -r SAFE_REMOVAL_REQUIRED
            ;;
        5)
            echo -ne "${CYAN}Auto filesystem check (true/false):${NC} "
            read -r FILESYSTEM_CHECK
            ;;
        6)
            echo -ne "${CYAN}Enable SMART monitoring (true/false):${NC} "
            read -r SMART_MONITORING
            ;;
        7)
            echo -ne "${CYAN}Preferred filesystem (ext4/ntfs/exfat):${NC} "
            read -r PREFERRED_FILESYSTEM
            ;;
        8)
            echo -ne "${CYAN}Enable storage encryption (true/false):${NC} "
            read -r STORAGE_ENCRYPTION
            ;;
        s|S)
            cat > "$STORAGE_CONFIG_DIR/settings.conf" << EOF
# BluejayLinux Storage Manager Settings
AUTO_MOUNT_USB=$AUTO_MOUNT_USB
AUTO_MOUNT_EXTERNAL=$AUTO_MOUNT_EXTERNAL
SHOW_NOTIFICATIONS=$SHOW_NOTIFICATIONS
SAFE_REMOVAL_REQUIRED=$SAFE_REMOVAL_REQUIRED
FORMAT_WARNING=$FORMAT_WARNING
FILESYSTEM_CHECK=$FILESYSTEM_CHECK
SMART_MONITORING=$SMART_MONITORING
DISK_USAGE_ALERTS=$DISK_USAGE_ALERTS
STORAGE_ENCRYPTION=$STORAGE_ENCRYPTION
DEFAULT_MOUNT_OPTIONS=$DEFAULT_MOUNT_OPTIONS
PREFERRED_FILESYSTEM=$PREFERRED_FILESYSTEM
AUTO_FSCK=$AUTO_FSCK
MOUNT_TIMEOUT=$MOUNT_TIMEOUT
UNMOUNT_TIMEOUT=$UNMOUNT_TIMEOUT
THUMBNAIL_GENERATION=$THUMBNAIL_GENERATION
INDEX_CONTENT=$INDEX_CONTENT
BACKUP_MBR=$BACKUP_MBR
RAID_SUPPORT=$RAID_SUPPORT
LVM_SUPPORT=$LVM_SUPPORT
PARTITION_ALIGNMENT=$PARTITION_ALIGNMENT
EOF
            echo -e "${GREEN}✓${NC} Settings saved"
            ;;
    esac
}

# Main menu
main_menu() {
    echo -e "${PURPLE}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                 ${WHITE}BluejayLinux Storage Manager${PURPLE}                   ║${NC}"
    echo -e "${PURPLE}║              ${CYAN}Advanced USB & Storage Management${PURPLE}               ║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # Show storage overview
    local total_storage=$(df -h --total | tail -1 | awk '{print $2}')
    local used_storage=$(df -h --total | tail -1 | awk '{print $3}')
    local available_storage=$(df -h --total | tail -1 | awk '{print $4}')
    
    echo -e "${WHITE}Storage Overview:${NC} ${used_storage}/${total_storage} used (${available_storage} available)"
    echo
    
    echo -e "${WHITE}Device Management:${NC}"
    echo -e "${WHITE}1.${NC} Detect storage devices"
    echo -e "${WHITE}2.${NC} List mounted devices"
    echo -e "${WHITE}3.${NC} Show device info"
    echo -e "${WHITE}4.${NC} Mount device"
    echo -e "${WHITE}5.${NC} Unmount device"
    echo
    echo -e "${WHITE}Disk Operations:${NC}"
    echo -e "${WHITE}6.${NC} Format device"
    echo -e "${WHITE}7.${NC} Create partition table"
    echo -e "${WHITE}8.${NC} Create partition"
    echo -e "${WHITE}9.${NC} Check disk health"
    echo
    echo -e "${WHITE}Monitoring & Management:${NC}"
    echo -e "${WHITE}10.${NC} Monitor storage usage"
    echo -e "${WHITE}11.${NC} Auto-mount management"
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
                detect_storage_devices
                ;;
            --list)
                list_mounted_devices
                ;;
            --info)
                show_device_info "$2"
                ;;
            --mount)
                mount_device "$2" "$3" "$4" "$5"
                ;;
            --unmount)
                unmount_device "$2" "$3"
                ;;
            --format)
                format_device "$2" "$3" "$4" "$5"
                ;;
            --health)
                check_disk_health "$2"
                ;;
            --help|-h)
                echo "BluejayLinux Storage Manager"
                echo "Usage: $0 [options] [parameters]"
                echo "  --detect                    Detect storage devices"
                echo "  --list                      List mounted devices"
                echo "  --info <device>             Show device information"
                echo "  --mount <dev> [mp] [fs] [opts]  Mount device"
                echo "  --unmount <device> [force]  Unmount device"
                echo "  --format <dev> <fs> [label] [quick]  Format device"
                echo "  --health <device>           Check disk health"
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
                detect_storage_devices
                ;;
            2)
                list_mounted_devices
                ;;
            3)
                echo -ne "${CYAN}Enter device path (e.g., /dev/sdb1):${NC} "
                read -r device
                if [ -n "$device" ]; then
                    show_device_info "$device"
                fi
                ;;
            4)
                echo -ne "${CYAN}Device to mount (e.g., /dev/sdb1):${NC} "
                read -r device
                echo -ne "${CYAN}Mount point (optional):${NC} "
                read -r mount_point
                echo -ne "${CYAN}Filesystem (auto):${NC} "
                read -r filesystem
                if [ -n "$device" ]; then
                    mount_device "$device" "$mount_point" "$filesystem"
                fi
                ;;
            5)
                list_mounted_devices
                echo -ne "\n${CYAN}Device/mount point to unmount:${NC} "
                read -r target
                if [ -n "$target" ]; then
                    echo -ne "${CYAN}Force unmount? (y/N):${NC} "
                    read -r force_opt
                    local force=""
                    [ "$force_opt" = "y" ] && force="force"
                    unmount_device "$target" "$force"
                fi
                ;;
            6)
                echo -ne "${CYAN}Device to format (e.g., /dev/sdb1):${NC} "
                read -r device
                echo -ne "${CYAN}Filesystem ($PREFERRED_FILESYSTEM):${NC} "
                read -r filesystem
                filesystem="${filesystem:-$PREFERRED_FILESYSTEM}"
                echo -ne "${CYAN}Volume label (optional):${NC} "
                read -r label
                echo -ne "${CYAN}Quick format? (y/N):${NC} "
                read -r quick_opt
                local quick=""
                [ "$quick_opt" = "y" ] && quick="quick"
                if [ -n "$device" ] && [ -n "$filesystem" ]; then
                    format_device "$device" "$filesystem" "$label" "$quick"
                fi
                ;;
            7)
                echo -ne "${CYAN}Device for partition table (e.g., /dev/sdb):${NC} "
                read -r device
                echo -ne "${CYAN}Partition table type (gpt/msdos):${NC} "
                read -r table_type
                table_type="${table_type:-gpt}"
                if [ -n "$device" ]; then
                    create_partition_table "$device" "$table_type"
                fi
                ;;
            8)
                echo -ne "${CYAN}Device (e.g., /dev/sdb):${NC} "
                read -r device
                echo -ne "${CYAN}Start position (e.g., 1MiB):${NC} "
                read -r start
                echo -ne "${CYAN}End position (e.g., 100%):${NC} "
                read -r end
                echo -ne "${CYAN}Filesystem type (optional):${NC} "
                read -r filesystem
                if [ -n "$device" ] && [ -n "$start" ] && [ -n "$end" ]; then
                    create_partition "$device" "$start" "$end" "$filesystem"
                fi
                ;;
            9)
                echo -ne "${CYAN}Device to check (e.g., /dev/sda):${NC} "
                read -r device
                if [ -n "$device" ]; then
                    check_disk_health "$device"
                fi
                ;;
            10)
                monitor_storage_usage
                ;;
            11)
                manage_auto_mount
                ;;
            12)
                settings_menu
                ;;
            q|Q)
                echo -e "${GREEN}Storage Manager configuration saved${NC}"
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