#!/bin/bash
# Create Blue Placeholder Icons for Blue-Jay Linux

set -e

source ../build-bluejay.sh 2>/dev/null || {
    ROOTFS="/tmp/bluejay-build/rootfs"
}

log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }

create_placeholder_icon() {
    local name="$1"
    local size="$2"
    local text="$3"
    local output_path="$4"
    
    # Create blue square placeholder with text using ImageMagick if available
    if command -v convert >/dev/null; then
        convert -size ${size}x${size} xc:'#3B82F6' \
                -fill white -gravity center \
                -pointsize $((size/8)) \
                -annotate +0+0 "$text" \
                "$output_path"
    else
        # Fallback: create simple PPM format manually
        create_simple_placeholder "$name" "$size" "$output_path"
    fi
}

create_simple_placeholder() {
    local name="$1"
    local size="$2"
    local output_path="$3"
    
    # Create simple blue square in PPM format, then convert to PNG
    local ppm_file="${output_path%.png}.ppm"
    
    {
        echo "P3"
        echo "$size $size" 
        echo "255"
        for ((i=0; i<size*size; i++)); do
            echo "59 130 246"  # Blue color RGB
        done
    } > "$ppm_file"
    
    # Convert to PNG if possible, otherwise keep PPM
    if command -v convert >/dev/null; then
        convert "$ppm_file" "$output_path"
        rm "$ppm_file"
    else
        mv "$ppm_file" "$output_path"
    fi
}

# Enhanced icon creation function for appearance settings
create_appearance_icon() {
    local name="$1"
    local icon_dir="$2"
    local content="$3"
    
    mkdir -p "$icon_dir"
    
    cat > "$icon_dir/${name}.txt" << EOF
# ASCII Icon: $name
# BluejayLinux Icon Theme
$content
EOF
}

