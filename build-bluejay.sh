#!/bin/bash
# Blue-Jay Linux Build System
# Main build script for creating Blue-Jay Linux distribution

set -e

BLUEJAY_VERSION="1.0.0"
BLUEJAY_CODENAME="Reconnaissance"
KERNEL_VERSION="6.16.0"

# Build directories
BUILD_ROOT="/tmp/bluejay-build"
ROOTFS="${BUILD_ROOT}/rootfs"
ISO_DIR="${BUILD_ROOT}/iso"
TOOLS_DIR="${BUILD_ROOT}/tools"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

check_dependencies() {
    log_info "Checking build dependencies..."
    
    local deps=("gcc" "make" "git" "wget" "curl" "xorriso" "mksquashfs" 
                "cpio" "gzip" "fakeroot" "busybox" "bc" "bison" "flex" 
                "libssl-dev" "libelf-dev" "pkg-config" "rsync")
    
    # Check for kernel-specific build dependencies
    local kernel_deps=("pahole" "dwarves" "python3")
    
    # Essential tools for cross-compilation
    local cross_deps=("gcc-multilib" "libc6-dev-i386")
    
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    # Check optional but recommended dependencies
    for dep in "${kernel_deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_warn "Recommended dependency missing: $dep"
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing critical dependencies: ${missing_deps[*]}"
        log_info "Install with: sudo apt-get install ${missing_deps[*]}"
        exit 1
    fi
    
    log_success "All dependencies satisfied"
}

setup_build_env() {
    log_info "Setting up build environment..."
    
    # Create build directories
    mkdir -p "${BUILD_ROOT}"
    mkdir -p "${ROOTFS}"
    mkdir -p "${ISO_DIR}"
    mkdir -p "${TOOLS_DIR}"
    
    # Export build variables
    export BLUEJAY_ROOT="${BUILD_ROOT}"
    export BLUEJAY_ROOTFS="${ROOTFS}"
    
    log_success "Build environment ready"
}

build_kernel() {
    log_info "Building Blue-Jay kernel..."
    
    # Use BluejayLinux optimized configuration
    if [ ! -f .config ]; then
        log_info "Using BluejayLinux kernel configuration..."
        if [ -f "arch/x86/configs/bluejay_defconfig" ]; then
            make bluejay_defconfig ARCH=x86_64
            log_success "BluejayLinux configuration loaded"
        else
            log_error "BluejayLinux config not found, falling back to defconfig"
            make defconfig
            
            # Enable critical security features
            scripts/config --enable CONFIG_SECURITY
            scripts/config --enable CONFIG_SECURITY_SELINUX
            scripts/config --enable CONFIG_SECURITY_APPARMOR
            scripts/config --enable CONFIG_HARDENED_USERCOPY
            scripts/config --enable CONFIG_FORTIFY_SOURCE
            scripts/config --enable CONFIG_STACKPROTECTOR_STRONG
            
            # Enable networking features for cybersec tools
            scripts/config --enable CONFIG_NETFILTER
        scripts/config --enable CONFIG_NETFILTER_XT_TARGET_LOG
        scripts/config --enable CONFIG_PACKET
        scripts/config --enable CONFIG_TUN
        
        # Enable container support
        scripts/config --enable CONFIG_NAMESPACES
        scripts/config --enable CONFIG_CGROUPS
        
        log_success "Kernel configured for Blue-Jay Linux"
    fi
    
    # Build kernel
    make -j$(nproc) bzImage modules
    
    # Install kernel and modules to rootfs
    mkdir -p "${ROOTFS}/boot"
    mkdir -p "${ROOTFS}/lib/modules"
    
    cp arch/x86/boot/bzImage "${ROOTFS}/boot/vmlinuz-${KERNEL_VERSION}-bluejay"
    make INSTALL_MOD_PATH="${ROOTFS}" modules_install
    
    log_success "Kernel built and installed"
}

build_stage() {
    local stage=$1
    log_info "Building stage: $stage"
    
    case $stage in
        "kernel")
            build_kernel
            ;;
        "rootfs")
            bash scripts/build-rootfs.sh
            ;;
        "tools")
            bash scripts/build-security-tools.sh
            ;;
        "packages")
            bash scripts/build-package-system.sh
            ;;
        "gui")
            bash scripts/build-gui.sh
            ;;
        "storage")
            bash scripts/build-storage-system.sh
            ;;
        "iso")
            bash scripts/build-iso.sh
            ;;
        *)
            log_error "Unknown stage: $stage"
            exit 1
            ;;
    esac
}

main() {
    log_info "Starting Blue-Jay Linux build (v${BLUEJAY_VERSION} '${BLUEJAY_CODENAME}')"
    
    check_dependencies
    setup_build_env
    
    # Build stages
    if [ $# -eq 0 ]; then
        # Full build
        build_stage "kernel"
        build_stage "rootfs" 
        build_stage "tools"
        build_stage "packages"
        build_stage "gui"
        build_stage "storage"
        build_stage "iso"
    else
        # Build specific stage
        for stage in "$@"; do
            build_stage "$stage"
        done
    fi
    
    log_success "Blue-Jay Linux build complete!"
    log_info "ISO location: ${ISO_DIR}/bluejay-linux-${BLUEJAY_VERSION}.iso"
}

# Show help
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Blue-Jay Linux Build System"
    echo "Usage: $0 [stage1] [stage2] ..."
    echo "Stages: kernel, rootfs, tools, packages, gui, iso"
    echo "Run without arguments to build all stages"
    exit 0
fi

main "$@"