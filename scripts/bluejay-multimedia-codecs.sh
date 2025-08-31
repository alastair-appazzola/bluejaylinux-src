#!/bin/bash

# BluejayLinux - Multimedia Codec Support System
# Comprehensive codec management and media format support

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/bluejay"
CACHE_DIR="$HOME/.cache/bluejay/codecs"
CODECS_CONF="$CONFIG_DIR/multimedia_codecs.conf"
FORMATS_DB="$CONFIG_DIR/supported_formats.db"

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

# Supported codec categories
AUDIO_CODECS="mp3 aac flac ogg wav m4a opus wma"
VIDEO_CODECS="mp4 avi mkv mov wmv flv webm ogv 3gp"
IMAGE_CODECS="jpg jpeg png gif bmp tiff webp svg ico"
CONTAINER_FORMATS="mp4 avi mkv mov wmv flv webm ogv 3gp ts m2ts"

# Initialize directories and configuration
create_directories() {
    mkdir -p "$CONFIG_DIR" "$CACHE_DIR"
    
    # Create default codec configuration
    if [ ! -f "$CODECS_CONF" ]; then
        cat > "$CODECS_CONF" << 'EOF'
# BluejayLinux Multimedia Codecs Configuration
AUDIO_BACKEND=auto
VIDEO_BACKEND=auto
HARDWARE_DECODING=auto
SOFTWARE_FALLBACK=true
QUALITY_PREFERENCE=balanced
ENCODING_PRESET=medium
DECODING_THREADS=auto
AUDIO_SAMPLE_RATE=48000
VIDEO_BITRATE=auto
AUDIO_BITRATE=320k
SUBTITLE_SUPPORT=true
METADATA_EXTRACTION=true
THUMBNAIL_GENERATION=true
STREAMING_OPTIMIZATION=false
EOF
    fi
    
    # Create formats database
    if [ ! -f "$FORMATS_DB" ]; then
        create_formats_database
    fi
}

# Create formats database
create_formats_database() {
    cat > "$FORMATS_DB" << 'EOF'
# Audio Formats
mp3:audio:MPEG Audio Layer III:ffmpeg,gstreamer,vlc
aac:audio:Advanced Audio Coding:ffmpeg,gstreamer,vlc
flac:audio:Free Lossless Audio Codec:ffmpeg,gstreamer,vlc,flac
ogg:audio:Ogg Vorbis:ffmpeg,gstreamer,vlc,vorbis-tools
wav:audio:Waveform Audio File Format:ffmpeg,gstreamer,vlc,sox
m4a:audio:MPEG-4 Audio:ffmpeg,gstreamer,vlc
opus:audio:Opus Audio Codec:ffmpeg,gstreamer,vlc,opus-tools
wma:audio:Windows Media Audio:ffmpeg,gstreamer,vlc

# Video Formats
mp4:video:MPEG-4 Part 14:ffmpeg,gstreamer,vlc
avi:video:Audio Video Interleave:ffmpeg,gstreamer,vlc
mkv:video:Matroska Video:ffmpeg,gstreamer,vlc
mov:video:QuickTime File Format:ffmpeg,gstreamer,vlc
wmv:video:Windows Media Video:ffmpeg,gstreamer,vlc
flv:video:Flash Video:ffmpeg,gstreamer,vlc
webm:video:WebM:ffmpeg,gstreamer,vlc,libvpx
ogv:video:Ogg Video:ffmpeg,gstreamer,vlc,theora-tools
3gp:video:3GPP:ffmpeg,gstreamer,vlc
ts:video:MPEG Transport Stream:ffmpeg,gstreamer,vlc

# Image Formats
jpg:image:JPEG:imagemagick,ffmpeg,gstreamer
jpeg:image:JPEG:imagemagick,ffmpeg,gstreamer
png:image:Portable Network Graphics:imagemagick,ffmpeg,libpng
gif:image:Graphics Interchange Format:imagemagick,ffmpeg,gifsicle
bmp:image:Bitmap:imagemagick,ffmpeg
tiff:image:Tagged Image File Format:imagemagick,ffmpeg,libtiff
webp:image:WebP:imagemagick,ffmpeg,libwebp,cwebp
svg:image:Scalable Vector Graphics:imagemagick,inkscape,librsvg
ico:image:Icon:imagemagick,ffmpeg
EOF
}