create_ascii_art() {
    log_info "Creating ASCII art placeholders..."
    
    # Main Blue-Jay ASCII art
    cat > "${ROOTFS}/usr/share/pixmaps/bluejay-ascii.txt" << 'EOF'
 ____  _             
| __ )| |_   _  ___  
|  _ \| | | | |/ _ \ 
| |_) | | |_| |  __/ 
|____/|_|\__,_|\___| 
      _             
     | | __ _ _   _  
  _  | |/ _` | | | | 
 | |_| | (_| | |_| | 
  \___/ \__,_|\__, | 
              |___/  

🐦 Blue-Jay Linux
Cybersecurity Made Simple
EOF
    
    # Small ASCII for terminals
    cat > "${ROOTFS}/usr/share/pixmaps/bluejay-small.txt" << 'EOF'
🐦 Blue-Jay Linux
EOF
    
    log_success "ASCII art created"
}

create_fallback_icons() {
    log_info "Creating blue placeholder icons..."
    
    # Ensure directories exist
    mkdir -p "${ROOTFS}/usr/share/pixmaps/bluejay-icons"
    mkdir -p "${ROOTFS}/usr/share/icons/bluejay/48x48/apps"
    
    # Application icons with blue placeholders
    local icons=(
        "bluejay-control-center:🐦⚙️"
        "bluejay-tools:🐦🛡️" 
        "bluejay-files:🐦📁"
        "bluejay-terminal:🐦💻"
        "bluejay-browser:🐦🌐"
        "bluejay-images:🐦🖼️"
        "bluejay-settings:🐦🔧"
        "bluejay-disks:🐦💿"
        "bluejay-screenshot:🐦📷"
        "bluejay-media:🐦▶️"
    )
    
    for icon_info in "${icons[@]}"; do
        local icon_name="${icon_info%:*}"
        local icon_symbol="${icon_info#*:}"
        local icon_path="${ROOTFS}/usr/share/pixmaps/${icon_name}.png"
        
        # Check if real icon exists
        if [ ! -f "$icon_path" ]; then
            log_info "Creating placeholder for $icon_name..."
            create_placeholder_icon "$icon_name" 48 "$icon_symbol" "$icon_path"
        fi
        
        # Also create in standard icon directory
        cp "$icon_path" "${ROOTFS}/usr/share/icons/bluejay/48x48/apps/" 2>/dev/null || true
    done
    
    log_success "Placeholder icons created"
}

create_theme_fallbacks() {
    log_info "Creating theme and wallpaper fallbacks..."
    
    # Create solid blue wallpaper script
    cat > "${ROOTFS}/usr/bin/generate-bluejay-wallpaper" << 'EOF'
#!/bin/bash
# Generate Blue-Jay Linux wallpaper

WALLPAPER_DIR="$HOME/.config/bluejay/wallpapers"
mkdir -p "$WALLPAPER_DIR"

# Check if custom wallpaper exists
if [ -f "/usr/share/pixmaps/bluejay-wallpaper.png" ]; then
    # Use custom wallpaper
    cp "/usr/share/pixmaps/bluejay-wallpaper.png" "$WALLPAPER_DIR/current.png"
else
    # Generate solid blue background
    if command -v convert >/dev/null; then
        # Create gradient wallpaper
        convert -size 1920x1080 \
                gradient:'#1E3A8A-#3B82F6' \
                "$WALLPAPER_DIR/current.png"
        
        # Add Blue-Jay text overlay
        convert "$WALLPAPER_DIR/current.png" \
                -fill white -gravity southeast \
                -pointsize 48 -font Arial-Bold \
                -annotate +50+50 "🐦 Blue-Jay Linux" \
                "$WALLPAPER_DIR/current.png"
    else
        # Create simple solid color file
        echo "Creating solid blue wallpaper..."
        # For now, just use desktop color setting
    fi
fi

echo "Blue-Jay wallpaper ready: $WALLPAPER_DIR/current.png"
EOF
    chmod +x "${ROOTFS}/usr/bin/generate-bluejay-wallpaper"
    
    # Create boot splash generator
    cat > "${ROOTFS}/usr/bin/generate-boot-splash" << 'EOF'
#!/bin/bash
# Generate Blue-Jay Linux boot splash

if command -v convert >/dev/null; then
    # Create boot splash with solid background
    convert -size 1920x1080 xc:'#1E293B' \
            -fill '#3B82F6' -gravity center \
            -pointsize 72 -font Arial-Bold \
            -annotate +0-100 "🐦 Blue-Jay Linux" \
            -fill white -pointsize 24 \
            -annotate +0+50 "Cybersecurity Made Simple" \
            -annotate +0+100 "Version 1.0.0" \
            /boot/splash.png
else
    echo "ImageMagick not available, using text-only boot"
fi
EOF
    chmod +x "${ROOTFS}/usr/bin/generate-boot-splash"
    
    log_success "Theme generators created"
}

update_desktop_entries() {
    log_info "Updating desktop entries with fallback icons..."
    
    # Update all .desktop files to use fallback icons
    local desktop_files=(
        "${ROOTFS}/usr/share/applications/bluejay-control-center.desktop"
        "${ROOTFS}/usr/share/applications/bluejay-tools.desktop"
        "${ROOTFS}/usr/share/applications/bluejay-files.desktop"
        "${ROOTFS}/usr/share/applications/bluejay-terminal.desktop"
        "${ROOTFS}/usr/share/applications/bluejay-browser.desktop"
        "${ROOTFS}/usr/share/applications/bluejay-images.desktop"
        "${ROOTFS}/usr/share/applications/bluejay-settings.desktop"
        "${ROOTFS}/usr/share/applications/bluejay-disks.desktop"
        "${ROOTFS}/usr/share/applications/bluejay-screenshot.desktop"
        "${ROOTFS}/usr/share/applications/bluejay-media.desktop"
    )
    
    for desktop_file in "${desktop_files[@]}"; do
        if [ -f "$desktop_file" ]; then
            # Extract the app name for icon fallback
            local app_name=$(basename "$desktop_file" .desktop)
            
            # Add fallback icon path
            sed -i "s|^Icon=.*|Icon=/usr/share/pixmaps/${app_name}.png|" "$desktop_file"
            
            # Add GenericName for better menu integration
            echo "GenericName=Blue-Jay Application" >> "$desktop_file"
        fi
    done
    
    log_success "Desktop entries updated with fallback icons"
}

create_icon_theme() {
    log_info "Creating Blue-Jay icon theme..."
    
    # Create icon theme structure
    mkdir -p "${ROOTFS}/usr/share/icons/bluejay"/{16x16,24x24,32x32,48x48,64x64,96x96,128x128,256x256}/{apps,devices,places,status}
    
    # Create theme index
    cat > "${ROOTFS}/usr/share/icons/bluejay/index.theme" << 'EOF'
[Icon Theme]
Name=Blue-Jay
Comment=Blue-Jay Linux icon theme
Inherits=Adwaita,hicolor
Directories=16x16/apps,24x24/apps,32x32/apps,48x48/apps,64x64/apps,96x96/apps,128x128/apps,256x256/apps,48x48/devices,48x48/places,48x48/status

[16x16/apps]
Size=16
Context=Applications
Type=Fixed

[24x24/apps]  
Size=24
Context=Applications
Type=Fixed

[32x32/apps]
Size=32
Context=Applications
Type=Fixed

[48x48/apps]
Size=48
Context=Applications
Type=Fixed

[64x64/apps]
Size=64
Context=Applications
Type=Fixed

[96x96/apps]
Size=96
Context=Applications
Type=Fixed

[128x128/apps]
Size=128
Context=Applications
Type=Fixed

[256x256/apps]
Size=256
Context=Applications
Type=Fixed

[48x48/devices]
Size=48
Context=Devices
Type=Fixed

[48x48/places]
Size=48
Context=Places  
Type=Fixed

[48x48/status]
Size=48
Context=Status
Type=Fixed
EOF
    
    log_success "Icon theme structure created"
}

main() {
    log_info "Creating Blue-Jay Linux placeholder graphics..."
    
    create_ascii_art
    create_fallback_icons
    create_theme_fallbacks
    update_desktop_entries
    create_icon_theme
    
    log_success "Placeholder graphics system complete!"
    echo ""
    echo "Blue-Jay Linux graphics ready:"
    echo "  ✓ ASCII art logos with 🐦"
    echo "  ✓ Blue placeholder icons for all apps"
    echo "  ✓ Code-generated wallpapers (solid blue)"
    echo "  ✓ Fallback icon theme"
    echo "  ✓ Theme generation scripts"
    echo ""
    echo "When real images are available:"
    echo "  1. Drop PNG files in /usr/share/pixmaps/"
    echo "  2. System will automatically use them"
    echo "  3. Placeholders serve as backup"
}

main "$@"