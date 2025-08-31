#!/bin/bash

# BluejayLinux - Enhanced Graphics Pipeline
# Advanced graphics processing and acceleration integration

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/bluejay"
CACHE_DIR="$HOME/.cache/bluejay/graphics"
PIPELINE_CONF="$CONFIG_DIR/graphics_pipeline.conf"
DRIVERS_CONF="$CONFIG_DIR/graphics_drivers.conf"

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

# Initialize directories and configs
create_directories() {
    mkdir -p "$CONFIG_DIR" "$CACHE_DIR"
    
    # Create default graphics pipeline configuration
    if [ ! -f "$PIPELINE_CONF" ]; then
        cat > "$PIPELINE_CONF" << 'EOF'
# BluejayLinux Graphics Pipeline Configuration
HARDWARE_ACCELERATION=auto
VSYNC_ENABLED=true
TRIPLE_BUFFERING=true
TEXTURE_FILTERING=anisotropic
ANTIALIASING=4x
RENDER_QUALITY=high
COLOR_DEPTH=32
REFRESH_RATE=auto
COMPOSITOR_BACKEND=auto
GPU_SCHEDULER=fifo
MEMORY_MANAGEMENT=auto
POWER_PROFILE=balanced
EOF
    fi
}

# Load configuration
load_config() {
    if [ -f "$PIPELINE_CONF" ]; then
        source "$PIPELINE_CONF"
    fi
}

# Detect graphics capabilities
detect_graphics_capabilities() {
    local capabilities=()
    
    echo -e "${BLUE}Detecting graphics capabilities...${NC}"
    
    # Hardware acceleration support
    if lspci | grep -qi "vga\|3d\|display"; then
        capabilities+=("hardware_rendering")
        echo -e "${GREEN}✓${NC} Hardware rendering support detected"
    fi
    
    # OpenGL support
    if command -v glxinfo >/dev/null && glxinfo | grep -q "direct rendering: Yes"; then
        local gl_version=$(glxinfo | grep "OpenGL version string" | cut -d: -f2 | xargs)
        capabilities+=("opengl")
        echo -e "${GREEN}✓${NC} OpenGL support: $gl_version"
    fi
    
    # Vulkan support
    if command -v vulkaninfo >/dev/null && vulkaninfo >/dev/null 2>&1; then
        capabilities+=("vulkan")
        echo -e "${GREEN}✓${NC} Vulkan support detected"
    fi
    
    # DirectX (via Wine/DXVK)
    if command -v wine >/dev/null; then
        capabilities+=("directx")
        echo -e "${GREEN}✓${NC} DirectX support (via Wine) available"
    fi
    
    # Video acceleration
    if command -v vainfo >/dev/null && vainfo >/dev/null 2>&1; then
        capabilities+=("va-api")
        echo -e "${GREEN}✓${NC} VA-API hardware video acceleration"
    fi
    
    if command -v vdpauinfo >/dev/null && vdpauinfo >/dev/null 2>&1; then
        capabilities+=("vdpau")
        echo -e "${GREEN}✓${NC} VDPAU hardware video acceleration"
    fi
    
    # Compute shaders
    if command -v clinfo >/dev/null && clinfo >/dev/null 2>&1; then
        capabilities+=("opencl")
        echo -e "${GREEN}✓${NC} OpenCL compute support"
    fi
    
    echo "${capabilities[@]}"
}

