#!/bin/bash
# BluejayLinux Chrome Browser Installation Script

set -e

source ../build-bluejay.sh 2>/dev/null || {
    ROOTFS="/tmp/bluejay-build/rootfs"
    BUILD_ROOT="/tmp/bluejay-build"
}

log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $1"; }

install_chrome_browser() {
    log_info "Installing Google Chrome browser..."
    
    # Create temporary directory for Chrome installation
    local chrome_temp="${BUILD_ROOT}/chrome-temp"
    mkdir -p "$chrome_temp"
    
    # Download Chrome .deb package
    log_info "Downloading Google Chrome..."
    if command -v wget >/dev/null; then
        wget -O "$chrome_temp/google-chrome.deb" \
            "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
    elif command -v curl >/dev/null; then
        curl -L -o "$chrome_temp/google-chrome.deb" \
            "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
    else
        log_error "Neither wget nor curl available for download"
        return 1
    fi
    
    # Extract Chrome package
    log_info "Extracting Chrome package..."
    cd "$chrome_temp"
    
    # Extract .deb file
    if command -v dpkg-deb >/dev/null; then
        dpkg-deb -x google-chrome.deb chrome-extracted/
    elif command -v ar >/dev/null; then
        ar x google-chrome.deb
        tar -xf data.tar.xz -C chrome-extracted/ 2>/dev/null || tar -xf data.tar.gz -C chrome-extracted/
    else
        log_error "Cannot extract .deb package (need dpkg-deb or ar)"
        return 1
    fi
    
    # Copy Chrome to rootfs
    log_info "Installing Chrome into rootfs..."
    
    # Copy Chrome binaries
    if [ -d "chrome-extracted/opt/google/chrome" ]; then
        mkdir -p "${ROOTFS}/opt/google"
        cp -r chrome-extracted/opt/google/chrome "${ROOTFS}/opt/google/"
        
        # Make executable
        chmod +x "${ROOTFS}/opt/google/chrome/google-chrome"
        
        # Create symlink in /usr/bin
        mkdir -p "${ROOTFS}/usr/bin"
        ln -sf "/opt/google/chrome/google-chrome" "${ROOTFS}/usr/bin/google-chrome"
        
        log_success "Chrome binaries installed"
    else
        log_error "Chrome binaries not found in package"
        return 1
    fi
    
    # Copy desktop files and icons
    if [ -d "chrome-extracted/usr/share/applications" ]; then
        mkdir -p "${ROOTFS}/usr/share/applications"
        cp chrome-extracted/usr/share/applications/google-chrome.desktop \
           "${ROOTFS}/usr/share/applications/" 2>/dev/null || true
    fi
    
    if [ -d "chrome-extracted/usr/share/icons" ]; then
        mkdir -p "${ROOTFS}/usr/share/icons"
        cp -r chrome-extracted/usr/share/icons/* \
           "${ROOTFS}/usr/share/icons/" 2>/dev/null || true
    fi
    
    # Install essential Chrome dependencies
    install_chrome_dependencies
    
    # Clean up
    cd - > /dev/null
    rm -rf "$chrome_temp"
    
    log_success "Google Chrome installation completed"
}

install_chrome_dependencies() {
    log_info "Installing Chrome dependencies..."
    
    # Create basic library structure
    mkdir -p "${ROOTFS}/lib/x86_64-linux-gnu"
    mkdir -p "${ROOTFS}/usr/lib/x86_64-linux-gnu"
    
    # Essential libraries Chrome needs (we'll copy from host system if available)
    local essential_libs=(
        "libc.so.6"
        "libdl.so.2"
        "libm.so.6"
        "libpthread.so.0"
        "librt.so.1"
        "libX11.so.6"
        "libXext.so.6"
        "libXrender.so.1"
        "libXrandr.so.2"
        "libXcomposite.so.1"
        "libXdamage.so.1"
        "libXfixes.so.3"
        "libxcb.so.1"
        "libXss.so.1"
        "libglib-2.0.so.0"
        "libgobject-2.0.so.0"
        "libgtk-3.so.0"
        "libgdk-3.so.0"
        "libasound.so.2"
        "libcups.so.2"
        "libdrm.so.2"
        "libexpat.so.1"
        "libfontconfig.so.1"
        "libnss3.so"
        "libnssutil3.so"
        "libsmime3.so"
        "libssl3.so"
    )
    
    # Try to copy libraries from host system
    local libs_copied=0
    for lib in "${essential_libs[@]}"; do
        # Find library on host system
        local lib_path=""
        for search_dir in /lib/x86_64-linux-gnu /usr/lib/x86_64-linux-gnu /lib64 /usr/lib64; do
            if [ -f "$search_dir/$lib" ]; then
                lib_path="$search_dir/$lib"
                break
            fi
        done
        
        if [ -n "$lib_path" ] && [ -f "$lib_path" ]; then
            # Copy to rootfs
            cp "$lib_path" "${ROOTFS}/lib/x86_64-linux-gnu/" 2>/dev/null || \
            cp "$lib_path" "${ROOTFS}/usr/lib/x86_64-linux-gnu/" 2>/dev/null || true
            
            if [ -f "${ROOTFS}/lib/x86_64-linux-gnu/$lib" ] || [ -f "${ROOTFS}/usr/lib/x86_64-linux-gnu/$lib" ]; then
                libs_copied=$((libs_copied + 1))
            fi
        fi
    done
    
    log_info "Copied $libs_copied essential libraries"
    
    # Create Chrome wrapper script with library path
    cat > "${ROOTFS}/usr/bin/chrome-wrapper" << 'EOF'
#!/bin/bash
# Chrome wrapper script for BluejayLinux

export LD_LIBRARY_PATH="/lib/x86_64-linux-gnu:/usr/lib/x86_64-linux-gnu:/opt/google/chrome:$LD_LIBRARY_PATH"
export DISPLAY=:0

# Chrome flags for embedded/limited systems
CHROME_FLAGS="--no-sandbox --disable-dev-shm-usage --disable-gpu --disable-software-rasterizer --disable-background-timer-throttling --disable-backgrounding-occluded-windows --disable-renderer-backgrounding --disable-features=TranslateUI --disable-extensions --no-first-run --no-default-browser-check"

exec /opt/google/chrome/google-chrome $CHROME_FLAGS "$@"
EOF
    chmod +x "${ROOTFS}/usr/bin/chrome-wrapper"
    
    # Update the bluejay-browser to use wrapper
    if [ -f "${ROOTFS}/usr/bin/bluejay-browser" ]; then
        sed -i 's|commands+=("google-chrome")|commands+=("chrome-wrapper")|g' "${ROOTFS}/usr/bin/bluejay-browser"
    fi
    
    log_success "Chrome dependencies and wrapper installed"
}

# Font installation for better Chrome rendering
install_chrome_fonts() {
    log_info "Installing fonts for Chrome..."
    
    mkdir -p "${ROOTFS}/usr/share/fonts/truetype"
    
    # Basic font installation (if available on host)
    for font_dir in /usr/share/fonts/truetype/*; do
        if [ -d "$font_dir" ]; then
            local font_name=$(basename "$font_dir")
            case "$font_name" in
                "dejavu"|"liberation"|"droid"|"noto")
                    cp -r "$font_dir" "${ROOTFS}/usr/share/fonts/truetype/" 2>/dev/null || true
                    log_info "Installed font family: $font_name"
                    ;;
            esac
        fi
    done
    
    # Create basic fonts.conf
    mkdir -p "${ROOTFS}/etc/fonts"
    cat > "${ROOTFS}/etc/fonts/fonts.conf" << 'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
    <dir>/usr/share/fonts</dir>
    <dir>/usr/local/share/fonts</dir>
    <cachedir>/var/cache/fontconfig</cachedir>
    
    <alias>
        <family>serif</family>
        <prefer><family>DejaVu Serif</family></prefer>
    </alias>
    <alias>
        <family>sans-serif</family>
        <prefer><family>DejaVu Sans</family></prefer>
    </alias>
    <alias>
        <family>monospace</family>
        <prefer><family>DejaVu Sans Mono</family></prefer>
    </alias>
</fontconfig>
EOF
    
    log_success "Fonts installed for Chrome"
}

create_chrome_desktop_entry() {
    log_info "Creating Chrome desktop integration..."
    
    # Update the existing browser launcher to prioritize Chrome
    cat > "${ROOTFS}/usr/bin/bluejay-browser-chrome" << 'EOF'
#!/bin/bash
# BluejayLinux Chrome Browser Launcher

if [ -x /usr/bin/chrome-wrapper ]; then
    echo "Starting Google Chrome..."
    exec /usr/bin/chrome-wrapper "$@"
elif [ -x /usr/bin/google-chrome ]; then
    echo "Starting Google Chrome (direct)..."
    exec /usr/bin/google-chrome --no-sandbox --disable-dev-shm-usage "$@"
else
    echo "Chrome not installed. Starting browser selector..."
    exec /usr/bin/bluejay-browser "$@"
fi
EOF
    chmod +x "${ROOTFS}/usr/bin/bluejay-browser-chrome"
    
    # Create desktop shortcut
    mkdir -p "${ROOTFS}/home/bluejay/Desktop"
    cat > "${ROOTFS}/home/bluejay/Desktop/Chrome.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Google Chrome
Comment=Browse the web with Google Chrome
Icon=google-chrome
Exec=bluejay-browser-chrome
Categories=Network;WebBrowser;
Keywords=web;browser;internet;
StartupNotify=true
EOF
    chmod +x "${ROOTFS}/home/bluejay/Desktop/Chrome.desktop"
    
    log_success "Chrome desktop integration created"
}

main() {
    log_info "Starting Google Chrome installation for BluejayLinux..."
    
    # Check if we have internet connectivity
    if ! ping -c 1 google.com >/dev/null 2>&1; then
        log_error "No internet connectivity. Cannot download Chrome."
        exit 1
    fi
    
    # Install Chrome
    install_chrome_browser
    
    # Install fonts for better rendering
    install_chrome_fonts
    
    # Create desktop integration
    create_chrome_desktop_entry
    
    echo ""
    log_success "Google Chrome installation completed!"
    echo ""
    echo "Chrome is now available in BluejayLinux:"
    echo "  • Command: chrome-wrapper"
    echo "  • Browser launcher: bluejay-browser-chrome" 
    echo "  • Desktop shortcut: Chrome.desktop"
    echo ""
    echo "Note: Chrome requires X11 display server to be running"
    echo "Start with: bluejay-display-server start"
}

main "$@"