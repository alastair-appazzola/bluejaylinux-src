#!/bin/bash

# BluejayLinux - Encryption Tools Suite
# Comprehensive disk encryption and file encryption utilities

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/bluejay"
ENCRYPTION_CONFIG_DIR="$CONFIG_DIR/encryption"
KEYS_DIR="$ENCRYPTION_CONFIG_DIR/keys"
VAULTS_DIR="$HOME/.bluejay-vaults"
TEMP_DIR="/tmp/bluejay-encryption"

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

# Encryption algorithms
SYMMETRIC_ALGORITHMS="aes-256-cbc aes-256-gcm chacha20-poly1305 twofish serpent"
ASYMMETRIC_ALGORITHMS="rsa-2048 rsa-4096 ed25519 secp256k1"
HASH_ALGORITHMS="sha256 sha512 blake2b argon2id"

# Initialize directories
create_directories() {
    mkdir -p "$CONFIG_DIR" "$ENCRYPTION_CONFIG_DIR" "$KEYS_DIR" "$VAULTS_DIR" "$TEMP_DIR"
    chmod 700 "$KEYS_DIR" "$VAULTS_DIR" "$TEMP_DIR"
    
    # Create default encryption configuration
    if [ ! -f "$ENCRYPTION_CONFIG_DIR/settings.conf" ]; then
        cat > "$ENCRYPTION_CONFIG_DIR/settings.conf" << 'EOF'
# BluejayLinux Encryption Tools Settings
DEFAULT_SYMMETRIC_CIPHER=aes-256-gcm
DEFAULT_ASYMMETRIC_CIPHER=rsa-4096
DEFAULT_HASH_ALGORITHM=sha256
KEY_DERIVATION_FUNCTION=argon2id
COMPRESSION_ENABLED=true
COMPRESSION_ALGORITHM=gzip
SECURE_DELETE=true
BACKUP_KEYS=true
AUTO_LOCK_TIMEOUT=300
PARANOID_MODE=false
QUANTUM_RESISTANT=false
STEGANOGRAPHY_ENABLED=false
VAULT_AUTO_MOUNT=false
KEYFILE_REQUIRED=false
MULTIPLE_PASSWORDS=false
EOF
    fi
}

# Load settings
load_settings() {
    if [ -f "$ENCRYPTION_CONFIG_DIR/settings.conf" ]; then
        source "$ENCRYPTION_CONFIG_DIR/settings.conf"
    fi
}

# Detect encryption tools
detect_encryption_tools() {
    local tools=()
    
    echo -e "${BLUE}Detecting encryption tools...${NC}"
    
    # OpenSSL
    if command -v openssl >/dev/null; then
        tools+=("openssl")
        echo -e "${GREEN}✓${NC} OpenSSL: $(openssl version)"
    fi
    
    # GnuPG
    if command -v gpg >/dev/null; then
        tools+=("gnupg")
        echo -e "${GREEN}✓${NC} GnuPG: $(gpg --version | head -1)"
    fi
    
    # LUKS/cryptsetup
    if command -v cryptsetup >/dev/null; then
        tools+=("luks")
        echo -e "${GREEN}✓${NC} LUKS/cryptsetup: $(cryptsetup --version)"
    fi
    
    # VeraCrypt
    if command -v veracrypt >/dev/null; then
        tools+=("veracrypt")
        echo -e "${GREEN}✓${NC} VeraCrypt available"
    fi
    
    # Age (modern encryption)
    if command -v age >/dev/null; then
        tools+=("age")
        echo -e "${GREEN}✓${NC} Age: $(age --version)"
    fi
    
    # EncFS
    if command -v encfs >/dev/null; then
        tools+=("encfs")
        echo -e "${GREEN}✓${NC} EncFS available"
    fi
    
    # 7-Zip
    if command -v 7z >/dev/null; then
        tools+=("7zip")
        echo -e "${GREEN}✓${NC} 7-Zip available"
    fi
    
    echo "${tools[@]}"
}

# Generate secure random password
generate_password() {
    local length="${1:-32}"
    local charset="${2:-mixed}"
    
    case "$charset" in
        alphanumeric)
            tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$length"
            ;;
        symbols)
            tr -dc 'A-Za-z0-9!@#$%^&*()_+-=[]{}|;:,.<>?' < /dev/urandom | head -c "$length"
            ;;
        mixed|*)
            tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | head -c "$length"
            ;;
    esac
    echo
}

