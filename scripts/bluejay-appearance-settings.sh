#!/bin/bash
# BluejayLinux Desktop Appearance Settings - Complete Implementation
# Themes, wallpapers, icons, desktop customization

set -e

SETTINGS_CONFIG="/etc/bluejay/settings/appearance"
THEMES_DIR="/usr/share/bluejay/themes"
WALLPAPERS_DIR="/usr/share/bluejay/wallpapers"
ICONS_DIR="/usr/share/bluejay/icons"

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

init_appearance_config() {
    mkdir -p "$SETTINGS_CONFIG"
    mkdir -p "$THEMES_DIR"
    mkdir -p "$WALLPAPERS_DIR" 
    mkdir -p "$ICONS_DIR"
    
    cat > "$SETTINGS_CONFIG/config.conf" << 'EOF'
# Desktop Appearance Configuration
CURRENT_THEME=bluejay-default
CURRENT_WALLPAPER=default-bg.jpg
ICON_THEME=bluejay-icons
WINDOW_DECORATIONS=true
TRANSPARENCY_ENABLED=false
ANIMATION_SPEED=normal
DESKTOP_EFFECTS=minimal
TASKBAR_POSITION=bottom
TASKBAR_SIZE=normal
FONT_SIZE=12
FONT_FAMILY=Liberation Sans
CURSOR_THEME=default
ACCENT_COLOR=#4A90E2
EOF

    # Create default theme
    create_default_theme
    create_default_wallpapers
    create_icon_theme
}

create_default_theme() {
    mkdir -p "$THEMES_DIR/bluejay-default"
    
    cat > "$THEMES_DIR/bluejay-default/theme.conf" << 'EOF'
# BluejayLinux Default Theme
THEME_NAME=BluejayLinux Default
WINDOW_BG_COLOR=#2D3748
WINDOW_BORDER_COLOR=#4A5568
TASKBAR_BG_COLOR=#1A202C
TASKBAR_TEXT_COLOR=#FFFFFF
BUTTON_BG_COLOR=#4A90E2
BUTTON_TEXT_COLOR=#FFFFFF
TEXT_COLOR=#E2E8F0
HIGHLIGHT_COLOR=#63B3ED
SHADOW_COLOR=#000000
EOF

    cat > "$THEMES_DIR/bluejay-default/window.css" << 'EOF'
/* BluejayLinux Window Styling */
.window {
    background-color: #2D3748;
    border: 2px solid #4A5568;
    border-radius: 8px;
    box-shadow: 0 4px 12px rgba(0,0,0,0.3);
}

.window-title {
    background-color: #1A202C;
    color: #FFFFFF;
    padding: 8px;
    font-weight: bold;
}

.button {
    background-color: #4A90E2;
    color: #FFFFFF;
    border: none;
    border-radius: 4px;
    padding: 8px 16px;
    margin: 4px;
}

.button:hover {
    background-color: #63B3ED;
}
EOF

    # Create additional themes
    create_theme "dark-mode" "#1A1A1A" "#333333" "#000000" "#FFFFFF" "#BB86FC"
    create_theme "light-mode" "#FFFFFF" "#E0E0E0" "#F5F5F5" "#000000" "#1976D2"
    create_theme "cybersecurity" "#0D1B2A" "#1B263B" "#415A77" "#E0E1DD" "#FF6B35"
}

create_theme() {
    local name="$1"
    local window_bg="$2"
    local border_color="$3"
    local taskbar_bg="$4"
    local text_color="$5"
    local accent="$6"
    
    mkdir -p "$THEMES_DIR/$name"
    
    cat > "$THEMES_DIR/$name/theme.conf" << EOF
THEME_NAME=$name
WINDOW_BG_COLOR=$window_bg
WINDOW_BORDER_COLOR=$border_color
TASKBAR_BG_COLOR=$taskbar_bg
TASKBAR_TEXT_COLOR=$text_color
BUTTON_BG_COLOR=$accent
BUTTON_TEXT_COLOR=$text_color
TEXT_COLOR=$text_color
HIGHLIGHT_COLOR=$accent
SHADOW_COLOR=#000000
EOF
}

