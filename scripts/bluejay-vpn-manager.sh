#!/bin/bash

# BluejayLinux - VPN Integration & Connection Manager
# Professional VPN client with multi-protocol support

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/bluejay"
VPN_CONFIG_DIR="$CONFIG_DIR/vpn"
PROFILES_DIR="$VPN_CONFIG_DIR/profiles"
CONNECTIONS_LOG="$VPN_CONFIG_DIR/connections.log"
STATUS_FILE="/tmp/bluejay-vpn-status"

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

# VPN protocols supported
VPN_PROTOCOLS="openvpn wireguard ipsec-ikev2 pptp l2tp-ipsec"

# Initialize directories
create_directories() {
    mkdir -p "$CONFIG_DIR" "$VPN_CONFIG_DIR" "$PROFILES_DIR"
    touch "$CONNECTIONS_LOG"
    
    # Create default VPN configuration
    if [ ! -f "$VPN_CONFIG_DIR/settings.conf" ]; then
        cat > "$VPN_CONFIG_DIR/settings.conf" << 'EOF'
# BluejayLinux VPN Manager Settings
AUTO_CONNECT=false
KILL_SWITCH=true
DNS_LEAK_PROTECTION=true
PREFERRED_PROTOCOL=auto
LOG_CONNECTIONS=true
RECONNECT_ATTEMPTS=3
RECONNECT_DELAY=5
SHOW_NOTIFICATIONS=true
SYSTEM_TRAY=true
START_MINIMIZED=false
DEFAULT_DNS=1.1.1.1,8.8.8.8
IPV6_SUPPORT=true
COMPRESSION=auto
EOF
    fi
}

# Load settings
load_settings() {
    if [ -f "$VPN_CONFIG_DIR/settings.conf" ]; then
        source "$VPN_CONFIG_DIR/settings.conf"
    fi
}

# Detect available VPN clients
detect_vpn_clients() {
    local clients=()
    
    echo -e "${BLUE}Detecting VPN clients...${NC}"
    
    # OpenVPN
    if command -v openvpn >/dev/null; then
        clients+=("openvpn")
        echo -e "${GREEN}✓${NC} OpenVPN: $(openvpn --version 2>/dev/null | head -1 | cut -d' ' -f2)"
    fi
    
    # WireGuard
    if command -v wg >/dev/null; then
        clients+=("wireguard")
        echo -e "${GREEN}✓${NC} WireGuard: $(wg --version 2>/dev/null)"
    fi
    
    # StrongSwan (IPSec)
    if command -v ipsec >/dev/null; then
        clients+=("strongswan")
        echo -e "${GREEN}✓${NC} StrongSwan IPSec available"
    fi
    
    # NetworkManager VPN plugins
    if command -v nmcli >/dev/null; then
        clients+=("networkmanager")
        echo -e "${GREEN}✓${NC} NetworkManager VPN support"
    fi
    
    # PPTP client
    if command -v pptp >/dev/null; then
        clients+=("pptp")
        echo -e "${GREEN}✓${NC} PPTP client available"
    fi
    
    # L2TP client
    if command -v xl2tpd >/dev/null; then
        clients+=("l2tp")
        echo -e "${GREEN}✓${NC} L2TP client available"
    fi
    
    echo "${clients[@]}"
}

# Get current VPN status
get_vpn_status() {
    local status="disconnected"
    local connection=""
    local ip=""
    
    # Check OpenVPN
    if pgrep openvpn >/dev/null; then
        status="connected"
        connection="OpenVPN"
    fi
    
    # Check WireGuard
    if command -v wg >/dev/null && wg show 2>/dev/null | grep -q "interface:"; then
        status="connected"
        connection="WireGuard"
    fi
    
    # Check NetworkManager VPN
    if command -v nmcli >/dev/null; then
        local nm_vpn=$(nmcli connection show --active | grep vpn | head -1)
        if [ -n "$nm_vpn" ]; then
            status="connected"
            connection="NetworkManager VPN"
        fi
    fi
    
    # Get external IP if connected
    if [ "$status" = "connected" ]; then
        ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "Unknown")
    fi
    
    echo "$status|$connection|$ip"
}