# Load configuration
load_config() {
    if [ -f "$CODECS_CONF" ]; then
        source "$CODECS_CONF"
    fi
}

# Detect available codec backends
detect_codec_backends() {
    local backends=()
    
    echo -e "${BLUE}Detecting multimedia backends...${NC}"
    
    # FFmpeg (most comprehensive)
    if command -v ffmpeg >/dev/null; then
        backends+=("ffmpeg")
        echo -e "${GREEN}✓${NC} FFmpeg: $(ffmpeg -version 2>/dev/null | head -1 | cut -d' ' -f3)"
    fi
    
    # GStreamer
    if command -v gst-launch-1.0 >/dev/null; then
        backends+=("gstreamer")
        local gst_version=$(gst-launch-1.0 --version 2>/dev/null | head -1 | cut -d' ' -f4)
        echo -e "${GREEN}✓${NC} GStreamer: $gst_version"
    fi
    
    # VLC
    if command -v vlc >/dev/null; then
        backends+=("vlc")
        local vlc_version=$(vlc --version 2>/dev/null | head -1 | cut -d' ' -f4)
        echo -e "${GREEN}✓${NC} VLC: $vlc_version"
    fi
    
    # MPlayer/mpv
    if command -v mpv >/dev/null; then
        backends+=("mpv")
        echo -e "${GREEN}✓${NC} mpv: $(mpv --version 2>/dev/null | head -1 | cut -d' ' -f2)"
    elif command -v mplayer >/dev/null; then
        backends+=("mplayer")
        echo -e "${GREEN}✓${NC} MPlayer available"
    fi
    
    # ImageMagick
    if command -v convert >/dev/null; then
        backends+=("imagemagick")
        echo -e "${GREEN}✓${NC} ImageMagick: $(convert --version 2>/dev/null | head -1 | cut -d' ' -f3)"
    fi
    
    # Specialized tools
    command -v sox >/dev/null && backends+=("sox") && echo -e "${GREEN}✓${NC} SoX audio processing"
    command -v opus-tools >/dev/null && backends+=("opus") && echo -e "${GREEN}✓${NC} Opus tools"
    command -v vorbis-tools >/dev/null && backends+=("vorbis") && echo -e "${GREEN}✓${NC} Vorbis tools"
    command -v lame >/dev/null && backends+=("lame") && echo -e "${GREEN}✓${NC} LAME MP3 encoder"
    command -v x264 >/dev/null && backends+=("x264") && echo -e "${GREEN}✓${NC} x264 video encoder"
    command -v x265 >/dev/null && backends+=("x265") && echo -e "${GREEN}✓${NC} x265 video encoder"
    
    echo "${backends[@]}"
}

# Check hardware acceleration support
check_hardware_acceleration() {
    echo -e "${BLUE}Checking hardware acceleration support...${NC}"
    
    local hw_support=()
    
    # NVIDIA NVENC/NVDEC
    if command -v nvidia-smi >/dev/null && nvidia-smi >/dev/null 2>&1; then
        hw_support+=("nvenc")
        echo -e "${GREEN}✓${NC} NVIDIA hardware encoding/decoding"
    fi
    
    # Intel Quick Sync Video
    if lspci | grep -qi intel && [ -f /dev/dri/renderD128 ]; then
        hw_support+=("qsv")
        echo -e "${GREEN}✓${NC} Intel Quick Sync Video"
    fi
    
    # AMD VCE/VCN
    if lspci | grep -qi amd && [ -f /dev/dri/renderD128 ]; then
        hw_support+=("amf")
        echo -e "${GREEN}✓${NC} AMD hardware acceleration"
    fi
    
    # VA-API
    if command -v vainfo >/dev/null && vainfo >/dev/null 2>&1; then
        hw_support+=("vaapi")
        echo -e "${GREEN}✓${NC} VA-API hardware acceleration"
    fi
    
    # VDPAU
    if command -v vdpauinfo >/dev/null && vdpauinfo >/dev/null 2>&1; then
        hw_support+=("vdpau")
        echo -e "${GREEN}✓${NC} VDPAU hardware acceleration"
    fi
    
    echo "${hw_support[@]}"
}

