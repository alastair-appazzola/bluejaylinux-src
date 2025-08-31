#!/bin/bash

# BluejayLinux - Advanced Firewall Manager
# Professional firewall GUI interface with comprehensive security features

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/bluejay"
FIREWALL_CONFIG_DIR="$CONFIG_DIR/firewall"
RULES_DIR="$FIREWALL_CONFIG_DIR/rules"
PROFILES_DIR="$FIREWALL_CONFIG_DIR/profiles"
LOG_FILE="/var/log/bluejay-firewall.log"
RULES_BACKUP="/tmp/iptables-backup.rules"

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

# Predefined security profiles
SECURITY_PROFILES="minimal standard strict paranoid gaming server"

# Initialize directories
create_directories() {
    mkdir -p "$CONFIG_DIR" "$FIREWALL_CONFIG_DIR" "$RULES_DIR" "$PROFILES_DIR"
    
    # Create default firewall configuration
    if [ ! -f "$FIREWALL_CONFIG_DIR/settings.conf" ]; then
        cat > "$FIREWALL_CONFIG_DIR/settings.conf" << 'EOF'
# BluejayLinux Firewall Manager Settings
FIREWALL_ENABLED=true
DEFAULT_POLICY=DROP
LOG_DROPPED_PACKETS=true
LOG_ACCEPTED_PACKETS=false
RATE_LIMITING=true
CONNECTION_TRACKING=true
FAIL2BAN_INTEGRATION=true
INTRUSION_DETECTION=true
GEO_BLOCKING=false
BLOCKED_COUNTRIES=""
ALLOW_PING=true
ALLOW_LOOPBACK=true
STEALTH_MODE=false
AUTO_BACKUP_RULES=true
NOTIFICATION_LEVEL=normal
DEFAULT_PROFILE=standard
EOF
    fi
    
    # Create security profiles
    create_security_profiles
}

# Create predefined security profiles
create_security_profiles() {
    # Minimal profile
    cat > "$PROFILES_DIR/minimal.profile" << 'EOF'
# Minimal Security Profile
PROFILE_NAME=minimal
DESCRIPTION="Basic firewall protection with essential rules only"
DEFAULT_INPUT_POLICY=ACCEPT
DEFAULT_FORWARD_POLICY=DROP
DEFAULT_OUTPUT_POLICY=ACCEPT
ALLOW_SSH=true
ALLOW_HTTP=true
ALLOW_HTTPS=true
ALLOW_DNS=true
ALLOW_DHCP=true
BLOCK_COMMON_ATTACKS=false
RATE_LIMITING=false
CONNECTION_TRACKING=false
LOG_LEVEL=minimal
EOF

    # Standard profile
    cat > "$PROFILES_DIR/standard.profile" << 'EOF'
# Standard Security Profile
PROFILE_NAME=standard
DESCRIPTION="Balanced security for typical desktop usage"
DEFAULT_INPUT_POLICY=DROP
DEFAULT_FORWARD_POLICY=DROP
DEFAULT_OUTPUT_POLICY=ACCEPT
ALLOW_SSH=true
ALLOW_HTTP=true
ALLOW_HTTPS=true
ALLOW_DNS=true
ALLOW_DHCP=true
ALLOW_EMAIL=true
ALLOW_FTP=false
BLOCK_COMMON_ATTACKS=true
RATE_LIMITING=true
CONNECTION_TRACKING=true
LOG_LEVEL=normal
CUSTOM_PORTS="22,80,443,53,25,587,993,995"
EOF

    # Strict profile
    cat > "$PROFILES_DIR/strict.profile" << 'EOF'
# Strict Security Profile
PROFILE_NAME=strict
DESCRIPTION="High security with restrictive outbound filtering"
DEFAULT_INPUT_POLICY=DROP
DEFAULT_FORWARD_POLICY=DROP
DEFAULT_OUTPUT_POLICY=DROP
ALLOW_SSH=true
ALLOW_HTTP=true
ALLOW_HTTPS=true
ALLOW_DNS=true
ALLOW_DHCP=true
ALLOW_EMAIL=false
ALLOW_FTP=false
BLOCK_COMMON_ATTACKS=true
BLOCK_P2P=true
BLOCK_TORRENTS=true
RATE_LIMITING=true
CONNECTION_TRACKING=true
STEALTH_MODE=true
LOG_LEVEL=verbose
EOF

    # Gaming profile
    cat > "$PROFILES_DIR/gaming.profile" << 'EOF'
# Gaming Security Profile
PROFILE_NAME=gaming
DESCRIPTION="Optimized for gaming with necessary ports open"
DEFAULT_INPUT_POLICY=DROP
DEFAULT_FORWARD_POLICY=DROP
DEFAULT_OUTPUT_POLICY=ACCEPT
ALLOW_SSH=true
ALLOW_HTTP=true
ALLOW_HTTPS=true
ALLOW_DNS=true
ALLOW_DHCP=true
GAMING_PORTS=true
STEAM_PORTS=true
XBOX_LIVE=true
PLAYSTATION=true
NINTENDO=true
RATE_LIMITING=false
CONNECTION_TRACKING=true
LOG_LEVEL=minimal
CUSTOM_PORTS="27015,27036,3478-3480,7777-7784"
EOF

    # Server profile
    cat > "$PROFILES_DIR/server.profile" << 'EOF'
# Server Security Profile
PROFILE_NAME=server
DESCRIPTION="Security profile for server environments"
DEFAULT_INPUT_POLICY=DROP
DEFAULT_FORWARD_POLICY=DROP
DEFAULT_OUTPUT_POLICY=ACCEPT
ALLOW_SSH=true
ALLOW_HTTP=true
ALLOW_HTTPS=true
ALLOW_DNS=true
ALLOW_DHCP=false
ALLOW_EMAIL=true
ALLOW_FTP=true
WEB_SERVER=true
DATABASE_PORTS=true
BLOCK_COMMON_ATTACKS=true
RATE_LIMITING=true
CONNECTION_TRACKING=true
FAIL2BAN_RULES=true
LOG_LEVEL=verbose
CUSTOM_PORTS="22,80,443,25,587,993,995,21,3306,5432"
EOF
}