# Create VPN profile
create_profile() {
    local profile_name="$1"
    local protocol="$2"
    
    echo -e "${BLUE}Creating VPN profile: $profile_name${NC}"
    
    local profile_file="$PROFILES_DIR/${profile_name}.conf"
    
    case "$protocol" in
        openvpn)
            cat > "$profile_file" << EOF
# BluejayLinux VPN Profile - $profile_name
PROFILE_NAME=$profile_name
PROTOCOL=openvpn
SERVER_ADDRESS=
SERVER_PORT=1194
USERNAME=
PASSWORD_FILE=
CONFIG_FILE=
CERTIFICATE_FILE=
PRIVATE_KEY_FILE=
CA_FILE=
COMPRESSION=lzo
CIPHER=AES-256-CBC
AUTH_METHOD=SHA256
VERIFY_X509_NAME=
REMOTE_CERT_TLS=server
REDIRECT_GATEWAY=true
PERSIST_KEY=true
PERSIST_TUN=true
MUTE_REPLAY_WARNINGS=true
VERB=3
EOF
            ;;
        wireguard)
            cat > "$profile_file" << EOF
# BluejayLinux VPN Profile - $profile_name
PROFILE_NAME=$profile_name
PROTOCOL=wireguard
INTERFACE_NAME=wg0
PRIVATE_KEY=
PUBLIC_KEY=
SERVER_PUBLIC_KEY=
SERVER_ENDPOINT=
ALLOWED_IPS=0.0.0.0/0
DNS_SERVERS=1.1.1.1,8.8.8.8
MTU=1420
PERSISTENT_KEEPALIVE=25
PRESHARED_KEY=
EOF
            ;;
        ipsec-ikev2)
            cat > "$profile_file" << EOF
# BluejayLinux VPN Profile - $profile_name
PROFILE_NAME=$profile_name
PROTOCOL=ipsec-ikev2
SERVER_ADDRESS=
USERNAME=
PASSWORD=
CA_CERTIFICATE=
CLIENT_CERTIFICATE=
PRIVATE_KEY=
IKE_VERSION=2
ESP_ENCRYPTION=aes256
ESP_INTEGRITY=sha256
IKE_ENCRYPTION=aes256
IKE_INTEGRITY=sha256
DPD_DELAY=30
DPD_TIMEOUT=120
EOF
            ;;
    esac
    
    echo -e "${GREEN}✓${NC} Profile template created: $profile_file"
    echo -e "${YELLOW}Edit the profile file to add your VPN server details${NC}"
}

# Connect to VPN
connect_vpn() {
    local profile_name="$1"
    local profile_file="$PROFILES_DIR/${profile_name}.conf"
    
    if [ ! -f "$profile_file" ]; then
        echo -e "${RED}✗${NC} Profile not found: $profile_name"
        return 1
    fi
    
    # Load profile
    source "$profile_file"
    
    echo -e "${BLUE}Connecting to VPN: $profile_name${NC}"
    echo -e "${CYAN}Protocol: $PROTOCOL${NC}"
    
    # Log connection attempt
    echo "$(date): Connecting to $profile_name ($PROTOCOL)" >> "$CONNECTIONS_LOG"
    
    case "$PROTOCOL" in
        openvpn)
            connect_openvpn "$profile_file"
            ;;
        wireguard)
            connect_wireguard "$profile_file"
            ;;
        ipsec-ikev2)
            connect_ipsec "$profile_file"
            ;;
        networkmanager)
            connect_networkmanager "$profile_name"
            ;;
        *)
            echo -e "${RED}✗${NC} Unsupported protocol: $PROTOCOL"
            return 1
            ;;
    esac
}

