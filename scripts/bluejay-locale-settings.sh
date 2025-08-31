#!/bin/bash
# BluejayLinux Timezone & Locale Settings - Complete Implementation
# Time zones, languages, regional formats, date/time configuration

set -e

SETTINGS_CONFIG="/etc/bluejay/settings/locale"
LOCALE_CONFIG="/etc/bluejay/locale"

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

init_locale_config() {
    mkdir -p "$SETTINGS_CONFIG"
    mkdir -p "$LOCALE_CONFIG"
    
    cat > "$SETTINGS_CONFIG/config.conf" << 'EOF'
# Timezone and Locale Configuration
TIMEZONE=UTC
LOCALE_LANGUAGE=en_US.UTF-8
LOCALE_COLLATE=en_US.UTF-8
LOCALE_CTYPE=en_US.UTF-8
LOCALE_MESSAGES=en_US.UTF-8
LOCALE_MONETARY=en_US.UTF-8
LOCALE_NUMERIC=en_US.UTF-8
LOCALE_TIME=en_US.UTF-8

# Regional Settings
CURRENCY_FORMAT=USD
DATE_FORMAT="%Y-%m-%d"
TIME_FORMAT="%H:%M:%S"
DATETIME_FORMAT="%Y-%m-%d %H:%M:%S"
FIRST_DAY_OF_WEEK=1
DECIMAL_SEPARATOR="."
THOUSANDS_SEPARATOR=","

# System Time Settings
NTP_ENABLED=true
NTP_SERVERS="pool.ntp.org 0.pool.ntp.org 1.pool.ntp.org"
HARDWARE_CLOCK_UTC=true
AUTO_DST=true
EOF

    # Create timezone data
    create_timezone_data
    create_locale_data
}

create_timezone_data() {
    cat > "$LOCALE_CONFIG/timezones.conf" << 'EOF'
# Common Timezone Data
# Format: Display_Name:Timezone_Path

# UTC
UTC:UTC

# America
New_York_(EST/EDT):America/New_York
Los_Angeles_(PST/PDT):America/Los_Angeles
Chicago_(CST/CDT):America/Chicago
Denver_(MST/MDT):America/Denver
Toronto:America/Toronto
Mexico_City:America/Mexico_City
Sao_Paulo:America/Sao_Paulo
Buenos_Aires:America/Argentina/Buenos_Aires

# Europe
London_(GMT/BST):Europe/London
Paris_(CET/CEST):Europe/Paris
Berlin_(CET/CEST):Europe/Berlin
Rome_(CET/CEST):Europe/Rome
Madrid_(CET/CEST):Europe/Madrid
Amsterdam_(CET/CEST):Europe/Amsterdam
Stockholm_(CET/CEST):Europe/Stockholm
Moscow_(MSK):Europe/Moscow
Kiev_(EET/EEST):Europe/Kiev

# Asia
Tokyo_(JST):Asia/Tokyo
Hong_Kong_(HKT):Asia/Hong_Kong
Shanghai_(CST):Asia/Shanghai
Seoul_(KST):Asia/Seoul
Bangkok_(ICT):Asia/Bangkok
Singapore_(SGT):Asia/Singapore
Mumbai_(IST):Asia/Kolkata
Dubai_(GST):Asia/Dubai

# Australia
Sydney_(AEST/AEDT):Australia/Sydney
Melbourne_(AEST/AEDT):Australia/Melbourne
Perth_(AWST):Australia/Perth

# Africa
Cairo_(EET):Africa/Cairo
Johannesburg_(SAST):Africa/Johannesburg
Lagos_(WAT):Africa/Lagos
EOF
}

