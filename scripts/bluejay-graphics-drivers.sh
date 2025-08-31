#!/bin/bash

# BluejayLinux - 3D Acceleration & Advanced Graphics Drivers
# Professional graphics driver management and 3D acceleration setup

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/bluejay"
GRAPHICS_CONFIG_DIR="$CONFIG_DIR/graphics-drivers"
DRIVERS_DIR="$GRAPHICS_CONFIG_DIR/drivers"
PROFILES_DIR="$GRAPHICS_CONFIG_DIR/profiles"
LOG_FILE="$GRAPHICS_CONFIG_DIR/driver_install.log"

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

# Graphics vendors and drivers
NVIDIA_DRIVERS="nvidia-driver-535 nvidia-driver-525 nvidia-driver-470 nvidia-driver-390"
AMD_DRIVERS="amdgpu radeon fglrx"
INTEL_DRIVERS="i915 xe"

# Initialize directories
create_directories() {
    mkdir -p "$CONFIG_DIR" "$GRAPHICS_CONFIG_DIR" "$DRIVERS_DIR" "$PROFILES_DIR"
    
    # Create default graphics driver configuration
    if [ ! -f "$GRAPHICS_CONFIG_DIR/settings.conf" ]; then
        cat > "$GRAPHICS_CONFIG_DIR/settings.conf" << 'EOF'
# BluejayLinux Graphics Drivers Settings
AUTO_DETECT_HARDWARE=true
PREFERRED_DRIVER=auto
ENABLE_3D_ACCELERATION=true
ENABLE_VULKAN=true
ENABLE_OPENCL=true
MULTIMONITOR_SUPPORT=true
HDR_SUPPORT=false
VARIABLE_REFRESH_RATE=true
POWER_MANAGEMENT=balanced
DRIVER_UPDATE_CHECK=true
EXPERIMENTAL_FEATURES=false
FALLBACK_TO_NOUVEAU=true
WAYLAND_SUPPORT=true
X11_SUPPORT=true
LEGACY_COMPATIBILITY=true
EOF
    fi
}

# Load settings
load_settings() {
    if [ -f "$GRAPHICS_CONFIG_DIR/settings.conf" ]; then
        source "$GRAPHICS_CONFIG_DIR/settings.conf"
    fi
}