# Get format information
get_format_info() {
    local format="$1"
    local info=$(grep "^${format}:" "$FORMATS_DB" 2>/dev/null | head -1)
    
    if [ -n "$info" ]; then
        local type=$(echo "$info" | cut -d: -f2)
        local description=$(echo "$info" | cut -d: -f3)
        local tools=$(echo "$info" | cut -d: -f4)
        
        echo -e "${WHITE}Format:${NC} $format"
        echo -e "${WHITE}Type:${NC} $type"
        echo -e "${WHITE}Description:${NC} $description"
        echo -e "${WHITE}Supported by:${NC} $tools"
    else
        echo -e "${RED}✗${NC} Format not found in database"
    fi
}

# Test codec support
test_codec_support() {
    local format="$1"
    
    echo -e "${BLUE}Testing codec support for: $format${NC}"
    
    # Test with FFmpeg
    if command -v ffmpeg >/dev/null; then
        local codecs=$(ffmpeg -codecs 2>/dev/null | grep -i "$format" | head -3)
        if [ -n "$codecs" ]; then
            echo -e "${GREEN}✓${NC} FFmpeg supports $format"
            echo "$codecs"
        fi
    fi
    
    # Test with GStreamer
    if command -v gst-inspect-1.0 >/dev/null; then
        local plugins=$(gst-inspect-1.0 | grep -i "$format" | head -3)
        if [ -n "$plugins" ]; then
            echo -e "${GREEN}✓${NC} GStreamer supports $format"
            echo "$plugins"
        fi
    fi
}

# Convert media file
convert_media() {
    local input_file="$1"
    local output_file="$2"
    local codec="$3"
    local quality="${4:-medium}"
    
    if [ ! -f "$input_file" ]; then
        echo -e "${RED}✗${NC} Input file not found: $input_file"
        return 1
    fi
    
    echo -e "${BLUE}Converting: $(basename "$input_file") → $(basename "$output_file")${NC}"
    
    # Determine conversion parameters based on codec and quality
    local ffmpeg_opts=""
    case "$quality" in
        low)
            ffmpeg_opts="-preset fast -crf 28"
            ;;
        medium)
            ffmpeg_opts="-preset medium -crf 23"
            ;;
        high)
            ffmpeg_opts="-preset slow -crf 18"
            ;;
        lossless)
            ffmpeg_opts="-preset veryslow -crf 0"
            ;;
    esac
    
    # Hardware acceleration options
    local hw_accel=""
    if [ "$HARDWARE_DECODING" = "auto" ] || [ "$HARDWARE_DECODING" = "true" ]; then
        if command -v nvidia-smi >/dev/null && nvidia-smi >/dev/null 2>&1; then
            hw_accel="-hwaccel nvdec"
        elif [ -f /dev/dri/renderD128 ]; then
            hw_accel="-hwaccel vaapi"
        fi
    fi
    
    # Convert using FFmpeg
    if command -v ffmpeg >/dev/null; then
        ffmpeg $hw_accel -i "$input_file" $ffmpeg_opts "$output_file" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓${NC} Conversion completed successfully"
            return 0
        else
            echo -e "${YELLOW}!${NC} FFmpeg conversion failed, trying alternative method"
        fi
    fi
    
    # Fallback conversion methods
    case "$codec" in
        mp3)
            if command -v lame >/dev/null; then
                lame "$input_file" "$output_file"
            fi
            ;;
        ogg)
            if command -v oggenc >/dev/null; then
                oggenc "$input_file" -o "$output_file"
            fi
            ;;
        flac)
            if command -v flac >/dev/null; then
                flac "$input_file" -o "$output_file"
            fi
            ;;
        *)
            echo -e "${RED}✗${NC} No suitable converter found for $codec"
            return 1
            ;;
    esac
}

# Extract metadata
extract_metadata() {
    local media_file="$1"
    
    if [ ! -f "$media_file" ]; then
        echo -e "${RED}✗${NC} File not found: $media_file"
        return 1
    fi
    
    echo -e "${BLUE}Extracting metadata from: $(basename "$media_file")${NC}"
    
    # Use FFprobe for detailed metadata
    if command -v ffprobe >/dev/null; then
        ffprobe -v quiet -print_format json -show_format -show_streams "$media_file" 2>/dev/null
    elif command -v mediainfo >/dev/null; then
        mediainfo "$media_file"
    elif command -v exiftool >/dev/null; then
        exiftool "$media_file"
    else
        # Basic file information
        echo -e "${CYAN}File:${NC} $(basename "$media_file")"
        echo -e "${CYAN}Size:${NC} $(du -h "$media_file" | cut -f1)"
        echo -e "${CYAN}Modified:${NC} $(date -r "$media_file")"
        file "$media_file"
    fi
}

