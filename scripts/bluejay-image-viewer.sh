#!/bin/bash

# BluejayLinux - Advanced Image Viewer & Editor
# Professional image viewing and basic editing capabilities

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/bluejay"
CACHE_DIR="$HOME/.cache/bluejay/images"
RECENT_FILE="$CONFIG_DIR/recent_images.conf"
SETTINGS_FILE="$CONFIG_DIR/image_viewer.conf"

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

# Supported image formats
SUPPORTED_FORMATS="jpg jpeg png gif bmp tiff webp svg"

# Initialize directories
create_directories() {
    mkdir -p "$CONFIG_DIR" "$CACHE_DIR"
    
    # Create default settings if not exist
    if [ ! -f "$SETTINGS_FILE" ]; then
        cat > "$SETTINGS_FILE" << 'EOF'
# BluejayLinux Image Viewer Settings
DEFAULT_VIEWER=auto
THUMBNAIL_SIZE=200
SLIDESHOW_DELAY=3
AUTO_ROTATE=true
ZOOM_STEP=0.1
BACKGROUND_COLOR=black
FULLSCREEN_MODE=false
SHOW_METADATA=true
QUALITY_LEVEL=95
EOF
    fi
}

# Load settings
load_settings() {
    if [ -f "$SETTINGS_FILE" ]; then
        source "$SETTINGS_FILE"
    fi
}

# Detect available image viewers
detect_image_viewers() {
    local viewers=()
    
    # Professional viewers
    command -v feh >/dev/null && viewers+=("feh")
    command -v sxiv >/dev/null && viewers+=("sxiv")
    command -v geeqie >/dev/null && viewers+=("geeqie")
    command -v gpicview >/dev/null && viewers+=("gpicview")
    command -v mirage >/dev/null && viewers+=("mirage")
    command -v qiv >/dev/null && viewers+=("qiv")
    
    # Basic viewers
    command -v eog >/dev/null && viewers+=("eog")
    command -v xviewer >/dev/null && viewers+=("xviewer")
    command -v ristretto >/dev/null && viewers+=("ristretto")
    
    # Fallback viewers
    command -v display >/dev/null && viewers+=("display")
    command -v fim >/dev/null && viewers+=("fim")
    command -v fbi >/dev/null && viewers+=("fbi")
    
    echo "${viewers[@]}"
}

# Detect image editing tools
detect_image_editors() {
    local editors=()
    
    # Professional editors
    command -v gimp >/dev/null && editors+=("gimp")
    command -v krita >/dev/null && editors+=("krita")
    command -v pinta >/dev/null && editors+=("pinta")
    command -v mtpaint >/dev/null && editors+=("mtpaint")
    
    # Command-line editors
    command -v convert >/dev/null && editors+=("imagemagick")
    command -v ffmpeg >/dev/null && editors+=("ffmpeg")
    
    echo "${editors[@]}"
}

# Get image information
get_image_info() {
    local image_path="$1"
    
    if command -v identify >/dev/null; then
        identify -format "Format: %m\nDimensions: %wx%h\nSize: %b\nColorspace: %r\nDepth: %z-bit\n" "$image_path"
    elif command -v file >/dev/null; then
        file "$image_path"
    else
        echo "Image: $(basename "$image_path")"
        echo "Size: $(du -h "$image_path" | cut -f1)"
    fi
}

# Create thumbnail
create_thumbnail() {
    local image_path="$1"
    local thumb_path="$CACHE_DIR/$(basename "$image_path").thumb.png"
    
    if [ ! -f "$thumb_path" ] || [ "$image_path" -nt "$thumb_path" ]; then
        if command -v convert >/dev/null; then
            convert "$image_path" -thumbnail "${THUMBNAIL_SIZE:-200}x${THUMBNAIL_SIZE:-200}" "$thumb_path" 2>/dev/null
        elif command -v ffmpeg >/dev/null; then
            ffmpeg -i "$image_path" -vf "thumbnail,scale=${THUMBNAIL_SIZE:-200}:${THUMBNAIL_SIZE:-200}" -frames:v 1 "$thumb_path" -y 2>/dev/null
        fi
    fi
    
    echo "$thumb_path"
}

