#!/bin/bash
# BluejayLinux Comprehensive Testing and Validation Script

set -e

# Source build configuration
source ../build-bluejay.sh 2>/dev/null || {
    BUILD_ROOT="/tmp/bluejay-build"
    ROOTFS="${BUILD_ROOT}/rootfs"
    KERNEL_VERSION="6.16.0-bluejay"
}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNINGS=0

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[PASS]${NC} $1"; TESTS_PASSED=$((TESTS_PASSED + 1)); }
log_error() { echo -e "${RED}[FAIL]${NC} $1"; TESTS_FAILED=$((TESTS_FAILED + 1)); }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; TESTS_WARNINGS=$((TESTS_WARNINGS + 1)); }

print_header() {
    echo
    echo "=============================================="
    echo "  $1"
    echo "=============================================="
    echo
}

# Test kernel compilation
test_kernel() {
    print_header "Testing Kernel Build"
    
    # Check if kernel image exists
    if [ -f "vmlinux" ]; then
        log_success "Kernel image (vmlinux) exists"
    else
        log_error "Kernel image (vmlinux) not found"
        return 1
    fi
    
    # Check if kernel is the right version
    local kernel_version=$(file vmlinux | grep -o 'version [0-9.]*' | cut -d' ' -f2)
    if [ -n "$kernel_version" ]; then
        log_success "Kernel version detected: $kernel_version"
    else
        log_warn "Could not detect kernel version"
    fi
    
    # Check kernel configuration
    if [ -f ".config" ]; then
        log_success "Kernel configuration exists"
        
        # Check critical security features
        local security_features=(
            "CONFIG_SECURITY=y"
            "CONFIG_SECURITY_SELINUX=y" 
            "CONFIG_SECURITY_APPARMOR=y"
            "CONFIG_HARDENED_USERCOPY=y"
            "CONFIG_FORTIFY_SOURCE=y"
            "CONFIG_STACKPROTECTOR_STRONG=y"
        )
        
        for feature in "${security_features[@]}"; do
            if grep -q "^$feature" .config; then
                log_success "Security feature enabled: $feature"
            else
                log_warn "Security feature not enabled: $feature"
            fi
        done
        
        # Check networking features
        local network_features=(
            "CONFIG_NETFILTER=y"
            "CONFIG_NETFILTER_ADVANCED=y"
            "CONFIG_NF_CONNTRACK=y"
            "CONFIG_NETFILTER_XTABLES=y"
        )
        
        for feature in "${network_features[@]}"; do
            if grep -q "^$feature" .config; then
                log_success "Network feature enabled: $feature"
            else
                log_error "Critical network feature missing: $feature"
            fi
        done
        
    else
        log_error "Kernel configuration (.config) not found"
    fi
    
    # Check memory management
    if [ -d "mm" ]; then
        log_success "Memory management subsystem exists"
        
        # Check critical MM files
        local mm_files=("page_alloc.c" "memory.c" "mmap.c" "vmalloc.c" "slab_common.c")
        for file in "${mm_files[@]}"; do
            if [ -f "mm/$file" ]; then
                log_success "MM file exists: mm/$file"
            else
                log_error "Critical MM file missing: mm/$file"
            fi
        done
    else
        log_error "Memory management subsystem (mm/) not found"
    fi
    
    # Check filesystem support
    if [ -d "fs" ]; then
        log_success "Filesystem subsystem exists"
        
        # Check essential filesystems
        local filesystems=("ext4" "proc" "sysfs" "tmpfs" "devtmpfs")
        for fs in "${filesystems[@]}"; do
            if [ -d "fs/$fs" ] || grep -q "CONFIG_${fs^^}.*=y" .config 2>/dev/null; then
                log_success "Filesystem supported: $fs"
            else
                log_warn "Filesystem not found: $fs"
            fi
        done
    else
        log_error "Filesystem subsystem (fs/) not found"
    fi
    
    return 0
}

