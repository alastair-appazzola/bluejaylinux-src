#!/bin/bash
# Build Blue-Jay Linux Media Applications

set -e

source ../build-bluejay.sh 2>/dev/null || {
    ROOTFS="/tmp/bluejay-build/rootfs"
    BUILD_ROOT="/tmp/bluejay-build"
}

log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $1"; }

create_image_viewer() {
    log_info "Creating Blue-Jay image viewer..."
    
    cat > "${ROOTFS}/usr/bin/bluejay-images" << 'EOF'
#!/bin/bash
# Blue-Jay Linux Image Viewer

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

current_dir="${1:-$(pwd)}"
current_image=""
image_list=()

detect_image_viewers() {
    local viewers=()
    local commands=()
    
    # GUI image viewers (preferred)
    if command -v feh >/dev/null; then
        viewers+=("feh (Fast Image Viewer)")
        commands+=("feh")
    fi
    
    if command -v eog >/dev/null; then
        viewers+=("Eye of GNOME")
        commands+=("eog")
    fi
    
    if command -v xviewer >/dev/null; then
        viewers+=("XViewer")
        commands+=("xviewer")
    fi
    
    if command -v gpicview >/dev/null; then
        viewers+=("GPicView")
        commands+=("gpicview")
    fi
    
    if command -v ristretto >/dev/null; then
        viewers+=("Ristretto (XFCE)")
        commands+=("ristretto")
    fi
    
    # Terminal image viewers
    if command -v chafa >/dev/null; then
        viewers+=("Chafa (Terminal)")
        commands+=("chafa")
    fi
    
    if command -v catimg >/dev/null; then
        viewers+=("CatImg (Terminal)")
        commands+=("catimg")
    fi
    
    if command -v viu >/dev/null; then
        viewers+=("Viu (Terminal)")
        commands+=("viu")
    fi
    
    # Basic fallback
    if command -v file >/dev/null; then
        viewers+=("File Info (Basic)")
        commands+=("file")
    fi
    
    echo "${viewers[@]}|${commands[@]}"
}

find_images() {
    image_list=()
    local extensions="jpg jpeg png gif bmp tiff webp svg ico"
    
    for ext in $extensions; do
        for img in "$current_dir"/*.$ext "$current_dir"/*.$ext.* 2>/dev/null; do
            if [ -f "$img" ]; then
                image_list+=("$img")
            fi
        done
        # Also check uppercase
        for img in "$current_dir"/*.${ext^^} "$current_dir"/*.${ext^^}.* 2>/dev/null; do
            if [ -f "$img" ]; then
                image_list+=("$img")
            fi
        done
    done
    
    # Remove duplicates and sort
    if [ ${#image_list[@]} -gt 0 ]; then
        readarray -t image_list < <(printf '%s\n' "${image_list[@]}" | sort -u)
    fi
}

show_header() {
    clear
    echo -e "${BLUE}Blue-Jay Image Viewer${NC}"
    echo "===================="
    echo -e "Directory: ${GREEN}$current_dir${NC}"
    if [ -n "$current_image" ]; then
        echo -e "Current Image: ${YELLOW}$(basename "$current_image")${NC}"
    fi
    echo ""
}

list_images() {
    find_images
    
    if [ ${#image_list[@]} -eq 0 ]; then
        echo -e "${YELLOW}No images found in current directory.${NC}"
        echo ""
        return
    fi
    
    echo -e "${GREEN}Images found (${#image_list[@]}):${NC}"
    echo ""
    
    for i in "${!image_list[@]}"; do
        local img="${image_list[$i]}"
        local size=$(du -h "$img" 2>/dev/null | cut -f1)
        local dimensions=$(identify "$img" 2>/dev/null | cut -d' ' -f3 || echo "unknown")
        
        printf "%2d) %-30s %8s %s\n" $((i+1)) "$(basename "$img")" "$size" "$dimensions"
    done
    echo ""
}

view_image() {
    local image_file="$1"
    
    if [ ! -f "$image_file" ]; then
        echo -e "${RED}Image file not found: $image_file${NC}"
        return
    fi
    
    current_image="$image_file"
    
    # Get available viewers
    local viewer_info=$(detect_image_viewers)
    local viewers=(${viewer_info%|*})
    local commands=(${viewer_info#*|})
    
    if [ ${#commands[@]} -eq 0 ]; then
        echo -e "${RED}No image viewers available!${NC}"
        echo "Install an image viewer:"
        echo "  sudo jay-pkg install image-viewer"
        echo "  sudo apt install feh eog gpicview"
        return
    fi
    
    # Show image info first
    echo -e "${GREEN}Image Information:${NC}"
    echo "File: $(basename "$image_file")"
    echo "Size: $(du -h "$image_file" 2>/dev/null | cut -f1)"
    echo "Type: $(file "$image_file" | cut -d: -f2-)"
    
    if command -v identify >/dev/null; then
        identify "$image_file" 2>/dev/null | while read line; do
            echo "Details: $line"
        done
    fi
    echo ""
    
    # If in GUI, try GUI viewers first
    if [ -n "$DISPLAY" ]; then
        for cmd in "${commands[@]}"; do
            case "$cmd" in
                "feh"|"eog"|"xviewer"|"gpicview"|"ristretto")
                    echo "Opening with $cmd..."
                    "$cmd" "$image_file" 2>/dev/null &
                    return
                    ;;
            esac
        done
    fi
    
    # Try terminal viewers
    for cmd in "${commands[@]}"; do
        case "$cmd" in
            "chafa")
                echo "Displaying with chafa..."
                chafa --size=80x24 "$image_file"
                break
                ;;
            "catimg")
                echo "Displaying with catimg..."
                catimg "$image_file"
                break
                ;;
            "viu")
                echo "Displaying with viu..."
                viu "$image_file"
                break
                ;;
            "file")
                echo "Image file information:"
                file "$image_file"
                break
                ;;
        esac
    done
}

slideshow_mode() {
    if [ ${#image_list[@]} -eq 0 ]; then
        echo "No images for slideshow"
        return
    fi
    
    echo -e "${GREEN}Starting slideshow...${NC}"
    echo "Press Ctrl+C to stop"
    sleep 2
    
    for img in "${image_list[@]}"; do
        clear
        echo -e "${BLUE}Slideshow: $(basename "$img")${NC}"
        view_image "$img"
        sleep 3
    done
    
    echo "Slideshow complete!"
    read -p "Press Enter to continue..."
}

batch_convert() {
    if [ ${#image_list[@]} -eq 0 ]; then
        echo "No images to convert"
        return
    fi
    
    echo -e "${YELLOW}Batch Image Conversion${NC}"
    echo "===================="
    echo ""
    echo "Convert to format:"
    echo "[1] JPEG"
    echo "[2] PNG" 
    echo "[3] WebP"
    echo "[4] Resize images"
    echo ""
    echo -n "Choose option: "
    read option
    
    case "$option" in
        1)
            echo "Converting to JPEG..."
            for img in "${image_list[@]}"; do
                if command -v convert >/dev/null; then
                    convert "$img" "${img%.*}.jpg"
                    echo "Converted: $(basename "$img")"
                fi
            done
            ;;
        2)
            echo "Converting to PNG..."
            for img in "${image_list[@]}"; do
                if command -v convert >/dev/null; then
                    convert "$img" "${img%.*}.png"
                    echo "Converted: $(basename "$img")"
                fi
            done
            ;;
        3)
            echo "Converting to WebP..."
            for img in "${image_list[@]}"; do
                if command -v cwebp >/dev/null; then
                    cwebp "$img" -o "${img%.*}.webp"
                    echo "Converted: $(basename "$img")"
                fi
            done
            ;;
        4)
            echo -n "Resize to (e.g., 800x600): "
            read size
            for img in "${image_list[@]}"; do
                if command -v convert >/dev/null; then
                    convert "$img" -resize "$size" "${img%.*}_resized.${img##*.}"
                    echo "Resized: $(basename "$img")"
                fi
            done
            ;;
    esac
    
    read -p "Press Enter to continue..."
}

show_menu() {
    echo -e "${YELLOW}Image Viewer Commands:${NC}"
    echo ""
    echo "[number] View image by number"
    echo "[next/n] Next image"
    echo "[prev/p] Previous image" 
    echo "[slideshow/s] Start slideshow"
    echo "[convert/c] Batch convert images"
    echo "[info/i] Show image information"
    echo "[cd] Change directory"
    echo "[refresh/r] Refresh image list"
    echo "[help/h] Show help"
    echo "[quit/q] Exit"
    echo ""
    echo -n "bluejay-images> "
}

handle_command() {
    local cmd="$1"
    
    case "$cmd" in
        [0-9]*)
            local index=$((cmd - 1))
            if [ $index -ge 0 ] && [ $index -lt ${#image_list[@]} ]; then
                view_image "${image_list[$index]}"
                read -p "Press Enter to continue..."
            else
                echo "Invalid image number"
                sleep 1
            fi
            ;;
        "next"|"n")
            if [ -n "$current_image" ]; then
                for i in "${!image_list[@]}"; do
                    if [ "${image_list[$i]}" = "$current_image" ]; then
                        local next_index=$(( (i + 1) % ${#image_list[@]} ))
                        view_image "${image_list[$next_index]}"
                        read -p "Press Enter to continue..."
                        break
                    fi
                done
            else
                echo "No current image selected"
                sleep 1
            fi
            ;;
        "prev"|"p")
            if [ -n "$current_image" ]; then
                for i in "${!image_list[@]}"; do
                    if [ "${image_list[$i]}" = "$current_image" ]; then
                        local prev_index=$(( (i - 1 + ${#image_list[@]}) % ${#image_list[@]} ))
                        view_image "${image_list[$prev_index]}"
                        read -p "Press Enter to continue..."
                        break
                    fi
                done
            else
                echo "No current image selected"
                sleep 1
            fi
            ;;
        "slideshow"|"s")
            slideshow_mode
            ;;
        "convert"|"c")
            batch_convert
            ;;
        "info"|"i")
            if [ -n "$current_image" ]; then
                echo -e "${GREEN}Detailed Image Information:${NC}"
                echo "=========================="
                file "$current_image"
                if command -v exiftool >/dev/null; then
                    exiftool "$current_image" 2>/dev/null | head -20
                elif command -v identify >/dev/null; then
                    identify -verbose "$current_image" 2>/dev/null | head -20
                fi
                read -p "Press Enter to continue..."
            else
                echo "No current image selected"
                sleep 1
            fi
            ;;
        "cd")
            echo -n "Enter directory path: "
            read new_dir
            if [ -d "$new_dir" ]; then
                current_dir="$new_dir"
                current_image=""
            else
                echo "Directory not found: $new_dir"
                sleep 1
            fi
            ;;
        "refresh"|"r")
            find_images
            echo "Image list refreshed"
            sleep 1
            ;;
        "help"|"h")
            clear
            echo -e "${BLUE}Blue-Jay Image Viewer Help${NC}"
            echo "========================="
            echo ""
            echo "Supported formats: JPEG, PNG, GIF, BMP, TIFF, WebP, SVG, ICO"
            echo ""
            echo "Viewers supported:"
            echo "- feh (recommended)"
            echo "- Eye of GNOME (eog)"
            echo "- GPicView"
            echo "- Ristretto (XFCE)"
            echo "- chafa (terminal)"
            echo "- catimg (terminal)"
            echo ""
            echo "Install image tools:"
            echo "  sudo jay-pkg install image-viewer"
            echo "  sudo apt install feh eog imagemagick"
            echo ""
            read -p "Press Enter to continue..."
            ;;
        "quit"|"q"|"exit")
            exit 0
            ;;
        *)
            echo "Unknown command: $cmd"
            echo "Type 'help' for available commands"
            sleep 1
            ;;
    esac
}

main() {
    # Check if a specific image was passed
    if [ $# -eq 1 ] && [ -f "$1" ]; then
        view_image "$1"
        exit 0
    fi
    
    # Interactive mode
    while true; do
        show_header
        list_images
        show_menu
        read cmd
        handle_command "$cmd"
    done
}

main "$@"
EOF
    chmod +x "${ROOTFS}/usr/bin/bluejay-images"
    
    # Create desktop entry
    cat > "${ROOTFS}/usr/share/applications/bluejay-images.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Image Viewer
Comment=View and manage images
Icon=image-x-generic
Exec=xfce4-terminal -e bluejay-images
Categories=Graphics;Photography;Viewer;
Keywords=image;photo;picture;view;graphics;
MimeType=image/jpeg;image/png;image/gif;image/bmp;image/tiff;image/webp;
StartupNotify=true
EOF
    
    log_success "Image viewer created"
}

create_media_player() {
    log_info "Creating media player..."
    
    cat > "${ROOTFS}/usr/bin/bluejay-media" << 'EOF'
#!/bin/bash
# Blue-Jay Linux Media Player

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

detect_media_players() {
    echo -e "${GREEN}Available Media Players:${NC}"
    
    local found_player=false
    
    if command -v vlc >/dev/null; then
        echo "  VLC Media Player - vlc [file]"
        found_player=true
    fi
    
    if command -v mpv >/dev/null; then
        echo "  MPV Player - mpv [file]"
        found_player=true
    fi
    
    if command -v mplayer >/dev/null; then
        echo "  MPlayer - mplayer [file]"
        found_player=true
    fi
    
    if command -v totem >/dev/null; then
        echo "  GNOME Videos (Totem) - totem [file]"
        found_player=true
    fi
    
    if command -v parole >/dev/null; then
        echo "  Parole (XFCE) - parole [file]"
        found_player=true
    fi
    
    if [ "$found_player" = false ]; then
        echo "  No media players installed"
        echo ""
        echo "Install options:"
        echo "  sudo jay-pkg install media-player"
        echo "  sudo apt install vlc mpv"
    fi
    
    echo ""
}

play_media() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        echo -e "${RED}File not found: $file${NC}"
        return
    fi
    
    echo "Playing: $(basename "$file")"
    
    # Try players in order of preference
    if command -v vlc >/dev/null; then
        vlc "$file" 2>/dev/null &
    elif command -v mpv >/dev/null; then
        mpv "$file"
    elif command -v mplayer >/dev/null; then
        mplayer "$file"
    elif command -v totem >/dev/null; then
        totem "$file" 2>/dev/null &
    else
        echo "No media player available"
        echo "File info:"
        file "$file"
    fi
}

if [ $# -eq 1 ]; then
    play_media "$1"
else
    echo -e "${BLUE}Blue-Jay Media Player${NC}"
    echo "===================="
    echo ""
    detect_media_players
    echo -n "Enter media file path: "
    read media_file
    play_media "$media_file"
fi
EOF
    chmod +x "${ROOTFS}/usr/bin/bluejay-media"
    
    # Create desktop entry
    cat > "${ROOTFS}/usr/share/applications/bluejay-media.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Media Player
Comment=Play audio and video files
Icon=multimedia-player
Exec=bluejay-media
Categories=AudioVideo;Player;
Keywords=media;video;audio;player;music;
MimeType=video/mpeg;video/mp4;video/avi;audio/mpeg;audio/mp3;audio/ogg;
StartupNotify=true
EOF
    
    log_success "Media player created"
}

create_screenshot_tool() {
    log_info "Creating screenshot tool..."
    
    cat > "${ROOTFS}/usr/bin/bluejay-screenshot" << 'EOF'
#!/bin/bash
# Blue-Jay Linux Screenshot Tool

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

take_screenshot() {
    local mode="$1"
    local output_dir="$HOME/Pictures/Screenshots"
    local filename="bluejay-screenshot-$(date +%Y%m%d-%H%M%S).png"
    
    # Create screenshots directory
    mkdir -p "$output_dir"
    
    local full_path="$output_dir/$filename"
    
    case "$mode" in
        "full")
            if command -v scrot >/dev/null; then
                scrot "$full_path"
            elif command -v gnome-screenshot >/dev/null; then
                gnome-screenshot -f "$full_path"
            elif command -v import >/dev/null; then
                import -window root "$full_path"
            else
                echo "No screenshot tool available"
                return 1
            fi
            ;;
        "window")
            if command -v scrot >/dev/null; then
                echo "Click on window to capture..."
                scrot -s "$full_path"
            elif command -v gnome-screenshot >/dev/null; then
                gnome-screenshot -w -f "$full_path"
            elif command -v import >/dev/null; then
                echo "Click on window to capture..."
                import "$full_path"
            else
                echo "No screenshot tool available"
                return 1
            fi
            ;;
        "area")
            if command -v scrot >/dev/null; then
                echo "Select area to capture..."
                scrot -s "$full_path"
            elif command -v gnome-screenshot >/dev/null; then
                gnome-screenshot -a -f "$full_path"
            elif command -v import >/dev/null; then
                echo "Select area to capture..."
                import "$full_path"
            else
                echo "No screenshot tool available"
                return 1
            fi
            ;;
    esac
    
    if [ -f "$full_path" ]; then
        echo -e "${GREEN}Screenshot saved: $full_path${NC}"
        
        # Show thumbnail if possible
        if command -v chafa >/dev/null; then
            echo "Preview:"
            chafa --size=40x20 "$full_path"
        fi
        
        # Open with image viewer
        echo "Open with image viewer? (y/N): "
        read open_viewer
        if [[ "$open_viewer" =~ ^[Yy] ]]; then
            bluejay-images "$full_path"
        fi
    else
        echo -e "${RED}Screenshot failed${NC}"
    fi
}

echo -e "${BLUE}Blue-Jay Screenshot Tool${NC}"
echo "======================="
echo ""
echo "[1] Full screen"
echo "[2] Select window"
echo "[3] Select area"
echo "[q] Quit"
echo ""
echo -n "Choose option: "

read choice
case "$choice" in
    1) take_screenshot "full" ;;
    2) take_screenshot "window" ;;
    3) take_screenshot "area" ;;
    [Qq]) exit 0 ;;
    *) echo "Invalid option" ;;
esac
EOF
    chmod +x "${ROOTFS}/usr/bin/bluejay-screenshot"
    
    # Create desktop entry
    cat > "${ROOTFS}/usr/share/applications/bluejay-screenshot.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Screenshot
Comment=Take screenshots
Icon=applets-screenshooter
Exec=bluejay-screenshot
Categories=Graphics;Photography;
Keywords=screenshot;capture;image;
StartupNotify=true
EOF
    
    log_success "Screenshot tool created"
}

update_file_manager_media() {
    log_info "Adding media support to file manager..."
    
    # Create media file associations
    cat > "${ROOTFS}/usr/share/applications/mimeapps.list" << 'EOF'
[Default Applications]
image/jpeg=bluejay-images.desktop
image/png=bluejay-images.desktop
image/gif=bluejay-images.desktop
image/bmp=bluejay-images.desktop
image/tiff=bluejay-images.desktop
image/webp=bluejay-images.desktop
video/mp4=bluejay-media.desktop
video/avi=bluejay-media.desktop
video/mkv=bluejay-media.desktop
audio/mp3=bluejay-media.desktop
audio/ogg=bluejay-media.desktop
audio/wav=bluejay-media.desktop

[Added Associations]
image/jpeg=bluejay-images.desktop
image/png=bluejay-images.desktop
video/mp4=bluejay-media.desktop
audio/mp3=bluejay-media.desktop
EOF
    
    log_success "Media file associations created"
}

create_desktop_shortcuts() {
    log_info "Creating media desktop shortcuts..."
    
    cat > "${ROOTFS}/home/bluejay/Desktop/Image Viewer.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Image Viewer
Comment=View and manage images
Icon=image-x-generic
Exec=bluejay-images
StartupNotify=true
EOF
    
    cat > "${ROOTFS}/home/bluejay/Desktop/Screenshot.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Screenshot
Comment=Take screenshots
Icon=applets-screenshooter
Exec=bluejay-screenshot
StartupNotify=true
EOF
    
    chmod +x "${ROOTFS}/home/bluejay/Desktop"/*.desktop
    
    log_success "Desktop shortcuts created"
}

main() {
    log_info "Building Blue-Jay Linux media applications..."
    
    create_image_viewer
    create_media_player
    create_screenshot_tool
    update_file_manager_media
    create_desktop_shortcuts
    
    log_success "Media applications build complete!"
    echo ""
    echo "Blue-Jay Linux now includes:"
    echo "  ✓ Professional Image Viewer (bluejay-images)"
    echo "  ✓ Media Player (bluejay-media)"
    echo "  ✓ Screenshot Tool (bluejay-screenshot)"
    echo "  ✓ File associations for media files"
    echo "  ✓ Desktop shortcuts"
    echo ""
    echo "Supported formats:"
    echo "  Images: JPEG, PNG, GIF, BMP, TIFF, WebP, SVG"
    echo "  Video: MP4, AVI, MKV, MOV, WMV"
    echo "  Audio: MP3, OGG, WAV, FLAC"
    echo ""
    echo "Use: bluejay-images to browse and view images"
}

main "$@"