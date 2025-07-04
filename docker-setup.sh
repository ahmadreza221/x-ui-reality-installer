#!/bin/bash

# =============================================================================
# Docker-based VPN Deployment with 3x-ui (Sanaei Panel)
# VLESS + TCP + Reality Protocol over IPv4 and IPv6 with Domain-based SSL
# =============================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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

# Function to generate random strings
generate_random_string() {
    local length=$1
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w $length | head -n 1
}

# Function to generate UUID
generate_uuid() {
    cat /proc/sys/kernel/random/uuid
}

# Function to generate X25519 key pair
generate_x25519_keys() {
    # Generate private key in PEM
    openssl genpkey -algorithm X25519 -out reality_private.pem
    # Extract raw private key (base64, 32 bytes)
    openssl pkey -in reality_private.pem -outform DER | tail -c 32 | base64 > reality_private.key
    # Extract public key (base64, 32 bytes)
    openssl pkey -in reality_private.pem -pubout -outform DER | tail -c 32 | base64 > reality_public.key
    local private_key=$(cat reality_private.key)
    local public_key=$(cat reality_public.key)
    # Clean up
    rm -f reality_private.pem reality_private.key reality_public.key
    if [[ -z "$private_key" || -z "$public_key" ]]; then
        print_error "Reality key generation failed. Please check openssl installation."
        exit 1
    fi
    echo "$private_key:$public_key"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root"
   exit 1
fi

# Check if required environment variables are set
if [[ -z "$DOMAIN" ]]; then
    print_error "DOMAIN environment variable is required"
    echo "Usage: DOMAIN=yourdomain.com EMAIL=you@example.com ./docker-setup.sh"
    exit 1
fi

if [[ -z "$EMAIL" ]]; then
    print_error "EMAIL environment variable is required"
    echo "Usage: DOMAIN=yourdomain.com EMAIL=you@example.com ./docker-setup.sh"
    exit 1
fi

# Set default values
ADMIN_USERNAME=${ADMIN_USERNAME:-"admin"}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-$(generate_random_string 12)}

print_header "Docker-based VPN Deployment with 3x-ui"
print_status "Domain: $DOMAIN"
print_status "Email: $EMAIL"
print_status "Admin Username: $ADMIN_USERNAME"
print_status "Admin Password: $ADMIN_PASSWORD"

# Get server IP addresses
IPV4_ADDRESS=$(curl -s4 ifconfig.me)
IPV6_ADDRESS=$(curl -s6 ifconfig.me 2>/dev/null || echo "Not available")

print_status "IPv4 Address: $IPV4_ADDRESS"
if [[ "$IPV6_ADDRESS" != "Not available" ]]; then
    print_status "IPv6 Address: $IPV6_ADDRESS"
fi

# =============================================================================
# 1. Pre-installation Setup
# =============================================================================
print_header "Step 1: Pre-installation Setup"

print_status "Updating package lists..."
apt update

print_status "Installing required packages..."
apt install -y curl wget ufw socat software-properties-common apt-transport-https ca-certificates gnupg lsb-release

# =============================================================================
# 2. Docker Installation
# =============================================================================
print_header "Step 2: Docker Installation"

# Install Docker
print_status "Installing Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Start and enable Docker
systemctl start docker
systemctl enable docker

# Install Docker Compose if not available
if ! command -v docker-compose &> /dev/null; then
    print_status "Installing Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

# =============================================================================
# 3. Firewall Configuration
# =============================================================================
print_header "Step 3: Firewall Configuration"

# Configure UFW Firewall
print_status "Configuring UFW Firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# Allow SSH, HTTP, HTTPS, and 3x-ui panel
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 54321/tcp

# Enable IPv6 in UFW
sed -i 's/IPV6=no/IPV6=yes/' /etc/default/ufw

# Enable UFW
ufw --force enable

print_status "Firewall configured successfully"

# =============================================================================
# 4. Environment Setup
# =============================================================================
print_header "Step 4: Environment Setup"

# Create project directory
mkdir -p /opt/vpn-server
cd /opt/vpn-server

# Create .env file
cat > .env << EOF
DOMAIN=$DOMAIN
EMAIL=$EMAIL
ADMIN_USERNAME=$ADMIN_USERNAME
ADMIN_PASSWORD=$ADMIN_PASSWORD
REALITY_SERVER_NAME=www.google.com
REALITY_DEST=www.google.com:443
XUI_PORT=54321
NGINX_HTTP_PORT=80
NGINX_HTTPS_PORT=443
EOF

print_status "Environment file created"

# =============================================================================
# 5. SSL Certificate Setup
# =============================================================================
print_header "Step 5: SSL Certificate Setup"

# Create directories for SSL certificates
mkdir -p ssl-certs certbot-webroot

# Run certbot container to obtain certificate
print_status "Obtaining SSL certificate for $DOMAIN..."
docker run --rm \
    -v "$(pwd)/ssl-certs:/etc/letsencrypt" \
    -v "$(pwd)/certbot-webroot:/var/www/certbot" \
    certbot/certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email $EMAIL \
    --agree-tos \
    --no-eff-email \
    -d $DOMAIN

# Verify certificate
if [[ ! -f "ssl-certs/live/$DOMAIN/fullchain.pem" ]]; then
    print_error "SSL certificate generation failed"
    exit 1