# Test rootfs structure
test_rootfs() {
    print_header "Testing Root Filesystem"
    
    if [ ! -d "$ROOTFS" ]; then
        log_error "Root filesystem directory not found: $ROOTFS"
        return 1
    fi
    
    log_success "Root filesystem directory exists: $ROOTFS"
    
    # Check essential directories
    local essential_dirs=(
        "bin" "sbin" "etc" "dev" "proc" "sys" "tmp" "var" "usr" "root" "home"
        "usr/bin" "usr/sbin" "var/log" "opt/bluejay"
    )
    
    for dir in "${essential_dirs[@]}"; do
        if [ -d "$ROOTFS/$dir" ]; then
            log_success "Directory exists: /$dir"
        else
            log_error "Essential directory missing: /$dir"
        fi
    done
    
    # Check essential files
    local essential_files=(
        "etc/passwd" "etc/group" "etc/shadow" "etc/fstab" 
        "etc/hostname" "etc/hosts" "etc/profile"
    )
    
    for file in "${essential_files[@]}"; do
        if [ -f "$ROOTFS/$file" ]; then
            log_success "File exists: /$file"
        else
            log_error "Essential file missing: /$file"
        fi
    done
    
    # Check init system
    if [ -x "$ROOTFS/sbin/init" ]; then
        log_success "Init system exists and is executable"
    else
        log_error "Init system missing or not executable"
    fi
    
    # Check device nodes
    local device_nodes=(
        "dev/null" "dev/zero" "dev/random" "dev/urandom" 
        "dev/console" "dev/tty" "dev/ptmx"
    )
    
    for device in "${device_nodes[@]}"; do
        if [ -e "$ROOTFS/$device" ]; then
            log_success "Device node exists: /$device"
        else
            log_error "Critical device node missing: /$device"
        fi
    done
    
    # Check BluejayLinux specific tools
    local bluejay_tools=(
        "usr/bin/bluejay-tools" "usr/bin/bluejay-help" 
        "usr/bin/bluejay-config" "usr/bin/bluejay-update"
    )
    
    for tool in "${bluejay_tools[@]}"; do
        if [ -x "$ROOTFS/$tool" ]; then
            log_success "BluejayLinux tool exists: /$tool"
        else
            log_error "BluejayLinux tool missing: /$tool"
        fi
    done
    
    return 0
}