# Generate thumbnail
generate_thumbnail() {
    local media_file="$1"
    local output_path="${2:-$CACHE_DIR/$(basename "$media_file").thumb.png}"
    local timestamp="${3:-00:00:01}"
    
    echo -e "${BLUE}Generating thumbnail for: $(basename "$media_file")${NC}"
    
    # Video thumbnail
    if ffprobe "$media_file" 2>/dev/null | grep -q "Video:"; then
        if command -v ffmpeg >/dev/null; then
            ffmpeg -ss "$timestamp" -i "$media_file" -vframes 1 -q:v 2 "$output_path" 2>/dev/null
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓${NC} Video thumbnail created: $output_path"
                return 0
            fi
        fi
    fi
    
    # Audio thumbnail (waveform or album art)
    if ffprobe "$media_file" 2>/dev/null | grep -q "Audio:"; then
        if command -v ffmpeg >/dev/null; then
            # Try to extract album art first
            ffmpeg -i "$media_file" -an -vcodec copy "$output_path" 2>/dev/null || \
            # Create audio waveform thumbnail
            ffmpeg -i "$media_file" -filter_complex "showwavespic=s=640x120:colors=0x00ff00" -frames:v 1 "$output_path" 2>/dev/null
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓${NC} Audio thumbnail created: $output_path"
                return 0
            fi
        fi
    fi
    
    # Image thumbnail
    if command -v convert >/dev/null && file "$media_file" | grep -q "image"; then
        convert "$media_file" -thumbnail 200x200 "$output_path" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓${NC} Image thumbnail created: $output_path"
            return 0
        fi
    fi
    
    echo -e "${YELLOW}!${NC} Could not generate thumbnail"
    return 1
}

# Batch processing
batch_process() {
    local operation="$1"
    local source_dir="$2"
    local target_format="$3"
    
    echo -e "${BLUE}Batch processing: $operation${NC}"
    echo -e "${CYAN}Source directory:${NC} $source_dir"
    echo -e "${CYAN}Target format:${NC} $target_format"
    
    local processed=0
    local failed=0
    
    find "$source_dir" -type f | while read -r file; do
        local filename=$(basename "$file")
        local extension="${filename##*.}"
        
        # Skip if already target format
        if [ "$extension" = "$target_format" ]; then
            continue
        fi
        
        local output_file="${file%.*}.$target_format"
        
        case "$operation" in
            convert)
                if convert_media "$file" "$output_file" "$target_format" "medium"; then
                    ((processed++))
                    echo -e "${GREEN}✓${NC} Processed: $filename"
                else
                    ((failed++))
                    echo -e "${RED}✗${NC} Failed: $filename"
                fi
                ;;
            thumbnail)
                local thumb_dir="$source_dir/thumbnails"
                mkdir -p "$thumb_dir"
                local thumb_file="$thumb_dir/${filename}.thumb.png"
                
                if generate_thumbnail "$file" "$thumb_file"; then
                    ((processed++))
                else
                    ((failed++))
                fi
                ;;
        esac
    done
    
    echo -e "\n${BLUE}Batch processing completed${NC}"
    echo -e "${GREEN}Processed:${NC} $processed files"
    echo -e "${RED}Failed:${NC} $failed files"
}