# Load settings
load_settings() {
    if [ -f "$FIREWALL_CONFIG_DIR/settings.conf" ]; then
        source "$FIREWALL_CONFIG_DIR/settings.conf"
    fi
}

# Detect firewall backend
detect_firewall_backend() {
    local backends=()
    
    echo -e "${BLUE}Detecting firewall backends...${NC}"
    
    # iptables
    if command -v iptables >/dev/null; then
        backends+=("iptables")
        echo -e "${GREEN}✓${NC} iptables: $(iptables --version | head -1)"
    fi
    
    # nftables
    if command -v nft >/dev/null; then
        backends+=("nftables")
        echo -e "${GREEN}✓${NC} nftables: $(nft --version)"
    fi
    
    # ufw
    if command -v ufw >/dev/null; then
        backends+=("ufw")
        echo -e "${GREEN}✓${NC} UFW (Uncomplicated Firewall)"
    fi
    
    # firewalld
    if command -v firewall-cmd >/dev/null; then
        backends+=("firewalld")
        echo -e "${GREEN}✓${NC} firewalld"
    fi
    
    # fail2ban
    if command -v fail2ban-client >/dev/null; then
        backends+=("fail2ban")
        echo -e "${GREEN}✓${NC} fail2ban intrusion prevention"
    fi
    
    echo "${backends[@]}"
}

# Get current firewall status
get_firewall_status() {
    local status="unknown"
    local rules_count=0
    local backend=""
    
    # Check iptables
    if command -v iptables >/dev/null; then
        backend="iptables"
        rules_count=$(iptables -L -n | grep -c "^ACCEPT\|^DROP\|^REJECT")
        
        # Check if default policies are restrictive
        local input_policy=$(iptables -L INPUT | head -1 | grep -o "policy [A-Z]*" | cut -d' ' -f2)
        if [ "$input_policy" = "DROP" ] || [ "$input_policy" = "REJECT" ]; then
            status="active"
        elif [ "$rules_count" -gt 10 ]; then
            status="active"
        else
            status="inactive"
        fi
    fi
    
    # Check ufw
    if command -v ufw >/dev/null; then
        local ufw_status=$(ufw status | head -1 | grep -o "Status: [a-z]*" | cut -d' ' -f2)
        if [ "$ufw_status" = "active" ]; then
            status="active"
            backend="ufw"
            rules_count=$(ufw status numbered | grep -c "^\[")
        fi
    fi
    
    # Check firewalld
    if command -v firewall-cmd >/dev/null; then
        if systemctl is-active --quiet firewalld; then
            status="active"
            backend="firewalld"
            rules_count=$(firewall-cmd --list-all | grep -c "services\|ports")
        fi
    fi
    
    echo "$status|$backend|$rules_count"
}