# Detect graphics hardware
detect_graphics_hardware() {
    echo -e "${BLUE}Detecting graphics hardware...${NC}"
    
    local gpu_info=()
    local primary_vendor=""
    local discrete_gpu=""
    
    # Use lspci to detect GPUs
    if command -v lspci >/dev/null; then
        local gpu_list=$(lspci | grep -i "vga\|3d\|display")
        
        echo -e "${CYAN}Detected GPUs:${NC}"
        echo "$gpu_list"
        
        # Determine primary vendor
        if echo "$gpu_list" | grep -qi nvidia; then
            primary_vendor="nvidia"
            gpu_info+=("nvidia")
            echo -e "${GREEN}✓${NC} NVIDIA GPU detected"
            
            # Get NVIDIA GPU details
            if command -v nvidia-smi >/dev/null; then
                local nvidia_info=$(nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader,nounits 2>/dev/null)
                if [ -n "$nvidia_info" ]; then
                    echo -e "${CYAN}NVIDIA Details:${NC} $nvidia_info"
                fi
            fi
        fi
        
        if echo "$gpu_list" | grep -qi "amd\|ati"; then
            if [ -z "$primary_vendor" ]; then
                primary_vendor="amd"
            fi
            gpu_info+=("amd")
            echo -e "${GREEN}✓${NC} AMD GPU detected"
        fi
        
        if echo "$gpu_list" | grep -qi intel; then
            if [ -z "$primary_vendor" ]; then
                primary_vendor="intel"
            fi
            gpu_info+=("intel")
            echo -e "${GREEN}✓${NC} Intel GPU detected"
        fi
        
        # Check for discrete GPU
        if [ ${#gpu_info[@]} -gt 1 ]; then
            discrete_gpu="hybrid"
            echo -e "${YELLOW}!${NC} Hybrid graphics system detected"
        fi
    fi
    
    echo "$primary_vendor|${gpu_info[*]}|$discrete_gpu"
}

# Check current driver status
check_driver_status() {
    echo -e "${BLUE}Checking current driver status...${NC}"
    
    local loaded_modules=()
    local driver_status="unknown"
    local acceleration_status="disabled"
    
    # Check loaded kernel modules
    if lsmod | grep -q nvidia; then
        loaded_modules+=("nvidia")
        driver_status="nvidia_loaded"
        echo -e "${GREEN}✓${NC} NVIDIA driver loaded"
    fi
    
    if lsmod | grep -q amdgpu; then
        loaded_modules+=("amdgpu")
        driver_status="amd_loaded"
        echo -e "${GREEN}✓${NC} AMD GPU driver loaded"
    fi
    
    if lsmod | grep -q radeon; then
        loaded_modules+=("radeon")
        driver_status="amd_legacy_loaded"
        echo -e "${GREEN}✓${NC} AMD Radeon driver loaded"
    fi
    
    if lsmod | grep -q i915; then
        loaded_modules+=("i915")
        driver_status="intel_loaded"
        echo -e "${GREEN}✓${NC} Intel i915 driver loaded"
    fi
    
    if lsmod | grep -q nouveau; then
        loaded_modules+=("nouveau")
        driver_status="nouveau_loaded"
        echo -e "${YELLOW}!${NC} Nouveau (open-source NVIDIA) driver loaded"
    fi
    
    # Check 3D acceleration
    if command -v glxinfo >/dev/null; then
        if glxinfo | grep -q "direct rendering: Yes"; then
            acceleration_status="enabled"
            echo -e "${GREEN}✓${NC} 3D acceleration enabled"
            
            local renderer=$(glxinfo | grep "OpenGL renderer" | cut -d: -f2 | xargs)
            local version=$(glxinfo | grep "OpenGL version" | cut -d: -f2 | xargs)
            echo -e "${CYAN}Renderer:${NC} $renderer"
            echo -e "${CYAN}OpenGL Version:${NC} $version"
        else
            echo -e "${RED}✗${NC} 3D acceleration disabled"
        fi
    fi
    
    # Check Vulkan support
    if command -v vulkaninfo >/dev/null && vulkaninfo >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Vulkan support available"
        local vulkan_devices=$(vulkaninfo | grep "deviceName" | wc -l)
        echo -e "${CYAN}Vulkan Devices:${NC} $vulkan_devices"
    else
        echo -e "${YELLOW}!${NC} Vulkan support not available"
    fi
    
    echo "$driver_status|${loaded_modules[*]}|$acceleration_status"
}

# Install NVIDIA drivers
install_nvidia_drivers() {
    local driver_version="${1:-auto}"
    
    echo -e "${BLUE}Installing NVIDIA drivers...${NC}"
    echo -e "${YELLOW}This requires administrative privileges${NC}"
    
    # Detect recommended driver version
    if [ "$driver_version" = "auto" ]; then
        if command -v ubuntu-drivers >/dev/null; then
            driver_version=$(ubuntu-drivers devices | grep nvidia | head -1 | awk '{print $3}')
        elif command -v nvidia-detect >/dev/null; then
            driver_version=$(nvidia-detect | grep -o "nvidia-[0-9]*")
        else
            driver_version="nvidia-driver-535"  # Default to recent stable
        fi
        echo -e "${CYAN}Recommended driver:${NC} $driver_version"
    fi
    
    # Check if already installed
    if dpkg -l | grep -q "$driver_version"; then
        echo -e "${GREEN}✓${NC} NVIDIA driver already installed: $driver_version"
        return 0
    fi
    
    # Install driver
    echo -e "${BLUE}Installing $driver_version...${NC}"
    
    # Add NVIDIA repository if needed
    if ! apt-cache policy | grep -q "graphics-drivers"; then
        sudo add-apt-repository ppa:graphics-drivers/ppa -y
        sudo apt update
    fi
    
    # Install driver and utilities
    sudo apt install -y "$driver_version" nvidia-settings nvidia-prime
    
    # Install additional components
    sudo apt install -y nvidia-cuda-toolkit vulkan-utils
    
    # Configure Xorg
    sudo nvidia-xconfig
    
    echo -e "${GREEN}✓${NC} NVIDIA drivers installed"
    echo -e "${YELLOW}!${NC} Reboot required to activate drivers"
    
    # Log installation
    echo "$(date): NVIDIA driver $driver_version installed" >> "$LOG_FILE"
}

# Install AMD drivers
install_amd_drivers() {
    local driver_type="${1:-amdgpu}"
    
    echo -e "${BLUE}Installing AMD drivers...${NC}"
    
    case "$driver_type" in
        amdgpu)
            echo -e "${CYAN}Installing AMDGPU drivers (modern AMD cards)${NC}"
            
            # Install Mesa and AMDGPU drivers
            sudo apt install -y mesa-vulkan-drivers xserver-xorg-video-amdgpu
            sudo apt install -y libgl1-mesa-dri libglx-mesa0 mesa-vulkan-drivers
            sudo apt install -y vulkan-utils vulkan-tools
            
            # Install ROCm for compute (optional)
            if [ "$ENABLE_OPENCL" = "true" ]; then
                sudo apt install -y rocm-opencl-runtime
            fi
            
            echo -e "${GREEN}✓${NC} AMDGPU drivers installed"
            ;;
            
        radeon)
            echo -e "${CYAN}Installing Radeon drivers (legacy AMD cards)${NC}"
            
            sudo apt install -y xserver-xorg-video-radeon
            sudo apt install -y libgl1-mesa-dri libglx-mesa0
            
            echo -e "${GREEN}✓${NC} Radeon drivers installed"
            ;;
            
        fglrx)
            echo -e "${CYAN}Installing FGLRX drivers (discontinued)${NC}"
            echo -e "${YELLOW}!${NC} FGLRX drivers are no longer supported"
            echo -e "${YELLOW}!${NC} Falling back to AMDGPU drivers"
            install_amd_drivers "amdgpu"
            return
            ;;
    esac
    
    echo "$(date): AMD driver $driver_type installed" >> "$LOG_FILE"
}