# Basic image editing operations
resize_image() {
    local input="$1"
    local output="$2"
    local width="$3"
    local height="$4"
    
    if command -v convert >/dev/null; then
        convert "$input" -resize "${width}x${height}" "$output"
        echo -e "${GREEN}✓${NC} Image resized to ${width}x${height}"
    else
        echo -e "${RED}✗${NC} ImageMagick not available for resizing"
        return 1
    fi
}

# Rotate image
rotate_image() {
    local input="$1"
    local output="$2"
    local angle="$3"
    
    if command -v convert >/dev/null; then
        convert "$input" -rotate "$angle" "$output"
        echo -e "${GREEN}✓${NC} Image rotated by ${angle} degrees"
    else
        echo -e "${RED}✗${NC} ImageMagick not available for rotation"
        return 1
    fi
}

# Adjust brightness/contrast
adjust_image() {
    local input="$1"
    local output="$2"
    local brightness="$3"
    local contrast="$4"
    
    if command -v convert >/dev/null; then
        convert "$input" -brightness-contrast "${brightness}x${contrast}" "$output"
        echo -e "${GREEN}✓${NC} Adjusted brightness: ${brightness}%, contrast: ${contrast}%"
    else
        echo -e "${RED}✗${NC} ImageMagick not available for adjustments"
        return 1
    fi
}

# Convert image format
convert_format() {
    local input="$1"
    local output="$2"
    local quality="${3:-95}"
    
    if command -v convert >/dev/null; then
        convert "$input" -quality "$quality" "$output"
        echo -e "${GREEN}✓${NC} Converted to $(basename "$output")"
    else
        echo -e "${RED}✗${NC} ImageMagick not available for conversion"
        return 1
    fi
}