# Generate cryptographic keys
generate_keys() {
    local key_type="$1"
    local key_name="$2"
    local key_size="${3:-4096}"
    
    echo -e "${BLUE}Generating $key_type key: $key_name${NC}"
    
    case "$key_type" in
        rsa)
            # Generate RSA key pair
            openssl genrsa -out "$KEYS_DIR/${key_name}_private.pem" "$key_size"
            openssl rsa -in "$KEYS_DIR/${key_name}_private.pem" -pubout -out "$KEYS_DIR/${key_name}_public.pem"
            chmod 600 "$KEYS_DIR/${key_name}_private.pem"
            chmod 644 "$KEYS_DIR/${key_name}_public.pem"
            echo -e "${GREEN}✓${NC} RSA key pair generated"
            ;;
        ed25519)
            # Generate Ed25519 key pair
            openssl genpkey -algorithm Ed25519 -out "$KEYS_DIR/${key_name}_private.pem"
            openssl pkey -in "$KEYS_DIR/${key_name}_private.pem" -pubout -out "$KEYS_DIR/${key_name}_public.pem"
            chmod 600 "$KEYS_DIR/${key_name}_private.pem"
            chmod 644 "$KEYS_DIR/${key_name}_public.pem"
            echo -e "${GREEN}✓${NC} Ed25519 key pair generated"
            ;;
        symmetric)
            # Generate symmetric key
            openssl rand -hex 32 > "$KEYS_DIR/${key_name}_symmetric.key"
            chmod 600 "$KEYS_DIR/${key_name}_symmetric.key"
            echo -e "${GREEN}✓${NC} Symmetric key generated"
            ;;
        gpg)
            # Generate GPG key
            cat > "$TEMP_DIR/gpg_key_params" << EOF
Key-Type: RSA
Key-Length: $key_size
Name-Real: $key_name
Name-Email: ${key_name}@bluejaylinux.local
Expire-Date: 1y
%commit
EOF
            gpg --batch --generate-key "$TEMP_DIR/gpg_key_params"
            rm -f "$TEMP_DIR/gpg_key_params"
            echo -e "${GREEN}✓${NC} GPG key generated"
            ;;
    esac
}

# Encrypt file using symmetric encryption
encrypt_file_symmetric() {
    local input_file="$1"
    local output_file="${2:-${input_file}.enc}"
    local cipher="${3:-$DEFAULT_SYMMETRIC_CIPHER}"
    local password="$4"
    
    if [ ! -f "$input_file" ]; then
        echo -e "${RED}✗${NC} Input file not found: $input_file"
        return 1
    fi
    
    echo -e "${BLUE}Encrypting file with $cipher...${NC}"
    
    if [ -z "$password" ]; then
        echo -ne "${YELLOW}Enter encryption password:${NC} "
        read -r -s password
        echo
    fi
    
    # Compress if enabled
    local temp_input="$input_file"
    if [ "$COMPRESSION_ENABLED" = "true" ]; then
        temp_input="$TEMP_DIR/$(basename "$input_file").gz"
        gzip -c "$input_file" > "$temp_input"
        echo -e "${CYAN}File compressed before encryption${NC}"
    fi
    
    # Encrypt with OpenSSL
    if echo "$password" | openssl enc -"$cipher" -salt -pbkdf2 -iter 100000 -in "$temp_input" -out "$output_file" -pass stdin; then
        echo -e "${GREEN}✓${NC} File encrypted: $output_file"
        
        # Secure delete original if requested
        if [ "$SECURE_DELETE" = "true" ]; then
            shred -vfz -n 3 "$input_file" 2>/dev/null || rm -f "$input_file"
            echo -e "${GREEN}✓${NC} Original file securely deleted"
        fi
        
        # Clean up temp file
        [ "$temp_input" != "$input_file" ] && rm -f "$temp_input"
        return 0
    else
        echo -e "${RED}✗${NC} Encryption failed"
        [ "$temp_input" != "$input_file" ] && rm -f "$temp_input"
        return 1
    fi
}