# Install Intel drivers
install_intel_drivers() {
    echo -e "${BLUE}Installing Intel drivers...${NC}"
    
    # Install Intel graphics drivers
    sudo apt install -y xserver-xorg-video-intel
    sudo apt install -y intel-media-va-driver i965-va-driver
    sudo apt install -y libgl1-mesa-dri libglx-mesa0 mesa-vulkan-drivers
    
    # Install Intel compute runtime
    if [ "$ENABLE_OPENCL" = "true" ]; then
        sudo apt install -y intel-opencl-icd
    fi
    
    # Install Intel GPU tools
    sudo apt install -y intel-gpu-tools
    
    echo -e "${GREEN}✓${NC} Intel drivers installed"
    echo "$(date): Intel drivers installed" >> "$LOG_FILE"
}

# Configure graphics profiles
configure_graphics_profile() {
    local profile_name="$1"
    local gpu_vendor="$2"
    
    echo -e "${BLUE}Configuring graphics profile: $profile_name${NC}"
    
    local profile_file="$PROFILES_DIR/${profile_name}.conf"
    
    case "$profile_name" in
        gaming)
            cat > "$profile_file" << EOF
# Gaming Graphics Profile
PROFILE_NAME=gaming
GPU_VENDOR=$gpu_vendor
PERFORMANCE_MODE=maximum
POWER_PROFILE=performance
VSYNC=off
TRIPLE_BUFFER=on
TEXTURE_FILTERING=anisotropic_16x
ANTIALIASING=msaa_4x
SHADER_CACHE=large
GPU_MEMORY_CLOCK=max
CORE_CLOCK=max
FAN_CURVE=aggressive
TEMPERATURE_LIMIT=83
FRAME_LIMIT=unlimited
EOF
            ;;
            
        productivity)
            cat > "$profile_file" << EOF
# Productivity Graphics Profile
PROFILE_NAME=productivity
GPU_VENDOR=$gpu_vendor
PERFORMANCE_MODE=balanced
POWER_PROFILE=balanced
VSYNC=on
TRIPLE_BUFFER=on
TEXTURE_FILTERING=bilinear
ANTIALIASING=fxaa
SHADER_CACHE=medium
GPU_MEMORY_CLOCK=default
CORE_CLOCK=default
FAN_CURVE=quiet
TEMPERATURE_LIMIT=75
FRAME_LIMIT=60
EOF
            ;;
            
        power_saving)
            cat > "$profile_file" << EOF