# Backup current rules
backup_rules() {
    echo -e "${BLUE}Backing up current firewall rules...${NC}"
    
    local backup_file="$FIREWALL_CONFIG_DIR/backup-$(date +%Y%m%d-%H%M%S).rules"
    
    if command -v iptables >/dev/null; then
        iptables-save > "$backup_file"
        echo -e "${GREEN}✓${NC} Rules backed up to: $backup_file"
    else
        echo -e "${YELLOW}!${NC} No backup method available"
    fi
}

# Apply security profile
apply_security_profile() {
    local profile_name="$1"
    local profile_file="$PROFILES_DIR/${profile_name}.profile"
    
    if [ ! -f "$profile_file" ]; then
        echo -e "${RED}✗${NC} Profile not found: $profile_name"
        return 1
    fi
    
    echo -e "${BLUE}Applying security profile: $profile_name${NC}"
    
    # Backup current rules
    backup_rules
    
    # Load profile
    source "$profile_file"
    
    # Clear existing rules
    clear_firewall_rules
    
    # Set default policies
    iptables -P INPUT ${DEFAULT_INPUT_POLICY:-DROP}
    iptables -P FORWARD ${DEFAULT_FORWARD_POLICY:-DROP}
    iptables -P OUTPUT ${DEFAULT_OUTPUT_POLICY:-ACCEPT}
    
    # Allow loopback
    if [ "${ALLOW_LOOPBACK:-true}" = "true" ]; then
        iptables -A INPUT -i lo -j ACCEPT
        iptables -A OUTPUT -o lo -j ACCEPT
    fi
    
    # Connection tracking
    if [ "${CONNECTION_TRACKING:-true}" = "true" ]; then
        iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
        iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED -j ACCEPT
    fi
    
    # Allow specific services
    apply_service_rules
    
    # Apply rate limiting
    if [ "${RATE_LIMITING:-false}" = "true" ]; then
        apply_rate_limiting
    fi
    
    # Block common attacks
    if [ "${BLOCK_COMMON_ATTACKS:-false}" = "true" ]; then
        apply_attack_protection
    fi
    
    # Apply custom ports
    if [ -n "${CUSTOM_PORTS:-}" ]; then
        apply_custom_ports "$CUSTOM_PORTS"
    fi
    
    echo -e "${GREEN}✓${NC} Security profile applied: $profile_name"
}

# Apply service-specific rules
apply_service_rules() {
    # SSH
    if [ "${ALLOW_SSH:-false}" = "true" ]; then
        iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    fi
    
    # HTTP/HTTPS
    if [ "${ALLOW_HTTP:-false}" = "true" ]; then
        iptables -A INPUT -p tcp --dport 80 -j ACCEPT
    fi
    if [ "${ALLOW_HTTPS:-false}" = "true" ]; then
        iptables -A INPUT -p tcp --dport 443 -j ACCEPT
    fi
    
    # DNS
    if [ "${ALLOW_DNS:-true}" = "true" ]; then
        iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
        iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
    fi
    
    # DHCP
    if [ "${ALLOW_DHCP:-true}" = "true" ]; then
        iptables -A INPUT -p udp --sport 67 --dport 68 -j ACCEPT
        iptables -A OUTPUT -p udp --sport 68 --dport 67 -j ACCEPT
    fi
    
    # Email
    if [ "${ALLOW_EMAIL:-false}" = "true" ]; then
        iptables -A INPUT -p tcp --dport 25 -j ACCEPT   # SMTP
        iptables -A INPUT -p tcp --dport 587 -j ACCEPT  # Submission
        iptables -A INPUT -p tcp --dport 993 -j ACCEPT  # IMAPS
        iptables -A INPUT -p tcp --dport 995 -j ACCEPT  # POP3S
    fi
    
    # FTP
    if [ "${ALLOW_FTP:-false}" = "true" ]; then
        iptables -A INPUT -p tcp --dport 21 -j ACCEPT
        iptables -A INPUT -p tcp --dport 20 -j ACCEPT
    fi
    
    # Gaming ports
    if [ "${GAMING_PORTS:-false}" = "true" ]; then
        # Steam
        iptables -A INPUT -p tcp --dport 27015 -j ACCEPT
        iptables -A INPUT -p udp --dport 27015 -j ACCEPT
        # Xbox Live
        iptables -A INPUT -p tcp --dport 3074 -j ACCEPT
        iptables -A INPUT -p udp --dport 3074 -j ACCEPT
    fi
}