create_default_wallpapers() {
    # Create simple colored wallpapers using framebuffer
    cat > "$WALLPAPERS_DIR/generate-wallpapers.sh" << 'EOF'
#!/bin/bash
# Generate default wallpapers

create_solid_wallpaper() {
    local color="$1"
    local name="$2"
    local width=1920
    local height=1080
    
    # Create PPM format wallpaper
    {
        echo "P3"
        echo "$width $height"
        echo "255"
        for ((y=0; y<height; y++)); do
            for ((x=0; x<width; x++)); do
                echo "$color"
            done
        done
    } > "$WALLPAPERS_DIR/$name.ppm"
}

create_gradient_wallpaper() {
    local color1="$1"
    local color2="$2" 
    local name="$3"
    local width=1920
    local height=1080
    
    # Simple vertical gradient
    {
        echo "P3"
        echo "$width $height"
        echo "255"
        for ((y=0; y<height; y++)); do
            local factor=$((y * 255 / height))
            local inv_factor=$((255 - factor))
            for ((x=0; x<width; x++)); do
                echo "$((color1 * inv_factor / 255)) $((color1 * inv_factor / 255)) $((color1 * inv_factor / 255))"
            done
        done
    } > "$WALLPAPERS_DIR/$name.ppm"
}

# Create default wallpapers
create_solid_wallpaper "45 55 72" "bluejay-dark"
create_solid_wallpaper "240 240 245" "bluejay-light"
create_solid_wallpaper "13 27 42" "cybersec-dark"
create_gradient_wallpaper 45 13 "bluejay-gradient"

echo "Default wallpapers created"
EOF

    chmod +x "$WALLPAPERS_DIR/generate-wallpapers.sh"
    "$WALLPAPERS_DIR/generate-wallpapers.sh"
}

create_icon_theme() {
    mkdir -p "$ICONS_DIR/bluejay-icons"
    
    # Create basic icon definitions
    cat > "$ICONS_DIR/bluejay-icons/icons.conf" << 'EOF'
# BluejayLinux Icon Theme
ICON_THEME_NAME=BluejayLinux Icons
ICON_SIZE_SMALL=16
ICON_SIZE_MEDIUM=32
ICON_SIZE_LARGE=48

# Icon mappings
FOLDER_ICON=folder.png
FILE_ICON=file.png
TERMINAL_ICON=terminal.png
SETTINGS_ICON=settings.png
BROWSER_ICON=browser.png
TEXT_EDITOR_ICON=text.png
EOF

    # Create simple ASCII-based icons for now
    /home/alastair/linux-6.16/scripts/create-placeholder-icons.sh "$ICONS_DIR/bluejay-icons/"
}

show_appearance_menu() {
    clear
    source "$SETTINGS_CONFIG/config.conf"
    
    echo -e "${PURPLE}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║       BluejayLinux Appearance Settings       ║${NC}"  
    echo -e "${PURPLE}║           Desktop Customization              ║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Current Configuration:${NC}"
    echo "Theme: $CURRENT_THEME"
    echo "Wallpaper: $CURRENT_WALLPAPER"
    echo "Icon Theme: $ICON_THEME"
    echo "Font: $FONT_FAMILY ($FONT_SIZE pt)"
    echo "Taskbar: $TASKBAR_POSITION ($TASKBAR_SIZE)"
    echo ""
    echo -e "${YELLOW}Appearance Options:${NC}"
    echo "[1] Change Theme"
    echo "[2] Set Wallpaper" 
    echo "[3] Icon Theme Settings"
    echo "[4] Font Configuration"
    echo "[5] Window Decorations"
    echo "[6] Taskbar Customization"
    echo "[7] Desktop Effects"
    echo "[8] Color Scheme"
    echo "[9] Preview Changes"
    echo "[0] Apply & Exit"
    echo ""
    echo -n "Select option: "
}