# Optimize graphics settings
optimize_graphics_settings() {
    local gpu_vendor="$1"
    
    echo -e "${BLUE}Optimizing graphics settings for ${gpu_vendor} GPU...${NC}"
    
    case "$gpu_vendor" in
        nvidia)
            # NVIDIA-specific optimizations
            echo -e "${CYAN}Applying NVIDIA optimizations...${NC}"
            
            # Enable performance mode
            if command -v nvidia-settings >/dev/null; then
                nvidia-settings --assign GPUPowerMizerMode=1 2>/dev/null || true
                nvidia-settings --assign GPUMemoryTransferRateOffset[3]=1000 2>/dev/null || true
                echo -e "${GREEN}✓${NC} NVIDIA performance mode enabled"
            fi
            
            # Update pipeline config for NVIDIA
            sed -i 's/HARDWARE_ACCELERATION=.*/HARDWARE_ACCELERATION=nvidia/' "$PIPELINE_CONF"
            sed -i 's/COMPOSITOR_BACKEND=.*/COMPOSITOR_BACKEND=opengl/' "$PIPELINE_CONF"
            ;;
            
        amd)
            # AMD-specific optimizations
            echo -e "${CYAN}Applying AMD optimizations...${NC}"
            
            # Enable AMD GPU scheduling
            if [ -f /sys/module/amdgpu/parameters/gpu_recovery ]; then
                echo 1 | sudo tee /sys/module/amdgpu/parameters/gpu_recovery >/dev/null 2>&1 || true
            fi
            
            # Update pipeline config for AMD
            sed -i 's/HARDWARE_ACCELERATION=.*/HARDWARE_ACCELERATION=amd/' "$PIPELINE_CONF"
            sed -i 's/COMPOSITOR_BACKEND=.*/COMPOSITOR_BACKEND=vulkan/' "$PIPELINE_CONF"
            echo -e "${GREEN}✓${NC} AMD optimizations applied"
            ;;
            
        intel)
            # Intel-specific optimizations
            echo -e "${CYAN}Applying Intel optimizations...${NC}"
            
            # Update pipeline config for Intel
            sed -i 's/HARDWARE_ACCELERATION=.*/HARDWARE_ACCELERATION=intel/' "$PIPELINE_CONF"
            sed -i 's/COMPOSITOR_BACKEND=.*/COMPOSITOR_BACKEND=opengl/' "$PIPELINE_CONF"
            sed -i 's/POWER_PROFILE=.*/POWER_PROFILE=powersave/' "$PIPELINE_CONF"
            echo -e "${GREEN}✓${NC} Intel optimizations applied"
            ;;
            
        *)
            echo -e "${YELLOW}!${NC} Generic GPU detected, applying universal optimizations"
            sed -i 's/HARDWARE_ACCELERATION=.*/HARDWARE_ACCELERATION=auto/' "$PIPELINE_CONF"
            ;;
    esac
}

# Configure display server integration
configure_display_server() {
    echo -e "${BLUE}Configuring display server integration...${NC}"
    
    # Detect display server
    if [ -n "$WAYLAND_DISPLAY" ]; then
        echo -e "${CYAN}Wayland detected${NC}"
        configure_wayland_graphics
    elif [ -n "$DISPLAY" ]; then
        echo -e "${CYAN}X11 detected${NC}"
        configure_x11_graphics
    else
        echo -e "${CYAN}Framebuffer mode${NC}"
        configure_framebuffer_graphics
    fi
}

# Configure Wayland graphics
configure_wayland_graphics() {
    # Wayland-specific graphics setup
    export XDG_SESSION_TYPE=wayland
    export GDK_BACKEND=wayland
    export QT_QPA_PLATFORM=wayland
    export CLUTTER_BACKEND=wayland
    export SDL_VIDEODRIVER=wayland
    
    # Enable hardware acceleration for Wayland
    export WLR_NO_HARDWARE_CURSORS=1
    export WLR_RENDERER=vulkan
    
    echo -e "${GREEN}✓${NC} Wayland graphics configured"
}

# Configure X11 graphics
configure_x11_graphics() {
    # X11-specific graphics setup
    export XDG_SESSION_TYPE=x11
    
    # Enable hardware acceleration
    export LIBGL_ALWAYS_INDIRECT=0
    export MESA_GL_VERSION_OVERRIDE=4.6
    
    # Configure X11 compositor if available
    if command -v picom >/dev/null; then
        picom --backend glx --vsync --use-damage &
        echo -e "${GREEN}✓${NC} X11 compositor enabled"
    elif command -v compton >/dev/null; then
        compton --backend glx --vsync opengl &
        echo -e "${GREEN}✓${NC} X11 compositor enabled"
    fi
}

# Configure framebuffer graphics
configure_framebuffer_graphics() {
    # Framebuffer-specific setup
    export FRAMEBUFFER=/dev/fb0
    
    # Enable hardware acceleration where possible
    if [ -f /dev/fb0 ]; then
        echo -e "${GREEN}✓${NC} Framebuffer graphics configured"
    else
        echo -e "${YELLOW}!${NC} No framebuffer device found"
    fi
}