# OpenVPN connection
connect_openvpn() {
    local profile_file="$1"
    source "$profile_file"
    
    if [ -z "$CONFIG_FILE" ] || [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}✗${NC} OpenVPN config file not found: $CONFIG_FILE"
        return 1
    fi
    
    # Kill any existing OpenVPN connections
    sudo pkill openvpn 2>/dev/null || true
    
    # Start OpenVPN
    if [ -n "$PASSWORD_FILE" ] && [ -f "$PASSWORD_FILE" ]; then
        sudo openvpn --config "$CONFIG_FILE" --auth-user-pass "$PASSWORD_FILE" --daemon
    else
        sudo openvpn --config "$CONFIG_FILE" --daemon
    fi
    
    # Wait for connection
    local attempts=0
    while [ $attempts -lt 30 ]; do
        if pgrep openvpn >/dev/null && ip route | grep -q tun0; then
            echo -e "${GREEN}✓${NC} OpenVPN connected successfully"
            echo "connected|OpenVPN|$(curl -s --max-time 5 ifconfig.me 2>/dev/null)" > "$STATUS_FILE"
            return 0
        fi
        sleep 1
        ((attempts++))
    done
    
    echo -e "${RED}✗${NC} OpenVPN connection failed"
    return 1
}

# WireGuard connection
connect_wireguard() {
    local profile_file="$1"
    source "$profile_file"
    
    if [ -z "$PRIVATE_KEY" ] || [ -z "$SERVER_PUBLIC_KEY" ] || [ -z "$SERVER_ENDPOINT" ]; then
        echo -e "${RED}✗${NC} WireGuard configuration incomplete"
        return 1
    fi
    
    # Create WireGuard config
    local wg_config="/tmp/${INTERFACE_NAME:-wg0}.conf"
    cat > "$wg_config" << EOF
[Interface]
PrivateKey = $PRIVATE_KEY
DNS = ${DNS_SERVERS:-1.1.1.1}
MTU = ${MTU:-1420}

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $SERVER_ENDPOINT
AllowedIPs = ${ALLOWED_IPS:-0.0.0.0/0}
PersistentKeepalive = ${PERSISTENT_KEEPALIVE:-25}
EOF
    
    if [ -n "$PRESHARED_KEY" ]; then
        echo "PresharedKey = $PRESHARED_KEY" >> "$wg_config"
    fi
    
    # Bring up WireGuard interface
    sudo wg-quick up "$wg_config"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} WireGuard connected successfully"
        echo "connected|WireGuard|$(curl -s --max-time 5 ifconfig.me 2>/dev/null)" > "$STATUS_FILE"
        return 0
    else
        echo -e "${RED}✗${NC} WireGuard connection failed"
        return 1
    fi
}

# IPSec connection
connect_ipsec() {
    local profile_file="$1"
    source "$profile_file"
    
    if command -v nmcli >/dev/null; then
        # Use NetworkManager for IPSec
        nmcli connection add type vpn vpn-type strongswan \
            connection.id "$PROFILE_NAME" \
            vpn.data "address=$SERVER_ADDRESS,username=$USERNAME,password=$PASSWORD"
        
        nmcli connection up "$PROFILE_NAME"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓${NC} IPSec VPN connected via NetworkManager"
            return 0
        fi
    fi
    
    echo -e "${RED}✗${NC} IPSec connection failed"
    return 1
}

# NetworkManager VPN connection
connect_networkmanager() {
    local profile_name="$1"
    
    if command -v nmcli >/dev/null; then
        nmcli connection up "$profile_name"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓${NC} NetworkManager VPN connected"
            return 0
        fi
    fi
    
    echo -e "${RED}✗${NC} NetworkManager VPN connection failed"
    return 1
}

# Disconnect VPN
disconnect_vpn() {
    echo -e "${BLUE}Disconnecting VPN...${NC}"
    
    # Kill OpenVPN
    if pgrep openvpn >/dev/null; then
        sudo pkill openvpn
        echo -e "${GREEN}✓${NC} OpenVPN disconnected"
    fi
    
    # Disconnect WireGuard
    if command -v wg >/dev/null; then
        for interface in $(wg show interfaces 2>/dev/null); do
            sudo wg-quick down "$interface" 2>/dev/null || sudo ip link delete "$interface" 2>/dev/null
        done
        echo -e "${GREEN}✓${NC} WireGuard disconnected"
    fi
    
    # Disconnect NetworkManager VPN
    if command -v nmcli >/dev/null; then
        nmcli connection show --active | grep vpn | while read -r line; do
            local conn_name=$(echo "$line" | cut -d' ' -f1)
            nmcli connection down "$conn_name"
        done
        echo -e "${GREEN}✓${NC} NetworkManager VPN disconnected"
    fi
    
    # Clear status
    echo "disconnected||" > "$STATUS_FILE"
    echo "$(date): VPN disconnected" >> "$CONNECTIONS_LOG"
}