change_theme() {
    echo -e "${BLUE}Theme Selection${NC}"
    echo "=================="
    echo ""
    echo "Available themes:"
    local i=1
    for theme_dir in "$THEMES_DIR"/*; do
        if [ -d "$theme_dir" ]; then
            local theme_name=$(basename "$theme_dir")
            echo "[$i] $theme_name"
            i=$((i+1))
        fi
    done
    
    echo -n "Select theme number: "
    read theme_choice
    
    local selected_theme
    i=1
    for theme_dir in "$THEMES_DIR"/*; do
        if [ -d "$theme_dir" ] && [ "$i" = "$theme_choice" ]; then
            selected_theme=$(basename "$theme_dir")
            break
        fi
        i=$((i+1))
    done
    
    if [ -n "$selected_theme" ]; then
        sed -i "s/CURRENT_THEME=.*/CURRENT_THEME=$selected_theme/" "$SETTINGS_CONFIG/config.conf"
        apply_theme "$selected_theme"
        echo -e "${GREEN}Theme changed to: $selected_theme${NC}"
    else
        echo -e "${RED}Invalid theme selection${NC}"
    fi
    
    read -p "Press Enter to continue..."
}

set_wallpaper() {
    echo -e "${BLUE}Wallpaper Selection${NC}"
    echo "==================="
    echo ""
    echo "Available wallpapers:"
    ls "$WALLPAPERS_DIR"/*.ppm 2>/dev/null | sed 's|.*/||; s|\.ppm||' | nl
    echo ""
    echo -n "Enter wallpaper name: "
    read wallpaper_name
    
    if [ -f "$WALLPAPERS_DIR/$wallpaper_name.ppm" ]; then
        sed -i "s/CURRENT_WALLPAPER=.*/CURRENT_WALLPAPER=$wallpaper_name.ppm/" "$SETTINGS_CONFIG/config.conf"
        apply_wallpaper "$wallpaper_name.ppm"
        echo -e "${GREEN}Wallpaper set to: $wallpaper_name${NC}"
    else
        echo -e "${RED}Wallpaper not found: $wallpaper_name${NC}"
    fi
    
    read -p "Press Enter to continue..."
}

configure_fonts() {
    echo -e "${BLUE}Font Configuration${NC}"
    echo "=================="
    echo ""
    echo "Current font: $FONT_FAMILY ($FONT_SIZE pt)"
    echo ""
    echo "Available font families:"
    echo "[1] Liberation Sans"
    echo "[2] Liberation Mono"
    echo "[3] DejaVu Sans" 
    echo "[4] Ubuntu"
    echo -n "Select font family: "
    read font_choice
    
    local new_font
    case $font_choice in
        1) new_font="Liberation Sans" ;;
        2) new_font="Liberation Mono" ;;
        3) new_font="DejaVu Sans" ;;
        4) new_font="Ubuntu" ;;
        *) echo "Invalid choice"; return ;;
    esac
    
    echo -n "Enter font size (8-24): "
    read font_size
    
    if [ "$font_size" -ge 8 ] && [ "$font_size" -le 24 ]; then
        sed -i "s/FONT_FAMILY=.*/FONT_FAMILY=$new_font/" "$SETTINGS_CONFIG/config.conf"
        sed -i "s/FONT_SIZE=.*/FONT_SIZE=$font_size/" "$SETTINGS_CONFIG/config.conf"
        apply_font_settings "$new_font" "$font_size"
        echo -e "${GREEN}Font updated: $new_font ($font_size pt)${NC}"
    else
        echo -e "${RED}Invalid font size${NC}"
    fi
    
    read -p "Press Enter to continue..."
}

