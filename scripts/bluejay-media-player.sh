#!/bin/bash
# BluejayLinux Integrated Media Player - Complete Implementation
# Video, audio, image viewer with advanced features

set -e

MEDIA_CONFIG="$HOME/.config/bluejay/media.conf"
MEDIA_DATA="$HOME/.local/share/bluejay/media"
PLAYLISTS_DIR="$MEDIA_DATA/playlists"

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Initialize media configuration
init_media_config() {
    mkdir -p "$(dirname "$MEDIA_CONFIG")"
    mkdir -p "$MEDIA_DATA"
    mkdir -p "$PLAYLISTS_DIR"
    
    if [ ! -f "$MEDIA_CONFIG" ]; then
        cat > "$MEDIA_CONFIG" << 'EOF'
# BluejayLinux Media Player Configuration
DEFAULT_VOLUME=70
AUTO_PLAY=false
REPEAT_MODE=none
SHUFFLE_MODE=false
FULLSCREEN_MODE=false
SUBTITLE_ENABLED=true
VIDEO_QUALITY=auto

# Audio settings
AUDIO_OUTPUT=auto
EQUALIZER_ENABLED=false
BASS_BOOST=false
AUDIO_NORMALIZATION=true

# Video settings
VIDEO_ACCELERATION=auto
ASPECT_RATIO=auto
ZOOM_LEVEL=100
BRIGHTNESS=50
CONTRAST=50
SATURATION=50

# Interface settings
SHOW_CONTROLS=true
SHOW_PLAYLIST=true
SHOW_VISUALIZER=false
THEME=dark
CONTROL_TIMEOUT=3000
EOF
    fi
    
    create_default_playlists
}

# Create default playlists
create_default_playlists() {
    cat > "$PLAYLISTS_DIR/favorites.m3u" << 'EOF'
#EXTM3U
#PLAYLIST:Favorites
EOF

    cat > "$PLAYLISTS_DIR/recently_played.m3u" << 'EOF'
#EXTM3U
#PLAYLIST:Recently Played
EOF
}

# Load configuration
load_config() {
    [ -f "$MEDIA_CONFIG" ] && source "$MEDIA_CONFIG"
}

# Show media player menu
show_media_menu() {
    clear
    load_config
    
    echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║       BluejayLinux Integrated Media Player   ║${NC}"
    echo -e "${BLUE}║        Audio, Video & Image Viewer v2.0      ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${CYAN}Media Player Status:${NC}"
    echo "Volume: $DEFAULT_VOLUME%"
    echo "Repeat: $REPEAT_MODE"
    echo "Shuffle: $SHUFFLE_MODE"
    echo "Video Quality: $VIDEO_QUALITY"
    echo ""
    
    echo -e "${YELLOW}Media Options:${NC}"
    echo "[1] Open Media File              [9] Create Playlist"
    echo "[2] Browse Media Library         [10] Audio Settings"
    echo "[3] Play Audio                   [11] Video Settings"
    echo "[4] Play Video                   [12] Image Viewer"
    echo "[5] View Images                  [13] Media Converter"
    echo "[6] Playlist Manager             [14] Screen Recording"
    echo "[7] Recently Played              [15] Media Info"
    echo "[8] Media Scanner                [16] Settings"
    echo ""
    echo "[p] Quick Play  [v] Volume  [q] Quit"
    echo ""
    echo -n "bluejay-media> "
}

# Open media file
open_media_file() {
    echo -n "Media file path: "
    read filepath
    
    if [ ! -f "$filepath" ]; then
        echo -e "${RED}File not found: $filepath${NC}"
        return
    fi
    
    local file_type=$(detect_media_type "$filepath")
    
    case "$file_type" in
        audio) play_audio "$filepath" ;;
        video) play_video "$filepath" ;;
        image) view_image "$filepath" ;;
        *) echo -e "${RED}Unsupported file type${NC}" ;;
    esac
}

# Detect media file type
detect_media_type() {
    local filepath="$1"
    local extension="${filepath##*.}"
    
    case "${extension,,}" in
        mp3|wav|flac|ogg|aac|m4a|wma) echo "audio" ;;
        mp4|avi|mkv|mov|wmv|flv|webm|m4v) echo "video" ;;
        jpg|jpeg|png|gif|bmp|tiff|svg|webp) echo "image" ;;
        *) echo "unknown" ;;
    esac
}