# Graphics performance testing
benchmark_graphics() {
    echo -e "${BLUE}Running graphics performance tests...${NC}"
    
    local results_file="$CACHE_DIR/benchmark_results.txt"
    echo "Graphics Benchmark Results - $(date)" > "$results_file"
    echo "========================================" >> "$results_file"
    
    # OpenGL benchmark
    if command -v glxgears >/dev/null; then
        echo -e "${CYAN}Running OpenGL test...${NC}"
        timeout 10s glxgears -info 2>&1 | tail -5 >> "$results_file"
        echo -e "${GREEN}✓${NC} OpenGL benchmark completed"
    fi
    
    # GPU memory test
    if command -v gpu-burn >/dev/null; then
        echo -e "${CYAN}Running GPU stress test...${NC}"
        timeout 30s gpu-burn 30 >> "$results_file" 2>&1 || true
        echo -e "${GREEN}✓${NC} GPU stress test completed"
    fi
    
    # Vulkan test
    if command -v vkcube >/dev/null; then
        echo -e "${CYAN}Running Vulkan test...${NC}"
        timeout 5s vkcube --validate >> "$results_file" 2>&1 || true
        echo -e "${GREEN}✓${NC} Vulkan test completed"
    fi
    
    # Display benchmark results
    echo -e "\n${PURPLE}Benchmark Results:${NC}"
    cat "$results_file"
}

# Monitor graphics performance
monitor_graphics() {
    echo -e "${BLUE}Graphics Performance Monitor${NC}"
    echo -e "${GRAY}Press Ctrl+C to stop monitoring${NC}"
    echo
    
    while true; do
        clear
        echo -e "${PURPLE}=== Graphics Performance Monitor ===${NC}"
        echo -e "${CYAN}Timestamp: $(date)${NC}"
        echo
        
        # GPU utilization
        if command -v nvidia-smi >/dev/null; then
            echo -e "${WHITE}NVIDIA GPU Status:${NC}"
            nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits
        elif command -v radeontop >/dev/null; then
            echo -e "${WHITE}AMD GPU Status:${NC}"
            timeout 1s radeontop -d - -l 1 | tail -1
        elif command -v intel_gpu_top >/dev/null; then
            echo -e "${WHITE}Intel GPU Status:${NC}"
            timeout 1s intel_gpu_top -l 1 | tail -5
        fi
        
        echo
        
        # Memory usage
        echo -e "${WHITE}Graphics Memory Usage:${NC}"
        if command -v free >/dev/null; then
            free -h | grep -E "Mem:|Swap:"
        fi
        
        echo
        
        # Display information
        if command -v xrandr >/dev/null 2>&1; then
            echo -e "${WHITE}Display Information:${NC}"
            xrandr | grep " connected" | head -3
        fi
        
        sleep 2
    done
}

# Graphics troubleshooting
troubleshoot_graphics() {
    echo -e "${PURPLE}=== Graphics Troubleshooting ===${NC}"
    
    # Check basic graphics stack
    echo -e "\n${BLUE}1. Basic Graphics Stack:${NC}"
    
    if command -v lspci >/dev/null; then
        echo -e "${CYAN}Graphics Hardware:${NC}"
        lspci | grep -i "vga\|3d\|display" | head -3
    fi
    
    if command -v glxinfo >/dev/null; then
        echo -e "\n${CYAN}OpenGL Information:${NC}"
        glxinfo | grep -E "direct rendering|OpenGL version|OpenGL renderer" | head -3
    fi
    
    # Check drivers
    echo -e "\n${BLUE}2. Driver Status:${NC}"
    
    if lsmod | grep -qi nvidia; then
        echo -e "${GREEN}✓${NC} NVIDIA driver loaded"
        if command -v nvidia-smi >/dev/null; then
            nvidia-smi -q -d TEMPERATURE,POWER,CLOCK | grep -E "Product Name|Driver Version|GPU Current Temp|Power Draw"
        fi
    fi
    
    if lsmod | grep -qi amdgpu; then
        echo -e "${GREEN}✓${NC} AMD driver loaded"
    fi
    
    if lsmod | grep -qi i915; then
        echo -e "${GREEN}✓${NC} Intel driver loaded"
    fi
    
    # Check display server
    echo -e "\n${BLUE}3. Display Server:${NC}"
    if [ -n "$WAYLAND_DISPLAY" ]; then
        echo -e "${GREEN}✓${NC} Wayland session active"
        echo -e "${CYAN}Display:${NC} $WAYLAND_DISPLAY"
    elif [ -n "$DISPLAY" ]; then
        echo -e "${GREEN}✓${NC} X11 session active"
        echo -e "${CYAN}Display:${NC} $DISPLAY"
        if command -v xwininfo >/dev/null; then
            echo -e "${CYAN}Resolution:${NC} $(xwininfo -root | grep geometry | cut -d' ' -f4)"
        fi
    else
        echo -e "${YELLOW}!${NC} Console/framebuffer mode"
    fi
    
    # Check for common issues
    echo -e "\n${BLUE}4. Common Issues Check:${NC}"
    
    if [ ! -r /dev/dri/card0 ]; then
        echo -e "${RED}✗${NC} No GPU device access - check permissions"
    else
        echo -e "${GREEN}✓${NC} GPU device accessible"
    fi
    
    if ! groups | grep -q video; then
        echo -e "${YELLOW}!${NC} User not in video group - may cause permission issues"
    else
        echo -e "${GREEN}✓${NC} User in video group"
    fi
}

