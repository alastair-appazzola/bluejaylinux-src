#!/bin/bash
# BluejayLinux Bootloader Configuration Script

set -e

source ../build-bluejay.sh 2>/dev/null || {
    BUILD_ROOT="/tmp/bluejay-build"
    ROOTFS="${BUILD_ROOT}/rootfs"
    ISO_DIR="${BUILD_ROOT}/iso"
}

log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $1"; }

create_grub_config() {
    log_info "Creating GRUB bootloader configuration..."
    
    mkdir -p "${ISO_DIR}/boot/grub"
    
    cat > "${ISO_DIR}/boot/grub/grub.cfg" << 'EOF'
# BluejayLinux GRUB Configuration

set timeout=10
set default=0
set fallback=1

# Set GRUB theme colors
set color_normal=cyan/black
set color_highlight=white/blue

# Load video drivers
insmod all_video
insmod gfxterm

# Set graphics mode
set gfxmode=auto
terminal_output gfxterm

# Background image (if available)
if loadfont /boot/grub/fonts/unicode.pf2 ; then
    set gfxmode=auto
    load_video
    insmod gfxterm
    set locale_dir=$prefix/locale
    set lang=en_US
    insmod gettext
fi

# BluejayLinux ASCII Art
cat << 'LOGO'

 ____  _             _               _
| __ )| |_   _  ___ (_) __ _ _   _   | |   (_)_ __  _   ___  __
|  _ \| | | | |/ _ \| |/ _` | | | |  | |   | | '_ \| | | \ \/ /
| |_) | | |_| |  __/| | (_| | |_| |  | |___| | | | | |_| |>  <
|____/|_|\__,_|\___|| |\__,_|\__, |  |_____|_|_| |_|\__,_/_/\_\
                   |__/      |___/

        Cybersecurity Made Simple

LOGO

menuentry "BluejayLinux (Default)" {
    echo "Loading BluejayLinux kernel..."
    linux /boot/vmlinuz root=/dev/ram0 rw init=/sbin/init quiet splash bluejay.mode=default
    echo "Loading initial RAM disk..."
    initrd /boot/initrd.img
    echo "Starting BluejayLinux..."
}

menuentry "BluejayLinux (Debug Mode)" {
    echo "Loading BluejayLinux kernel in debug mode..."
    linux /boot/vmlinuz root=/dev/ram0 rw init=/sbin/init debug loglevel=7 bluejay.mode=debug
    echo "Loading initial RAM disk..."
    initrd /boot/initrd.img
    echo "Starting BluejayLinux in debug mode..."
}

menuentry "BluejayLinux (Safe Mode)" {
    echo "Loading BluejayLinux kernel in safe mode..."
    linux /boot/vmlinuz root=/dev/ram0 rw init=/sbin/init single nomodeset noacpi bluejay.mode=safe
    echo "Loading initial RAM disk..."
    initrd /boot/initrd.img
    echo "Starting BluejayLinux in safe mode..."
}

menuentry "BluejayLinux (Recovery Mode)" {
    echo "Loading BluejayLinux recovery environment..."
    linux /boot/vmlinuz root=/dev/ram0 rw init=/bin/sh emergency bluejay.mode=recovery
    echo "Loading recovery RAM disk..."
    initrd /boot/initrd.img
    echo "Starting BluejayLinux recovery shell..."
}

menuentry "Memory Test (Memtest86+)" {
    echo "Loading memory test..."
    linux16 /boot/memtest86+.bin
}

submenu "Advanced Options" {
    menuentry "BluejayLinux (Forensics Mode)" {
        echo "Loading BluejayLinux for digital forensics..."
        linux /boot/vmlinuz root=/dev/ram0 rw init=/sbin/init readonly forensics bluejay.mode=forensics
        echo "Loading forensics RAM disk..."
        initrd /boot/initrd.img
        echo "Starting BluejayLinux forensics environment..."
    }
    
    menuentry "BluejayLinux (Penetration Testing)" {
        echo "Loading BluejayLinux for penetration testing..."
        linux /boot/vmlinuz root=/dev/ram0 rw init=/sbin/init pentest bluejay.mode=pentest
        echo "Loading pentest RAM disk..."
        initrd /boot/initrd.img
        echo "Starting BluejayLinux penetration testing environment..."
    }
    
    menuentry "BluejayLinux (Network Analysis)" {
        echo "Loading BluejayLinux for network analysis..."
        linux /boot/vmlinuz root=/dev/ram0 rw init=/sbin/init netanalysis bluejay.mode=netanalysis
        echo "Loading network analysis RAM disk..."
        initrd /boot/initrd.img
        echo "Starting BluejayLinux network analysis environment..."
    }
    
    menuentry "BluejayLinux (Incident Response)" {
        echo "Loading BluejayLinux for incident response..."
        linux /boot/vmlinuz root=/dev/ram0 rw init=/sbin/init incident bluejay.mode=incident
        echo "Loading incident response RAM disk..."
        initrd /boot/initrd.img
        echo "Starting BluejayLinux incident response environment..."
    }
}

submenu "System Tools" {
    menuentry "Hardware Detection Tool" {
        echo "Loading hardware detection..."
        linux /boot/vmlinuz root=/dev/ram0 rw init=/sbin/init hwdetect bluejay.mode=hwdetect
        initrd /boot/initrd.img
    }
    
    menuentry "Disk Utility" {
        echo "Loading disk utility..."
        linux /boot/vmlinuz root=/dev/ram0 rw init=/sbin/init diskutil bluejay.mode=diskutil
        initrd /boot/initrd.img
    }
    
    menuentry "Network Configuration" {
        echo "Loading network configuration..."
        linux /boot/vmlinuz root=/dev/ram0 rw init=/sbin/init netconfig bluejay.mode=netconfig
        initrd /boot/initrd.img
    }
}

# UEFI Boot options
if [ "${grub_platform}" == "efi" ]; then
    menuentry "UEFI Firmware Settings" {
        fwsetup
    }
fi

# Legacy BIOS options  
if [ "${grub_platform}" == "pc" ]; then
    menuentry "Reboot" {
        reboot
    }
    
    menuentry "Shutdown" {
        halt
    }
fi

EOF

    log_success "GRUB configuration created"
}

create_syslinux_config() {
    log_info "Creating SYSLINUX bootloader configuration..."
    
    mkdir -p "${ISO_DIR}/isolinux"
    
    cat > "${ISO_DIR}/isolinux/isolinux.cfg" << 'EOF'
# BluejayLinux SYSLINUX Configuration
DEFAULT vesamenu.c32
PROMPT 0
TIMEOUT 100
ONTIMEOUT bluejay

# Menu configuration
MENU TITLE BluejayLinux Boot Menu
MENU BACKGROUND splash.png
MENU COLOR border 37;40    #80ffffff #00000000 std
MENU COLOR title  37;40    #ffffffff #00000000 std
MENU COLOR sel    7;37;40  #e0000000 #20ff8000 all
MENU COLOR unsel  37;40    #b0ffffff #00000000 std
MENU COLOR help   37;40    #c0ffffff #00000000 std
MENU COLOR timeout_msg 37;40 #80ffffff #00000000 std
MENU COLOR timeout 37;40   #c0ffffff #00000000 std
MENU COLOR msg07  37;40    #90ffffff #00000000 std
MENU COLOR tabmsg 37;40    #80ffffff #00000000 std

LABEL bluejay
    MENU LABEL ^BluejayLinux (Default)
    MENU DEFAULT
    KERNEL /boot/vmlinuz
    APPEND initrd=/boot/initrd.img root=/dev/ram0 rw init=/sbin/init quiet splash bluejay.mode=default
    TEXT HELP
        Start BluejayLinux with default settings optimized for cybersecurity.
    ENDTEXT

LABEL debug
    MENU LABEL BluejayLinux (^Debug Mode)
    KERNEL /boot/vmlinuz
    APPEND initrd=/boot/initrd.img root=/dev/ram0 rw init=/sbin/init debug loglevel=7 bluejay.mode=debug
    TEXT HELP
        Start BluejayLinux with verbose logging for troubleshooting.
    ENDTEXT

LABEL safe
    MENU LABEL BluejayLinux (^Safe Mode)
    KERNEL /boot/vmlinuz
    APPEND initrd=/boot/initrd.img root=/dev/ram0 rw init=/sbin/init single nomodeset noacpi bluejay.mode=safe
    TEXT HELP
        Start BluejayLinux with minimal drivers for maximum compatibility.
    ENDTEXT

LABEL recovery
    MENU LABEL BluejayLinux (^Recovery)
    KERNEL /boot/vmlinuz
    APPEND initrd=/boot/initrd.img root=/dev/ram0 rw init=/bin/sh emergency bluejay.mode=recovery
    TEXT HELP
        Start BluejayLinux recovery shell for system repair.
    ENDTEXT

LABEL forensics
    MENU LABEL BluejayLinux (^Forensics)
    KERNEL /boot/vmlinuz
    APPEND initrd=/boot/initrd.img root=/dev/ram0 rw init=/sbin/init readonly forensics bluejay.mode=forensics
    TEXT HELP
        Start BluejayLinux for digital forensics and evidence collection.
    ENDTEXT

LABEL pentest
    MENU LABEL BluejayLinux (^Penetration Testing)
    KERNEL /boot/vmlinuz
    APPEND initrd=/boot/initrd.img root=/dev/ram0 rw init=/sbin/init pentest bluejay.mode=pentest
    TEXT HELP
        Start BluejayLinux with penetration testing tools loaded.
    ENDTEXT

LABEL memtest
    MENU LABEL ^Memory Test
    KERNEL /boot/memtest86+.bin
    TEXT HELP
        Test system memory for errors using Memtest86+.
    ENDTEXT

MENU SEPARATOR

LABEL reboot
    MENU LABEL ^Reboot
    COM32 reboot.c32
    TEXT HELP
        Restart the computer.
    ENDTEXT

LABEL poweroff
    MENU LABEL ^Power Off
    COM32 poweroff.c32
    TEXT HELP
        Shut down the computer.
    ENDTEXT

EOF

    log_success "SYSLINUX configuration created"
}

install_bootloader_files() {
    log_info "Installing bootloader files..."
    
    # Create boot directory structure
    mkdir -p "${ISO_DIR}/boot"
    mkdir -p "${ISO_DIR}/EFI/BOOT"
    
    # Copy kernel and initrd (these should be built first)
    if [ -f "/boot/vmlinuz" ]; then
        cp "/boot/vmlinuz" "${ISO_DIR}/boot/vmlinuz"
        log_success "Kernel copied"
    else
        log_error "Kernel not found at /boot/vmlinuz"
        return 1
    fi
    
    # Create initrd from rootfs
    if [ -d "${ROOTFS}" ]; then
        log_info "Creating initrd from rootfs..."
        cd "${ROOTFS}"
        find . | cpio -o -H newc | gzip > "${ISO_DIR}/boot/initrd.img"
        log_success "Initrd created"
    else
        log_error "Rootfs not found at ${ROOTFS}"
        return 1
    fi
    
    # Copy GRUB files (if available)
    if command -v grub-mkrescue >/dev/null; then
        # GRUB will be installed during ISO creation
        log_info "GRUB bootloader will be installed during ISO creation"
    fi
    
    # Copy SYSLINUX files for legacy boot
    local syslinux_files=(
        "/usr/lib/ISOLINUX/isolinux.bin"
        "/usr/lib/syslinux/modules/bios/vesamenu.c32"
        "/usr/lib/syslinux/modules/bios/libcom32.c32"
        "/usr/lib/syslinux/modules/bios/libutil.c32"
        "/usr/lib/syslinux/modules/bios/reboot.c32"
        "/usr/lib/syslinux/modules/bios/poweroff.c32"
    )
    
    for file in "${syslinux_files[@]}"; do
        if [ -f "$file" ]; then
            cp "$file" "${ISO_DIR}/isolinux/"
            log_info "Copied $(basename "$file")"
        else
            log_error "SYSLINUX file not found: $file"
        fi
    done
    
    # Make isolinux.bin bootable
    if [ -f "${ISO_DIR}/isolinux/isolinux.bin" ]; then
        chmod 644 "${ISO_DIR}/isolinux/isolinux.bin"
    fi
    
    # Copy memtest86+ if available
    if [ -f "/boot/memtest86+.bin" ]; then
        cp "/boot/memtest86+.bin" "${ISO_DIR}/boot/"
        log_success "Memtest86+ copied"
    else
        log_info "Memtest86+ not found, skipping"
    fi
    
    log_success "Bootloader files installed"
}

create_efi_boot() {
    log_info "Creating EFI boot configuration..."
    
    mkdir -p "${ISO_DIR}/EFI/BOOT"
    
    # Create EFI boot configuration
    cat > "${ISO_DIR}/EFI/BOOT/grub.cfg" << 'EOF'
# BluejayLinux EFI Boot Configuration

set timeout=10
set default=0

menuentry "BluejayLinux" {
    linux /boot/vmlinuz root=/dev/ram0 rw init=/sbin/init quiet splash
    initrd /boot/initrd.img
}

menuentry "BluejayLinux (Debug)" {
    linux /boot/vmlinuz root=/dev/ram0 rw init=/sbin/init debug loglevel=7
    initrd /boot/initrd.img
}
EOF
    
    # Copy EFI bootloader if available
    if [ -f "/usr/lib/grub/x86_64-efi/grubx64.efi" ]; then
        cp "/usr/lib/grub/x86_64-efi/grubx64.efi" "${ISO_DIR}/EFI/BOOT/BOOTX64.EFI"
        log_success "EFI bootloader copied"
    else
        log_info "EFI bootloader not found, EFI boot may not work"
    fi
    
    log_success "EFI boot configuration created"
}

main() {
    log_info "Creating BluejayLinux bootloader configuration..."
    
    # Create bootloader configurations
    create_grub_config
    create_syslinux_config
    create_efi_boot
    
    # Install bootloader files
    install_bootloader_files
    
    log_success "BluejayLinux bootloader configuration completed"
}

main "$@"