# View single image
view_image() {
    local image_path="$1"
    local viewer="$2"
    
    # Add to recent files
    echo "$image_path" >> "$RECENT_FILE"
    tail -20 "$RECENT_FILE" > "$RECENT_FILE.tmp" && mv "$RECENT_FILE.tmp" "$RECENT_FILE"
    
    case "$viewer" in
        feh)
            feh --auto-zoom --borderless --title "BluejayLinux Image Viewer - %f" "$image_path"
            ;;
        sxiv)
            sxiv -a "$image_path"
            ;;
        geeqie)
            geeqie "$image_path"
            ;;
        gpicview)
            gpicview "$image_path"
            ;;
        mirage)
            mirage "$image_path"
            ;;
        qiv)
            qiv -f "$image_path"
            ;;
        eog)
            eog "$image_path"
            ;;
        xviewer)
            xviewer "$image_path"
            ;;
        ristretto)
            ristretto "$image_path"
            ;;
        display)
            display "$image_path"
            ;;
        fim)
            fim "$image_path"
            ;;
        fbi)
            fbi "$image_path"
            ;;
        *)
            # Auto-detect best viewer
            local viewers=($(detect_image_viewers))
            if [ ${#viewers[@]} -gt 0 ]; then
                view_image "$image_path" "${viewers[0]}"
            else
                echo -e "${RED}✗${NC} No image viewer available"
                return 1
            fi
            ;;
    esac
}

# Browse directory
browse_directory() {
    local dir_path="$1"
    local viewer="$2"
    
    # Find all supported images
    local images=()
    for format in $SUPPORTED_FORMATS; do
        while IFS= read -r -d '' file; do
            images+=("$file")
        done < <(find "$dir_path" -maxdepth 1 -type f -iname "*.${format}" -print0 2>/dev/null)
    done
    
    if [ ${#images[@]} -eq 0 ]; then
        echo -e "${YELLOW}!${NC} No supported images found in directory"
        return 1
    fi
    
    # Sort images
    IFS=$'\n' images=($(sort <<<"${images[*]}"))
    unset IFS
    
    case "$viewer" in
        feh)
            feh --auto-zoom --borderless --title "BluejayLinux Image Browser - %f" "${images[@]}"
            ;;
        sxiv)
            sxiv -t "${images[@]}"
            ;;
        geeqie)
            geeqie "${images[0]}"
            ;;
        *)
            # Auto-detect and use best viewer
            local viewers=($(detect_image_viewers))
            if [ ${#viewers[@]} -gt 0 ]; then
                browse_directory "$dir_path" "${viewers[0]}"
            else
                echo -e "${RED}✗${NC} No image viewer available"
                return 1
            fi
            ;;
    esac
}

# Image slideshow
slideshow() {
    local dir_path="$1"
    local delay="${2:-3}"
    
    # Find all supported images
    local images=()
    for format in $SUPPORTED_FORMATS; do
        while IFS= read -r -d '' file; do
            images+=("$file")
        done < <(find "$dir_path" -maxdepth 1 -type f -iname "*.${format}" -print0 2>/dev/null)
    done
    
    if [ ${#images[@]} -eq 0 ]; then
        echo -e "${YELLOW}!${NC} No supported images found for slideshow"
        return 1
    fi
    
    # Sort images
    IFS=$'\n' images=($(sort <<<"${images[*]}"))
    unset IFS
    
    if command -v feh >/dev/null; then
        feh --auto-zoom --borderless --slideshow-delay "$delay" --title "BluejayLinux Slideshow - %f" "${images[@]}"
    else
        echo -e "${BLUE}i${NC} Starting basic slideshow (${delay}s delay)..."
        for image in "${images[@]}"; do
            echo -e "${CYAN}Showing:${NC} $(basename "$image")"
            view_image "$image" "auto"
            sleep "$delay"
        done
    fi
}

# Simple editing interface
editing_menu() {
    local input_file="$1"
    
    echo -e "\n${PURPLE}=== BluejayLinux Image Editor ===${NC}"
    echo -e "${CYAN}Current image:${NC} $(basename "$input_file")"
    echo
    echo -e "${WHITE}1.${NC} Resize image"
    echo -e "${WHITE}2.${NC} Rotate image"
    echo -e "${WHITE}3.${NC} Adjust brightness/contrast"
    echo -e "${WHITE}4.${NC} Convert format"
    echo -e "${WHITE}5.${NC} View image info"
    echo -e "${WHITE}6.${NC} Create thumbnail"
    echo -e "${WHITE}q.${NC} Quit editor"
    echo
    
    while true; do
        echo -ne "${YELLOW}Select option:${NC} "
        read -r choice
        
        case "$choice" in
            1)
                echo -ne "${CYAN}Enter width:${NC} "
                read -r width
                echo -ne "${CYAN}Enter height:${NC} "
                read -r height
                
                local output="${input_file%.*}_resized.${input_file##*.}"
                resize_image "$input_file" "$output" "$width" "$height" && input_file="$output"
                ;;
            2)
                echo -ne "${CYAN}Enter rotation angle (90, 180, 270):${NC} "
                read -r angle
                
                local output="${input_file%.*}_rotated.${input_file##*.}"
                rotate_image "$input_file" "$output" "$angle" && input_file="$output"
                ;;
            3)
                echo -ne "${CYAN}Enter brightness (-100 to 100):${NC} "
                read -r brightness
                echo -ne "${CYAN}Enter contrast (-100 to 100):${NC} "
                read -r contrast
                
                local output="${input_file%.*}_adjusted.${input_file##*.}"
                adjust_image "$input_file" "$output" "$brightness" "$contrast" && input_file="$output"
                ;;
            4)
                echo -ne "${CYAN}Enter new format (jpg, png, gif, etc.):${NC} "
                read -r format
                echo -ne "${CYAN}Enter quality (1-100):${NC} "
                read -r quality
                
                local output="${input_file%.*}.${format}"
                convert_format "$input_file" "$output" "$quality"
                ;;
            5)
                echo -e "\n${BLUE}Image Information:${NC}"
                get_image_info "$input_file"
                echo
                ;;
            6)
                local thumb=$(create_thumbnail "$input_file")
                echo -e "${GREEN}✓${NC} Thumbnail created: $thumb"
                ;;
            q|Q)
                break
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                ;;
        esac
        echo
    done
}