# Kill switch implementation
enable_kill_switch() {
    echo -e "${BLUE}Enabling VPN kill switch...${NC}"
    
    # Block all traffic except VPN
    sudo iptables -P INPUT DROP
    sudo iptables -P FORWARD DROP
    sudo iptables -P OUTPUT DROP
    
    # Allow loopback
    sudo iptables -A INPUT -i lo -j ACCEPT
    sudo iptables -A OUTPUT -o lo -j ACCEPT
    
    # Allow VPN traffic
    sudo iptables -A OUTPUT -o tun+ -j ACCEPT
    sudo iptables -A INPUT -i tun+ -j ACCEPT
    sudo iptables -A OUTPUT -o wg+ -j ACCEPT
    sudo iptables -A INPUT -i wg+ -j ACCEPT
    
    # Allow VPN server connection
    if [ -f "$STATUS_FILE" ]; then
        local server_ip=$(grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+' "$PROFILES_DIR"/*.conf | head -1)
        if [ -n "$server_ip" ]; then
            sudo iptables -A OUTPUT -d "$server_ip" -j ACCEPT
            sudo iptables -A INPUT -s "$server_ip" -j ACCEPT
        fi
    fi
    
    echo -e "${GREEN}✓${NC} Kill switch enabled"
}

# Disable kill switch
disable_kill_switch() {
    echo -e "${BLUE}Disabling VPN kill switch...${NC}"
    
    # Reset iptables to accept all
    sudo iptables -P INPUT ACCEPT
    sudo iptables -P FORWARD ACCEPT
    sudo iptables -P OUTPUT ACCEPT
    
    # Flush VPN rules
    sudo iptables -F
    
    echo -e "${GREEN}✓${NC} Kill switch disabled"
}

# DNS leak protection
setup_dns_protection() {
    local dns_servers="${1:-$DEFAULT_DNS}"
    
    echo -e "${BLUE}Setting up DNS leak protection...${NC}"
    
    # Backup original resolv.conf
    if [ ! -f "/etc/resolv.conf.backup" ]; then
        sudo cp /etc/resolv.conf /etc/resolv.conf.backup
    fi
    
    # Set VPN DNS servers
    sudo tee /etc/resolv.conf > /dev/null << EOF
# BluejayLinux VPN DNS Configuration
$(echo "$dns_servers" | tr ',' '\n' | sed 's/^/nameserver /')
options edns0 trust-ad
EOF
    
    echo -e "${GREEN}✓${NC} DNS protection enabled with servers: $dns_servers"
}

# Restore original DNS
restore_dns() {
    echo -e "${BLUE}Restoring original DNS settings...${NC}"
    
    if [ -f "/etc/resolv.conf.backup" ]; then
        sudo cp /etc/resolv.conf.backup /etc/resolv.conf
        echo -e "${GREEN}✓${NC} Original DNS restored"
    fi
}

# List VPN profiles
list_profiles() {
    echo -e "\n${BLUE}Available VPN Profiles:${NC}"
    
    if [ ! -d "$PROFILES_DIR" ] || [ -z "$(ls -A "$PROFILES_DIR" 2>/dev/null)" ]; then
        echo -e "${YELLOW}No profiles found${NC}"
        return
    fi
    
    local count=1
    for profile in "$PROFILES_DIR"/*.conf; do
        if [ -f "$profile" ]; then
            local name=$(basename "$profile" .conf)
            local protocol=$(grep "^PROTOCOL=" "$profile" | cut -d'=' -f2)
            local server=$(grep -E "^SERVER_ADDRESS=|^SERVER_ENDPOINT=" "$profile" | cut -d'=' -f2)
            
            echo -e "${WHITE}$count.${NC} $name"
            echo -e "   ${CYAN}Protocol:${NC} $protocol"
            echo -e "   ${CYAN}Server:${NC} ${server:-Not configured}"
        fi
        ((count++))
    done
}

# Connection status display
show_status() {
    local status_info=$(get_vpn_status)
    local status=$(echo "$status_info" | cut -d'|' -f1)
    local connection=$(echo "$status_info" | cut -d'|' -f2)
    local ip=$(echo "$status_info" | cut -d'|' -f3)
    
    echo -e "\n${PURPLE}=== VPN Status ===${NC}"
    
    if [ "$status" = "connected" ]; then
        echo -e "${GREEN}Status: Connected${NC}"
        echo -e "${CYAN}Connection: $connection${NC}"
        echo -e "${CYAN}External IP: $ip${NC}"
        
        # Show interface information
        if ip route | grep -q tun0; then
            echo -e "${CYAN}Interface: tun0 (OpenVPN)${NC}"
        elif command -v wg >/dev/null && wg show 2>/dev/null | grep -q interface; then
            echo -e "${CYAN}Interface: $(wg show interfaces | head -1) (WireGuard)${NC}"
        fi
    else
        echo -e "${RED}Status: Disconnected${NC}"
        local real_ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "Unknown")
        echo -e "${CYAN}Real IP: $real_ip${NC}"
    fi
    
    # Show recent connections
    if [ -f "$CONNECTIONS_LOG" ] && [ -s "$CONNECTIONS_LOG" ]; then
        echo -e "\n${BLUE}Recent Connections:${NC}"
        tail -5 "$CONNECTIONS_LOG"
    fi
}

# Settings menu
settings_menu() {
    echo -e "\n${PURPLE}=== VPN Manager Settings ===${NC}"
    echo -e "${WHITE}1.${NC} Auto connect: ${AUTO_CONNECT}"
    echo -e "${WHITE}2.${NC} Kill switch: ${KILL_SWITCH}"
    echo -e "${WHITE}3.${NC} DNS leak protection: ${DNS_LEAK_PROTECTION}"
    echo -e "${WHITE}4.${NC} Preferred protocol: ${PREFERRED_PROTOCOL}"
    echo -e "${WHITE}5.${NC} Default DNS: ${DEFAULT_DNS}"
    echo -e "${WHITE}6.${NC} Reconnection attempts: ${RECONNECT_ATTEMPTS}"
    echo -e "${WHITE}7.${NC} Show notifications: ${SHOW_NOTIFICATIONS}"
    echo -e "${WHITE}8.${NC} IPv6 support: ${IPV6_SUPPORT}"
    echo -e "${WHITE}s.${NC} Save settings"
    echo -e "${WHITE}q.${NC} Back to main menu"
    echo
    
    echo -ne "${YELLOW}Select option:${NC} "
    read -r choice
    
    case "$choice" in
        1)
            echo -ne "${CYAN}Auto connect on startup (true/false):${NC} "
            read -r AUTO_CONNECT
            ;;
        2)
            echo -ne "${CYAN}Enable kill switch (true/false):${NC} "
            read -r KILL_SWITCH
            ;;
        3)
            echo -ne "${CYAN}DNS leak protection (true/false):${NC} "
            read -r DNS_LEAK_PROTECTION
            ;;
        4)
            echo -ne "${CYAN}Preferred protocol (auto/openvpn/wireguard/ipsec):${NC} "
            read -r PREFERRED_PROTOCOL
            ;;
        5)
            echo -ne "${CYAN}Default DNS servers (comma separated):${NC} "
            read -r DEFAULT_DNS
            ;;
        6)
            echo -ne "${CYAN}Reconnection attempts:${NC} "
            read -r RECONNECT_ATTEMPTS
            ;;
        7)
            echo -ne "${CYAN}Show notifications (true/false):${NC} "
            read -r SHOW_NOTIFICATIONS
            ;;
        8)
            echo -ne "${CYAN}IPv6 support (true/false):${NC} "
            read -r IPV6_SUPPORT
            ;;
        s|S)
            cat > "$VPN_CONFIG_DIR/settings.conf" << EOF
# BluejayLinux VPN Manager Settings
AUTO_CONNECT=$AUTO_CONNECT
KILL_SWITCH=$KILL_SWITCH
DNS_LEAK_PROTECTION=$DNS_LEAK_PROTECTION
PREFERRED_PROTOCOL=$PREFERRED_PROTOCOL
LOG_CONNECTIONS=$LOG_CONNECTIONS
RECONNECT_ATTEMPTS=$RECONNECT_ATTEMPTS
RECONNECT_DELAY=$RECONNECT_DELAY
SHOW_NOTIFICATIONS=$SHOW_NOTIFICATIONS
SYSTEM_TRAY=$SYSTEM_TRAY
START_MINIMIZED=$START_MINIMIZED
DEFAULT_DNS=$DEFAULT_DNS
IPV6_SUPPORT=$IPV6_SUPPORT
COMPRESSION=$COMPRESSION
EOF
            echo -e "${GREEN}✓${NC} Settings saved"
            ;;
    esac
}

# Main menu
main_menu() {
    echo -e "${PURPLE}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                   ${WHITE}BluejayLinux VPN Manager${PURPLE}                       ║${NC}"
    echo -e "${PURPLE}║                 ${CYAN}Professional VPN Integration${PURPLE}                   ║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    local clients=($(detect_vpn_clients))
    echo -e "${WHITE}Available VPN clients:${NC} ${clients[*]}"
    echo
    
    echo -e "${WHITE}1.${NC} Show VPN status"
    echo -e "${WHITE}2.${NC} Connect to VPN"
    echo -e "${WHITE}3.${NC} Disconnect VPN"
    echo -e "${WHITE}4.${NC} Create new profile"
    echo -e "${WHITE}5.${NC} List profiles"
    echo -e "${WHITE}6.${NC} Enable kill switch"
    echo -e "${WHITE}7.${NC} Disable kill switch"
    echo -e "${WHITE}8.${NC} DNS protection"
    echo -e "${WHITE}9.${NC} Settings"
    echo -e "${WHITE}q.${NC} Quit"
    echo
}

# Main function
main() {
    create_directories
    load_settings
    
    if [ $# -gt 0 ]; then
        case "$1" in
            --connect|-c)
                connect_vpn "$2"
                ;;
            --disconnect|-d)
                disconnect_vpn
                ;;
            --status|-s)
                show_status
                ;;
            --list|-l)
                list_profiles
                ;;
            --create)
                create_profile "$2" "$3"
                ;;
            --kill-switch-on)
                enable_kill_switch
                ;;
            --kill-switch-off)
                disable_kill_switch
                ;;
            --help|-h)
                echo "BluejayLinux VPN Manager"
                echo "Usage: $0 [options] [parameters]"
                echo "  --connect, -c <profile>    Connect to VPN profile"
                echo "  --disconnect, -d           Disconnect VPN"
                echo "  --status, -s               Show VPN status"
                echo "  --list, -l                 List VPN profiles"
                echo "  --create <name> <protocol> Create new profile"
                echo "  --kill-switch-on           Enable kill switch"
                echo "  --kill-switch-off          Disable kill switch"
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
                show_status
                ;;
            2)
                list_profiles
                echo -ne "${CYAN}Enter profile name to connect:${NC} "
                read -r profile_name
                if [ -n "$profile_name" ]; then
                    connect_vpn "$profile_name"
                fi
                ;;
            3)
                disconnect_vpn
                ;;
            4)
                echo -ne "${CYAN}Enter profile name:${NC} "
                read -r profile_name
                echo -ne "${CYAN}Enter protocol (openvpn/wireguard/ipsec-ikev2):${NC} "
                read -r protocol
                create_profile "$profile_name" "$protocol"
                ;;
            5)
                list_profiles
                ;;
            6)
                enable_kill_switch
                ;;
            7)
                disable_kill_switch
                ;;
            8)
                echo -ne "${CYAN}Enter DNS servers (comma separated):${NC} "
                read -r dns_servers
                setup_dns_protection "$dns_servers"
                ;;
            9)
                settings_menu
                ;;
            q|Q)
                echo -e "${GREEN}VPN Manager configuration saved${NC}"
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