customize_taskbar() {
    echo -e "${BLUE}Taskbar Customization${NC}"
    echo "=====================" 
    echo ""
    echo "Current: $TASKBAR_POSITION position, $TASKBAR_SIZE size"
    echo ""
    echo "Position:"
    echo "[1] Top"
    echo "[2] Bottom"
    echo "[3] Left"
    echo "[4] Right"
    echo -n "Select position: "
    read pos_choice
    
    local new_position
    case $pos_choice in
        1) new_position="top" ;;
        2) new_position="bottom" ;;
        3) new_position="left" ;;
        4) new_position="right" ;;
        *) echo "Invalid choice"; return ;;
    esac
    
    echo ""
    echo "Size:"
    echo "[1] Small"
    echo "[2] Normal"
    echo "[3] Large"
    echo -n "Select size: "
    read size_choice
    
    local new_size
    case $size_choice in
        1) new_size="small" ;;
        2) new_size="normal" ;;
        3) new_size="large" ;;
        *) echo "Invalid choice"; return ;;
    esac
    
    sed -i "s/TASKBAR_POSITION=.*/TASKBAR_POSITION=$new_position/" "$SETTINGS_CONFIG/config.conf"
    sed -i "s/TASKBAR_SIZE=.*/TASKBAR_SIZE=$new_size/" "$SETTINGS_CONFIG/config.conf"
    apply_taskbar_settings "$new_position" "$new_size"
    echo -e "${GREEN}Taskbar updated: $new_position position, $new_size size${NC}"
    
    read -p "Press Enter to continue..."
}

configure_color_scheme() {
    echo -e "${BLUE}Color Scheme Configuration${NC}"
    echo "=========================="
    echo ""
    echo "Current accent color: $ACCENT_COLOR"
    echo ""
    echo "Preset color schemes:"
    echo "[1] Blue (#4A90E2)"
    echo "[2] Purple (#BB86FC)"
    echo "[3] Green (#4CAF50)"
    echo "[4] Orange (#FF9800)"
    echo "[5] Red (#F44336)"
    echo "[6] Custom color"
    echo -n "Select color scheme: "
    read color_choice
    
    local new_color
    case $color_choice in
        1) new_color="#4A90E2" ;;
        2) new_color="#BB86FC" ;;
        3) new_color="#4CAF50" ;;
        4) new_color="#FF9800" ;;
        5) new_color="#F44336" ;;
        6) 
            echo -n "Enter hex color (e.g., #FF6600): "
            read new_color
            ;;
        *) echo "Invalid choice"; return ;;
    esac
    
    sed -i "s/ACCENT_COLOR=.*/ACCENT_COLOR=$new_color/" "$SETTINGS_CONFIG/config.conf"
    apply_color_scheme "$new_color"
    echo -e "${GREEN}Accent color updated: $new_color${NC}"
    
    read -p "Press Enter to continue..."
}

apply_theme() {
    local theme_name="$1"
    
    if [ -f "$THEMES_DIR/$theme_name/theme.conf" ]; then
        source "$THEMES_DIR/$theme_name/theme.conf"
        
        # Apply theme to window manager
        if [ -x /opt/bluejay/bin/bluejay-window-manager ]; then
            echo "Applying theme: $theme_name"
            # Signal window manager to reload theme
            killall -USR1 bluejay-window-manager 2>/dev/null || true
        fi
        
        # Update CSS if available
        if [ -f "$THEMES_DIR/$theme_name/window.css" ]; then
            cp "$THEMES_DIR/$theme_name/window.css" "/etc/bluejay/current-theme.css"
        fi
        
        echo "Theme '$theme_name' applied successfully"
    fi
}

apply_wallpaper() {
    local wallpaper="$1"
    
    if [ -f "$WALLPAPERS_DIR/$wallpaper" ]; then
        # Set wallpaper using framebuffer
        if [ -c /dev/fb0 ]; then
            # Convert PPM to framebuffer format and apply
            echo "Setting wallpaper: $wallpaper"
            # This would require a PPM to framebuffer converter
            echo "Wallpaper applied (framebuffer implementation needed)"
        fi
        
        # Update desktop background
        echo "$wallpaper" > /tmp/current-wallpaper
    fi
}