fi

print_status "SSL certificate obtained successfully"

# =============================================================================
# 6. Reality Protocol Configuration
# =============================================================================
print_header "Step 6: Reality Protocol Configuration"

# Generate Reality keys
print_status "Generating Reality protocol keys..."
KEYS=$(generate_x25519_keys)
REALITY_PRIVATE_KEY=$(echo $KEYS | cut -d: -f1)
REALITY_PUBLIC_KEY=$(echo $KEYS | cut -d: -f2)

# Generate UUID for default user
DEFAULT_UUID=$(generate_uuid)

print_status "Reality Private Key: $REALITY_PRIVATE_KEY"
print_status "Reality Public Key: $REALITY_PUBLIC_KEY"
print_status "Default User UUID: $DEFAULT_UUID"

# =============================================================================
# 7. Docker Compose Deployment
# =============================================================================
print_header "Step 7: Docker Compose Deployment"

# Copy docker-compose.yml and nginx.conf
cp docker-compose.yml .
cp nginx.conf .

# Start services
print_status "Starting Docker services..."
docker-compose up -d

# Wait for services to be ready
print_status "Waiting for services to be ready..."
sleep 30

# =============================================================================
# 8. SSL Auto-renewal Setup
# =============================================================================
print_header "Step 8: SSL Auto-renewal Setup"

# Create renewal script
cat > /usr/local/bin/docker-renew-ssl.sh << 'EOF'
#!/bin/bash
cd /opt/vpn-server
docker-compose run --rm certbot renew
docker-compose restart nginx
EOF

chmod +x /usr/local/bin/docker-renew-ssl.sh

# Add to crontab for auto-renewal
(crontab -l 2>/dev/null; echo "0 12 * * * /usr/local/bin/docker-renew-ssl.sh") | crontab -

print_status "SSL auto-renewal configured"

# =============================================================================
# 9. Final Configuration and Information
# =============================================================================
print_header "Step 9: Final Configuration"

# Wait a bit more for services to be fully ready
sleep 10

# Create connection information file
cat > /root/vpn-info.txt << EOF
===========================================
    Docker-based VPN Server Configuration
===========================================

🌐 Domain: $DOMAIN
📧 Email: $EMAIL
🖥️  Server IPv4: $IPV4_ADDRESS
🖥️  Server IPv6: $IPV6_ADDRESS

🔐 3x-ui Panel Access:
   URL: https://$DOMAIN
   Username: $ADMIN_USERNAME
   Password: $ADMIN_PASSWORD

🔑 Reality Protocol Configuration:
   UUID: $DEFAULT_UUID
   Public Key: $REALITY_PUBLIC_KEY
   Server Name: www.google.com
   Port: 443

📱 VLESS Connection String:
   vless://$DEFAULT_UUID@$DOMAIN:443?encryption=none&security=reality&sni=www.google.com&fp=chrome&pbk=$REALITY_PUBLIC_KEY&type=tcp&flow=xtls-rprx-vision#VPN-Server

🔧 Manual Configuration:
   Protocol: VLESS
   Address: $DOMAIN
   Port: 443
   UUID: $DEFAULT_UUID
   Encryption: none
   Transport: tcp
   Security: reality
   SNI: www.google.com
   Public Key: $REALITY_PUBLIC_KEY
   Flow: xtls-rprx-vision

🐳 Docker Management:
   - View logs: docker-compose logs -f
   - Restart services: docker-compose restart
   - Stop services: docker-compose down
   - Update services: docker-compose pull && docker-compose up -d

⚠️  IMPORTANT NOTES:
   - All traffic is routed through port 443
   - Server IP is hidden (domain-only access)
   - Reality protocol mimics Google's TLS handshake
   - SSL certificate auto-renews every 60 days
   - Firewall allows: 22, 80, 443, 54321
   - Services run in Docker containers

🔧 Management Commands:
   - View logs: docker-compose logs -f
   - Restart panel: docker-compose restart x-ui
   - Check status: docker-compose ps
   - SSL renewal: /usr/local/bin/docker-renew-ssl.sh

Generated on: $(date)
EOF

# Display final information
print_header "🎉 Docker-based Installation Complete!"
echo ""
print_status "3x-ui Panel URL: https://$DOMAIN"
print_status "Admin Username: $ADMIN_USERNAME"
print_status "Admin Password: $ADMIN_PASSWORD"
echo ""
print_status "Reality UUID: $DEFAULT_UUID"
print_status "Reality Public Key: $REALITY_PUBLIC_KEY"
echo ""
print_status "VLESS Connection String:"
echo "vless://$DEFAULT_UUID@$DOMAIN:443?encryption=none&security=reality&sni=www.google.com&fp=chrome&pbk=$REALITY_PUBLIC_KEY&type=tcp&flow=xtls-rprx-vision#VPN-Server"
echo ""
print_status "Configuration saved to: /root/vpn-info.txt"
print_status "Docker project directory: /opt/vpn-server"
echo ""
print_warning "Please wait 2-3 minutes for all services to fully initialize"
print_warning "Then access the panel at: https://$DOMAIN"
echo ""
print_status "Docker-based installation completed successfully! 🚀" 