# Codec installation helper
install_codecs() {
    echo -e "${BLUE}Multimedia codec installation helper${NC}"
    echo -e "${YELLOW}Note: This will suggest package installations${NC}"
    echo
    
    # Check what's missing and suggest installations
    local missing_codecs=()
    
    # Essential codecs
    command -v ffmpeg >/dev/null || missing_codecs+=("ffmpeg")
    command -v gst-launch-1.0 >/dev/null || missing_codecs+=("gstreamer1.0-plugins-base")
    command -v vlc >/dev/null || missing_codecs+=("vlc")
    command -v convert >/dev/null || missing_codecs+=("imagemagick")
    
    # Audio codecs
    command -v lame >/dev/null || missing_codecs+=("lame")
    command -v oggenc >/dev/null || missing_codecs+=("vorbis-tools")
    command -v flac >/dev/null || missing_codecs+=("flac")
    command -v opusenc >/dev/null || missing_codecs+=("opus-tools")
    
    # Video codecs
    command -v x264 >/dev/null || missing_codecs+=("x264")
    command -v x265 >/dev/null || missing_codecs+=("x265")
    
    if [ ${#missing_codecs[@]} -gt 0 ]; then
        echo -e "${YELLOW}Missing codecs detected. Suggested installation:${NC}"
        echo
        echo -e "${CYAN}For Debian/Ubuntu:${NC}"
        echo "sudo apt update && sudo apt install ${missing_codecs[*]}"
        echo
        echo -e "${CYAN}For Red Hat/CentOS/Fedora:${NC}"
        echo "sudo yum install ${missing_codecs[*]}"
        echo
        echo -e "${CYAN}For Arch Linux:${NC}"
        echo "sudo pacman -S ${missing_codecs[*]}"
        echo
    else
        echo -e "${GREEN}✓${NC} All essential codecs appear to be installed"
    fi
}

# Main menu
main_menu() {
    echo -e "${PURPLE}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                ${WHITE}BluejayLinux Multimedia Codec System${PURPLE}                ║${NC}"
    echo -e "${PURPLE}║                 ${CYAN}Universal Media Format Support${PURPLE}                   ║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    local backends=($(detect_codec_backends))
    echo -e "${WHITE}Available backends:${NC} ${backends[*]}"
    
    local hw_accel=($(check_hardware_acceleration))
    if [ ${#hw_accel[@]} -gt 0 ]; then
        echo -e "${WHITE}Hardware acceleration:${NC} ${hw_accel[*]}"
    fi
    echo
    
    echo -e "${WHITE}1.${NC} Convert media file"
    echo -e "${WHITE}2.${NC} Extract metadata"
    echo -e "${WHITE}3.${NC} Generate thumbnail"
    echo -e "${WHITE}4.${NC} Test codec support"
    echo -e "${WHITE}5.${NC} Batch processing"
    echo -e "${WHITE}6.${NC} Format information"
    echo -e "${WHITE}7.${NC} Install missing codecs"
    echo -e "${WHITE}8.${NC} Settings"
    echo -e "${WHITE}q.${NC} Quit"
    echo
}

# Settings menu
settings_menu() {
    echo -e "\n${PURPLE}=== Multimedia Codec Settings ===${NC}"
    echo -e "${WHITE}1.${NC} Audio backend: ${AUDIO_BACKEND}"
    echo -e "${WHITE}2.${NC} Video backend: ${VIDEO_BACKEND}"
    echo -e "${WHITE}3.${NC} Hardware decoding: ${HARDWARE_DECODING}"
    echo -e "${WHITE}4.${NC} Software fallback: ${SOFTWARE_FALLBACK}"
    echo -e "${WHITE}5.${NC} Quality preference: ${QUALITY_PREFERENCE}"
    echo -e "${WHITE}6.${NC} Encoding preset: ${ENCODING_PRESET}"
    echo -e "${WHITE}7.${NC} Audio bitrate: ${AUDIO_BITRATE}"
    echo -e "${WHITE}8.${NC} Thumbnail generation: ${THUMBNAIL_GENERATION}"
    echo -e "${WHITE}s.${NC} Save settings"
    echo -e "${WHITE}q.${NC} Back to main menu"
    echo
    
    echo -ne "${YELLOW}Select option:${NC} "
    read -r choice
    
    case "$choice" in
        1)
            echo -ne "${CYAN}Audio backend (auto/ffmpeg/gstreamer/vlc):${NC} "
            read -r AUDIO_BACKEND
            ;;
        2)
            echo -ne "${CYAN}Video backend (auto/ffmpeg/gstreamer/vlc):${NC} "
            read -r VIDEO_BACKEND
            ;;
        3)
            echo -ne "${CYAN}Hardware decoding (auto/true/false):${NC} "
            read -r HARDWARE_DECODING
            ;;
        4)
            echo -ne "${CYAN}Software fallback (true/false):${NC} "
            read -r SOFTWARE_FALLBACK
            ;;
        5)
            echo -ne "${CYAN}Quality preference (low/balanced/high/lossless):${NC} "
            read -r QUALITY_PREFERENCE
            ;;
        6)
            echo -ne "${CYAN}Encoding preset (ultrafast/fast/medium/slow/veryslow):${NC} "
            read -r ENCODING_PRESET
            ;;
        7)
            echo -ne "${CYAN}Audio bitrate (128k/192k/256k/320k):${NC} "
            read -r AUDIO_BITRATE
            ;;
        8)
            echo -ne "${CYAN}Thumbnail generation (true/false):${NC} "
            read -r THUMBNAIL_GENERATION
            ;;
        s|S)
            cat > "$CODECS_CONF" << EOF
