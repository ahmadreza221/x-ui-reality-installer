#!/bin/bash

# =============================================================================
# 3x-ui User Management Script
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

# Function to generate UUID
generate_uuid() {
    cat /proc/sys/kernel/random/uuid
}

# Function to generate random string
generate_random_string() {
    local length=$1
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w $length | head -n 1
}

# Function to check if 3x-ui is running
check_xui_status() {
    if systemctl is-active --quiet x-ui; then
        return 0
    else
        return 1
    fi
}

# Function to get 3x-ui database path
get_xui_db_path() {
    if [[ -f "/usr/local/x-ui/x-ui.db" ]]; then
        echo "/usr/local/x-ui/x-ui.db"
    elif [[ -f "/opt/vpn-server/x-ui-data/x-ui.db" ]]; then
        echo "/opt/vpn-server/x-ui-data/x-ui.db"
    else
        print_error "3x-ui database not found"
        exit 1
    fi
}

# Function to add user
add_user() {
    local email=$1
    local uuid=${2:-$(generate_uuid)}
    local db_path=$(get_xui_db_path)
    local short_id=$(generate_short_id)
    
    print_status "Adding user: $email"
    
    # Check if user already exists
    if sqlite3 "$db_path" "SELECT COUNT(*) FROM inbounds WHERE email = '$email';" | grep -q "1"; then
        print_error "User with email $email already exists"
        return 1
    fi
    
    # Add user to database
    sqlite3 "$db_path" << EOF
INSERT INTO inbounds (
    up, down, total, remark, enable, expiry_time, listen, port, protocol, settings, stream_settings, tag, sniffing
) VALUES (
    0, 0, 0, '$email', 1, 0, '', 443, 'vless', 
    '{"clients":[{"id":"$uuid","flow":"","email":"$email","limitIp":0,"totalGB":0,"expiryTime":0,"enable":true,"tgId":"","subId":""}],"decryption":"none","fallbacks":[]}',
    '{"network":"tcp","security":"reality","realitySettings":{"show":false,"dest":"$SNI_DOMAIN:443","xver":0,"serverNames":["$SNI_DOMAIN"],"privateKey":"","shortIds":["$short_id"],"spiderX":"$SPIDERX"},"tcpSettings":{"header":{"type":"none"}},"fingerprint":"$FINGERPRINT"}',
    'vless-reality',
    '{"enabled":true,"destOverride":["http","tls"]}'
);
EOF
    
    print_status "User added successfully"
    print_status "Email: $email"
    print_status "UUID: $uuid"
    print_status "Short ID: $short_id"
    
    # Generate connection string
    local domain=$(grep "DOMAIN=" /root/vpn-info.txt 2>/dev/null | cut -d'=' -f2 || echo "yourdomain.com")
    local public_key=$(grep "Public Key:" /root/vpn-info.txt 2>/dev/null | cut -d':' -f2 | tr -d ' ' || echo "your-public-key")
    
    echo ""
    print_status "VLESS Connection String:"
    echo "vless://$uuid@$domain:443?encryption=none&security=reality&sni=$SNI_DOMAIN&fp=$FINGERPRINT&pbk=$public_key&type=tcp&flow=xtls-rprx-vision&sid=$short_id&spx=$SPIDERX#$email"
    echo ""
}

# Function to remove user
remove_user() {
    local email=$1
    local db_path=$(get_xui_db_path)
    
    print_status "Removing user: $email"
    
    # Check if user exists
    if ! sqlite3 "$db_path" "SELECT COUNT(*) FROM inbounds WHERE email = '$email';" | grep -q "1"; then
        print_error "User with email $email not found"
        return 1
    fi
    
    # Remove user from database
    sqlite3 "$db_path" "DELETE FROM inbounds WHERE email = '$email';"
    
    print_status "User removed successfully"
}

# Function to list users
list_users() {
    local db_path=$(get_xui_db_path)
    
    print_status "Listing all users:"
    echo ""
    
    sqlite3 "$db_path" << EOF
.mode column
.headers on
SELECT 
    email as Email,
    up as Upload_GB,
    down as Download_GB,
    total as Total_GB,
    CASE WHEN enable = 1 THEN 'Enabled' ELSE 'Disabled' END as Status,
    CASE WHEN expiry_time = 0 THEN 'Never' ELSE datetime(expiry_time/1000, 'unixepoch') END as Expiry
FROM inbounds 
WHERE email IS NOT NULL AND email != '';
EOF
    
    echo ""
}

# Function to enable/disable user
toggle_user() {
    local email=$1
    local action=$2
    local db_path=$(get_xui_db_path)
    
    local enable_value=1
    if [[ "$action" == "disable" ]]; then
        enable_value=0
    fi
    
    print_status "${action^}ing user: $email"
    
    # Check if user exists
    if ! sqlite3 "$db_path" "SELECT COUNT(*) FROM inbounds WHERE email = '$email';" | grep -q "1"; then
        print_error "User with email $email not found"
        return 1
    fi
    
    # Update user status
    sqlite3 "$db_path" "UPDATE inbounds SET enable = $enable_value WHERE email = '$email';"
    
    print_status "User ${action}d successfully"
}