# Main configuration menu
main_menu() {
    echo -e "${PURPLE}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                   ${WHITE}BluejayLinux Graphics Pipeline${PURPLE}                  ║${NC}"
    echo -e "${PURPLE}║                  ${CYAN}Hardware Acceleration & Optimization${PURPLE}             ║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    local capabilities=($(detect_graphics_capabilities))
    echo -e "${WHITE}Detected capabilities:${NC} ${capabilities[*]}"
    echo
    
    echo -e "${WHITE}1.${NC} Auto-optimize graphics settings"
    echo -e "${WHITE}2.${NC} Configure display server"
    echo -e "${WHITE}3.${NC} Run graphics benchmark"
    echo -e "${WHITE}4.${NC} Monitor graphics performance"
    echo -e "${WHITE}5.${NC} Troubleshoot graphics issues"
    echo -e "${WHITE}6.${NC} Pipeline settings"
    echo -e "${WHITE}7.${NC} Driver information"
    echo -e "${WHITE}q.${NC} Quit"
    echo
}

# Settings configuration
settings_menu() {
    echo -e "\n${PURPLE}=== Graphics Pipeline Settings ===${NC}"
    echo -e "${WHITE}1.${NC} Hardware acceleration: ${HARDWARE_ACCELERATION}"
    echo -e "${WHITE}2.${NC} VSync: ${VSYNC_ENABLED}"
    echo -e "${WHITE}3.${NC} Triple buffering: ${TRIPLE_BUFFERING}"
    echo -e "${WHITE}4.${NC} Texture filtering: ${TEXTURE_FILTERING}"
    echo -e "${WHITE}5.${NC} Anti-aliasing: ${ANTIALIASING}"
    echo -e "${WHITE}6.${NC} Render quality: ${RENDER_QUALITY}"
    echo -e "${WHITE}7.${NC} Color depth: ${COLOR_DEPTH}"
    echo -e "${WHITE}8.${NC} Power profile: ${POWER_PROFILE}"
    echo -e "${WHITE}s.${NC} Save settings"
    echo -e "${WHITE}r.${NC} Reset to defaults"
    echo -e "${WHITE}q.${NC} Back to main menu"
    echo
    
    echo -ne "${YELLOW}Select option:${NC} "
    read -r choice
    
    case "$choice" in
        1)
            echo -ne "${CYAN}Hardware acceleration (auto/nvidia/amd/intel/off):${NC} "
            read -r HARDWARE_ACCELERATION
            ;;
        2)
            echo -ne "${CYAN}Enable VSync (true/false):${NC} "
            read -r VSYNC_ENABLED
            ;;
        3)
            echo -ne "${CYAN}Enable triple buffering (true/false):${NC} "
            read -r TRIPLE_BUFFERING
            ;;
        4)
            echo -ne "${CYAN}Texture filtering (linear/anisotropic/none):${NC} "
            read -r TEXTURE_FILTERING
            ;;
        5)
            echo -ne "${CYAN}Anti-aliasing (off/2x/4x/8x/16x):${NC} "
            read -r ANTIALIASING
            ;;
        6)
            echo -ne "${CYAN}Render quality (low/medium/high/ultra):${NC} "
            read -r RENDER_QUALITY
            ;;
        7)
            echo -ne "${CYAN}Color depth (16/24/32):${NC} "
            read -r COLOR_DEPTH
            ;;
        8)
            echo -ne "${CYAN}Power profile (powersave/balanced/performance):${NC} "
            read -r POWER_PROFILE
            ;;
        s|S)
            cat > "$PIPELINE_CONF" << EOF