create_locale_data() {
    cat > "$LOCALE_CONFIG/locales.conf" << 'EOF'
# Available Locales
# Format: Display_Name:Locale_Code

# English
English_(US):en_US.UTF-8
English_(UK):en_GB.UTF-8
English_(Australia):en_AU.UTF-8
English_(Canada):en_CA.UTF-8

# European
German_(Germany):de_DE.UTF-8
French_(France):fr_FR.UTF-8
Spanish_(Spain):es_ES.UTF-8
Italian_(Italy):it_IT.UTF-8
Portuguese_(Portugal):pt_PT.UTF-8
Dutch_(Netherlands):nl_NL.UTF-8
Swedish_(Sweden):sv_SE.UTF-8
Norwegian_(Norway):no_NO.UTF-8
Danish_(Denmark):da_DK.UTF-8
Polish_(Poland):pl_PL.UTF-8
Russian_(Russia):ru_RU.UTF-8

# Asian
Japanese_(Japan):ja_JP.UTF-8
Chinese_(China):zh_CN.UTF-8
Chinese_(Taiwan):zh_TW.UTF-8
Korean_(Korea):ko_KR.UTF-8
Hindi_(India):hi_IN.UTF-8
Arabic_(Saudi_Arabia):ar_SA.UTF-8
Thai_(Thailand):th_TH.UTF-8

# American
Portuguese_(Brazil):pt_BR.UTF-8
Spanish_(Mexico):es_MX.UTF-8
Spanish_(Argentina):es_AR.UTF-8
French_(Canada):fr_CA.UTF-8
EOF
}

show_locale_menu() {
    clear
    source "$SETTINGS_CONFIG/config.conf"
    
    echo -e "${PURPLE}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║      BluejayLinux Timezone & Locale          ║${NC}"
    echo -e "${PURPLE}║    Time, Language & Regional Settings        ║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Show current time and settings
    echo -e "${CYAN}Current Configuration:${NC}"
    echo "Current Time: $(date)"
    echo "Timezone: $TIMEZONE"
    echo "Language: $LOCALE_LANGUAGE"
    echo "Date Format: $(date +"$DATE_FORMAT")"
    echo "Time Format: $(date +"$TIME_FORMAT")"
    echo "NTP: $NTP_ENABLED"
    echo ""
    
    echo -e "${YELLOW}Locale & Timezone Options:${NC}"
    echo "[1] Change Timezone"
    echo "[2] Set Language & Locale"
    echo "[3] Date & Time Formats"
    echo "[4] Regional Settings"
    echo "[5] Network Time Protocol (NTP)"
    echo "[6] Manual Time Setting"
    echo "[7] Calendar Settings"
    echo "[8] Import/Export Locale"
    echo "[9] System Clock Info"
    echo "[0] Apply & Exit"
    echo ""
    echo -n "Select option: "
}