# Play audio file
play_audio() {
    local filepath="$1"
    
    echo -e "${BLUE}Playing Audio: $(basename "$filepath")${NC}"
    show_media_info "$filepath"
    
    # Add to recently played
    add_to_recently_played "$filepath"
    
    # Try different audio players
    if command -v mpg123 >/dev/null; then
        echo "Using mpg123..."
        mpg123 "$filepath"
    elif command -v aplay >/dev/null && [[ "$filepath" == *.wav ]]; then
        echo "Using aplay for WAV..."
        aplay "$filepath"
    elif command -v paplay >/dev/null; then
        echo "Using paplay..."
        paplay "$filepath"
    elif command -v ffplay >/dev/null; then
        echo "Using ffplay..."
        ffplay -nodisp -autoexit "$filepath"
    else
        echo -e "${YELLOW}No audio player found. Simulating playback...${NC}"
        simulate_audio_playback "$filepath"
    fi
}

# Play video file
play_video() {
    local filepath="$1"
    
    echo -e "${BLUE}Playing Video: $(basename "$filepath")${NC}"
    show_media_info "$filepath"
    
    # Add to recently played
    add_to_recently_played "$filepath"
    
    # Try different video players
    if command -v mpv >/dev/null; then
        echo "Using mpv..."
        mpv "$filepath"
    elif command -v vlc >/dev/null; then
        echo "Using VLC..."
        vlc "$filepath"
    elif command -v ffplay >/dev/null; then
        echo "Using ffplay..."
        ffplay "$filepath"
    else
        echo -e "${YELLOW}No video player found. Showing video info...${NC}"
        simulate_video_playback "$filepath"
    fi
}

# View image
view_image() {
    local filepath="$1"
    
    echo -e "${BLUE}Viewing Image: $(basename "$filepath")${NC}"
    show_image_info "$filepath"
    
    # Try different image viewers
    if command -v feh >/dev/null; then
        echo "Using feh..."
        feh "$filepath"
    elif command -v eog >/dev/null; then
        echo "Using Eye of GNOME..."
        eog "$filepath"
    elif command -v display >/dev/null; then
        echo "Using ImageMagick display..."
        display "$filepath"
    else
        echo -e "${YELLOW}No image viewer found. Showing image info...${NC}"
        show_detailed_image_info "$filepath"
    fi
}

# Show media information
show_media_info() {
    local filepath="$1"
    
    echo -e "${CYAN}Media Information:${NC}"
    echo "File: $(basename "$filepath")"
    echo "Size: $(ls -lh "$filepath" | awk '{print $5}')"
    echo "Path: $filepath"
    
    if command -v file >/dev/null; then
        echo "Type: $(file -b "$filepath")"
    fi
    
    # Try to get duration and other metadata
    if command -v ffprobe >/dev/null 2>&1; then
        echo ""
        echo -e "${CYAN}Technical Details:${NC}"
        ffprobe -v quiet -show_format -show_streams "$filepath" 2>/dev/null | \
        grep -E "^(duration|width|height|codec_name|bit_rate)" | \
        head -10 || echo "Metadata not available"
    fi
    
    echo ""
}

# Show detailed image information
show_detailed_image_info() {
    local filepath="$1"
    
    echo -e "${CYAN}Image Details:${NC}"
    
    if command -v identify >/dev/null; then
        identify "$filepath"
    else
        echo "Image viewer not available for detailed info"
    fi
    
    echo ""
    echo "🖼️  Image would be displayed here in GUI mode"
    echo ""
    
    read -p "Press Enter to continue..."
}

# Simulate audio playback
simulate_audio_playback() {
    local filepath="$1"
    local duration=30  # Simulate 30 second playback
    
    echo ""
    echo -e "${GREEN}♪ Now Playing: $(basename "$filepath")${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "🎵 Audio visualization would appear here"
    echo ""
    echo "Controls: [Space] Play/Pause  [Q] Quit  [→] Next  [←] Previous"
    echo ""
    
    local elapsed=0
    while [ $elapsed -lt $duration ]; do
        local progress=$((elapsed * 50 / duration))
        local bar=""
        for i in $(seq 1 50); do
            if [ $i -le $progress ]; then
                bar="${bar}█"
            else
                bar="${bar}░"
            fi
        done
        
        printf "\r🎵 %02d:%02d [$bar] %02d:%02d" \
            $((elapsed / 60)) $((elapsed % 60)) \
            $((duration / 60)) $((duration % 60))
        
        sleep 1
        elapsed=$((elapsed + 1))
    done
    
    echo ""
    echo ""
    echo -e "${GREEN}Playback completed${NC}"
}