# Apply rate limiting
apply_rate_limiting() {
    echo -e "${CYAN}Applying rate limiting rules...${NC}"
    
    # SSH brute force protection
    iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --set --name SSH
    iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 4 --rttl --name SSH -j DROP
    
    # HTTP flood protection
    iptables -A INPUT -p tcp --dport 80 -m connlimit --connlimit-above 20 -j DROP
    iptables -A INPUT -p tcp --dport 443 -m connlimit --connlimit-above 20 -j DROP
    
    # General connection limiting
    iptables -A INPUT -p tcp -m conntrack --ctstate NEW -m limit --limit 60/s --limit-burst 20 -j ACCEPT
    iptables -A INPUT -p tcp -m conntrack --ctstate NEW -j DROP
}

# Apply attack protection
apply_attack_protection() {
    echo -e "${CYAN}Applying attack protection rules...${NC}"
    
    # Block invalid packets
    iptables -A INPUT -m conntrack --ctstate INVALID -j DROP
    
    # Block null packets
    iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
    
    # Block SYN flood attacks
    iptables -A INPUT -p tcp ! --syn -m conntrack --ctstate NEW -j DROP
    
    # Block XMAS packets
    iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP
    
    # Block fragmented packets
    iptables -A INPUT -f -j DROP
    
    # Block common port scans
    iptables -A INPUT -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
    iptables -A INPUT -p tcp --tcp-flags FIN,SYN FIN,SYN -j DROP
    
    # Limit ping requests
    iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s -j ACCEPT
    iptables -A INPUT -p icmp --icmp-type echo-request -j DROP
}

# Apply custom ports
apply_custom_ports() {
    local ports="$1"
    echo -e "${CYAN}Applying custom port rules: $ports${NC}"
    
    IFS=',' read -ra PORT_ARRAY <<< "$ports"
    for port in "${PORT_ARRAY[@]}"; do
        if [[ $port == *-* ]]; then
            # Port range
            iptables -A INPUT -p tcp --dport "$port" -j ACCEPT
        else
            # Single port
            iptables -A INPUT -p tcp --dport "$port" -j ACCEPT
        fi
    done
}

# Clear firewall rules
clear_firewall_rules() {
    echo -e "${BLUE}Clearing firewall rules...${NC}"
    
    # Flush all rules
    iptables -F
    iptables -X
    iptables -t nat -F
    iptables -t nat -X
    iptables -t mangle -F
    iptables -t mangle -X
    
    # Set default policies to ACCEPT temporarily
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    
    echo -e "${GREEN}✓${NC} Firewall rules cleared"
}

# Enable firewall
enable_firewall() {
    echo -e "${BLUE}Enabling firewall...${NC}"
    
    # Apply default profile if no rules exist
    local status_info=$(get_firewall_status)
    local rules_count=$(echo "$status_info" | cut -d'|' -f3)
    
    if [ "$rules_count" -lt 5 ]; then
        echo -e "${YELLOW}No rules found, applying default profile${NC}"
        apply_security_profile "${DEFAULT_PROFILE:-standard}"
    fi
    
    # Save rules for persistence
    if command -v iptables-save >/dev/null; then
        iptables-save > "$FIREWALL_CONFIG_DIR/active.rules"
    fi
    
    echo -e "${GREEN}✓${NC} Firewall enabled"
}

# Disable firewall
disable_firewall() {
    echo -e "${BLUE}Disabling firewall...${NC}"
    
    # Set all policies to ACCEPT
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    
    # Flush all rules
    iptables -F
    iptables -X
    iptables -t nat -F
    iptables -t nat -X
    iptables -t mangle -F
    iptables -t mangle -X
    
    echo -e "${GREEN}✓${NC} Firewall disabled"
}