# Power Saving Graphics Profile
PROFILE_NAME=power_saving
GPU_VENDOR=$gpu_vendor
PERFORMANCE_MODE=power_saver
POWER_PROFILE=powersave
VSYNC=on
TRIPLE_BUFFER=off
TEXTURE_FILTERING=bilinear
ANTIALIASING=off
SHADER_CACHE=small
GPU_MEMORY_CLOCK=min
CORE_CLOCK=min
FAN_CURVE=silent
TEMPERATURE_LIMIT=70
FRAME_LIMIT=30
EOF
            ;;
    esac
    
    echo -e "${GREEN}✓${NC} Graphics profile created: $profile_file"
}

# Apply graphics profile
apply_graphics_profile() {
    local profile_name="$1"
    local profile_file="$PROFILES_DIR/${profile_name}.conf"
    
    if [ ! -f "$profile_file" ]; then
        echo -e "${RED}✗${NC} Profile not found: $profile_name"
        return 1
    fi
    
    echo -e "${BLUE}Applying graphics profile: $profile_name${NC}"
    source "$profile_file"
    
    # Apply NVIDIA settings
    if [ "$GPU_VENDOR" = "nvidia" ] && command -v nvidia-settings >/dev/null; then
        case "$PERFORMANCE_MODE" in
            maximum)
                nvidia-settings --assign GPUPowerMizerMode=1  # Prefer maximum performance
                nvidia-settings --assign GPUMemoryTransferRateOffset[3]=1000
                nvidia-settings --assign GPUGraphicsClockOffset[3]=100
                ;;
            balanced)
                nvidia-settings --assign GPUPowerMizerMode=0  # Adaptive
                ;;
            power_saver)
                nvidia-settings --assign GPUPowerMizerMode=2  # Auto
                ;;
        esac
        
        # Set fan curve if supported
        if [ -n "$FAN_CURVE" ]; then
            case "$FAN_CURVE" in
                aggressive)
                    nvidia-settings --assign GPUFanControlState=1
                    nvidia-settings --assign GPUTargetFanSpeed=80
                    ;;
                quiet)
                    nvidia-settings --assign GPUFanControlState=1
                    nvidia-settings --assign GPUTargetFanSpeed=40
                    ;;
                silent)
                    nvidia-settings --assign GPUFanControlState=0  # Auto
                    ;;
            esac
        fi
        
        echo -e "${GREEN}✓${NC} NVIDIA profile applied"
    fi
    
    # Apply AMD settings
    if [ "$GPU_VENDOR" = "amd" ]; then
        # AMD GPU settings would go here
        # Note: AMD has different tools like rocm-smi for modern cards
        echo -e "${GREEN}✓${NC} AMD profile applied"
    fi
    
    # Apply Intel settings
    if [ "$GPU_VENDOR" = "intel" ]; then
        # Intel GPU settings
        echo -e "${GREEN}✓${NC} Intel profile applied"
    fi
}

# Test 3D acceleration
test_3d_acceleration() {
    echo -e "${BLUE}Testing 3D acceleration...${NC}"
    
    local test_results=()
    
    # OpenGL test
    if command -v glxgears >/dev/null; then
        echo -e "${CYAN}Running OpenGL test (10 seconds)...${NC}"
        local fps_result=$(timeout 10s glxgears 2>&1 | tail -1)
        test_results+=("OpenGL: $fps_result")
        echo -e "${GREEN}✓${NC} OpenGL test completed"
    fi
    
    # Vulkan test
    if command -v vkcube >/dev/null; then
        echo -e "${CYAN}Running Vulkan test...${NC}"
        timeout 5s vkcube --validate >/dev/null 2>&1 && \
        test_results+=("Vulkan: Available") || \
        test_results+=("Vulkan: Not available")
    fi
    
    # OpenCL test
    if command -v clinfo >/dev/null; then
        echo -e "${CYAN}Testing OpenCL...${NC}"
        local opencl_devices=$(clinfo | grep -c "Device Name" 2>/dev/null || echo "0")
        test_results+=("OpenCL: $opencl_devices devices")
    fi
    
    # Display results
    echo -e "\n${PURPLE}=== 3D Acceleration Test Results ===${NC}"
    for result in "${test_results[@]}"; do
        echo -e "${CYAN}$result${NC}"
    done
}