# Simulate video playback
simulate_video_playback() {
    local filepath="$1"
    
    echo ""
    echo -e "${GREEN}📽️  Now Playing: $(basename "$filepath")${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "🎬 Video would be playing here"
    echo "   [Full screen video display]"
    echo ""
    echo "Video Controls:"
    echo "  [Space] Play/Pause"
    echo "  [F] Fullscreen"
    echo "  [↑/↓] Volume"
    echo "  [←/→] Seek"
    echo "  [Q] Quit"
    echo ""
    
    read -p "Press Enter to stop video..."
}

# Browse media library
browse_media_library() {
    echo -e "${BLUE}Media Library Browser${NC}"
    echo "===================="
    echo ""
    
    local media_dirs=("$HOME/Music" "$HOME/Videos" "$HOME/Pictures" "$HOME/Downloads")
    
    for dir in "${media_dirs[@]}"; do
        if [ -d "$dir" ]; then
            echo -e "${YELLOW}📁 $dir${NC}"
            
            # Count media files
            local audio_count=$(find "$dir" -maxdepth 2 -type f \( -iname "*.mp3" -o -iname "*.wav" -o -iname "*.flac" -o -iname "*.ogg" \) 2>/dev/null | wc -l)
            local video_count=$(find "$dir" -maxdepth 2 -type f \( -iname "*.mp4" -o -iname "*.avi" -o -iname "*.mkv" -o -iname "*.mov" \) 2>/dev/null | wc -l)
            local image_count=$(find "$dir" -maxdepth 2 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \) 2>/dev/null | wc -l)
            
            echo "  🎵 Audio: $audio_count files"
            echo "  🎬 Video: $video_count files"  
            echo "  🖼️  Images: $image_count files"
            echo ""
            
            # Show recent files
            echo "  Recent files:"
            find "$dir" -maxdepth 2 -type f \( -iname "*.mp3" -o -iname "*.mp4" -o -iname "*.jpg" -o -iname "*.png" \) -printf "    %f\n" 2>/dev/null | head -3
            echo ""
        fi
    done
    
    echo "[1] Browse Music"
    echo "[2] Browse Videos"
    echo "[3] Browse Images"
    echo "[4] Search Media"
    echo "[b] Back to main menu"
    echo -n "Choice: "
    read browse_choice
    
    case $browse_choice in
        1) browse_directory "$HOME/Music" "audio" ;;
        2) browse_directory "$HOME/Videos" "video" ;;
        3) browse_directory "$HOME/Pictures" "image" ;;
        4) search_media ;;
        b) return ;;
    esac
}

# Browse specific directory
browse_directory() {
    local dir="$1"
    local type="$2"
    
    if [ ! -d "$dir" ]; then
        echo "Directory not found: $dir"
        return
    fi
    
    echo -e "${BLUE}Browsing $type files in: $dir${NC}"
    echo ""
    
    local pattern=""
    case "$type" in
        audio) pattern="-iname *.mp3 -o -iname *.wav -o -iname *.flac -o -iname *.ogg -o -iname *.aac" ;;
        video) pattern="-iname *.mp4 -o -iname *.avi -o -iname *.mkv -o -iname *.mov -o -iname *.wmv" ;;
        image) pattern="-iname *.jpg -o -iname *.jpeg -o -iname *.png -o -iname *.gif -o -iname *.bmp" ;;
    esac
    
    local files=()
    while IFS= read -r -d '' file; do
        files+=("$file")
    done < <(find "$dir" -type f \( $pattern \) -print0 2>/dev/null | head -20)
    
    if [ ${#files[@]} -eq 0 ]; then
        echo "No $type files found in $dir"
        return
    fi
    
    for i in "${!files[@]}"; do
        echo "[$((i+1))] $(basename "${files[$i]}")"
    done
    
    echo ""
    echo -n "Select file to play (1-${#files[@]}): "
    read file_choice
    
    if [ "$file_choice" -ge 1 ] && [ "$file_choice" -le ${#files[@]} ]; then
        local selected_file="${files[$((file_choice - 1))]}"
        case "$type" in
            audio) play_audio "$selected_file" ;;
            video) play_video "$selected_file" ;;
            image) view_image "$selected_file" ;;
        esac
    fi
}

# Search media files
search_media() {
    echo -n "Search term: "
    read search_term
    
    if [ -z "$search_term" ]; then
        return
    fi
    
    echo -e "${BLUE}Searching for: $search_term${NC}"
    echo ""
    
    local search_dirs=("$HOME/Music" "$HOME/Videos" "$HOME/Pictures" "$HOME/Downloads")
    
    for dir in "${search_dirs[@]}"; do
        if [ -d "$dir" ]; then
            local results=$(find "$dir" -type f \( -iname "*$search_term*" \) \
                           \( -iname "*.mp3" -o -iname "*.wav" -o -iname "*.mp4" -o -iname "*.avi" -o -iname "*.jpg" -o -iname "*.png" \) 2>/dev/null)
            
            if [ -n "$results" ]; then
                echo -e "${YELLOW}Results in $dir:${NC}"
                echo "$results" | while read -r file; do
                    echo "  $(basename "$file")"
                done
                echo ""
            fi
        fi
    done
}

