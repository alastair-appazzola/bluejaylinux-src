#!/bin/bash
# Build Blue-Jay Linux Security Tools

set -e

source ../build-bluejay.sh 2>/dev/null || {
    ROOTFS="/tmp/bluejay-build/rootfs"
    BUILD_ROOT="/tmp/bluejay-build"
    TOOLS_DIR="/tmp/bluejay-build/tools"
}

log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $1"; }
log_warning() { echo -e "\033[1;33m[WARNING]\033[0m $1"; }

setup_tools_env() {
    log_info "Setting up security tools environment..."
    
    # Create tools directory structure
    mkdir -p "${ROOTFS}/opt/bluejay/tools"/{bin,lib,share,src}
    mkdir -p "${ROOTFS}/opt/bluejay/wordlists"
    mkdir -p "${ROOTFS}/opt/bluejay/payloads"
    
    # Create categories
    local categories=("network" "web" "forensics" "reversing" "exploitation" "recon")
    for cat in "${categories[@]}"; do
        mkdir -p "${ROOTFS}/opt/bluejay/tools/${cat}"
    done
    
    log_success "Tools environment ready"
}

install_networking_tools() {
    log_info "Installing networking security tools..."
    
    cd "${TOOLS_DIR}"
    
    # Install nmap
    if [ ! -d "nmap" ]; then
        log_info "Building nmap..."
        git clone https://github.com/nmap/nmap.git
        cd nmap
        ./configure --prefix="${ROOTFS}/opt/bluejay/tools/network/nmap"
        make -j$(nproc)
        make install
        
        # Create symlinks
        ln -sf "/opt/bluejay/tools/network/nmap/bin/nmap" "${ROOTFS}/usr/bin/nmap"
        ln -sf "/opt/bluejay/tools/network/nmap/bin/ncat" "${ROOTFS}/usr/bin/ncat"
        
        cd ..
        log_success "nmap installed"
    fi
    
    # Install netcat (static build)
    log_info "Installing netcat..."
    if [ ! -f "${ROOTFS}/usr/bin/nc" ]; then
        # Use busybox nc for now, will enhance later
        ln -sf "/bin/busybox" "${ROOTFS}/usr/bin/nc"
        log_success "netcat (busybox) installed"
    fi
    
    # Install tcpdump (simplified - would normally build from source)
    log_info "Preparing tcpdump installation..."
    # For now, create placeholder - in full build would compile libpcap + tcpdump
    cat > "${ROOTFS}/usr/bin/tcpdump" << 'EOF'
#!/bin/sh
echo "tcpdump: Network packet analyzer"
echo "This is a placeholder - full tcpdump will be installed in complete build"
echo "Usage: tcpdump [options] [expression]"
EOF
    chmod +x "${ROOTFS}/usr/bin/tcpdump"
    
    log_success "Network tools installed"
}

install_web_tools() {
    log_info "Installing web security tools..."
    
    # Install curl (if not already present)
    if [ ! -x "${ROOTFS}/usr/bin/curl" ]; then
        log_info "curl installation placeholder created"
        cat > "${ROOTFS}/usr/bin/curl" << 'EOF'
#!/bin/sh
echo "curl: Command line HTTP client"
echo "This is a placeholder - full curl will be installed in complete build"
echo "Usage: curl [options] <url>"
EOF
        chmod +x "${ROOTFS}/usr/bin/curl"
    fi
    
    # Create web tools directory structure
    mkdir -p "${ROOTFS}/opt/bluejay/tools/web"/{burpsuite,dirb,gobuster}
    
    # Install wordlists
    log_info "Installing wordlists..."
    mkdir -p "${ROOTFS}/opt/bluejay/wordlists/web"
    
    # Common wordlists
    cat > "${ROOTFS}/opt/bluejay/wordlists/web/common.txt" << 'EOF'
admin
administrator
login
index
home
test
config
backup
temp
data
upload
download
api
ajax
js
css
img
images
static
assets
lib
libs
include
inc
src
tmp
logs
log
cache
private
public
www
web
site
files
file
docs
doc
pdf
txt
xml
json
html
htm
php
asp
aspx
jsp
do
action
servlet
cgi
bin
sbin
usr
var
etc
opt
root
home
EOF
    
    log_success "Web security tools installed"
}