# BluejayLinux Graphics Pipeline Configuration
HARDWARE_ACCELERATION=$HARDWARE_ACCELERATION
VSYNC_ENABLED=$VSYNC_ENABLED
TRIPLE_BUFFERING=$TRIPLE_BUFFERING
TEXTURE_FILTERING=$TEXTURE_FILTERING
ANTIALIASING=$ANTIALIASING
RENDER_QUALITY=$RENDER_QUALITY
COLOR_DEPTH=$COLOR_DEPTH
REFRESH_RATE=$REFRESH_RATE
COMPOSITOR_BACKEND=$COMPOSITOR_BACKEND
GPU_SCHEDULER=$GPU_SCHEDULER
MEMORY_MANAGEMENT=$MEMORY_MANAGEMENT
POWER_PROFILE=$POWER_PROFILE
EOF
            echo -e "${GREEN}✓${NC} Settings saved"
            ;;
        r|R)
            rm -f "$PIPELINE_CONF"
            create_directories
            load_config
            echo -e "${GREEN}✓${NC} Settings reset to defaults"
            ;;
    esac
}

# Driver information display
driver_info() {
    echo -e "\n${PURPLE}=== Graphics Driver Information ===${NC}"
    
    # Kernel modules
    echo -e "\n${BLUE}Loaded Graphics Modules:${NC}"
    lsmod | grep -E "nvidia|nouveau|amdgpu|radeon|i915|drm" | head -10
    
    # Driver versions
    echo -e "\n${BLUE}Driver Versions:${NC}"
    if command -v nvidia-smi >/dev/null; then
        echo -e "${CYAN}NVIDIA:${NC} $(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1)"
    fi
    
    if [ -f /sys/module/amdgpu/version ]; then
        echo -e "${CYAN}AMD GPU:${NC} $(cat /sys/module/amdgpu/version 2>/dev/null)"
    fi
    
    if [ -f /sys/module/i915/version ]; then
        echo -e "${CYAN}Intel:${NC} $(cat /sys/module/i915/version 2>/dev/null)"
    fi
    
    # OpenGL information
    if command -v glxinfo >/dev/null; then
        echo -e "\n${BLUE}OpenGL Information:${NC}"
        glxinfo | grep -E "OpenGL vendor|OpenGL renderer|OpenGL version" | head -3
    fi
    
    # Vulkan information
    if command -v vulkaninfo >/dev/null; then
        echo -e "\n${BLUE}Vulkan Information:${NC}"
        vulkaninfo | grep -E "deviceName|driverInfo|apiVersion" | head -5
    fi
}

# Main function
main() {
    create_directories
    load_config
    
    if [ $# -gt 0 ]; then
        case "$1" in
            --optimize|-o)
                local gpu_vendor=$(detect_graphics_capabilities | grep -o "nvidia\|amd\|intel" | head -1)
                optimize_graphics_settings "${gpu_vendor:-auto}"
                configure_display_server
                ;;
            --benchmark|-b)
                benchmark_graphics
                ;;
            --monitor|-m)
                monitor_graphics
                ;;
            --troubleshoot|-t)
                troubleshoot_graphics
                ;;
            --info|-i)
                driver_info
                ;;
            --help|-h)
                echo "BluejayLinux Graphics Pipeline"
                echo "Usage: $0 [options]"
                echo "  --optimize, -o      Auto-optimize graphics"
                echo "  --benchmark, -b     Run graphics benchmark"
                echo "  --monitor, -m       Monitor graphics performance"
                echo "  --troubleshoot, -t  Troubleshoot graphics issues"
                echo "  --info, -i          Show driver information"
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
                local gpu_vendor=$(lspci | grep -i "vga\|3d" | grep -oi "nvidia\|amd\|intel" | head -1)
                optimize_graphics_settings "${gpu_vendor:-auto}"
                configure_display_server
                echo -e "${GREEN}✓${NC} Graphics optimization completed"
                ;;
            2)
                configure_display_server
                ;;
            3)
                benchmark_graphics
                ;;
            4)
                monitor_graphics
                ;;
            5)
                troubleshoot_graphics
                ;;
            6)
                settings_menu
                ;;
            7)
                driver_info
                ;;
            q|Q)
                echo -e "${GREEN}Graphics pipeline configuration saved${NC}"
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