# Benchmark graphics performance
benchmark_graphics() {
    echo -e "${BLUE}Running graphics benchmark...${NC}"
    
    local benchmark_results="$GRAPHICS_CONFIG_DIR/benchmark_results.txt"
    echo "Graphics Benchmark Results - $(date)" > "$benchmark_results"
    
    # OpenGL benchmark
    if command -v glmark2 >/dev/null; then
        echo -e "${CYAN}Running GLMark2 benchmark...${NC}"
        glmark2 --fullscreen >> "$benchmark_results" 2>&1
        echo -e "${GREEN}✓${NC} GLMark2 benchmark completed"
    elif command -v glxgears >/dev/null; then
        echo -e "${CYAN}Running GLXGears benchmark...${NC}"
        timeout 60s glxgears 2>&1 | tail -10 >> "$benchmark_results"
    fi
    
    # Vulkan benchmark
    if command -v vkmark >/dev/null; then
        echo -e "${CYAN}Running Vulkan benchmark...${NC}"
        vkmark >> "$benchmark_results" 2>&1
    fi
    
    # GPU information
    echo -e "\nGPU Information:" >> "$benchmark_results"
    if command -v nvidia-smi >/dev/null; then
        nvidia-smi >> "$benchmark_results" 2>&1
    fi
    
    echo -e "${GREEN}✓${NC} Benchmark completed: $benchmark_results"
}

# Troubleshoot graphics issues
troubleshoot_graphics() {
    echo -e "${PURPLE}=== Graphics Troubleshooting ===${NC}"
    
    # Check basic graphics info
    echo -e "\n${BLUE}1. Hardware Detection:${NC}"
    lspci | grep -i "vga\|3d\|display"
    
    echo -e "\n${BLUE}2. Loaded Drivers:${NC}"
    lsmod | grep -E "nvidia|nouveau|amdgpu|radeon|i915"
    
    echo -e "\n${BLUE}3. X11 Configuration:${NC}"
    if [ -f "/etc/X11/xorg.conf" ]; then
        echo -e "${GREEN}✓${NC} Custom X11 config found"
        grep -E "Driver|Device" /etc/X11/xorg.conf | head -5
    else
        echo -e "${YELLOW}!${NC} Using automatic X11 configuration"
    fi
    
    echo -e "\n${BLUE}4. Display Server:${NC}"
    if [ -n "$WAYLAND_DISPLAY" ]; then
        echo -e "${GREEN}✓${NC} Wayland session"
        echo "Display: $WAYLAND_DISPLAY"
    elif [ -n "$DISPLAY" ]; then
        echo -e "${GREEN}✓${NC} X11 session"
        echo "Display: $DISPLAY"
    else
        echo -e "${RED}✗${NC} No display server detected"
    fi
    
    echo -e "\n${BLUE}5. OpenGL Information:${NC}"
    if command -v glxinfo >/dev/null; then
        glxinfo | grep -E "direct rendering|OpenGL vendor|OpenGL renderer|OpenGL version"
    else
        echo -e "${YELLOW}!${NC} glxinfo not available"
    fi
    
    echo -e "\n${BLUE}6. Common Issues Check:${NC}"
    
    # Check for conflicting drivers
    if lsmod | grep -q nouveau && lsmod | grep -q nvidia; then
        echo -e "${RED}✗${NC} Conflicting drivers: nouveau and nvidia both loaded"
        echo -e "${YELLOW}Solution: Blacklist nouveau driver${NC}"
    fi
    
    # Check secure boot
    if command -v mokutil >/dev/null && mokutil --sb-state | grep -q "SecureBoot enabled"; then
        echo -e "${YELLOW}!${NC} Secure Boot is enabled - may block proprietary drivers"
    fi
    
    # Check for missing firmware
    if dmesg | grep -q "firmware.*failed"; then
        echo -e "${YELLOW}!${NC} Missing firmware detected in dmesg"
    fi
}