install_exploitation_tools() {
    log_info "Installing exploitation frameworks..."
    
    mkdir -p "${ROOTFS}/opt/bluejay/tools/exploitation"
    
    # Metasploit placeholder (full installation would be complex)
    cat > "${ROOTFS}/usr/bin/msfconsole" << 'EOF'
#!/bin/sh
echo "Metasploit Framework Console"
echo "============================================"
echo "This is a placeholder for Metasploit Framework"
echo "Full installation requires Ruby, PostgreSQL, and extensive dependencies"
echo ""
echo "In a complete Blue-Jay Linux build, this would launch the full MSF console"
echo "with all exploits, payloads, and auxiliary modules available."
echo ""
echo "Common MSF commands:"
echo "  search <term>     - Search for exploits/modules"
echo "  use <module>      - Select a module to use"  
echo "  show options      - Display module options"
echo "  set <option>      - Set module option"
echo "  run/exploit       - Execute the module"
EOF
    chmod +x "${ROOTFS}/usr/bin/msfconsole"
    
    # SearchSploit placeholder
    cat > "${ROOTFS}/usr/bin/searchsploit" << 'EOF'
#!/bin/sh
echo "SearchSploit - Exploit Database Search Tool"
echo "==========================================="
echo "This is a placeholder for SearchSploit"
echo ""
echo "Usage: searchsploit [options] <search term>"
echo "  -m <id>          Mirror/copy exploit"
echo "  -x <id>          Examine exploit" 
echo "  -u               Update database"
echo ""
echo "Full version would search the Exploit Database offline archive"
EOF
    chmod +x "${ROOTFS}/usr/bin/searchsploit"
    
    log_success "Exploitation tools installed"
}

install_forensics_tools() {
    log_info "Installing forensics tools..."
    
    mkdir -p "${ROOTFS}/opt/bluejay/tools/forensics"
    
    # File analysis tools
    cat > "${ROOTFS}/usr/bin/strings" << 'EOF'
#!/bin/sh
# Simple strings implementation using grep
if [ $# -eq 0 ]; then
    echo "Usage: strings <file>"
    echo "Extracts printable strings from files"
    exit 1
fi

grep -a -o -E "[[:print:]]{4,}" "$@" 2>/dev/null || echo "Error reading file: $1"
EOF
    chmod +x "${ROOTFS}/usr/bin/strings"
    
    # Hexdump (using busybox)
    ln -sf "/bin/busybox" "${ROOTFS}/usr/bin/hexdump"
    
    # File type detection
    cat > "${ROOTFS}/usr/bin/file" << 'EOF'
#!/bin/sh
if [ $# -eq 0 ]; then
    echo "Usage: file <file>"
    exit 1
fi

for f in "$@"; do
    if [ ! -e "$f" ]; then
        echo "$f: cannot open (No such file or directory)"
        continue
    fi
    
    if [ -d "$f" ]; then
        echo "$f: directory"
        continue
    fi
    
    # Read first few bytes to determine file type
    head -c 16 "$f" | od -t x1 | head -n 1 | {
        read offset bytes
        case "$bytes" in
            *"7f 45 4c 46"*) echo "$f: ELF executable" ;;
            *"89 50 4e 47"*) echo "$f: PNG image" ;;
            *"ff d8 ff"*) echo "$f: JPEG image" ;;
            *"50 4b 03 04"*) echo "$f: ZIP archive" ;;
            *"1f 8b 08"*) echo "$f: gzip compressed data" ;;
            *) echo "$f: data" ;;
        esac
    }
done
EOF
    chmod +x "${ROOTFS}/usr/bin/file"
    
    log_success "Forensics tools installed"
}

