#!/bin/bash
# BluejayLinux Complete OS Build Script
# This script builds the entire BluejayLinux OS from scratch

set -e

# Source main configuration
source ../build-bluejay.sh

log_info "Starting complete BluejayLinux OS build..."

print_banner() {
    echo
    echo "=============================================="
    echo "  $1"
    echo "=============================================="
    echo
}

build_complete_os() {
    print_banner "BluejayLinux Complete OS Build"
    
    log_info "This will build the complete BluejayLinux operating system"
    log_info "Estimated time: 30-60 minutes depending on hardware"
    echo
    
    # Step 1: Check dependencies
    print_banner "Step 1/8: Checking Dependencies"
    check_dependencies
    
    # Step 2: Setup build environment
    print_banner "Step 2/8: Setting Up Build Environment"
    setup_build_env
    
    # Step 3: Build kernel
    print_banner "Step 3/8: Building Kernel"
    build_kernel
    
    # Step 4: Build rootfs with Chrome
    print_banner "Step 4/8: Building Root Filesystem (with Chrome)"
    if [ -x scripts/build-rootfs.sh ]; then
        scripts/build-rootfs.sh
    else
        log_error "Root filesystem build script not found"
        exit 1
    fi
    
    # Step 5: Create device files and system integration
    print_banner "Step 5/8: Creating Device Files and System Integration"
    if [ -x scripts/create-devices.sh ]; then
        scripts/create-devices.sh
    else
        log_error "Device creation script not found"
        exit 1
    fi
    
    # Step 6: Create bootloader
    print_banner "Step 6/8: Creating Bootloader Configuration"
    if [ -x scripts/create-bootloader.sh ]; then
        scripts/create-bootloader.sh
    else
        log_error "Bootloader creation script not found"
        exit 1
    fi
    
    # Step 7: Create ISO
    print_banner "Step 7/8: Creating Bootable ISO"
    create_iso
    
    # Step 8: Run tests
    print_banner "Step 8/8: Running Comprehensive Tests"
    if [ -x scripts/test-bluejay.sh ]; then
        scripts/test-bluejay.sh
    else
        log_error "Test script not found"
        exit 1
    fi
    
    print_banner "Build Complete!"
    
    log_success "BluejayLinux OS build completed successfully!"
    echo
    echo "Output files:"
    echo "  Kernel: vmlinux"
    echo "  ISO: ${ISO_DIR}/bluejay-linux-${VERSION}.iso"
    echo "  Root filesystem: ${ROOTFS}/"
    echo
    echo "Included applications:"
    echo "  ✓ File Manager (bluejay-files)"
    echo "  ✓ Terminal (bluejay-terminal)"
    echo "  ✓ Text Editor (bluejay-editor)" 
    echo "  ✓ Google Chrome Browser (chrome-wrapper)"
    echo "  ✓ System Settings (bluejay-settings)"
    echo "  ✓ Medium-level managers (10 components)"
    echo
    echo "You can now:"
    echo "  1. Boot the ISO in a virtual machine with internet access"
    echo "  2. Write the ISO to a USB drive"
    echo "  3. Install BluejayLinux on physical hardware"
    echo "  4. Use Chrome browser: Run 'bluejay-browser-chrome' or click desktop icon"
    echo
    echo "For more information, see the documentation in BLUE_JAY_DESIGN.md"
}