# BluejayLinux Multimedia Codecs Configuration
AUDIO_BACKEND=$AUDIO_BACKEND
VIDEO_BACKEND=$VIDEO_BACKEND
HARDWARE_DECODING=$HARDWARE_DECODING
SOFTWARE_FALLBACK=$SOFTWARE_FALLBACK
QUALITY_PREFERENCE=$QUALITY_PREFERENCE
ENCODING_PRESET=$ENCODING_PRESET
DECODING_THREADS=$DECODING_THREADS
AUDIO_SAMPLE_RATE=$AUDIO_SAMPLE_RATE
VIDEO_BITRATE=$VIDEO_BITRATE
AUDIO_BITRATE=$AUDIO_BITRATE
SUBTITLE_SUPPORT=$SUBTITLE_SUPPORT
METADATA_EXTRACTION=$METADATA_EXTRACTION
THUMBNAIL_GENERATION=$THUMBNAIL_GENERATION
STREAMING_OPTIMIZATION=$STREAMING_OPTIMIZATION
EOF
            echo -e "${GREEN}✓${NC} Settings saved"
            ;;
    esac
}

# Main function
main() {
    create_directories
    load_config
    
    if [ $# -gt 0 ]; then
        case "$1" in
            --convert|-c)
                convert_media "$2" "$3" "$4" "${5:-medium}"
                ;;
            --metadata|-m)
                extract_metadata "$2"
                ;;
            --thumbnail|-t)
                generate_thumbnail "$2" "$3" "$4"
                ;;
            --test|-T)
                test_codec_support "$2"
                ;;
            --info|-i)
                get_format_info "$2"
                ;;
            --install)
                install_codecs
                ;;
            --help|-h)
                echo "BluejayLinux Multimedia Codec System"
                echo "Usage: $0 [options] [parameters]"
                echo "  --convert, -c <input> <output> [format] [quality]"
                echo "  --metadata, -m <file>           Extract metadata"
                echo "  --thumbnail, -t <file> [output] [timestamp]"
                echo "  --test, -T <format>             Test codec support"
                echo "  --info, -i <format>             Format information"
                echo "  --install                       Install missing codecs"
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
                echo -ne "${CYAN}Input file:${NC} "
                read -r input_file
                echo -ne "${CYAN}Output file:${NC} "
                read -r output_file
                echo -ne "${CYAN}Target format:${NC} "
                read -r format
                echo -ne "${CYAN}Quality (low/medium/high/lossless):${NC} "
                read -r quality
                quality="${quality:-medium}"
                
                convert_media "$input_file" "$output_file" "$format" "$quality"
                ;;
            2)
                echo -ne "${CYAN}Media file:${NC} "
                read -r media_file
                extract_metadata "$media_file"
                ;;
            3)
                echo -ne "${CYAN}Media file:${NC} "
                read -r media_file
                echo -ne "${CYAN}Output path (optional):${NC} "
                read -r output_path
                echo -ne "${CYAN}Timestamp for video (e.g., 00:00:05):${NC} "
                read -r timestamp
                
                generate_thumbnail "$media_file" "$output_path" "$timestamp"
                ;;
            4)
                echo -ne "${CYAN}Format to test:${NC} "
                read -r test_format
                test_codec_support "$test_format"
                ;;
            5)
                echo -ne "${CYAN}Operation (convert/thumbnail):${NC} "
                read -r operation
                echo -ne "${CYAN}Source directory:${NC} "
                read -r source_dir
                echo -ne "${CYAN}Target format:${NC} "
                read -r target_format
                
                batch_process "$operation" "$source_dir" "$target_format"
                ;;
            6)
                echo -ne "${CYAN}Format to query:${NC} "
                read -r query_format
                get_format_info "$query_format"
                ;;
            7)
                install_codecs
                ;;
            8)
                settings_menu
                ;;
            q|Q)
                echo -e "${GREEN}Multimedia codec system configuration saved${NC}"
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