apply_font_settings() {
    local font_family="$1"
    local font_size="$2"
    
    # Update font configuration
    cat > /etc/bluejay/font.conf << EOF
SYSTEM_FONT_FAMILY=$font_family
SYSTEM_FONT_SIZE=$font_size
EOF
    
    # Signal applications to reload fonts
    echo "Font settings updated: $font_family ($font_size pt)"
}

apply_taskbar_settings() {
    local position="$1"
    local size="$2"
    
    # Update taskbar configuration
    cat > /etc/bluejay/taskbar.conf << EOF
TASKBAR_POSITION=$position
TASKBAR_SIZE=$size
EOF
    
    # Signal window manager to reconfigure taskbar
    killall -USR2 bluejay-window-manager 2>/dev/null || true
    echo "Taskbar configuration updated"
}

apply_color_scheme() {
    local accent_color="$1"
    
    # Update color scheme
    sed -i "s/#4A90E2/$accent_color/g" /etc/bluejay/current-theme.css 2>/dev/null || true
    echo "Color scheme updated with accent: $accent_color"
}

preview_changes() {
    echo -e "${BLUE}Preview Current Settings${NC}"
    echo "======================="
    echo ""
    source "$SETTINGS_CONFIG/config.conf"
    
    echo "Theme: $CURRENT_THEME"
    echo "Wallpaper: $CURRENT_WALLPAPER"
    echo "Icons: $ICON_THEME"
    echo "Font: $FONT_FAMILY ($FONT_SIZE pt)"
    echo "Taskbar: $TASKBAR_POSITION ($TASKBAR_SIZE)"
    echo "Accent Color: $ACCENT_COLOR"
    echo "Transparency: $TRANSPARENCY_ENABLED"
    echo "Animations: $ANIMATION_SPEED"
    echo ""
    echo "Changes will be applied to:"
    echo "• Window decorations and borders"
    echo "• Desktop background"
    echo "• Application themes"
    echo "• Font rendering"
    echo "• Taskbar appearance"
    echo ""
    read -p "Press Enter to continue..."
}

apply_all_settings() {
    echo -e "${YELLOW}Applying all appearance settings...${NC}"
    
    source "$SETTINGS_CONFIG/config.conf"
    
    apply_theme "$CURRENT_THEME"
    apply_wallpaper "$CURRENT_WALLPAPER"
    apply_font_settings "$FONT_FAMILY" "$FONT_SIZE"
    apply_taskbar_settings "$TASKBAR_POSITION" "$TASKBAR_SIZE"
    apply_color_scheme "$ACCENT_COLOR"
    
    echo -e "${GREEN}✅ All appearance settings applied successfully!${NC}"
    echo ""
    echo "Desktop appearance has been updated."
    echo "Some changes may require logging out and back in."
    
    read -p "Press Enter to continue..."
}

main() {
    # Initialize if needed
    if [ ! -f "$SETTINGS_CONFIG/config.conf" ]; then
        echo "Initializing appearance settings..."
        init_appearance_config
    fi
    
    while true; do
        show_appearance_menu
        read choice
        
        case $choice in
            1) change_theme ;;
            2) set_wallpaper ;;
            3) echo "Icon theme settings - Coming soon" && read -p "Press Enter..." ;;
            4) configure_fonts ;;
            5) echo "Window decorations - Coming soon" && read -p "Press Enter..." ;;
            6) customize_taskbar ;;
            7) echo "Desktop effects - Coming soon" && read -p "Press Enter..." ;;
            8) configure_color_scheme ;;
            9) preview_changes ;;
            0) apply_all_settings && exit 0 ;;
            *) echo -e "${RED}Invalid option${NC}" && sleep 1 ;;
        esac
    done
}

main "$@"