# Main menu
main_menu() {
    echo -e "${PURPLE}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                    ${WHITE}BluejayLinux Image Viewer${PURPLE}                     ║${NC}"
    echo -e "${PURPLE}║                   ${CYAN}Professional Image Management${PURPLE}                 ║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${WHITE}Available viewers:${NC} $(detect_image_viewers | tr ' ' ', ')"
    echo -e "${WHITE}Available editors:${NC} $(detect_image_editors | tr ' ' ', ')"
    echo
    echo -e "${WHITE}1.${NC} View single image"
    echo -e "${WHITE}2.${NC} Browse directory"
    echo -e "${WHITE}3.${NC} Start slideshow"
    echo -e "${WHITE}4.${NC} Edit image"
    echo -e "${WHITE}5.${NC} Recent images"
    echo -e "${WHITE}6.${NC} Image information"
    echo -e "${WHITE}7.${NC} Settings"
    echo -e "${WHITE}q.${NC} Quit"
    echo
}

# Recent images menu
recent_images_menu() {
    if [ ! -f "$RECENT_FILE" ] || [ ! -s "$RECENT_FILE" ]; then
        echo -e "${YELLOW}!${NC} No recent images"
        return
    fi
    
    echo -e "\n${CYAN}Recent Images:${NC}"
    local count=1
    while IFS= read -r image; do
        if [ -f "$image" ]; then
            echo -e "${WHITE}$count.${NC} $(basename "$image")"
            ((count++))
        fi
    done < "$RECENT_FILE"
    
    echo -ne "${YELLOW}Select image (1-$((count-1))) or 'q' to quit:${NC} "
    read -r choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -lt "$count" ]; then
        local selected=$(sed -n "${choice}p" "$RECENT_FILE")
        if [ -f "$selected" ]; then
            view_image "$selected" "auto"
        fi
    fi
}

# Settings menu
settings_menu() {
    echo -e "\n${PURPLE}=== Settings ===${NC}"
    echo -e "${WHITE}1.${NC} Default viewer: ${DEFAULT_VIEWER:-auto}"
    echo -e "${WHITE}2.${NC} Thumbnail size: ${THUMBNAIL_SIZE:-200}px"
    echo -e "${WHITE}3.${NC} Slideshow delay: ${SLIDESHOW_DELAY:-3}s"
    echo -e "${WHITE}4.${NC} Auto rotate: ${AUTO_ROTATE:-true}"
    echo -e "${WHITE}5.${NC} Background color: ${BACKGROUND_COLOR:-black}"
    echo -e "${WHITE}6.${NC} Show metadata: ${SHOW_METADATA:-true}"
    echo -e "${WHITE}s.${NC} Save settings"
    echo -e "${WHITE}q.${NC} Back to main menu"
    echo
    
    echo -ne "${YELLOW}Select option:${NC} "
    read -r choice
    
    case "$choice" in
        1)
            echo -ne "${CYAN}Enter default viewer (auto/feh/sxiv/etc.):${NC} "
            read -r DEFAULT_VIEWER
            ;;
        2)
            echo -ne "${CYAN}Enter thumbnail size (pixels):${NC} "
            read -r THUMBNAIL_SIZE
            ;;
        3)
            echo -ne "${CYAN}Enter slideshow delay (seconds):${NC} "
            read -r SLIDESHOW_DELAY
            ;;
        4)
            echo -ne "${CYAN}Auto rotate images (true/false):${NC} "
            read -r AUTO_ROTATE
            ;;
        5)
            echo -ne "${CYAN}Enter background color:${NC} "
            read -r BACKGROUND_COLOR
            ;;
        6)
            echo -ne "${CYAN}Show metadata (true/false):${NC} "
            read -r SHOW_METADATA
            ;;
        s|S)
            cat > "$SETTINGS_FILE" << EOF