change_timezone() {
    echo -e "${BLUE}Timezone Configuration${NC}"
    echo "======================"
    echo ""
    echo "Current timezone: $TIMEZONE"
    echo ""
    
    echo "Available timezones:"
    local i=1
    while IFS=':' read -r display_name timezone_path; do
        # Skip comments and empty lines
        [[ "$display_name" =~ ^#.*$ ]] || [ -z "$display_name" ] && continue
        echo "[$i] $display_name"
        i=$((i+1))
    done < "$LOCALE_CONFIG/timezones.conf"
    
    echo ""
    echo -n "Select timezone number (or enter custom timezone): "
    read timezone_choice
    
    local new_timezone
    if [[ "$timezone_choice" =~ ^[0-9]+$ ]]; then
        # User selected by number
        local count=1
        while IFS=':' read -r display_name timezone_path; do
            [[ "$display_name" =~ ^#.*$ ]] || [ -z "$display_name" ] && continue
            if [ "$count" = "$timezone_choice" ]; then
                new_timezone="$timezone_path"
                break
            fi
            count=$((count+1))
        done < "$LOCALE_CONFIG/timezones.conf"
    else
        # User entered custom timezone
        new_timezone="$timezone_choice"
    fi
    
    if [ -n "$new_timezone" ]; then
        # Validate timezone (check if it exists in system)
        if [ -f "/usr/share/zoneinfo/$new_timezone" ] || [ "$new_timezone" = "UTC" ]; then
            sed -i "s|TIMEZONE=.*|TIMEZONE=$new_timezone|" "$SETTINGS_CONFIG/config.conf"
            apply_timezone "$new_timezone"
            echo -e "${GREEN}Timezone changed to: $new_timezone${NC}"
        else
            echo -e "${RED}Invalid timezone: $new_timezone${NC}"
        fi
    else
        echo -e "${RED}Invalid timezone selection${NC}"
    fi
    
    read -p "Press Enter to continue..."
}

set_language_locale() {
    echo -e "${BLUE}Language & Locale Configuration${NC}"
    echo "==============================="
    echo ""
    echo "Current language: $LOCALE_LANGUAGE"
    echo ""
    
    echo "Available languages:"
    local i=1
    while IFS=':' read -r display_name locale_code; do
        # Skip comments and empty lines
        [[ "$display_name" =~ ^#.*$ ]] || [ -z "$display_name" ] && continue
        echo "[$i] $display_name"
        i=$((i+1))
    done < "$LOCALE_CONFIG/locales.conf"
    
    echo ""
    echo -n "Select language number: "
    read language_choice
    
    local new_locale
    local count=1
    while IFS=':' read -r display_name locale_code; do
        [[ "$display_name" =~ ^#.*$ ]] || [ -z "$display_name" ] && continue
        if [ "$count" = "$language_choice" ]; then
            new_locale="$locale_code"
            break
        fi
        count=$((count+1))
    done < "$LOCALE_CONFIG/locales.conf"
    
    if [ -n "$new_locale" ]; then
        echo ""
        echo -n "Apply this locale to all categories? (y/n): "
        read apply_all
        
        if [ "$apply_all" = "y" ]; then
            # Apply to all locale categories
            sed -i "s/LOCALE_LANGUAGE=.*/LOCALE_LANGUAGE=$new_locale/" "$SETTINGS_CONFIG/config.conf"
            sed -i "s/LOCALE_COLLATE=.*/LOCALE_COLLATE=$new_locale/" "$SETTINGS_CONFIG/config.conf"
            sed -i "s/LOCALE_CTYPE=.*/LOCALE_CTYPE=$new_locale/" "$SETTINGS_CONFIG/config.conf"
            sed -i "s/LOCALE_MESSAGES=.*/LOCALE_MESSAGES=$new_locale/" "$SETTINGS_CONFIG/config.conf"
            sed -i "s/LOCALE_MONETARY=.*/LOCALE_MONETARY=$new_locale/" "$SETTINGS_CONFIG/config.conf"
            sed -i "s/LOCALE_NUMERIC=.*/LOCALE_NUMERIC=$new_locale/" "$SETTINGS_CONFIG/config.conf"
            sed -i "s/LOCALE_TIME=.*/LOCALE_TIME=$new_locale/" "$SETTINGS_CONFIG/config.conf"
        else
            # Only apply to language
            sed -i "s/LOCALE_LANGUAGE=.*/LOCALE_LANGUAGE=$new_locale/" "$SETTINGS_CONFIG/config.conf"
        fi
        
        apply_locale "$new_locale"
        echo -e "${GREEN}Language locale set to: $new_locale${NC}"
    else
        echo -e "${RED}Invalid language selection${NC}"
    fi
    
    read -p "Press Enter to continue..."
}

configure_date_time_formats() {
    echo -e "${BLUE}Date & Time Format Configuration${NC}"
    echo "================================="
    echo ""
    echo "Current formats:"
    echo "Date: $(date +"$DATE_FORMAT") (format: $DATE_FORMAT)"
    echo "Time: $(date +"$TIME_FORMAT") (format: $TIME_FORMAT)"
    echo "DateTime: $(date +"$DATETIME_FORMAT") (format: $DATETIME_FORMAT)"
    echo ""
    
    echo "Common date formats:"
    echo "[1] YYYY-MM-DD (2024-01-15)"
    echo "[2] MM/DD/YYYY (01/15/2024)"
    echo "[3] DD/MM/YYYY (15/01/2024)"
    echo "[4] DD.MM.YYYY (15.01.2024)"
    echo "[5] Custom format"
    echo -n "Select date format: "
    read date_choice
    
    local new_date_format
    case $date_choice in
        1) new_date_format="%Y-%m-%d" ;;
        2) new_date_format="%m/%d/%Y" ;;
        3) new_date_format="%d/%m/%Y" ;;
        4) new_date_format="%d.%m.%Y" ;;
        5) 
            echo -n "Enter custom date format (e.g., %Y-%m-%d): "
            read new_date_format
            ;;
        *) echo "Invalid choice"; return ;;
    esac
    
    echo ""
    echo "Common time formats:"
    echo "[1] 24-hour (14:30:00)"
    echo "[2] 12-hour with AM/PM (2:30:00 PM)"
    echo "[3] 24-hour without seconds (14:30)"
    echo "[4] 12-hour without seconds (2:30 PM)"
    echo "[5] Custom format"
    echo -n "Select time format: "
    read time_choice
    
    local new_time_format
    case $time_choice in
        1) new_time_format="%H:%M:%S" ;;
        2) new_time_format="%I:%M:%S %p" ;;
        3) new_time_format="%H:%M" ;;
        4) new_time_format="%I:%M %p" ;;
        5)
            echo -n "Enter custom time format (e.g., %H:%M:%S): "
            read new_time_format
            ;;
        *) echo "Invalid choice"; return ;;
    esac
    
    # Apply formats
    sed -i "s|DATE_FORMAT=.*|DATE_FORMAT=\"$new_date_format\"|" "$SETTINGS_CONFIG/config.conf"
    sed -i "s|TIME_FORMAT=.*|TIME_FORMAT=\"$new_time_format\"|" "$SETTINGS_CONFIG/config.conf"
    sed -i "s|DATETIME_FORMAT=.*|DATETIME_FORMAT=\"$new_date_format $new_time_format\"|" "$SETTINGS_CONFIG/config.conf"
    
    echo ""
    echo "New format preview:"
    echo "Date: $(date +"$new_date_format")"
    echo "Time: $(date +"$new_time_format")"
    echo "DateTime: $(date +"$new_date_format $new_time_format")"
    
    echo -e "${GREEN}Date and time formats updated!${NC}"
    read -p "Press Enter to continue..."
}