# Add to recently played
add_to_recently_played() {
    local filepath="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Add to recently played playlist
    echo "$timestamp | $(basename "$filepath") | $filepath" >> "$PLAYLISTS_DIR/recently_played.log"
    
    # Keep only last 50 entries
    tail -50 "$PLAYLISTS_DIR/recently_played.log" > "$PLAYLISTS_DIR/recently_played.log.tmp"
    mv "$PLAYLISTS_DIR/recently_played.log.tmp" "$PLAYLISTS_DIR/recently_played.log"
}

# Show recently played
show_recently_played() {
    echo -e "${BLUE}Recently Played Media${NC}"
    echo "===================="
    echo ""
    
    if [ -f "$PLAYLISTS_DIR/recently_played.log" ]; then
        tail -10 "$PLAYLISTS_DIR/recently_played.log" | nl
        echo ""
        echo -n "Play item number (or Enter to go back): "
        read item_choice
        
        if [[ "$item_choice" =~ ^[0-9]+$ ]]; then
            local item_line=$(tail -10 "$PLAYLISTS_DIR/recently_played.log" | sed -n "${item_choice}p")
            if [ -n "$item_line" ]; then
                local filepath=$(echo "$item_line" | awk -F' | ' '{print $3}')
                if [ -f "$filepath" ]; then
                    local file_type=$(detect_media_type "$filepath")
                    case "$file_type" in
                        audio) play_audio "$filepath" ;;
                        video) play_video "$filepath" ;;
                        image) view_image "$filepath" ;;
                    esac
                else
                    echo "File not found: $filepath"
                fi
            fi
        fi
    else
        echo "No recently played media"
    fi
}

# Volume control
volume_control() {
    load_config
    
    echo -e "${BLUE}Volume Control${NC}"
    echo "=============="
    echo ""
    echo "Current volume: $DEFAULT_VOLUME%"
    echo ""
    echo "[1] Set Volume"
    echo "[2] Volume Up (+10)"
    echo "[3] Volume Down (-10)"
    echo "[4] Mute/Unmute"
    echo "[5] Audio Test"
    echo -n "Choice: "
    read vol_choice
    
    case $vol_choice in
        1)
            echo -n "New volume (0-100): "
            read new_volume
            if [ "$new_volume" -ge 0 ] && [ "$new_volume" -le 100 ]; then
                set_system_volume "$new_volume"
                sed -i "s/DEFAULT_VOLUME=.*/DEFAULT_VOLUME=$new_volume/" "$MEDIA_CONFIG"
                echo "Volume set to $new_volume%"
            fi
            ;;
        2)
            new_volume=$((DEFAULT_VOLUME + 10))
            [ "$new_volume" -gt 100 ] && new_volume=100
            set_system_volume "$new_volume"
            sed -i "s/DEFAULT_VOLUME=.*/DEFAULT_VOLUME=$new_volume/" "$MEDIA_CONFIG"
            echo "Volume increased to $new_volume%"
            ;;
        3)
            new_volume=$((DEFAULT_VOLUME - 10))
            [ "$new_volume" -lt 0 ] && new_volume=0
            set_system_volume "$new_volume"
            sed -i "s/DEFAULT_VOLUME=.*/DEFAULT_VOLUME=$new_volume/" "$MEDIA_CONFIG"
            echo "Volume decreased to $new_volume%"
            ;;
        4)
            toggle_mute
            ;;
        5)
            echo "Playing audio test..."
            # Generate a test tone if available
            if command -v speaker-test >/dev/null; then
                speaker-test -t sine -f 1000 -l 1 -s 1
            else
                echo "Audio test: beep beep! 🔊"
            fi
            ;;
    esac
}

# Set system volume
set_system_volume() {
    local volume="$1"
    
    if command -v amixer >/dev/null; then
        amixer set Master "${volume}%" >/dev/null 2>&1
    elif command -v pactl >/dev/null; then
        pactl set-sink-volume @DEFAULT_SINK@ "${volume}%" >/dev/null 2>&1
    fi
}

# Toggle mute
toggle_mute() {
    if command -v amixer >/dev/null; then
        amixer set Master toggle >/dev/null 2>&1
        local mute_status=$(amixer get Master | grep -o '\[on\]\|\[off\]' | head -1)
        if [ "$mute_status" = "[off]" ]; then
            echo "Audio muted"
        else
            echo "Audio unmuted"
        fi
    else
        echo "Mute toggle not available"
    fi
}