# BluejayLinux Image Viewer Settings
DEFAULT_VIEWER=$DEFAULT_VIEWER
THUMBNAIL_SIZE=$THUMBNAIL_SIZE
SLIDESHOW_DELAY=$SLIDESHOW_DELAY
AUTO_ROTATE=$AUTO_ROTATE
ZOOM_STEP=$ZOOM_STEP
BACKGROUND_COLOR=$BACKGROUND_COLOR
FULLSCREEN_MODE=$FULLSCREEN_MODE
SHOW_METADATA=$SHOW_METADATA
QUALITY_LEVEL=$QUALITY_LEVEL
EOF
            echo -e "${GREEN}✓${NC} Settings saved"
            ;;
    esac
}

# Main function
main() {
    create_directories
    load_settings
    
    if [ $# -gt 0 ]; then
        # Command line usage
        case "$1" in
            --view|-v)
                view_image "$2" "${3:-auto}"
                ;;
            --browse|-b)
                browse_directory "${2:-.}" "${3:-auto}"
                ;;
            --slideshow|-s)
                slideshow "${2:-.}" "${3:-$SLIDESHOW_DELAY}"
                ;;
            --edit|-e)
                editing_menu "$2"
                ;;
            --info|-i)
                get_image_info "$2"
                ;;
            --help|-h)
                echo "BluejayLinux Image Viewer"
                echo "Usage: $0 [options] [file/directory]"
                echo "  --view, -v <file> [viewer]     View single image"
                echo "  --browse, -b [dir] [viewer]    Browse directory"
                echo "  --slideshow, -s [dir] [delay]  Start slideshow"
                echo "  --edit, -e <file>              Edit image"
                echo "  --info, -i <file>              Show image info"
                ;;
            *)
                if [ -f "$1" ]; then
                    view_image "$1" "auto"
                elif [ -d "$1" ]; then
                    browse_directory "$1" "auto"
                else
                    echo -e "${RED}✗${NC} File or directory not found: $1"
                fi
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
                echo -ne "${CYAN}Enter image path:${NC} "
                read -r image_path
                if [ -f "$image_path" ]; then
                    view_image "$image_path" "auto"
                else
                    echo -e "${RED}✗${NC} Image not found"
                fi
                ;;
            2)
                echo -ne "${CYAN}Enter directory path (or . for current):${NC} "
                read -r dir_path
                dir_path="${dir_path:-.}"
                if [ -d "$dir_path" ]; then
                    browse_directory "$dir_path" "auto"
                else
                    echo -e "${RED}✗${NC} Directory not found"
                fi
                ;;
            3)
                echo -ne "${CYAN}Enter directory path (or . for current):${NC} "
                read -r dir_path
                dir_path="${dir_path:-.}"
                echo -ne "${CYAN}Enter delay in seconds (default: $SLIDESHOW_DELAY):${NC} "
                read -r delay
                delay="${delay:-$SLIDESHOW_DELAY}"
                if [ -d "$dir_path" ]; then
                    slideshow "$dir_path" "$delay"
                else
                    echo -e "${RED}✗${NC} Directory not found"
                fi
                ;;
            4)
                echo -ne "${CYAN}Enter image path to edit:${NC} "
                read -r image_path
                if [ -f "$image_path" ]; then
                    editing_menu "$image_path"
                else
                    echo -e "${RED}✗${NC} Image not found"
                fi
                ;;
            5)
                recent_images_menu
                ;;
            6)
                echo -ne "${CYAN}Enter image path:${NC} "
                read -r image_path
                if [ -f "$image_path" ]; then
                    echo -e "\n${BLUE}Image Information:${NC}"
                    get_image_info "$image_path"
                else
                    echo -e "${RED}✗${NC} Image not found"
                fi
                ;;
            7)
                settings_menu
                ;;
            q|Q)
                echo -e "${GREEN}Thanks for using BluejayLinux Image Viewer!${NC}"
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