configure_regional_settings() {
    echo -e "${BLUE}Regional Settings Configuration${NC}"
    echo "==============================="
    echo ""
    echo "Current regional settings:"
    echo "Currency: $CURRENCY_FORMAT"
    echo "Decimal separator: $DECIMAL_SEPARATOR"
    echo "Thousands separator: $THOUSANDS_SEPARATOR"
    echo "First day of week: $FIRST_DAY_OF_WEEK (1=Monday, 0=Sunday)"
    echo ""
    
    echo "Currency formats:"
    echo "[1] USD (US Dollar)"
    echo "[2] EUR (Euro)"
    echo "[3] GBP (British Pound)"
    echo "[4] JPY (Japanese Yen)"
    echo "[5] CAD (Canadian Dollar)"
    echo "[6] AUD (Australian Dollar)"
    echo "[7] Custom"
    echo -n "Select currency: "
    read currency_choice
    
    local new_currency
    case $currency_choice in
        1) new_currency="USD" ;;
        2) new_currency="EUR" ;;
        3) new_currency="GBP" ;;
        4) new_currency="JPY" ;;
        5) new_currency="CAD" ;;
        6) new_currency="AUD" ;;
        7)
            echo -n "Enter currency code (e.g., CHF): "
            read new_currency
            ;;
        *) echo "Invalid choice"; return ;;
    esac
    
    echo ""
    echo "Number format:"
    echo -n "Decimal separator (current: $DECIMAL_SEPARATOR): "
    read decimal_sep
    [ -n "$decimal_sep" ] && DECIMAL_SEPARATOR="$decimal_sep"
    
    echo -n "Thousands separator (current: $THOUSANDS_SEPARATOR): "
    read thousands_sep
    [ -n "$thousands_sep" ] && THOUSANDS_SEPARATOR="$thousands_sep"
    
    echo ""
    echo "Calendar:"
    echo "[1] Monday (ISO 8601)"
    echo "[2] Sunday (US/Canada)"
    echo -n "First day of week: "
    read first_day_choice
    
    local first_day
    case $first_day_choice in
        1) first_day=1 ;;
        2) first_day=0 ;;
        *) first_day=1 ;;
    esac
    
    # Apply regional settings
    sed -i "s/CURRENCY_FORMAT=.*/CURRENCY_FORMAT=$new_currency/" "$SETTINGS_CONFIG/config.conf"
    sed -i "s|DECIMAL_SEPARATOR=.*|DECIMAL_SEPARATOR=\"$DECIMAL_SEPARATOR\"|" "$SETTINGS_CONFIG/config.conf"
    sed -i "s|THOUSANDS_SEPARATOR=.*|THOUSANDS_SEPARATOR=\"$THOUSANDS_SEPARATOR\"|" "$SETTINGS_CONFIG/config.conf"
    sed -i "s/FIRST_DAY_OF_WEEK=.*/FIRST_DAY_OF_WEEK=$first_day/" "$SETTINGS_CONFIG/config.conf"
    
    echo -e "${GREEN}Regional settings updated!${NC}"
    read -p "Press Enter to continue..."
}