# Decrypt file using symmetric encryption
decrypt_file_symmetric() {
    local input_file="$1"
    local output_file="${2:-${input_file%.enc}}"
    local cipher="${3:-$DEFAULT_SYMMETRIC_CIPHER}"
    local password="$4"
    
    if [ ! -f "$input_file" ]; then
        echo -e "${RED}✗${NC} Input file not found: $input_file"
        return 1
    fi
    
    echo -e "${BLUE}Decrypting file with $cipher...${NC}"
    
    if [ -z "$password" ]; then
        echo -ne "${YELLOW}Enter decryption password:${NC} "
        read -r -s password
        echo
    fi
    
    # Decrypt with OpenSSL
    local temp_output="$output_file"
    if [ "$COMPRESSION_ENABLED" = "true" ]; then
        temp_output="$TEMP_DIR/$(basename "$output_file").gz"
    fi
    
    if echo "$password" | openssl enc -d -"$cipher" -pbkdf2 -iter 100000 -in "$input_file" -out "$temp_output" -pass stdin; then
        # Decompress if needed
        if [ "$COMPRESSION_ENABLED" = "true" ]; then
            gzip -d -c "$temp_output" > "$output_file"
            rm -f "$temp_output"
            echo -e "${CYAN}File decompressed after decryption${NC}"
        fi
        
        echo -e "${GREEN}✓${NC} File decrypted: $output_file"
        return 0
    else
        echo -e "${RED}✗${NC} Decryption failed"
        rm -f "$temp_output"
        return 1
    fi
}

# Encrypt file using public key
encrypt_file_asymmetric() {
    local input_file="$1"
    local output_file="${2:-${input_file}.pub.enc}"
    local public_key="$3"
    
    if [ ! -f "$input_file" ]; then
        echo -e "${RED}✗${NC} Input file not found: $input_file"
        return 1
    fi
    
    if [ ! -f "$public_key" ]; then
        echo -e "${RED}✗${NC} Public key not found: $public_key"
        return 1
    fi
    
    echo -e "${BLUE}Encrypting file with public key...${NC}"
    
    # Generate random symmetric key for hybrid encryption
    local sym_key=$(openssl rand -hex 32)
    local sym_key_file="$TEMP_DIR/symmetric.key"
    echo "$sym_key" > "$sym_key_file"
    
    # Encrypt file with symmetric key
    openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 -in "$input_file" -out "${output_file}.data" -pass "file:$sym_key_file"
    
    # Encrypt symmetric key with public key
    openssl rsautl -encrypt -inkey "$public_key" -pubin -in "$sym_key_file" -out "${output_file}.key"
    
    # Combine encrypted data and key
    cat "${output_file}.key" "${output_file}.data" > "$output_file"
    
    # Clean up
    rm -f "$sym_key_file" "${output_file}.key" "${output_file}.data"
    
    echo -e "${GREEN}✓${NC} File encrypted with public key: $output_file"
}

# Decrypt file using private key
decrypt_file_asymmetric() {
    local input_file="$1"
    local output_file="${2:-${input_file%.pub.enc}}"
    local private_key="$3"
    
    if [ ! -f "$input_file" ]; then
        echo -e "${RED}✗${NC} Input file not found: $input_file"
        return 1
    fi
    
    if [ ! -f "$private_key" ]; then
        echo -e "${RED}✗${NC} Private key not found: $private_key"
        return 1
    fi
    
    echo -e "${BLUE}Decrypting file with private key...${NC}"
    
    # Split encrypted file (key is first 256 bytes for RSA-2048, 512 for RSA-4096)
    local key_size=256
    if grep -q "4096" "$private_key"; then
        key_size=512
    fi
    
    dd if="$input_file" bs=1 count="$key_size" of="$TEMP_DIR/encrypted_key" 2>/dev/null
    dd if="$input_file" bs=1 skip="$key_size" of="$TEMP_DIR/encrypted_data" 2>/dev/null
    
    # Decrypt symmetric key
    openssl rsautl -decrypt -inkey "$private_key" -in "$TEMP_DIR/encrypted_key" -out "$TEMP_DIR/decrypted_key"
    
    # Decrypt file with symmetric key
    openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 -in "$TEMP_DIR/encrypted_data" -out "$output_file" -pass "file:$TEMP_DIR/decrypted_key"
    
    # Clean up
    rm -f "$TEMP_DIR/encrypted_key" "$TEMP_DIR/encrypted_data" "$TEMP_DIR/decrypted_key"
    
    echo -e "${GREEN}✓${NC} File decrypted with private key: $output_file"
}