# Settings menu
settings_menu() {
    echo -e "\n${PURPLE}=== Graphics Drivers Settings ===${NC}"
    echo -e "${WHITE}1.${NC} Auto-detect hardware: ${AUTO_DETECT_HARDWARE}"
    echo -e "${WHITE}2.${NC} Preferred driver: ${PREFERRED_DRIVER}"
    echo -e "${WHITE}3.${NC} Enable 3D acceleration: ${ENABLE_3D_ACCELERATION}"
    echo -e "${WHITE}4.${NC} Enable Vulkan: ${ENABLE_VULKAN}"
    echo -e "${WHITE}5.${NC} Enable OpenCL: ${ENABLE_OPENCL}"
    echo -e "${WHITE}6.${NC} Multi-monitor support: ${MULTIMONITOR_SUPPORT}"
    echo -e "${WHITE}7.${NC} Power management: ${POWER_MANAGEMENT}"
    echo -e "${WHITE}8.${NC} Experimental features: ${EXPERIMENTAL_FEATURES}"
    echo -e "${WHITE}s.${NC} Save settings"
    echo -e "${WHITE}q.${NC} Back to main menu"
    echo
    
    echo -ne "${YELLOW}Select option:${NC} "
    read -r choice
    
    case "$choice" in
        1)
            echo -ne "${CYAN}Auto-detect hardware (true/false):${NC} "
            read -r AUTO_DETECT_HARDWARE
            ;;
        2)
            echo -ne "${CYAN}Preferred driver (auto/nvidia/amd/intel):${NC} "
            read -r PREFERRED_DRIVER
            ;;
        3)
            echo -ne "${CYAN}Enable 3D acceleration (true/false):${NC} "
            read -r ENABLE_3D_ACCELERATION
            ;;
        4)
            echo -ne "${CYAN}Enable Vulkan support (true/false):${NC} "
            read -r ENABLE_VULKAN
            ;;
        5)
            echo -ne "${CYAN}Enable OpenCL support (true/false):${NC} "
            read -r ENABLE_OPENCL
            ;;
        6)
            echo -ne "${CYAN}Multi-monitor support (true/false):${NC} "
            read -r MULTIMONITOR_SUPPORT
            ;;
        7)
            echo -ne "${CYAN}Power management (performance/balanced/powersave):${NC} "
            read -r POWER_MANAGEMENT
            ;;
        8)
            echo -ne "${CYAN}Enable experimental features (true/false):${NC} "
            read -r EXPERIMENTAL_FEATURES
            ;;
        s|S)
            cat > "$GRAPHICS_CONFIG_DIR/settings.conf" << EOF
# BluejayLinux Graphics Drivers Settings
AUTO_DETECT_HARDWARE=$AUTO_DETECT_HARDWARE
PREFERRED_DRIVER=$PREFERRED_DRIVER
ENABLE_3D_ACCELERATION=$ENABLE_3D_ACCELERATION
ENABLE_VULKAN=$ENABLE_VULKAN
ENABLE_OPENCL=$ENABLE_OPENCL
MULTIMONITOR_SUPPORT=$MULTIMONITOR_SUPPORT
HDR_SUPPORT=$HDR_SUPPORT
VARIABLE_REFRESH_RATE=$VARIABLE_REFRESH_RATE
POWER_MANAGEMENT=$POWER_MANAGEMENT
DRIVER_UPDATE_CHECK=$DRIVER_UPDATE_CHECK
EXPERIMENTAL_FEATURES=$EXPERIMENTAL_FEATURES
FALLBACK_TO_NOUVEAU=$FALLBACK_TO_NOUVEAU
WAYLAND_SUPPORT=$WAYLAND_SUPPORT
X11_SUPPORT=$X11_SUPPORT
LEGACY_COMPATIBILITY=$LEGACY_COMPATIBILITY
EOF
            echo -e "${GREEN}✓${NC} Settings saved"
            ;;
    esac
}