# Show firewall rules
show_firewall_rules() {
    echo -e "\n${BLUE}Current Firewall Rules:${NC}"
    
    if command -v iptables >/dev/null; then
        echo -e "\n${WHITE}Filter Table:${NC}"
        iptables -L -n -v --line-numbers
        
        echo -e "\n${WHITE}NAT Table:${NC}"
        iptables -t nat -L -n -v --line-numbers
        
        echo -e "\n${WHITE}Mangle Table:${NC}"
        iptables -t mangle -L -n -v --line-numbers
    else
        echo -e "${RED}No firewall backend available${NC}"
    fi
}

# Add custom rule
add_custom_rule() {
    echo -e "${BLUE}Add Custom Firewall Rule${NC}"
    echo
    echo -e "${WHITE}1.${NC} Allow incoming port"
    echo -e "${WHITE}2.${NC} Block incoming port"
    echo -e "${WHITE}3.${NC} Allow outgoing port"
    echo -e "${WHITE}4.${NC} Block outgoing port"
    echo -e "${WHITE}5.${NC} Allow IP address"
    echo -e "${WHITE}6.${NC} Block IP address"
    echo -e "${WHITE}7.${NC} Custom iptables rule"
    echo
    
    echo -ne "${YELLOW}Select rule type:${NC} "
    read -r rule_type
    
    case "$rule_type" in
        1)
            echo -ne "${CYAN}Enter port number:${NC} "
            read -r port
            echo -ne "${CYAN}Protocol (tcp/udp/both):${NC} "
            read -r protocol
            
            if [ "$protocol" = "both" ]; then
                iptables -A INPUT -p tcp --dport "$port" -j ACCEPT
                iptables -A INPUT -p udp --dport "$port" -j ACCEPT
            else
                iptables -A INPUT -p "$protocol" --dport "$port" -j ACCEPT
            fi
            echo -e "${GREEN}✓${NC} Rule added: Allow incoming $protocol port $port"
            ;;
        2)
            echo -ne "${CYAN}Enter port number:${NC} "
            read -r port
            echo -ne "${CYAN}Protocol (tcp/udp/both):${NC} "
            read -r protocol
            
            if [ "$protocol" = "both" ]; then
                iptables -A INPUT -p tcp --dport "$port" -j DROP
                iptables -A INPUT -p udp --dport "$port" -j DROP
            else
                iptables -A INPUT -p "$protocol" --dport "$port" -j DROP
            fi
            echo -e "${GREEN}✓${NC} Rule added: Block incoming $protocol port $port"
            ;;
        5)
            echo -ne "${CYAN}Enter IP address:${NC} "
            read -r ip_address
            iptables -A INPUT -s "$ip_address" -j ACCEPT
            echo -e "${GREEN}✓${NC} Rule added: Allow IP $ip_address"
            ;;
        6)
            echo -ne "${CYAN}Enter IP address:${NC} "
            read -r ip_address
            iptables -A INPUT -s "$ip_address" -j DROP
            echo -e "${GREEN}✓${NC} Rule added: Block IP $ip_address"
            ;;
        7)
            echo -ne "${CYAN}Enter custom iptables rule:${NC} "
            read -r custom_rule
            if iptables $custom_rule; then
                echo -e "${GREEN}✓${NC} Custom rule added"
            else
                echo -e "${RED}✗${NC} Failed to add custom rule"
            fi
            ;;
    esac
}

# Remove firewall rule
remove_rule() {
    echo -e "${BLUE}Current INPUT rules:${NC}"
    iptables -L INPUT -n --line-numbers
    
    echo -ne "\n${CYAN}Enter rule number to remove:${NC} "
    read -r rule_number
    
    if [[ "$rule_number" =~ ^[0-9]+$ ]]; then
        iptables -D INPUT "$rule_number"
        echo -e "${GREEN}✓${NC} Rule $rule_number removed"
    else
        echo -e "${RED}✗${NC} Invalid rule number"
    fi
}