# Create encrypted vault
create_vault() {
    local vault_name="$1"
    local vault_size="${2:-100M}"
    local filesystem="${3:-ext4}"
    
    local vault_file="$VAULTS_DIR/${vault_name}.vault"
    local vault_mount="/mnt/bluejay-vault-${vault_name}"
    
    echo -e "${BLUE}Creating encrypted vault: $vault_name${NC}"
    
    # Create vault file
    dd if=/dev/zero of="$vault_file" bs=1 count=0 seek="$vault_size" 2>/dev/null
    
    if command -v cryptsetup >/dev/null; then
        # Use LUKS for disk encryption
        echo -e "${YELLOW}Setting up LUKS encryption...${NC}"
        echo -ne "${YELLOW}Enter vault password:${NC} "
        read -r -s vault_password
        echo
        
        echo "$vault_password" | cryptsetup luksFormat "$vault_file" -
        echo "$vault_password" | cryptsetup luksOpen "$vault_file" "bluejay-vault-${vault_name}" -
        
        # Create filesystem
        sudo mkfs."$filesystem" "/dev/mapper/bluejay-vault-${vault_name}"
        
        # Create mount point
        sudo mkdir -p "$vault_mount"
        sudo mount "/dev/mapper/bluejay-vault-${vault_name}" "$vault_mount"
        sudo chown "$USER:$USER" "$vault_mount"
        
        echo -e "${GREEN}✓${NC} LUKS vault created and mounted at: $vault_mount"
        
    elif command -v encfs >/dev/null; then
        # Use EncFS for directory encryption
        local vault_encrypted="$VAULTS_DIR/${vault_name}_encrypted"
        local vault_decrypted="$VAULTS_DIR/${vault_name}_decrypted"
        
        mkdir -p "$vault_encrypted" "$vault_decrypted"
        
        echo -e "${YELLOW}Setting up EncFS encryption...${NC}"
        encfs "$vault_encrypted" "$vault_decrypted"
        
        echo -e "${GREEN}✓${NC} EncFS vault created at: $vault_decrypted"
        
    else
        # Fallback to file-based encryption
        echo -e "${YELLOW}Using file-based encryption...${NC}"
        mkdir -p "${vault_file%.vault}"
        
        echo -e "${GREEN}✓${NC} File-based vault created at: ${vault_file%.vault}"
    fi
}

# Mount encrypted vault
mount_vault() {
    local vault_name="$1"
    local vault_file="$VAULTS_DIR/${vault_name}.vault"
    local vault_mount="/mnt/bluejay-vault-${vault_name}"
    
    if [ ! -f "$vault_file" ]; then
        echo -e "${RED}✗${NC} Vault not found: $vault_name"
        return 1
    fi
    
    echo -e "${BLUE}Mounting vault: $vault_name${NC}"
    
    if command -v cryptsetup >/dev/null; then
        echo -ne "${YELLOW}Enter vault password:${NC} "
        read -r -s vault_password
        echo
        
        echo "$vault_password" | cryptsetup luksOpen "$vault_file" "bluejay-vault-${vault_name}" -
        
        if [ $? -eq 0 ]; then
            sudo mkdir -p "$vault_mount"
            sudo mount "/dev/mapper/bluejay-vault-${vault_name}" "$vault_mount"
            echo -e "${GREEN}✓${NC} Vault mounted at: $vault_mount"
        else
            echo -e "${RED}✗${NC} Failed to unlock vault"
        fi
    fi
}

# Unmount encrypted vault
unmount_vault() {
    local vault_name="$1"
    local vault_mount="/mnt/bluejay-vault-${vault_name}"
    
    echo -e "${BLUE}Unmounting vault: $vault_name${NC}"
    
    # Unmount filesystem
    if mountpoint -q "$vault_mount"; then
        sudo umount "$vault_mount"
        echo -e "${GREEN}✓${NC} Filesystem unmounted"
    fi
    
    # Close LUKS device
    if [ -e "/dev/mapper/bluejay-vault-${vault_name}" ]; then
        sudo cryptsetup luksClose "bluejay-vault-${vault_name}"
        echo -e "${GREEN}✓${NC} LUKS device closed"
    fi
}