create_iso() {
    log_info "Creating bootable ISO image..."
    
    # Ensure ISO directory exists
    mkdir -p "${ISO_DIR}"
    
    # Copy kernel and initrd
    if [ -f "arch/x86/boot/bzImage" ]; then
        cp "arch/x86/boot/bzImage" "${ISO_DIR}/boot/vmlinuz"
    elif [ -f "vmlinux" ]; then
        cp "vmlinux" "${ISO_DIR}/boot/vmlinuz"
    else
        log_error "Kernel image not found"
        return 1
    fi
    
    # Create initrd from rootfs
    log_info "Creating initrd from rootfs..."
    cd "${ROOTFS}"
    find . | cpio -o -H newc | gzip > "${ISO_DIR}/boot/initrd.img"
    cd - > /dev/null
    
    # Create ISO using genisoimage or xorriso
    local iso_file="${ISO_DIR}/bluejay-linux-${VERSION}.iso"
    
    if command -v xorriso >/dev/null 2>&1; then
        log_info "Creating ISO using xorriso..."
        xorriso -as mkisofs \
            -iso-level 3 \
            -full-iso9660-filenames \
            -volid "BLUEJAY_LINUX" \
            -appid "BluejayLinux ${VERSION}" \
            -publisher "BluejayLinux Project" \
            -preparer "BluejayLinux Build System" \
            -eltorito-boot isolinux/isolinux.bin \
            -eltorito-catalog isolinux/boot.cat \
            -no-emul-boot \
            -boot-load-size 4 \
            -boot-info-table \
            -eltorito-alt-boot \
            -e EFI/BOOT/BOOTX64.EFI \
            -no-emul-boot \
            -isohybrid-gpt-basdat \
            -output "$iso_file" \
            "${ISO_DIR}"
    elif command -v genisoimage >/dev/null 2>&1; then
        log_info "Creating ISO using genisoimage..."
        genisoimage \
            -o "$iso_file" \
            -b isolinux/isolinux.bin \
            -c isolinux/boot.cat \
            -no-emul-boot \
            -boot-load-size 4 \
            -boot-info-table \
            -V "BLUEJAY_LINUX" \
            -A "BluejayLinux ${VERSION}" \
            -publisher "BluejayLinux Project" \
            -preparer "BluejayLinux Build System" \
            -iso-level 3 \
            -full-iso9660-filenames \
            "${ISO_DIR}"
    else
        log_error "ISO creation tools not found (xorriso or genisoimage required)"
        return 1
    fi
    
    # Make ISO hybrid (bootable from USB)
    if command -v isohybrid >/dev/null 2>&1; then
        isohybrid "$iso_file"
        log_success "ISO made hybrid (USB bootable)"
    else
        log_warn "isohybrid not found, ISO may not be USB bootable"
    fi
    
    # Calculate checksum
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$iso_file" > "${iso_file}.sha256"
        log_success "SHA256 checksum created"
    fi
    
    log_success "ISO created: $iso_file"
    
    # Show ISO information
    local iso_size=$(du -h "$iso_file" | cut -f1)
    log_info "ISO size: $iso_size"
    
    return 0
}

# Show usage
show_usage() {
    echo "BluejayLinux Complete OS Build Script"
    echo
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -v, --verbose  Enable verbose output"
    echo "  -q, --quiet    Suppress non-essential output"
    echo "  --test-only    Run tests without building"
    echo "  --clean        Clean build artifacts first"
    echo
    echo "This script will build the complete BluejayLinux OS including:"
    echo "  - Kernel compilation with security features"
    echo "  - Root filesystem with security tools"
    echo "  - Bootloader configuration"
    echo "  - Device files and system integration"
    echo "  - Bootable ISO image"
    echo "  - Comprehensive testing"
    echo
}

# Handle command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        -q|--quiet)
            QUIET=1
            shift
            ;;
        --test-only)
            TEST_ONLY=1
            shift
            ;;
        --clean)
            CLEAN_FIRST=1
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    # Change to kernel source directory
    cd "$(dirname "$0")/.."
    
    # Clean if requested
    if [ "$CLEAN_FIRST" = "1" ]; then
        log_info "Cleaning previous build artifacts..."
        make clean 2>/dev/null || true
        rm -rf "${BUILD_ROOT}" 2>/dev/null || true
    fi
    
    # Test only mode
    if [ "$TEST_ONLY" = "1" ]; then
        log_info "Running tests only..."
        if [ -x scripts/test-bluejay.sh ]; then
            scripts/test-bluejay.sh
        else
            log_error "Test script not found"
            exit 1
        fi
        exit $?
    fi
    
    # Build complete OS
    build_complete_os
    
    echo
    log_success "BluejayLinux build completed successfully!"
    echo
    echo "Next steps:"
    echo "1. Test the ISO in a virtual machine:"
    echo "   qemu-system-x86_64 -cdrom ${ISO_DIR}/bluejay-linux-${VERSION}.iso -m 2048"
    echo
    echo "2. Write to USB drive (replace /dev/sdX with your device):"
    echo "   sudo dd if=${ISO_DIR}/bluejay-linux-${VERSION}.iso of=/dev/sdX bs=4M status=progress"
    echo
    echo "3. Boot from USB or CD/DVD"
    echo
}

main "$@"