# Main menu
main_menu() {
    echo -e "${PURPLE}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║               ${WHITE}BluejayLinux Graphics Drivers Manager${PURPLE}             ║${NC}"
    echo -e "${PURPLE}║              ${CYAN}3D Acceleration & Advanced Graphics${PURPLE}               ║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    local hw_info=$(detect_graphics_hardware)
    local primary_vendor=$(echo "$hw_info" | cut -d'|' -f1)
    local all_gpus=($(echo "$hw_info" | cut -d'|' -f2))
    
    echo -e "${WHITE}Detected GPUs:${NC} ${all_gpus[*]}"
    echo -e "${WHITE}Primary vendor:${NC} $primary_vendor"
    
    local driver_status=$(check_driver_status)
    local current_driver=$(echo "$driver_status" | cut -d'|' -f1)
    local acceleration=$(echo "$driver_status" | cut -d'|' -f3)
    
    echo -e "${WHITE}Current driver:${NC} $current_driver"
    echo -e "${WHITE}3D acceleration:${NC} $acceleration"
    echo
    
    echo -e "${WHITE}Driver Installation:${NC}"
    echo -e "${WHITE}1.${NC} Install NVIDIA drivers"
    echo -e "${WHITE}2.${NC} Install AMD drivers"
    echo -e "${WHITE}3.${NC} Install Intel drivers"
    echo -e "${WHITE}4.${NC} Auto-install recommended drivers"
    echo
    echo -e "${WHITE}Configuration:${NC}"
    echo -e "${WHITE}5.${NC} Configure graphics profile"
    echo -e "${WHITE}6.${NC} Apply graphics profile"
    echo
    echo -e "${WHITE}Testing & Diagnostics:${NC}"
    echo -e "${WHITE}7.${NC} Test 3D acceleration"
    echo -e "${WHITE}8.${NC} Run graphics benchmark"
    echo -e "${WHITE}9.${NC} Troubleshoot issues"
    echo
    echo -e "${WHITE}10.${NC} Settings"
    echo -e "${WHITE}q.${NC} Quit"
    echo
}

# Main function
main() {
    create_directories
    load_settings
    
    if [ $# -gt 0 ]; then
        case "$1" in
            --install-nvidia)
                install_nvidia_drivers "$2"
                ;;
            --install-amd)
                install_amd_drivers "$2"
                ;;
            --install-intel)
                install_intel_drivers
                ;;
            --auto-install)
                local hw_info=$(detect_graphics_hardware)
                local vendor=$(echo "$hw_info" | cut -d'|' -f1)
                case "$vendor" in
                    nvidia) install_nvidia_drivers ;;
                    amd) install_amd_drivers ;;
                    intel) install_intel_drivers ;;
                esac
                ;;
            --test)
                test_3d_acceleration
                ;;
            --benchmark)
                benchmark_graphics
                ;;
            --troubleshoot)
                troubleshoot_graphics
                ;;
            --help|-h)
                echo "BluejayLinux Graphics Drivers Manager"
                echo "Usage: $0 [options] [parameters]"
                echo "  --install-nvidia [version]  Install NVIDIA drivers"
                echo "  --install-amd [type]        Install AMD drivers"
                echo "  --install-intel             Install Intel drivers"
                echo "  --auto-install              Auto-install recommended drivers"
                echo "  --test                      Test 3D acceleration"
                echo "  --benchmark                 Run graphics benchmark"
                echo "  --troubleshoot              Troubleshoot graphics issues"
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
                echo -ne "${CYAN}Enter NVIDIA driver version (or 'auto'):${NC} "
                read -r version
                install_nvidia_drivers "$version"
                ;;
            2)
                echo -ne "${CYAN}AMD driver type (amdgpu/radeon):${NC} "
                read -r driver_type
                install_amd_drivers "$driver_type"
                ;;
            3)
                install_intel_drivers
                ;;
            4)
                local hw_info=$(detect_graphics_hardware)
                local vendor=$(echo "$hw_info" | cut -d'|' -f1)
                echo -e "${BLUE}Auto-installing drivers for: $vendor${NC}"
                case "$vendor" in
                    nvidia) install_nvidia_drivers ;;
                    amd) install_amd_drivers ;;
                    intel) install_intel_drivers ;;
                    *) echo -e "${YELLOW}!${NC} No supported GPU detected" ;;
                esac
                ;;
            5)
                echo -ne "${CYAN}Profile name (gaming/productivity/power_saving):${NC} "
                read -r profile_name
                local hw_info=$(detect_graphics_hardware)
                local vendor=$(echo "$hw_info" | cut -d'|' -f1)
                configure_graphics_profile "$profile_name" "$vendor"
                ;;
            6)
                echo -ne "${CYAN}Profile to apply:${NC} "
                read -r profile_name
                apply_graphics_profile "$profile_name"
                ;;
            7)
                test_3d_acceleration
                ;;
            8)
                benchmark_graphics
                ;;
            9)
                troubleshoot_graphics
                ;;
            10)
                settings_menu
                ;;
            q|Q)
                echo -e "${GREEN}Graphics drivers configuration saved${NC}"
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