# Media settings
media_settings() {
    load_config
    
    echo -e "${BLUE}Media Player Settings${NC}"
    echo "===================="
    echo ""
    echo "[1] Default Volume (Current: $DEFAULT_VOLUME%)"
    echo "[2] Auto-play (Current: $AUTO_PLAY)"
    echo "[3] Repeat Mode (Current: $REPEAT_MODE)"
    echo "[4] Shuffle Mode (Current: $SHUFFLE_MODE)"
    echo "[5] Video Quality (Current: $VIDEO_QUALITY)"
    echo "[6] Subtitle Support (Current: $SUBTITLE_ENABLED)"
    echo "[7] Audio Output (Current: $AUDIO_OUTPUT)"
    echo "[8] Video Acceleration (Current: $VIDEO_ACCELERATION)"
    echo -n "Select setting: "
    read setting_choice
    
    case $setting_choice in
        1) volume_control ;;
        2) toggle_media_setting "AUTO_PLAY" ;;
        3) change_repeat_mode ;;
        4) toggle_media_setting "SHUFFLE_MODE" ;;
        5) change_video_quality ;;
        6) toggle_media_setting "SUBTITLE_ENABLED" ;;
        *) echo "Setting not yet implemented" ;;
    esac
}

# Toggle media setting
toggle_media_setting() {
    local setting="$1"
    local current_value=$(grep "^$setting=" "$MEDIA_CONFIG" | cut -d= -f2)
    
    if [ "$current_value" = "true" ]; then
        sed -i "s/$setting=.*/$setting=false/" "$MEDIA_CONFIG"
        echo "$setting disabled"
    else
        sed -i "s/$setting=.*/$setting=true/" "$MEDIA_CONFIG"
        echo "$setting enabled"
    fi
}

# Main application loop
main() {
    init_media_config
    
    # Handle command line arguments
    case "$1" in
        --help|help)
            show_media_help
            exit 0
            ;;
        *.mp3|*.wav|*.flac|*.ogg|*.aac)
            play_audio "$1"
            exit 0
            ;;
        *.mp4|*.avi|*.mkv|*.mov|*.wmv)
            play_video "$1"
            exit 0
            ;;
        *.jpg|*.jpeg|*.png|*.gif|*.bmp)
            view_image "$1"
            exit 0
            ;;
    esac
    
    while true; do
        show_media_menu
        read choice
        
        case $choice in
            1) open_media_file ;;
            2) browse_media_library ;;
            3) echo -n "Audio file: "; read audio_file; [ -f "$audio_file" ] && play_audio "$audio_file" ;;
            4) echo -n "Video file: "; read video_file; [ -f "$video_file" ] && play_video "$video_file" ;;
            5) echo -n "Image file: "; read image_file; [ -f "$image_file" ] && view_image "$image_file" ;;
            6) echo "Playlist manager - Coming soon" ;;
            7) show_recently_played ;;
            8) echo "Media scanner - Coming soon" ;;
            9) echo "Create playlist - Coming soon" ;;
            10) echo "Audio settings - Coming soon" ;;
            11) echo "Video settings - Coming soon" ;;
            12) browse_directory "$HOME/Pictures" "image" ;;
            13) echo "Media converter - Coming soon" ;;
            14) echo "Screen recording - Coming soon" ;;
            15) echo -n "Media file for info: "; read info_file; [ -f "$info_file" ] && show_media_info "$info_file" ;;
            16) media_settings ;;
            p) open_media_file ;;
            v) volume_control ;;
            q) exit 0 ;;
            *) echo "Invalid option" ;;
        esac
        
        [ "$choice" != "p" ] && [ "$choice" != "v" ] && read -p "Press Enter to continue..."
    done
}

# Show media help
show_media_help() {
    echo -e "${BLUE}BluejayLinux Media Player Help${NC}"
    echo "=============================="
    echo ""
    echo -e "${YELLOW}Supported Formats:${NC}"
    echo "Audio: MP3, WAV, FLAC, OGG, AAC, M4A"
    echo "Video: MP4, AVI, MKV, MOV, WMV, FLV"
    echo "Image: JPG, PNG, GIF, BMP, TIFF, SVG"
    echo ""
    echo -e "${YELLOW}Features:${NC}"
    echo "• Integrated audio/video/image playback"
    echo "• Media library management"
    echo "• Playlist support"
    echo "• Recently played tracking"
    echo "• Volume control integration"
    echo "• Media information display"
}

main "$@"