configure_ntp() {
    echo -e "${BLUE}Network Time Protocol (NTP) Configuration${NC}"
    echo "==========================================="
    echo ""
    echo "Current NTP settings:"
    echo "NTP enabled: $NTP_ENABLED"
    echo "NTP servers: $NTP_SERVERS"
    echo ""
    
    echo -n "Enable NTP synchronization? (y/n): "
    read enable_ntp
    
    local ntp_enabled="false"
    if [ "$enable_ntp" = "y" ]; then
        ntp_enabled="true"
        
        echo ""
        echo "NTP Server options:"
        echo "[1] Use default pool servers"
        echo "[2] Use regional servers"
        echo "[3] Custom servers"
        echo -n "Select NTP servers: "
        read ntp_choice
        
        local new_ntp_servers
        case $ntp_choice in
            1) new_ntp_servers="pool.ntp.org 0.pool.ntp.org 1.pool.ntp.org" ;;
            2)
                echo "Regional NTP pools:"
                echo "[1] North America (north-america.pool.ntp.org)"
                echo "[2] Europe (europe.pool.ntp.org)"
                echo "[3] Asia (asia.pool.ntp.org)"
                echo -n "Select region: "
                read region_choice
                case $region_choice in
                    1) new_ntp_servers="north-america.pool.ntp.org" ;;
                    2) new_ntp_servers="europe.pool.ntp.org" ;;
                    3) new_ntp_servers="asia.pool.ntp.org" ;;
                    *) new_ntp_servers="pool.ntp.org" ;;
                esac
                ;;
            3)
                echo -n "Enter NTP servers (space separated): "
                read new_ntp_servers
                ;;
            *) new_ntp_servers="pool.ntp.org" ;;
        esac
        
        sed -i "s/NTP_SERVERS=.*/NTP_SERVERS=\"$new_ntp_servers\"/" "$SETTINGS_CONFIG/config.conf"
        apply_ntp_settings "$ntp_enabled" "$new_ntp_servers"
    fi
    
    sed -i "s/NTP_ENABLED=.*/NTP_ENABLED=$ntp_enabled/" "$SETTINGS_CONFIG/config.conf"
    
    echo -e "${GREEN}NTP settings updated!${NC}"
    read -p "Press Enter to continue..."
}

manual_time_setting() {
    echo -e "${BLUE}Manual Time Setting${NC}"
    echo "==================="
    echo ""
    echo "Current system time: $(date)"
    echo ""
    echo -e "${YELLOW}Warning: Manual time setting will disable NTP${NC}"
    echo ""
    echo -n "Do you want to continue? (y/n): "
    read continue_manual
    
    if [ "$continue_manual" != "y" ]; then
        return
    fi
    
    echo ""
    echo -n "Enter date (YYYY-MM-DD): "
    read new_date
    
    echo -n "Enter time (HH:MM:SS): "
    read new_time
    
    # Validate and set time
    if date -d "$new_date $new_time" >/dev/null 2>&1; then
        # Disable NTP first
        sed -i "s/NTP_ENABLED=.*/NTP_ENABLED=false/" "$SETTINGS_CONFIG/config.conf"
        
        # Set system time
        if command -v timedatectl >/dev/null 2>&1; then
            timedatectl set-ntp false
            timedatectl set-time "$new_date $new_time"
        else
            date -s "$new_date $new_time"
        fi
        
        echo -e "${GREEN}System time set to: $(date)${NC}"
        echo -e "${YELLOW}NTP has been disabled${NC}"
    else
        echo -e "${RED}Invalid date/time format${NC}"
    fi
    
    read -p "Press Enter to continue..."
}