install_reversing_tools() {
    log_info "Installing reverse engineering tools..."
    
    mkdir -p "${ROOTFS}/opt/bluejay/tools/reversing"
    
    # objdump (from binutils)
    cat > "${ROOTFS}/usr/bin/objdump" << 'EOF'
#!/bin/sh
echo "objdump - Object file disassembler"
echo "================================="
echo "This is a placeholder for objdump (part of binutils)"
echo "Full version would disassemble object files and executables"
echo ""
echo "Usage: objdump [options] <object-files>"
echo "  -d             Disassemble executable sections"
echo "  -t             Print symbol table"
echo "  -h             Print section headers"
echo "  -x             Print all headers"
EOF
    chmod +x "${ROOTFS}/usr/bin/objdump"
    
    # nm (symbol lister)
    cat > "${ROOTFS}/usr/bin/nm" << 'EOF'
#!/bin/sh
echo "nm - List symbols from object files"
echo "=================================="
echo "This is a placeholder for nm (part of binutils)"
echo "Full version would list symbols from object files"
echo ""
echo "Usage: nm [options] <object-files>"
EOF
    chmod +x "${ROOTFS}/usr/bin/nm"
    
    log_success "Reverse engineering tools installed"
}

create_tool_management() {
    log_info "Creating tool management system..."
    
    # Create Blue-Jay tools manager
    cat > "${ROOTFS}/usr/bin/jay-tools" << 'EOF'
#!/bin/sh
# Blue-Jay Linux Security Tools Manager

TOOLS_DIR="/opt/bluejay/tools"
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

show_banner() {
    echo -e "${BLUE}"
    cat << 'BANNER'
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
BANNER
    echo -e "${NC}"
    echo -e "${GREEN}Blue-Jay Linux Security Tools${NC}"
    echo "=============================="
}

list_category() {
    local category=$1
    echo -e "${YELLOW}$category Tools:${NC}"
    case $category in
        "network")
            echo "  nmap          - Network discovery and security auditing"
            echo "  ncat          - Network swiss army knife"
            echo "  tcpdump       - Network packet analyzer"
            echo "  nc            - Netcat - networking utility"
            ;;
        "web")
            echo "  curl          - Command line web client"
            echo "  burpsuite     - Web application security testing (placeholder)"
            ;;
        "forensics")
            echo "  strings       - Extract printable strings from files"
            echo "  hexdump       - Display file contents in hex format"
            echo "  file          - Determine file type"
            ;;
        "reversing")
            echo "  objdump       - Object file disassembler (placeholder)"
            echo "  nm            - List symbols from object files (placeholder)"
            ;;
        "exploitation")
            echo "  msfconsole    - Metasploit Framework console (placeholder)"
            echo "  searchsploit  - Exploit database search tool (placeholder)"
            ;;
    esac
    echo ""
}

case "$1" in
    "list"|"")
        show_banner
        echo ""
        list_category "network"
        list_category "web"
        list_category "forensics"
        list_category "reversing" 
        list_category "exploitation"
        echo "Use 'jay-tools <category>' to see tools in a specific category"
        echo "Use 'jay-tools update' to update tool database"
        ;;
    "network"|"web"|"forensics"|"reversing"|"exploitation")
        show_banner
        echo ""
        list_category "$1"
        ;;
    "update")
        echo "Updating Blue-Jay Linux tools database..."
        echo "This feature will be implemented in future versions."
        ;;
    "help")
        echo "Blue-Jay Linux Security Tools Manager"
        echo "Usage: jay-tools [command|category]"
        echo ""
        echo "Commands:"
        echo "  list          Show all available tools (default)"
        echo "  update        Update tools database"
        echo "  help          Show this help message"
        echo ""
        echo "Categories:"
        echo "  network       Network analysis and scanning tools"
        echo "  web           Web application security tools"  
        echo "  forensics     Digital forensics and analysis tools"
        echo "  reversing     Reverse engineering tools"
        echo "  exploitation  Exploitation frameworks and tools"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Use 'jay-tools help' for usage information"
        exit 1
        ;;
esac
EOF
    chmod +x "${ROOTFS}/usr/bin/jay-tools"
    
    # Create symlink for compatibility
    ln -sf "/usr/bin/jay-tools" "${ROOTFS}/usr/bin/bluejay-tools"
    
    log_success "Tool management system created"
}

main() {
    log_info "Building Blue-Jay Linux security tools..."
    
    setup_tools_env
    install_networking_tools
    install_web_tools
    install_exploitation_tools
    install_forensics_tools
    install_reversing_tools
    create_tool_management
    
    log_success "Security tools build complete"
    log_info "Run 'jay-tools' in Blue-Jay Linux to see available tools"
}

main "$@"