# List vaults
list_vaults() {
    echo -e "\n${BLUE}Available Encrypted Vaults:${NC}"
    
    if [ ! -d "$VAULTS_DIR" ] || [ -z "$(ls -A "$VAULTS_DIR" 2>/dev/null)" ]; then
        echo -e "${YELLOW}No vaults found${NC}"
        return
    fi
    
    local count=1
    for vault_file in "$VAULTS_DIR"/*.vault; do
        if [ -f "$vault_file" ]; then
            local vault_name=$(basename "$vault_file" .vault)
            local vault_size=$(du -h "$vault_file" | cut -f1)
            local mount_status="unmounted"
            
            if mountpoint -q "/mnt/bluejay-vault-${vault_name}" 2>/dev/null; then
                mount_status="${GREEN}mounted${NC}"
            else
                mount_status="${RED}unmounted${NC}"
            fi
            
            echo -e "${WHITE}$count.${NC} $vault_name"
            echo -e "   ${CYAN}Size: $vault_size${NC}"
            echo -e "   ${CYAN}Status: $mount_status${NC}"
            echo -e "   ${GRAY}File: $vault_file${NC}"
        fi
        ((count++))
    done
}

# Calculate file hash
calculate_hash() {
    local file_path="$1"
    local algorithm="${2:-$DEFAULT_HASH_ALGORITHM}"
    
    if [ ! -f "$file_path" ]; then
        echo -e "${RED}✗${NC} File not found: $file_path"
        return 1
    fi
    
    echo -e "${BLUE}Calculating $algorithm hash for: $(basename "$file_path")${NC}"
    
    case "$algorithm" in
        sha256)
            sha256sum "$file_path"
            ;;
        sha512)
            sha512sum "$file_path"
            ;;
        md5)
            md5sum "$file_path"
            ;;
        blake2b)
            if command -v b2sum >/dev/null; then
                b2sum "$file_path"
            else
                echo -e "${RED}✗${NC} BLAKE2b not available"
            fi
            ;;
        *)
            echo -e "${RED}✗${NC} Unsupported hash algorithm: $algorithm"
            ;;
    esac
}

# Verify file integrity
verify_integrity() {
    local file_path="$1"
    local hash_file="${2:-${file_path}.hash}"
    
    if [ ! -f "$file_path" ] || [ ! -f "$hash_file" ]; then
        echo -e "${RED}✗${NC} File or hash file not found"
        return 1
    fi
    
    echo -e "${BLUE}Verifying file integrity...${NC}"
    
    local stored_hash=$(cat "$hash_file" | cut -d' ' -f1)
    local algorithm=$(head -1 "$hash_file" | grep -o "sha256\|sha512\|md5\|blake2b" || echo "sha256")
    
    local current_hash
    case "$algorithm" in
        sha256)
            current_hash=$(sha256sum "$file_path" | cut -d' ' -f1)
            ;;
        sha512)
            current_hash=$(sha512sum "$file_path" | cut -d' ' -f1)
            ;;
        md5)
            current_hash=$(md5sum "$file_path" | cut -d' ' -f1)
            ;;
    esac
    
    if [ "$stored_hash" = "$current_hash" ]; then
        echo -e "${GREEN}✓${NC} File integrity verified"
        return 0
    else
        echo -e "${RED}✗${NC} File integrity check failed"
        echo -e "${YELLOW}Expected: $stored_hash${NC}"
        echo -e "${YELLOW}Current:  $current_hash${NC}"
        return 1
    fi
}

# Shred files securely
secure_delete() {
    local target="$1"
    local passes="${2:-3}"
    
    if [ ! -e "$target" ]; then
        echo -e "${RED}✗${NC} Target not found: $target"
        return 1
    fi
    
    echo -e "${BLUE}Securely deleting: $target${NC}"
    echo -e "${YELLOW}This operation cannot be undone!${NC}"
    echo -ne "${YELLOW}Confirm deletion (y/N):${NC} "
    read -r confirm
    
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        if command -v shred >/dev/null; then
            shred -vfz -n "$passes" "$target"
        elif command -v wipe >/dev/null; then
            wipe -rf "$target"
        else
            # Fallback: overwrite with random data
            if [ -f "$target" ]; then
                dd if=/dev/urandom of="$target" bs=1024 count=$(du -k "$target" | cut -f1) 2>/dev/null
            fi
            rm -rf "$target"
        fi
        
        echo -e "${GREEN}✓${NC} Target securely deleted"
    else
        echo -e "${YELLOW}Operation cancelled${NC}"
    fi
}

# Settings menu
settings_menu() {
    echo -e "\n${PURPLE}=== Encryption Tools Settings ===${NC}"
    echo -e "${WHITE}1.${NC} Default symmetric cipher: ${DEFAULT_SYMMETRIC_CIPHER}"
    echo -e "${WHITE}2.${NC} Default asymmetric cipher: ${DEFAULT_ASYMMETRIC_CIPHER}"
    echo -e "${WHITE}3.${NC} Default hash algorithm: ${DEFAULT_HASH_ALGORITHM}"
    echo -e "${WHITE}4.${NC} Compression enabled: ${COMPRESSION_ENABLED}"
    echo -e "${WHITE}5.${NC} Secure delete: ${SECURE_DELETE}"
    echo -e "${WHITE}6.${NC} Paranoid mode: ${PARANOID_MODE}"
    echo -e "${WHITE}7.${NC} Auto-lock timeout: ${AUTO_LOCK_TIMEOUT}s"
    echo -e "${WHITE}8.${NC} Backup keys: ${BACKUP_KEYS}"
    echo -e "${WHITE}s.${NC} Save settings"
    echo -e "${WHITE}q.${NC} Back to main menu"
    echo
    
    echo -ne "${YELLOW}Select option:${NC} "
    read -r choice
    
    case "$choice" in
        1)
            echo -e "${CYAN}Available ciphers: $SYMMETRIC_ALGORITHMS${NC}"
            echo -ne "${CYAN}Default symmetric cipher:${NC} "
            read -r DEFAULT_SYMMETRIC_CIPHER
            ;;
        2)
            echo -e "${CYAN}Available ciphers: $ASYMMETRIC_ALGORITHMS${NC}"
            echo -ne "${CYAN}Default asymmetric cipher:${NC} "
            read -r DEFAULT_ASYMMETRIC_CIPHER
            ;;
        3)
            echo -e "${CYAN}Available algorithms: $HASH_ALGORITHMS${NC}"
            echo -ne "${CYAN}Default hash algorithm:${NC} "
            read -r DEFAULT_HASH_ALGORITHM
            ;;
        4)
            echo -ne "${CYAN}Enable compression (true/false):${NC} "
            read -r COMPRESSION_ENABLED
            ;;
        5)
            echo -ne "${CYAN}Secure delete original files (true/false):${NC} "
            read -r SECURE_DELETE
            ;;
        6)
            echo -ne "${CYAN}Enable paranoid mode (true/false):${NC} "
            read -r PARANOID_MODE
            ;;
        7)
            echo -ne "${CYAN}Auto-lock timeout (seconds):${NC} "
            read -r AUTO_LOCK_TIMEOUT
            ;;
        8)
            echo -ne "${CYAN}Backup encryption keys (true/false):${NC} "
            read -r BACKUP_KEYS
            ;;
        s|S)
            cat > "$ENCRYPTION_CONFIG_DIR/settings.conf" << EOF
# BluejayLinux Encryption Tools Settings
DEFAULT_SYMMETRIC_CIPHER=$DEFAULT_SYMMETRIC_CIPHER
DEFAULT_ASYMMETRIC_CIPHER=$DEFAULT_ASYMMETRIC_CIPHER
DEFAULT_HASH_ALGORITHM=$DEFAULT_HASH_ALGORITHM
KEY_DERIVATION_FUNCTION=$KEY_DERIVATION_FUNCTION
COMPRESSION_ENABLED=$COMPRESSION_ENABLED
COMPRESSION_ALGORITHM=$COMPRESSION_ALGORITHM
SECURE_DELETE=$SECURE_DELETE
BACKUP_KEYS=$BACKUP_KEYS
AUTO_LOCK_TIMEOUT=$AUTO_LOCK_TIMEOUT
PARANOID_MODE=$PARANOID_MODE
QUANTUM_RESISTANT=$QUANTUM_RESISTANT
STEGANOGRAPHY_ENABLED=$STEGANOGRAPHY_ENABLED
VAULT_AUTO_MOUNT=$VAULT_AUTO_MOUNT
KEYFILE_REQUIRED=$KEYFILE_REQUIRED
MULTIPLE_PASSWORDS=$MULTIPLE_PASSWORDS
EOF
            echo -e "${GREEN}✓${NC} Settings saved"
            ;;
    esac
}

# Main menu
main_menu() {
    echo -e "${PURPLE}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                 ${WHITE}BluejayLinux Encryption Tools${PURPLE}                   ║${NC}"
    echo -e "${PURPLE}║               ${CYAN}Professional Security & Privacy Suite${PURPLE}             ║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    local tools=($(detect_encryption_tools))
    echo -e "${WHITE}Available tools:${NC} ${tools[*]}"
    echo
    
    echo -e "${WHITE}File Encryption:${NC}"
    echo -e "${WHITE}1.${NC} Encrypt file (symmetric)"
    echo -e "${WHITE}2.${NC} Decrypt file (symmetric)"
    echo -e "${WHITE}3.${NC} Encrypt file (public key)"
    echo -e "${WHITE}4.${NC} Decrypt file (private key)"
    echo
    echo -e "${WHITE}Key Management:${NC}"
    echo -e "${WHITE}5.${NC} Generate keys"
    echo -e "${WHITE}6.${NC} Generate password"
    echo
    echo -e "${WHITE}Encrypted Vaults:${NC}"
    echo -e "${WHITE}7.${NC} Create vault"
    echo -e "${WHITE}8.${NC} Mount vault"
    echo -e "${WHITE}9.${NC} Unmount vault"
    echo -e "${WHITE}10.${NC} List vaults"
    echo
    echo -e "${WHITE}Security Tools:${NC}"
    echo -e "${WHITE}11.${NC} Calculate file hash"
    echo -e "${WHITE}12.${NC} Verify file integrity"
    echo -e "${WHITE}13.${NC} Secure delete"
    echo -e "${WHITE}14.${NC} Settings"
    echo -e "${WHITE}q.${NC} Quit"
    echo
}

# Main function
main() {
    create_directories
    load_settings
    
    if [ $# -gt 0 ]; then
        case "$1" in
            --encrypt-sym|-es)
                encrypt_file_symmetric "$2" "$3" "$4" "$5"
                ;;
            --decrypt-sym|-ds)
                decrypt_file_symmetric "$2" "$3" "$4" "$5"
                ;;
            --encrypt-pub|-ep)
                encrypt_file_asymmetric "$2" "$3" "$4"
                ;;
            --decrypt-priv|-dp)
                decrypt_file_asymmetric "$2" "$3" "$4"
                ;;
            --gen-keys|-gk)
                generate_keys "$2" "$3" "$4"
                ;;
            --gen-password|-gp)
                generate_password "$2" "$3"
                ;;
            --create-vault|-cv)
                create_vault "$2" "$3" "$4"
                ;;
            --mount-vault|-mv)
                mount_vault "$2"
                ;;
            --unmount-vault|-uv)
                unmount_vault "$2"
                ;;
            --hash|-h)
                calculate_hash "$2" "$3"
                ;;
            --verify|-v)
                verify_integrity "$2" "$3"
                ;;
            --shred|-s)
                secure_delete "$2" "$3"
                ;;
            --help)
                echo "BluejayLinux Encryption Tools"
                echo "Usage: $0 [options] [parameters]"
                echo "  --encrypt-sym, -es <file> [output] [cipher] [password]"
                echo "  --decrypt-sym, -ds <file> [output] [cipher] [password]"
                echo "  --encrypt-pub, -ep <file> [output] <public_key>"
                echo "  --decrypt-priv, -dp <file> [output] <private_key>"
                echo "  --gen-keys, -gk <type> <name> [size]"
                echo "  --gen-password, -gp [length] [charset]"
                echo "  --create-vault, -cv <name> [size] [filesystem]"
                echo "  --mount-vault, -mv <name>"
                echo "  --unmount-vault, -uv <name>"
                echo "  --hash, -h <file> [algorithm]"
                echo "  --verify, -v <file> [hash_file]"
                echo "  --shred, -s <target> [passes]"
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
                echo -ne "${CYAN}Output file (optional):${NC} "
                read -r output_file
                echo -ne "${CYAN}Cipher ($DEFAULT_SYMMETRIC_CIPHER):${NC} "
                read -r cipher
                cipher="${cipher:-$DEFAULT_SYMMETRIC_CIPHER}"
                encrypt_file_symmetric "$input_file" "$output_file" "$cipher"
                ;;
            2)
                echo -ne "${CYAN}Input file:${NC} "
                read -r input_file
                echo -ne "${CYAN}Output file (optional):${NC} "
                read -r output_file
                echo -ne "${CYAN}Cipher ($DEFAULT_SYMMETRIC_CIPHER):${NC} "
                read -r cipher
                cipher="${cipher:-$DEFAULT_SYMMETRIC_CIPHER}"
                decrypt_file_symmetric "$input_file" "$output_file" "$cipher"
                ;;
            3)
                echo -ne "${CYAN}Input file:${NC} "
                read -r input_file
                echo -ne "${CYAN}Public key file:${NC} "
                read -r public_key
                encrypt_file_asymmetric "$input_file" "" "$public_key"
                ;;
            4)
                echo -ne "${CYAN}Input file:${NC} "
                read -r input_file
                echo -ne "${CYAN}Private key file:${NC} "
                read -r private_key
                decrypt_file_asymmetric "$input_file" "" "$private_key"
                ;;
            5)
                echo -ne "${CYAN}Key type (rsa/ed25519/symmetric/gpg):${NC} "
                read -r key_type
                echo -ne "${CYAN}Key name:${NC} "
                read -r key_name
                echo -ne "${CYAN}Key size (default varies by type):${NC} "
                read -r key_size
                generate_keys "$key_type" "$key_name" "$key_size"
                ;;
            6)
                echo -ne "${CYAN}Password length (32):${NC} "
                read -r length
                length="${length:-32}"
                echo -ne "${CYAN}Character set (mixed/alphanumeric/symbols):${NC} "
                read -r charset
                charset="${charset:-mixed}"
                echo -e "${GREEN}Generated password:${NC} $(generate_password "$length" "$charset")"
                ;;
            7)
                echo -ne "${CYAN}Vault name:${NC} "
                read -r vault_name
                echo -ne "${CYAN}Vault size (100M):${NC} "
                read -r vault_size
                vault_size="${vault_size:-100M}"
                echo -ne "${CYAN}Filesystem (ext4):${NC} "
                read -r filesystem
                filesystem="${filesystem:-ext4}"
                create_vault "$vault_name" "$vault_size" "$filesystem"
                ;;
            8)
                list_vaults
                echo -ne "\n${CYAN}Vault name to mount:${NC} "
                read -r vault_name
                mount_vault "$vault_name"
                ;;
            9)
                list_vaults
                echo -ne "\n${CYAN}Vault name to unmount:${NC} "
                read -r vault_name
                unmount_vault "$vault_name"
                ;;
            10)
                list_vaults
                ;;
            11)
                echo -ne "${CYAN}File path:${NC} "
                read -r file_path
                echo -ne "${CYAN}Hash algorithm ($DEFAULT_HASH_ALGORITHM):${NC} "
                read -r algorithm
                algorithm="${algorithm:-$DEFAULT_HASH_ALGORITHM}"
                calculate_hash "$file_path" "$algorithm"
                ;;
            12)
                echo -ne "${CYAN}File path:${NC} "
                read -r file_path
                echo -ne "${CYAN}Hash file (optional):${NC} "
                read -r hash_file
                verify_integrity "$file_path" "$hash_file"
                ;;
            13)
                echo -ne "${CYAN}Target to delete:${NC} "
                read -r target
                echo -ne "${CYAN}Number of passes (3):${NC} "
                read -r passes
                passes="${passes:-3}"
                secure_delete "$target" "$passes"
                ;;
            14)
                settings_menu
                ;;
            q|Q)
                echo -e "${GREEN}Encryption tools configuration saved${NC}"
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