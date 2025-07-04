#!/bin/bash

# =============================================================================
# QR Code Generator for VPN Configuration
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${CYAN}================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}================================${NC}"
}

# Function to check if qrencode is installed
check_qrencode() {
    if ! command -v qrencode &> /dev/null; then
        print_status "Installing qrencode..."
        apt update
        apt install -y qrencode
    fi
}

# Function to generate QR code for VLESS connection
generate_vless_qr() {
    local uuid=$1
    local domain=$2
    local public_key=$3
    local email=$4
    local output_file=$5
    
    local connection_string="vless://$uuid@$domain:443?encryption=none&security=reality&sni=www.google.com&fp=chrome&pbk=$public_key&type=tcp&flow=xtls-rprx-vision#$email"
    
    print_status "Generating QR code for: $email"
    
    # Generate QR code
    qrencode -t PNG -o "$output_file" "$connection_string"
    
    print_status "QR code saved to: $output_file"
    echo ""
    print_status "Connection string:"
    echo "$connection_string"
    echo ""
}

# Function to generate QR code for Clash configuration
generate_clash_qr() {
    local uuid=$1
    local domain=$2
    local public_key=$3
    local email=$4
    local output_file=$5
    
    local clash_config="proxies:
  - name: \"$email\"
    type: vless
    server: $domain
    port: 443
    uuid: $uuid
    network: tcp
    tls: true
    udp: true
    reality-opts:
      public-key: $public_key
      short-id: \"\"
    client-fingerprint: chrome
    flow: xtls-rprx-vision"
    
    print_status "Generating Clash QR code for: $email"
    
    # Generate QR code
    qrencode -t PNG -o "$output_file" "$clash_config"
    
    print_status "Clash QR code saved to: $output_file"
    echo ""
    print_status "Clash configuration:"
    echo "$clash_config"
    echo ""
}

# Function to generate QR code for Surge configuration
generate_surge_qr() {
    local uuid=$1
    local domain=$2
    local public_key=$3
    local email=$4
    local output_file=$5
    
    local surge_config="[Proxy]
$email = vless, $domain, 443, username=$uuid, tls=true, tls13=true, reality-opts=public-key=$public_key, sni=www.google.com, fp=chrome, flow=xtls-rprx-vision"
    
    print_status "Generating Surge QR code for: $email"
    
    # Generate QR code
    qrencode -t PNG -o "$output_file" "$surge_config"
    
    print_status "Surge QR code saved to: $output_file"
    echo ""
    print_status "Surge configuration:"
    echo "$surge_config"
    echo ""
}

# Function to generate QR code for Quantumult X configuration
generate_quantumult_qr() {
    local uuid=$1
    local domain=$2
    local public_key=$3
    local email=$4
    local output_file=$5
    
    local quantumult_config="vless=$domain:443, method=none, password=$uuid, obfs=over-tls, obfs-host=www.google.com, obfs-uri=, tls13=true, fast-open=false, udp-relay=false, tag=$email"
    
    print_status "Generating Quantumult X QR code for: $email"
    
    # Generate QR code
    qrencode -t PNG -o "$output_file" "$quantumult_config"
    
    print_status "Quantumult X QR code saved to: $output_file"
    echo ""
    print_status "Quantumult X configuration:"
    echo "$quantumult_config"
    echo ""
}

# Function to generate all QR codes for a user
generate_all_qr_codes() {
    local email=$1
    local uuid=$2
    local domain=$3
    local public_key=$4
    
    # Create output directory
    local output_dir="/root/qr-codes/$email"
    mkdir -p "$output_dir"
    
    print_header "Generating QR Codes for: $email"
    
    # Generate VLESS QR code
    generate_vless_qr "$uuid" "$domain" "$public_key" "$email" "$output_dir/vless.png"
    
    # Generate Clash QR code
    generate_clash_qr "$uuid" "$domain" "$public_key" "$email" "$output_dir/clash.png"
    
    # Generate Surge QR code
    generate_surge_qr "$uuid" "$domain" "$public_key" "$email" "$output_dir/surge.png"
    
    # Generate Quantumult X QR code
    generate_quantumult_qr "$uuid" "$domain" "$public_key" "$email" "$output_dir/quantumult.png"
    
    print_status "All QR codes generated in: $output_dir"
    echo ""
}