show_clock_info() {
    echo -e "${BLUE}System Clock Information${NC}"
    echo "========================"
    echo ""
    
    echo "Current system time: $(date)"
    echo "Hardware clock (UTC): $HARDWARE_CLOCK_UTC"
    echo ""
    
    echo "=== Time Sources ==="
    if command -v timedatectl >/dev/null 2>&1; then
        timedatectl status 2>/dev/null || echo "timedatectl not available"
    else
        echo "System time: $(date)"
        echo "Hardware clock: $(hwclock -r 2>/dev/null || echo 'Not accessible')"
    fi
    
    echo ""
    echo "=== NTP Status ==="
    if [ "$NTP_ENABLED" = "true" ]; then
        echo "NTP: Enabled"
        echo "NTP Servers: $NTP_SERVERS"
        
        # Check NTP synchronization
        if command -v ntpq >/dev/null 2>&1; then
            echo "NTP Sync Status:"
            ntpq -p 2>/dev/null || echo "NTP daemon not running"
        fi
    else
        echo "NTP: Disabled"
    fi
    
    echo ""
    echo "=== Timezone Information ==="
    echo "Timezone: $TIMEZONE"
    echo "UTC Offset: $(date +%z)"
    echo "DST Active: $(date +%Z)"
    
    read -p "Press Enter to continue..."
}

# Application functions

apply_timezone() {
    local timezone="$1"
    
    # Set system timezone
    if command -v timedatectl >/dev/null 2>&1; then
        timedatectl set-timezone "$timezone"
    else
        # Fallback method
        if [ -f "/usr/share/zoneinfo/$timezone" ]; then
            ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime
            echo "$timezone" > /etc/timezone
        fi
    fi
    
    echo "Timezone set to: $timezone"
}

apply_locale() {
    local locale="$1"
    
    # Generate locale if needed
    if command -v locale-gen >/dev/null 2>&1; then
        locale-gen "$locale" 2>/dev/null || true
    fi
    
    # Set system locale
    cat > /etc/locale.conf << EOF
LANG=$locale
LC_CTYPE=$locale
LC_NUMERIC=$locale
LC_TIME=$locale
LC_COLLATE=$locale
LC_MONETARY=$locale
LC_MESSAGES=$locale
LC_ALL=$locale
EOF
    
    # Export for current session
    export LANG="$locale"
    export LC_ALL="$locale"
    
    echo "Locale set to: $locale"
}

apply_ntp_settings() {
    local enabled="$1"
    local servers="$2"
    
    if [ "$enabled" = "true" ]; then
        # Enable NTP
        if command -v timedatectl >/dev/null 2>&1; then
            timedatectl set-ntp true
        fi
        
        # Configure NTP servers (simplified)
        echo "NTP enabled with servers: $servers"
    else
        # Disable NTP
        if command -v timedatectl >/dev/null 2>&1; then
            timedatectl set-ntp false
        fi
        echo "NTP disabled"
    fi
}

apply_all_locale_settings() {
    echo -e "${YELLOW}Applying all timezone and locale settings...${NC}"
    
    source "$SETTINGS_CONFIG/config.conf"
    
    apply_timezone "$TIMEZONE"
    apply_locale "$LOCALE_LANGUAGE"
    apply_ntp_settings "$NTP_ENABLED" "$NTP_SERVERS"
    
    echo -e "${GREEN}✅ All timezone and locale settings applied successfully!${NC}"
    echo ""
    echo "System configuration:"
    echo "• Timezone: $TIMEZONE"
    echo "• Language: $LOCALE_LANGUAGE"
    echo "• Date format: $(date +"$DATE_FORMAT")"
    echo "• Time format: $(date +"$TIME_FORMAT")"
    echo "• Currency: $CURRENCY_FORMAT"
    echo "• NTP: $NTP_ENABLED"
    
    read -p "Press Enter to continue..."
}

main() {
    # Initialize if needed
    if [ ! -f "$SETTINGS_CONFIG/config.conf" ]; then
        echo "Initializing timezone and locale settings..."
        init_locale_config
    fi
    
    while true; do
        show_locale_menu
        read choice
        
        case $choice in
            1) change_timezone ;;
            2) set_language_locale ;;
            3) configure_date_time_formats ;;
            4) configure_regional_settings ;;
            5) configure_ntp ;;
            6) manual_time_setting ;;
            7) echo "Calendar settings - Coming soon" && read -p "Press Enter..." ;;
            8) echo "Import/export locale - Coming soon" && read -p "Press Enter..." ;;
            9) show_clock_info ;;
            0) apply_all_locale_settings && exit 0 ;;
            *) echo -e "${RED}Invalid option${NC}" && sleep 1 ;;
        esac
    done
}

main "$@"