#!/bin/bash
# Add Chrome to existing BluejayLinux build

set -e

log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $1"; }

# Source build configuration
source ../build-bluejay.sh 2>/dev/null || {
    ROOTFS="/tmp/bluejay-build/rootfs"
    BUILD_ROOT="/tmp/bluejay-build"
}

main() {
    log_info "Adding Google Chrome to existing BluejayLinux build..."
    
    # Check if rootfs exists
    if [ ! -d "$ROOTFS" ]; then
        log_error "BluejayLinux rootfs not found at: $ROOTFS"
        log_error "Please run './scripts/build-rootfs.sh' first"
        exit 1
    fi
    
    # Run Chrome installer
    if [ -x scripts/install-chrome.sh ]; then
        scripts/install-chrome.sh
        log_success "Chrome added to existing BluejayLinux build"
        
        echo ""
        echo "Chrome is now available in your BluejayLinux build!"
        echo "Run './scripts/build-complete-os.sh' to create a new ISO with Chrome"
    else
        log_error "Chrome installer not found"
        exit 1
    fi
}

main "$@"