# Function to get user information from database
get_user_info() {
    local email=$1
    local db_path=""
    
    # Find database path
    if [[ -f "/usr/local/x-ui/x-ui.db" ]]; then
        db_path="/usr/local/x-ui/x-ui.db"
    elif [[ -f "/opt/vpn-server/x-ui-data/x-ui.db" ]]; then
        db_path="/opt/vpn-server/x-ui-data/x-ui.db"
    else
        print_error "3x-ui database not found"
        exit 1
    fi
    
    # Get user data
    local user_data=$(sqlite3 "$db_path" << EOF
SELECT settings FROM inbounds WHERE email = '$email';
EOF
)
    
    if [[ -z "$user_data" ]]; then
        print_error "User with email $email not found"
        exit 1
    fi
    
    # Extract UUID from settings
    local uuid=$(echo "$user_data" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
    
    echo "$uuid"
}

# Function to get server configuration
get_server_config() {
    local domain=""
    local public_key=""
    
    # Try to read from vpn-info.txt
    if [[ -f "/root/vpn-info.txt" ]]; then
        domain=$(grep "DOMAIN=" /root/vpn-info.txt | cut -d'=' -f2 | tr -d ' ')
        public_key=$(grep "Public Key:" /root/vpn-info.txt | cut -d':' -f2 | tr -d ' ')
    fi
    
    # If not found, prompt user
    if [[ -z "$domain" ]]; then
        read -p "Enter your domain: " domain
    fi
    
    if [[ -z "$public_key" ]]; then
        read -p "Enter your Reality public key: " public_key
    fi
    
    echo "$domain:$public_key"
}

# Function to show help
show_help() {
    print_header "QR Code Generator for VPN Configuration"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -u, --user <email>     Generate QR codes for specific user"
    echo "  -a, --all              Generate QR codes for all users"
    echo "  -t, --type <type>      QR code type (vless, clash, surge, quantumult, all)"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -u user@example.com"
    echo "  $0 -u user@example.com -t vless"
    echo "  $0 -a"
    echo "  $0 -a -t clash"
    echo ""
}

# Main script logic
main() {
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
    
    # Check if qrencode is installed
    check_qrencode
    
    # Parse command line arguments
    local user_email=""
    local generate_all=false
    local qr_type="all"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -u|--user)
                user_email="$2"
                shift 2
                ;;
            -a|--all)
                generate_all=true
                shift
                ;;
            -t|--type)
                qr_type="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Get server configuration
    local server_config=$(get_server_config)
    local domain=$(echo "$server_config" | cut -d':' -f1)
    local public_key=$(echo "$server_config" | cut -d':' -f2)
    
    if [[ -z "$domain" ]] || [[ -z "$public_key" ]]; then
        print_error "Failed to get server configuration"
        exit 1
    fi
    
    print_status "Domain: $domain"
    print_status "Public Key: $public_key"
    echo ""
    
    # Generate QR codes
    if [[ "$generate_all" == true ]]; then
        # Generate for all users
        local db_path=""
        if [[ -f "/usr/local/x-ui/x-ui.db" ]]; then
            db_path="/usr/local/x-ui/x-ui.db"
        elif [[ -f "/opt/vpn-server/x-ui-data/x-ui.db" ]]; then
            db_path="/opt/vpn-server/x-ui-data/x-ui.db"
        else
            print_error "3x-ui database not found"
            exit 1
        fi
        
        # Get all users
        local users=$(sqlite3 "$db_path" "SELECT email, settings FROM inbounds WHERE email IS NOT NULL AND email != '';")
        
        if [[ -z "$users" ]]; then
            print_warning "No users found in database"
            exit 0
        fi
        
        while IFS='|' read -r email settings; do
            local uuid=$(echo "$settings" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
            if [[ -n "$uuid" ]]; then
                generate_all_qr_codes "$email" "$uuid" "$domain" "$public_key"
            fi
        done <<< "$users"
        
    elif [[ -n "$user_email" ]]; then
        # Generate for specific user
        local uuid=$(get_user_info "$user_email")
        if [[ -n "$uuid" ]]; then
            generate_all_qr_codes "$user_email" "$uuid" "$domain" "$public_key"
        fi
    else
        print_error "Please specify a user with -u or use -a for all users"
        show_help
        exit 1
    fi
    
    print_status "QR code generation completed!"
    print_status "QR codes are saved in: /root/qr-codes/"
}

# Run main function with all arguments
main "$@" 