# Monitor firewall activity
monitor_firewall() {
    echo -e "${BLUE}Firewall Activity Monitor${NC}"
    echo -e "${GRAY}Press Ctrl+C to stop monitoring${NC}"
    echo
    
    # Enable logging if not already enabled
    if ! iptables -L | grep -q "LOG"; then
        iptables -I INPUT -j LOG --log-prefix "FIREWALL-INPUT: "
        iptables -I OUTPUT -j LOG --log-prefix "FIREWALL-OUTPUT: "
    fi
    
    # Monitor logs
    if [ -f "/var/log/kern.log" ]; then
        tail -f /var/log/kern.log | grep "FIREWALL"
    elif [ -f "/var/log/messages" ]; then
        tail -f /var/log/messages | grep "FIREWALL"
    else
        echo -e "${YELLOW}!${NC} No suitable log file found for monitoring"
        echo "Checking iptables counters instead:"
        
        while true; do
            clear
            echo -e "${PURPLE}=== Firewall Activity Monitor ===${NC}"
            echo -e "${CYAN}Timestamp: $(date)${NC}"
            echo
            iptables -L -n -v | head -20
            sleep 5
        done
    fi
}

# List security profiles
list_profiles() {
    echo -e "\n${BLUE}Available Security Profiles:${NC}"
    
    local count=1
    for profile in "$PROFILES_DIR"/*.profile; do
        if [ -f "$profile" ]; then
            local name=$(basename "$profile" .profile)
            local description=$(grep "^DESCRIPTION=" "$profile" | cut -d'=' -f2 | tr -d '"')
            
            echo -e "${WHITE}$count.${NC} $name"
            echo -e "   ${CYAN}$description${NC}"
        fi
        ((count++))
    done
}

# Settings menu
settings_menu() {
    echo -e "\n${PURPLE}=== Firewall Manager Settings ===${NC}"
    echo -e "${WHITE}1.${NC} Firewall enabled: ${FIREWALL_ENABLED}"
    echo -e "${WHITE}2.${NC} Default policy: ${DEFAULT_POLICY}"
    echo -e "${WHITE}3.${NC} Log dropped packets: ${LOG_DROPPED_PACKETS}"
    echo -e "${WHITE}4.${NC} Rate limiting: ${RATE_LIMITING}"
    echo -e "${WHITE}5.${NC} Connection tracking: ${CONNECTION_TRACKING}"
    echo -e "${WHITE}6.${NC} Stealth mode: ${STEALTH_MODE}"
    echo -e "${WHITE}7.${NC} Default profile: ${DEFAULT_PROFILE}"
    echo -e "${WHITE}8.${NC} Auto backup rules: ${AUTO_BACKUP_RULES}"
    echo -e "${WHITE}s.${NC} Save settings"
    echo -e "${WHITE}q.${NC} Back to main menu"
    echo
    
    echo -ne "${YELLOW}Select option:${NC} "
    read -r choice
    
    case "$choice" in
        1)
            echo -ne "${CYAN}Enable firewall (true/false):${NC} "
            read -r FIREWALL_ENABLED
            ;;
        2)
            echo -ne "${CYAN}Default policy (ACCEPT/DROP/REJECT):${NC} "
            read -r DEFAULT_POLICY
            ;;
        3)
            echo -ne "${CYAN}Log dropped packets (true/false):${NC} "
            read -r LOG_DROPPED_PACKETS
            ;;
        4)
            echo -ne "${CYAN}Enable rate limiting (true/false):${NC} "
            read -r RATE_LIMITING
            ;;
        5)
            echo -ne "${CYAN}Enable connection tracking (true/false):${NC} "
            read -r CONNECTION_TRACKING
            ;;
        6)
            echo -ne "${CYAN}Enable stealth mode (true/false):${NC} "
            read -r STEALTH_MODE
            ;;
        7)
            list_profiles
            echo -ne "${CYAN}Default security profile:${NC} "
            read -r DEFAULT_PROFILE
            ;;
        8)
            echo -ne "${CYAN}Auto backup rules (true/false):${NC} "
            read -r AUTO_BACKUP_RULES
            ;;
        s|S)
            cat > "$FIREWALL_CONFIG_DIR/settings.conf" << EOF
# BluejayLinux Firewall Manager Settings
FIREWALL_ENABLED=$FIREWALL_ENABLED
DEFAULT_POLICY=$DEFAULT_POLICY
LOG_DROPPED_PACKETS=$LOG_DROPPED_PACKETS
LOG_ACCEPTED_PACKETS=$LOG_ACCEPTED_PACKETS
RATE_LIMITING=$RATE_LIMITING
CONNECTION_TRACKING=$CONNECTION_TRACKING
FAIL2BAN_INTEGRATION=$FAIL2BAN_INTEGRATION
INTRUSION_DETECTION=$INTRUSION_DETECTION
GEO_BLOCKING=$GEO_BLOCKING
BLOCKED_COUNTRIES="$BLOCKED_COUNTRIES"
ALLOW_PING=$ALLOW_PING
ALLOW_LOOPBACK=$ALLOW_LOOPBACK
STEALTH_MODE=$STEALTH_MODE
AUTO_BACKUP_RULES=$AUTO_BACKUP_RULES
NOTIFICATION_LEVEL=$NOTIFICATION_LEVEL
DEFAULT_PROFILE=$DEFAULT_PROFILE
EOF
            echo -e "${GREEN}✓${NC} Settings saved"
            ;;
    esac
}

# Main menu
main_menu() {
    echo -e "${PURPLE}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                 ${WHITE}BluejayLinux Firewall Manager${PURPLE}                   ║${NC}"
    echo -e "${PURPLE}║                ${CYAN}Advanced Security & Network Protection${PURPLE}           ║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    local backends=($(detect_firewall_backend))
    local status_info=$(get_firewall_status)
    local status=$(echo "$status_info" | cut -d'|' -f1)
    local backend=$(echo "$status_info" | cut -d'|' -f2)
    local rules_count=$(echo "$status_info" | cut -d'|' -f3)
    
    echo -e "${WHITE}Available backends:${NC} ${backends[*]}"
    echo -e "${WHITE}Current status:${NC} $status ($backend, $rules_count rules)"
    echo
    
    echo -e "${WHITE}1.${NC} Show firewall status"
    echo -e "${WHITE}2.${NC} Enable firewall"
    echo -e "${WHITE}3.${NC} Disable firewall"
    echo -e "${WHITE}4.${NC} Apply security profile"
    echo -e "${WHITE}5.${NC} Show current rules"
    echo -e "${WHITE}6.${NC} Add custom rule"
    echo -e "${WHITE}7.${NC} Remove rule"
    echo -e "${WHITE}8.${NC} Monitor activity"
    echo -e "${WHITE}9.${NC} Backup rules"
    echo -e "${WHITE}10.${NC} Settings"
    echo -e "${WHITE}q.${NC} Quit"
    echo
}

# Main function
main() {
    create_directories
    load_settings
    
    if [ $# -gt 0 ]; then
        case "$1" in
            --enable|-e)
                enable_firewall
                ;;
            --disable|-d)
                disable_firewall
                ;;
            --status|-s)
                local status_info=$(get_firewall_status)
                echo "Status: $(echo "$status_info" | cut -d'|' -f1)"
                echo "Backend: $(echo "$status_info" | cut -d'|' -f2)"
                echo "Rules: $(echo "$status_info" | cut -d'|' -f3)"
                ;;
            --profile|-p)
                apply_security_profile "$2"
                ;;
            --list|-l)
                show_firewall_rules
                ;;
            --backup|-b)
                backup_rules
                ;;
            --help|-h)
                echo "BluejayLinux Firewall Manager"
                echo "Usage: $0 [options] [parameters]"
                echo "  --enable, -e              Enable firewall"
                echo "  --disable, -d             Disable firewall"
                echo "  --status, -s              Show firewall status"
                echo "  --profile, -p <name>      Apply security profile"
                echo "  --list, -l                List current rules"
                echo "  --backup, -b              Backup current rules"
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
                local status_info=$(get_firewall_status)
                echo -e "\n${BLUE}Firewall Status:${NC}"
                echo -e "${CYAN}Status: $(echo "$status_info" | cut -d'|' -f1)${NC}"
                echo -e "${CYAN}Backend: $(echo "$status_info" | cut -d'|' -f2)${NC}"
                echo -e "${CYAN}Rules Count: $(echo "$status_info" | cut -d'|' -f3)${NC}"
                ;;
            2)
                enable_firewall
                ;;
            3)
                disable_firewall
                ;;
            4)
                list_profiles
                echo -ne "\n${CYAN}Enter profile name:${NC} "
                read -r profile_name
                if [ -n "$profile_name" ]; then
                    apply_security_profile "$profile_name"
                fi
                ;;
            5)
                show_firewall_rules
                ;;
            6)
                add_custom_rule
                ;;
            7)
                remove_rule
                ;;
            8)
                monitor_firewall
                ;;
            9)
                backup_rules
                ;;
            10)
                settings_menu
                ;;
            q|Q)
                echo -e "${GREEN}Firewall Manager configuration saved${NC}"
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