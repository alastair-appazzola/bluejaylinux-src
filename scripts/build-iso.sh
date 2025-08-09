#!/bin/bash
# Build Blue-Jay Linux ISO

set -e

source ../build-bluejay.sh 2>/dev/null || {
    ROOTFS="/tmp/bluejay-build/rootfs"
    BUILD_ROOT="/tmp/bluejay-build"
    ISO_DIR="/tmp/bluejay-build/iso"
    BLUEJAY_VERSION="1.0.0"
}

log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $1"; }

check_iso_tools() {
    local tools=("xorriso" "mksquashfs" "unsquashfs")
    
    for tool in "${tools[@]}"; do
        if ! command -v $tool &> /dev/null; then
            log_error "Missing required tool: $tool"
            echo "Install with: sudo apt install xorriso squashfs-tools"
            exit 1
        fi
    done
}

create_iso_structure() {
    log_info "Creating ISO directory structure..."
    
    # Clean and create ISO directories
    rm -rf "${ISO_DIR}"
    mkdir -p "${ISO_DIR}"/{isolinux,live,boot}
    
    # Copy kernel
    cp "${ROOTFS}/boot/vmlinuz-"* "${ISO_DIR}/live/vmlinuz"
    
    log_success "ISO structure created"
}

create_initramfs() {
    log_info "Creating initramfs..."
    
    local initramfs_dir="${BUILD_ROOT}/initramfs"
    mkdir -p "${initramfs_dir}"
    
    # Create minimal initramfs structure
    mkdir -p "${initramfs_dir}"/{bin,sbin,etc,proc,sys,dev,mnt,root,tmp}
    
    # Copy essential binaries from rootfs
    cp "${ROOTFS}/bin/busybox" "${initramfs_dir}/bin/"
    
    # Create symlinks for busybox applets
    cd "${initramfs_dir}/bin"
    for applet in sh mount umount mkdir mknod switch_root; do
        ln -sf busybox "$applet"
    done
    cd - > /dev/null
    
    # Create init script for initramfs
    cat > "${initramfs_dir}/init" << 'EOF'
#!/bin/sh
# Blue-Jay Linux initramfs init

export PATH="/bin:/sbin"

# Mount essential filesystems
mount -t proc proc /proc
mount -t sysfs sysfs /sys

# Create device nodes
mknod /dev/null c 1 3
mknod /dev/console c 5 1

echo "Blue-Jay Linux initramfs starting..."

# Look for the squashfs root filesystem
for device in /sys/block/*/dev; do
    if [ -f "$device" ]; then
        devname=$(echo $device | sed 's|/sys/block/||; s|/dev||')
        mknod /dev/$devname b $(cat $device | tr ':' ' ')
        
        # Try to mount the device and look for our squashfs
        mkdir -p /mnt/cdrom
        if mount -o ro /dev/$devname /mnt/cdrom 2>/dev/null; then
            if [ -f /mnt/cdrom/live/filesystem.squashfs ]; then
                echo "Found Blue-Jay Linux live filesystem"
                
                # Mount the squashfs
                mkdir -p /mnt/squashfs
                mount -t squashfs -o loop /mnt/cdrom/live/filesystem.squashfs /mnt/squashfs
                
                # Switch to the real root
                echo "Switching to Blue-Jay Linux system..."
                exec switch_root /mnt/squashfs /sbin/init
            fi
            umount /mnt/cdrom
        fi
    fi
done

echo "Error: Could not find Blue-Jay Linux filesystem!"
echo "Dropping to emergency shell..."
exec /bin/sh
EOF
    chmod +x "${initramfs_dir}/init"
    
    # Create initramfs archive
    cd "${initramfs_dir}"
    find . | cpio -o -H newc | gzip > "${ISO_DIR}/live/initrd"
    cd - > /dev/null
    
    log_success "Initramfs created"
}

create_squashfs() {
    log_info "Creating SquashFS filesystem..."
    
    # Create compressed filesystem
    mksquashfs "${ROOTFS}" "${ISO_DIR}/live/filesystem.squashfs" \
        -comp xz -b 1M -Xdict-size 100% -no-xattrs -noappend
    
    log_success "SquashFS filesystem created"
}

install_bootloader() {
    log_info "Installing bootloader..."
    
    # Check if isolinux is available
    if [ ! -f /usr/lib/ISOLINUX/isolinux.bin ]; then
        log_error "ISOLINUX not found. Install with: sudo apt install isolinux"
        exit 1
    fi
    
    # Copy ISOLINUX files
    cp /usr/lib/ISOLINUX/isolinux.bin "${ISO_DIR}/isolinux/"
    cp /usr/lib/syslinux/modules/bios/{ldlinux.c32,libcom32.c32,libutil.c32,menu.c32} "${ISO_DIR}/isolinux/" 2>/dev/null || {
        log_warning "Some SYSLINUX modules not found, continuing anyway"
    }
    
    # Create ISOLINUX configuration
    cat > "${ISO_DIR}/isolinux/isolinux.cfg" << 'EOF'
DEFAULT menu.c32
PROMPT 0
MENU TITLE Blue-Jay Linux Live Boot Menu
TIMEOUT 100

LABEL bluejay
  MENU LABEL Blue-Jay Linux (Live)
  KERNEL /live/vmlinuz
  APPEND initrd=/live/initrd boot=live quiet splash

LABEL bluejay-safe
  MENU LABEL Blue-Jay Linux (Safe Mode)
  KERNEL /live/vmlinuz  
  APPEND initrd=/live/initrd boot=live single

LABEL memtest
  MENU LABEL Memory Test
  KERNEL /live/vmlinuz
  APPEND initrd=/live/initrd memtest

MENU SEPARATOR

LABEL local
  MENU LABEL Boot from Hard Disk
  LOCALBOOT 0x80

MENU SEPARATOR
MENU TITLE
MENU TITLE Blue-Jay Linux 1.0.0 "Reconnaissance"
MENU TITLE Cybersecurity Made Simple
EOF
    
    # Create boot info
    cat > "${ISO_DIR}/isolinux/boot.msg" << 'EOF'
Welcome to Blue-Jay Linux!

Press ENTER to boot Blue-Jay Linux, or wait for automatic boot.

For help and documentation, visit: https://bluejay-linux.org
EOF
    
    log_success "Bootloader installed"
}

create_iso() {
    log_info "Creating ISO image..."
    
    local iso_name="bluejay-linux-${BLUEJAY_VERSION}.iso"
    
    # Create the ISO
    xorriso -as mkisofs \
        -iso-level 3 \
        -full-iso9660-filenames \
        -volid "BLUEJAY_LINUX" \
        -appid "Blue-Jay Linux ${BLUEJAY_VERSION}" \
        -publisher "Blue-Jay Linux Project" \
        -preparer "Blue-Jay Build System" \
        -eltorito-boot isolinux/isolinux.bin \
        -eltorito-catalog isolinux/boot.cat \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
        -output "${BUILD_ROOT}/${iso_name}" \
        "${ISO_DIR}"
    
    # Make it bootable from USB
    if command -v isohybrid &> /dev/null; then
        isohybrid "${BUILD_ROOT}/${iso_name}"
    fi
    
    # Calculate checksums
    cd "${BUILD_ROOT}"
    sha256sum "${iso_name}" > "${iso_name}.sha256"
    md5sum "${iso_name}" > "${iso_name}.md5"
    cd - > /dev/null
    
    log_success "ISO image created: ${BUILD_ROOT}/${iso_name}"
    
    # Display ISO information
    local iso_size=$(du -h "${BUILD_ROOT}/${iso_name}" | cut -f1)
    log_info "ISO size: ${iso_size}"
    log_info "SHA256: $(cat "${BUILD_ROOT}/${iso_name}.sha256" | cut -d' ' -f1)"
}

create_documentation() {
    log_info "Creating ISO documentation..."
    
    mkdir -p "${ISO_DIR}/docs"
    
    # Create README for the ISO
    cat > "${ISO_DIR}/docs/README.txt" << 'EOF'
Blue-Jay Linux 1.0.0 "Reconnaissance"
===================================

Welcome to Blue-Jay Linux - Cybersecurity Made Simple

WHAT IS BLUE-JAY LINUX?
-----------------------
Blue-Jay Linux is a cybersecurity-focused Linux distribution that combines:
- The security tools and capabilities of Kali Linux
- The customizability and user control of Arch Linux  
- User-friendly design principles for easier adoption

BOOT OPTIONS:
------------
- Blue-Jay Linux (Live): Normal boot with full desktop environment
- Safe Mode: Boot with minimal drivers and services
- Memory Test: Test your system's RAM for errors
- Boot from Hard Disk: Boot your installed operating system

GETTING STARTED:
---------------
1. Boot from the USB/DVD
2. Select "Blue-Jay Linux (Live)" from the menu
3. Wait for the system to load
4. Run 'jay-tools' to see available security tools
5. Use 'sudo bluejay-install' to install to hard disk (future feature)

DEFAULT CREDENTIALS:
-------------------
Username: bluejay
Password: bluejay (change after installation)
Root Password: bluejay (change immediately)

TOOLS INCLUDED:
--------------
Network Analysis: nmap, netcat, tcpdump
Web Security: curl, burpsuite (placeholder)
Forensics: strings, hexdump, file analysis tools
Exploitation: metasploit (placeholder), searchsploit (placeholder)
Reverse Engineering: objdump, nm (placeholders)

SUPPORT:
--------
Documentation: https://bluejay-linux.org/docs
Community: https://bluejay-linux.org/community
Issues: https://github.com/bluejay-linux/bluejay/issues

LICENSE:
--------
Blue-Jay Linux is built from open source software.
Individual components retain their respective licenses.
Build system and Blue-Jay specific tools: GPL v3

DISCLAIMER:
----------
Blue-Jay Linux is intended for authorized security testing and
educational purposes only. Users are responsible for complying
with all applicable laws and regulations.

The Blue-Jay Linux Project
https://bluejay-linux.org
EOF
    
    log_success "Documentation created"
}

main() {
    log_info "Building Blue-Jay Linux ISO..."
    
    check_iso_tools
    create_iso_structure  
    create_initramfs
    create_squashfs
    install_bootloader
    create_documentation
    create_iso
    
    log_success "Blue-Jay Linux ISO build complete!"
    echo ""
    echo "Your Blue-Jay Linux ISO is ready:"
    echo "  Location: ${BUILD_ROOT}/bluejay-linux-${BLUEJAY_VERSION}.iso"
    echo "  Size: $(du -h "${BUILD_ROOT}/bluejay-linux-${BLUEJAY_VERSION}.iso" | cut -f1)"
    echo ""
    echo "To test your ISO:"
    echo "  1. Write to USB: dd if=bluejay-linux-${BLUEJAY_VERSION}.iso of=/dev/sdX bs=4M"
    echo "  2. Or use in VM: qemu-system-x86_64 -cdrom bluejay-linux-${BLUEJAY_VERSION}.iso -m 2048"
}

main "$@"