# Test build scripts
test_build_scripts() {
    print_header "Testing Build Scripts"
    
    # Check main build script
    if [ -x "build-bluejay.sh" ]; then
        log_success "Main build script exists and is executable"
    else
        log_error "Main build script missing or not executable"
    fi
    
    # Check script directory
    if [ -d "scripts" ]; then
        log_success "Scripts directory exists"
        
        local build_scripts=(
            "build-rootfs.sh" "create-bootloader.sh" "create-devices.sh"
            "bluejay-init.sh" "test-bluejay.sh"
        )
        
        for script in "${build_scripts[@]}"; do
            if [ -x "scripts/$script" ]; then
                log_success "Script exists and is executable: $script"
            else
                log_error "Script missing or not executable: $script"
            fi
        done
    else
        log_error "Scripts directory not found"
    fi
    
    # Test script syntax
    log_info "Testing script syntax..."
    for script in build-bluejay.sh scripts/*.sh; do
        if [ -f "$script" ]; then
            if bash -n "$script" 2>/dev/null; then
                log_success "Script syntax OK: $(basename "$script")"
            else
                log_error "Script syntax error: $(basename "$script")"
            fi
        fi
    done
    
    return 0
}

# Test security configuration
test_security() {
    print_header "Testing Security Configuration"
    
    # Check SELinux configuration
    if [ -d "security/selinux" ]; then
        log_success "SELinux subsystem present"
    else
        log_warn "SELinux subsystem not found"
    fi
    
    # Check AppArmor configuration  
    if [ -d "security/apparmor" ]; then
        log_success "AppArmor subsystem present"
    else
        log_warn "AppArmor subsystem not found"
    fi
    
    # Check other security modules
    local security_modules=("landlock" "yama" "integrity")
    for module in "${security_modules[@]}"; do
        if [ -d "security/$module" ]; then
            log_success "Security module present: $module"
        else
            log_warn "Security module not found: $module"
        fi
    done
    
    # Check security-related configuration files
    if [ -f "$ROOTFS/etc/securetty" ]; then
        log_success "Secure TTY configuration exists"
    else
        log_warn "Secure TTY configuration missing"
    fi
    
    if [ -f "$ROOTFS/etc/login.defs" ]; then
        log_success "Login definitions exist"
        
        # Check password aging settings
        if grep -q "PASS_MAX_DAYS" "$ROOTFS/etc/login.defs"; then
            log_success "Password aging configured"
        else
            log_warn "Password aging not configured"
        fi
    else
        log_warn "Login definitions missing"
    fi
    
    # Check file permissions
    if [ -f "$ROOTFS/etc/shadow" ]; then
        local shadow_perms=$(stat -c "%a" "$ROOTFS/etc/shadow" 2>/dev/null)
        if [ "$shadow_perms" = "640" ] || [ "$shadow_perms" = "600" ]; then
            log_success "Shadow file has secure permissions: $shadow_perms"
        else
            log_error "Shadow file has insecure permissions: $shadow_perms"
        fi
    fi
    
    return 0
}

# Test network configuration
test_networking() {
    print_header "Testing Network Configuration"
    
    # Check network subsystem
    if [ -d "net" ]; then
        log_success "Network subsystem exists"
        
        # Check critical network components
        local net_components=("core" "ipv4" "ipv6" "netfilter")
        for component in "${net_components[@]}"; do
            if [ -d "net/$component" ]; then
                log_success "Network component exists: $component"
            else
                log_error "Critical network component missing: $component"
            fi
        done
        
        # Check netfilter components
        if [ -d "net/netfilter" ]; then
            local netfilter_files=("core.c" "nf_conntrack_core.c" "nf_tables_api.c")
            for file in "${netfilter_files[@]}"; do
                if [ -f "net/netfilter/$file" ]; then
                    log_success "Netfilter file exists: $file"
                else
                    log_warn "Netfilter file missing: $file"
                fi
            done
        fi
    else
        log_error "Network subsystem not found"
    fi
    
    # Check network configuration files
    if [ -f "$ROOTFS/etc/hosts" ]; then
        log_success "Hosts file exists"
    else
        log_error "Hosts file missing"
    fi
    
    if [ -f "$ROOTFS/etc/resolv.conf" ]; then
        log_success "DNS configuration exists"
    else
        log_warn "DNS configuration missing"
    fi
    
    if [ -f "$ROOTFS/etc/nsswitch.conf" ]; then
        log_success "Name service switch configuration exists"
    else
        log_warn "Name service switch configuration missing"
    fi
    
    return 0
}

# Test documentation and help
test_documentation() {
    print_header "Testing Documentation and Help"
    
    # Check README files
    local readme_files=("README" "README.md" "BLUE_JAY_DESIGN.md")
    for readme in "${readme_files[@]}"; do
        if [ -f "$readme" ]; then
            log_success "Documentation file exists: $readme"
        else
            log_warn "Documentation file missing: $readme"
        fi
    done
    
    # Check help system
    if [ -x "$ROOTFS/usr/bin/bluejay-help" ]; then
        log_success "Help system exists"
    else
        log_error "Help system missing"
    fi
    
    # Check man pages directory structure
    if [ -d "$ROOTFS/usr/share/man" ]; then
        log_success "Man pages directory exists"
    else
        log_warn "Man pages directory missing"
    fi
    
    # Check system information
    if [ -f "$ROOTFS/etc/issue" ]; then
        log_success "Login banner exists"
    else
        log_warn "Login banner missing"
    fi
    
    if [ -f "$ROOTFS/etc/motd" ]; then
        log_success "Message of the day exists"
    else
        log_warn "Message of the day missing"
    fi
    
    return 0
}

# Test build dependencies
test_dependencies() {
    print_header "Testing Build Dependencies"
    
    local critical_deps=("gcc" "make" "git" "wget" "curl")
    local optional_deps=("busybox" "xorriso" "mksquashfs" "cpio" "gzip")
    
    for dep in "${critical_deps[@]}"; do
        if command -v "$dep" >/dev/null 2>&1; then
            log_success "Critical dependency found: $dep"
        else
            log_error "Critical dependency missing: $dep"
        fi
    done
    
    for dep in "${optional_deps[@]}"; do
        if command -v "$dep" >/dev/null 2>&1; then
            log_success "Optional dependency found: $dep"
        else
            log_warn "Optional dependency missing: $dep"
        fi
    done
    
    # Check compiler version
    if command -v gcc >/dev/null 2>&1; then
        local gcc_version=$(gcc --version | head -1)
        log_success "GCC version: $gcc_version"
    fi
    
    # Check make version
    if command -v make >/dev/null 2>&1; then
        local make_version=$(make --version | head -1)
        log_success "Make version: $make_version"
    fi
    
    return 0
}

# Test system integrity
test_integrity() {
    print_header "Testing System Integrity"
    
    # Check for common issues
    log_info "Checking for common build issues..."
    
    # Check for empty directories that should have content
    if [ -d "$ROOTFS/dev" ]; then
        local dev_count=$(ls -1 "$ROOTFS/dev" | wc -l)
        if [ "$dev_count" -gt 10 ]; then
            log_success "Device directory has adequate content ($dev_count items)"
        else
            log_warn "Device directory seems sparse ($dev_count items)"
        fi
    fi
    
    # Check for proper symlinks
    if [ -L "$ROOTFS/etc/mtab" ]; then
        log_success "mtab is properly symlinked"
    else
        log_warn "mtab is not a symlink"
    fi
    
    # Check file sizes
    if [ -f "vmlinux" ]; then
        local kernel_size=$(stat -c%s "vmlinux" 2>/dev/null)
        if [ "$kernel_size" -gt 1000000 ]; then  # > 1MB
            log_success "Kernel size seems reasonable ($(( kernel_size / 1024 / 1024 )) MB)"
        else
            log_error "Kernel size seems too small ($(( kernel_size / 1024 )) KB)"
        fi
    fi
    
    # Check for build artifacts
    local build_artifacts=("*.o" "*.a" ".*.cmd" ".tmp_versions")
    for pattern in "${build_artifacts[@]}"; do
        if ls $pattern 1> /dev/null 2>&1; then
            log_warn "Build artifacts found: $pattern (consider cleaning)"
        fi
    done
    
    return 0
}

# Performance benchmarks
test_performance() {
    print_header "Performance Benchmarks"
    
    log_info "Running basic performance tests..."
    
    # Measure kernel build time estimate
    if [ -f "vmlinux" ]; then
        local kernel_mtime=$(stat -c %Y "vmlinux" 2>/dev/null)
        local config_mtime=$(stat -c %Y ".config" 2>/dev/null)
        if [ -n "$kernel_mtime" ] && [ -n "$config_mtime" ]; then
            local build_time=$(( kernel_mtime - config_mtime ))
            log_success "Kernel build took approximately $(( build_time / 60 )) minutes"
        fi
    fi
    
    # Check rootfs size
    if [ -d "$ROOTFS" ]; then
        local rootfs_size=$(du -sm "$ROOTFS" 2>/dev/null | cut -f1)
        if [ -n "$rootfs_size" ]; then
            log_success "Root filesystem size: ${rootfs_size} MB"
            if [ "$rootfs_size" -gt 2000 ]; then
                log_warn "Root filesystem is quite large (${rootfs_size} MB)"
            fi
        fi
    fi
    
    return 0
}

# Generate test report
generate_report() {
    print_header "Test Results Summary"
    
    local total_tests=$((TESTS_PASSED + TESTS_FAILED + TESTS_WARNINGS))
    
    echo "Test Results:"
    echo "============="
    echo -e "${GREEN}PASSED: ${TESTS_PASSED}${NC}"
    echo -e "${RED}FAILED: ${TESTS_FAILED}${NC}" 
    echo -e "${YELLOW}WARNINGS: ${TESTS_WARNINGS}${NC}"
    echo "TOTAL: ${total_tests}"
    echo
    
    if [ $TESTS_FAILED -eq 0 ]; then
        if [ $TESTS_WARNINGS -eq 0 ]; then
            echo -e "${GREEN}✅ ALL TESTS PASSED! BluejayLinux is ready for use.${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠️  All critical tests passed, but there are warnings to address.${NC}"
            return 0
        fi
    else
        echo -e "${RED}❌ CRITICAL ISSUES FOUND! BluejayLinux may not function properly.${NC}"
        echo
        echo "Please address the failed tests before proceeding."
        return 1
    fi
}

# Main test execution
main() {
    echo "BluejayLinux Comprehensive Test Suite"
    echo "====================================="
    echo "Testing BluejayLinux build and configuration..."
    echo
    
    # Change to kernel source directory
    cd "$(dirname "$0")/.."
    
    # Run all tests
    test_dependencies
    test_kernel
    test_rootfs  
    test_build_scripts
    test_security
    test_networking
    test_documentation
    test_integrity
    test_performance
    
    # Generate final report
    generate_report
    return $?
}

# Run tests
main "$@"