# Function to reset user traffic
reset_traffic() {
    local email=$1
    local db_path=$(get_xui_db_path)
    
    print_status "Resetting traffic for user: $email"
    
    # Check if user exists
    if ! sqlite3 "$db_path" "SELECT COUNT(*) FROM inbounds WHERE email = '$email';" | grep -q "1"; then
        print_error "User with email $email not found"
        return 1
    fi
    
    # Reset traffic counters
    sqlite3 "$db_path" "UPDATE inbounds SET up = 0, down = 0, total = 0 WHERE email = '$email';"
    
    print_status "Traffic reset successfully"
}

# Function to set user limit
set_user_limit() {
    local email=$1
    local limit_gb=$2
    local db_path=$(get_xui_db_path)
    
    print_status "Setting traffic limit for user: $email to ${limit_gb}GB"
    
    # Check if user exists
    if ! sqlite3 "$db_path" "SELECT COUNT(*) FROM inbounds WHERE email = '$email';" | grep -q "1"; then
        print_error "User with email $email not found"
        return 1
    fi
    
    # Update user limit
    sqlite3 "$db_path" "UPDATE inbounds SET total = $((limit_gb * 1024 * 1024 * 1024)) WHERE email = '$email';"
    
    print_status "Traffic limit set successfully"
}

# Function to show user info
show_user_info() {
    local email=$1
    local db_path=$(get_xui_db_path)
    
    print_status "User information for: $email"
    echo ""
    
    # Get user data
    local user_data=$(sqlite3 "$db_path" << EOF
SELECT 
    email,
    up,
    down,
    total,
    enable,
    expiry_time,
    settings
FROM inbounds 
WHERE email = '$email';
EOF
)
    
    if [[ -z "$user_data" ]]; then
        print_error "User with email $email not found"
        return 1
    fi
    
    # Parse user data
    IFS='|' read -r email up down total enable expiry_time settings <<< "$user_data"
    
    # Extract UUID from settings
    local uuid=$(echo "$settings" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
    
    echo "Email: $email"
    echo "UUID: $uuid"
    echo "Upload: $((up / 1024 / 1024 / 1024))GB"
    echo "Download: $((down / 1024 / 1024 / 1024))GB"
    echo "Total Limit: $((total / 1024 / 1024 / 1024))GB"
    echo "Status: $([[ $enable -eq 1 ]] && echo "Enabled" || echo "Disabled")"
    echo "Expiry: $([[ $expiry_time -eq 0 ]] && echo "Never" || date -d @$((expiry_time/1000)))"
    
    # Generate connection string
    local domain=$(grep "DOMAIN=" /root/vpn-info.txt 2>/dev/null | cut -d'=' -f2 | tr -d ' ' || echo "yourdomain.com")
    local public_key=$(grep "Public Key:" /root/vpn-info.txt 2>/dev/null | cut -d':' -f2 | tr -d ' ' || echo "your-public-key")
    
    echo ""
    print_status "VLESS Connection String:"
    echo "vless://$uuid@$domain:443?encryption=none&security=reality&sni=www.google.com&fp=chrome&pbk=$public_key&type=tcp&flow=xtls-rprx-vision#$email"
    echo ""
}

# Function to show help
show_help() {
    print_header "3x-ui User Management Script"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  add <email> [uuid]     Add a new user with optional UUID"
    echo "  remove <email>         Remove a user"
    echo "  list                   List all users"
    echo "  enable <email>         Enable a user"
    echo "  disable <email>        Disable a user"
    echo "  reset <email>          Reset user traffic"
    echo "  limit <email> <gb>     Set user traffic limit in GB"
    echo "  info <email>           Show user information"
    echo "  help                   Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 add user@example.com"
    echo "  $0 add user@example.com 12345678-1234-1234-1234-123456789012"
    echo "  $0 remove user@example.com"
    echo "  $0 list"
    echo "  $0 enable user@example.com"
    echo "  $0 disable user@example.com"
    echo "  $0 reset user@example.com"
    echo "  $0 limit user@example.com 10"
    echo "  $0 info user@example.com"
    echo ""
}

# Main script logic
main() {
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
    
    # Check if 3x-ui is running
    if ! check_xui_status; then
        print_error "3x-ui is not running. Please start it first."
        exit 1
    fi
    
    # Check command
    case "${1:-help}" in
        "add")
            if [[ -z "$2" ]]; then
                print_error "Email is required for add command"
                exit 1
            fi
            add_user "$2" "$3"
            ;;
        "remove")
            if [[ -z "$2" ]]; then
                print_error "Email is required for remove command"
                exit 1
            fi
            remove_user "$2"
            ;;
        "list")
            list_users
            ;;
        "enable")
            if [[ -z "$2" ]]; then
                print_error "Email is required for enable command"
                exit 1
            fi
            toggle_user "$2" "enable"
            ;;
        "disable")
            if [[ -z "$2" ]]; then
                print_error "Email is required for disable command"
                exit 1
            fi
            toggle_user "$2" "disable"
            ;;
        "reset")
            if [[ -z "$2" ]]; then
                print_error "Email is required for reset command"
                exit 1
            fi
            reset_traffic "$2"
            ;;
        "limit")
            if [[ -z "$2" ]] || [[ -z "$3" ]]; then
                print_error "Email and limit (GB) are required for limit command"
                exit 1
            fi
            set_user_limit "$2" "$3"
            ;;
        "info")
            if [[ -z "$2" ]]; then
                print_error "Email is required for info command"
                exit 1
            fi
            show_user_info "$2"
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# Run main function with all arguments
main "$@" 