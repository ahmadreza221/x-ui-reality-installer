#!/bin/bash

# =============================================================================
# Fully Automated VPN Deployment with 3x-ui (Sanaei Panel)
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

# Function to generate random shortId (8-16 hex chars)
generate_short_id() {
    cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 16 | head -n 1
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root"
   exit 1
fi

# Check if required environment variables are set
if [[ -z "$DOMAIN" ]]; then
    print_error "DOMAIN environment variable is required"
    echo "Usage: DOMAIN=yourdomain.com EMAIL=you@example.com ./setup.sh"
    exit 1
fi

if [[ -z "$EMAIL" ]]; then
    print_error "EMAIL environment variable is required"
    echo "Usage: DOMAIN=yourdomain.com EMAIL=you@example.com ./setup.sh"
    exit 1
fi

# Set default values
ADMIN_USERNAME=${ADMIN_USERNAME:-"admin"}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-$(generate_random_string 12)}
SNI_DOMAIN=${SNI_DOMAIN:-"www.google.com"} # SNI for Reality, can be set via env

print_header "Fully Automated VPN Deployment with 3x-ui"
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

print_status "Upgrading packages..."
apt upgrade -y

print_status "Installing required packages..."
apt install -y curl wget certbot ufw socat nginx software-properties-common apt-transport-https ca-certificates gnupg lsb-release

# =============================================================================
# 2. Environment Configuration
# =============================================================================
print_header "Step 2: Environment Configuration"

# Install Docker
print_status "Installing Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Start and enable Docker
systemctl start docker
systemctl enable docker

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
# 3. SSL Certificate Setup
# =============================================================================
print_header "Step 3: SSL Certificate Setup"

# Stop nginx temporarily for certbot
systemctl stop nginx 2>/dev/null || true

print_status "Obtaining SSL certificate for $DOMAIN..."
certbot certonly --standalone --non-interactive --agree-tos --email $EMAIL -d $DOMAIN

# Verify certificate
if [[ ! -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]]; then
    print_error "SSL certificate generation failed"
    exit 1
fi

print_status "SSL certificate obtained successfully"

# =============================================================================
# 4. 3x-ui Panel Installation
# =============================================================================
print_header "Step 4: 3x-ui Panel Installation"

# Create 3x-ui directory
mkdir -p /usr/local/x-ui
cd /usr/local/x-ui

# Download 3x-ui
print_status "Downloading 3x-ui..."
wget -O x-ui-linux-amd64.tar.gz https://github.com/MHSanaei/3x-ui/releases/latest/download/x-ui-linux-amd64.tar.gz

# Extract and install
tar -xzf x-ui-linux-amd64.tar.gz
chmod +x x-ui

# Create systemd service
cat > /etc/systemd/system/x-ui.service << EOF
[Unit]
Description=x-ui Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/usr/local/x-ui
ExecStart=/usr/local/x-ui/x-ui
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable service
systemctl daemon-reload
systemctl enable x-ui
systemctl start x-ui

print_status "3x-ui panel installed and started"

# =============================================================================
# 5. Nginx Reverse Proxy Configuration
# =============================================================================
print_header "Step 5: Nginx Reverse Proxy Configuration"

# Create nginx configuration
cat > /etc/nginx/sites-available/x-ui << EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    location / {
        proxy_pass http://127.0.0.1:54321;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

# Enable site and restart nginx
ln -sf /etc/nginx/sites-available/x-ui /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
systemctl restart nginx

print_status "Nginx reverse proxy configured"

# =============================================================================
# 6. Reality Protocol Configuration
# =============================================================================
print_header "Step 6: Reality Protocol Configuration"

# Generate Reality keys
print_status "Generating Reality protocol keys..."
KEYS=$(generate_x25519_keys)
REALITY_PRIVATE_KEY=$(echo $KEYS | cut -d: -f1)
REALITY_PUBLIC_KEY=$(echo $KEYS | cut -d: -f2)
REALITY_SHORT_ID=$(generate_short_id)

# Generate UUID for default user
DEFAULT_UUID=$(generate_uuid)

print_status "Reality Private Key: $REALITY_PRIVATE_KEY"
print_status "Reality Public Key: $REALITY_PUBLIC_KEY"
print_status "Default User UUID: $DEFAULT_UUID"

# Wait for 3x-ui to be ready
print_status "Waiting for 3x-ui panel to be ready..."
sleep 10

# Configure 3x-ui via API (we'll need to set up the initial configuration)
# First, let's create a configuration file
cat > /usr/local/x-ui/config.json << EOF
{
  "panel": {
    "type": "x-ui",
    "web": {
      "port": 54321,
      "host": "127.0.0.1"
    },
    "db": {
      "type": "sqlite",
      "path": "/usr/local/x-ui/x-ui.db"
    }
  },
  "xray": {
    "log": {
      "loglevel": "warning"
    },
    "inbounds": [
      {
        "port": 443,
        "protocol": "vless",
        "settings": {
          "clients": [
            {
              "id": "$DEFAULT_UUID",
              "flow": ""
            }
          ],
          "decryption": "none"
        },
        "streamSettings": {
          "network": "tcp",
          "security": "reality",
          "realitySettings": {
            "show": false,
            "dest": "$SNI_DOMAIN:443", // SNI destination
            "xver": 0,
            "serverNames": ["$SNI_DOMAIN"], // SNI for handshake
            "privateKey": "$REALITY_PRIVATE_KEY",
            "shortIds": ["$REALITY_SHORT_ID"], // Random shortId for obfuscation
            "spiderX": "/" // SpiderX path for advanced obfuscation
          },
          "fingerprint": "chrome" // Simulate Chrome browser
        },
        "tag": "vless-reality"
      }
    ],
    "outbounds": [
      {
        "protocol": "freedom",
        "tag": "direct"
      }
    ]
  }
}
EOF

# Restart 3x-ui to apply configuration
systemctl restart x-ui

print_status "Reality protocol configured successfully"

# =============================================================================
# 7. SSL Auto-renewal Setup
# =============================================================================
print_header "Step 7: SSL Auto-renewal Setup"

# Create renewal script
cat > /usr/local/bin/renew-ssl.sh << 'EOF'
#!/bin/bash
certbot renew --quiet
systemctl reload nginx
EOF

chmod +x /usr/local/bin/renew-ssl.sh

# Add to crontab for auto-renewal
(crontab -l 2>/dev/null; echo "0 12 * * * /usr/local/bin/renew-ssl.sh") | crontab -

print_status "SSL auto-renewal configured"

# =============================================================================
# 8. Final Configuration and Information
# =============================================================================
print_header "Step 8: Final Configuration"

# Wait a bit more for services to be fully ready
sleep 5

# Create connection information file
cat > /root/vpn-info.txt << EOF
===========================================
    VPN Server Configuration Summary
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
   Short ID: $REALITY_SHORT_ID
   SNI: $SNI_DOMAIN
   Fingerprint: chrome
   SpiderX: /
   Server Name: $SNI_DOMAIN
   Port: 443

📱 VLESS Connection String:
   vless://$DEFAULT_UUID@$DOMAIN:443?encryption=none&security=reality&sni=$SNI_DOMAIN&fp=chrome&pbk=$REALITY_PUBLIC_KEY&type=tcp&flow=xtls-rprx-vision&sid=$REALITY_SHORT_ID&spx=/#VPN-Server

🔧 Manual Configuration:
   Protocol: VLESS
   Address: $DOMAIN
   Port: 443
   UUID: $DEFAULT_UUID
   Encryption: none
   Transport: tcp
   Security: reality
   SNI: $SNI_DOMAIN
   Public Key: $REALITY_PUBLIC_KEY
   Flow: xtls-rprx-vision

⚠️  IMPORTANT NOTES:
   - All traffic is routed through port 443
   - Server IP is hidden (domain-only access)
   - Reality protocol mimics Google's TLS handshake
   - SSL certificate auto-renews every 60 days
   - Firewall allows: 22, 80, 443, 54321

🔧 Management Commands:
   - View logs: journalctl -u x-ui -f
   - Restart panel: systemctl restart x-ui
   - Check status: systemctl status x-ui
   - SSL renewal: /usr/local/bin/renew-ssl.sh

Generated on: $(date)
EOF

# Display final information
print_header "🎉 Installation Complete!"
echo ""
print_status "3x-ui Panel URL: https://$DOMAIN"
print_status "Admin Username: $ADMIN_USERNAME"
print_status "Admin Password: $ADMIN_PASSWORD"
echo ""
print_status "Reality UUID: $DEFAULT_UUID"
print_status "Reality Public Key: $REALITY_PUBLIC_KEY"
echo ""
print_status "VLESS Connection String:"
echo "vless://$DEFAULT_UUID@$DOMAIN:443?encryption=none&security=reality&sni=$SNI_DOMAIN&fp=chrome&pbk=$REALITY_PUBLIC_KEY&type=tcp&flow=xtls-rprx-vision&sid=$REALITY_SHORT_ID&spx=/#VPN-Server"
echo ""
print_status "Configuration saved to: /root/vpn-info.txt"
echo ""
print_warning "Please wait 2-3 minutes for all services to fully initialize"
print_warning "Then access the panel at: https://$DOMAIN"
echo ""
print_status "Installation completed successfully! 🚀" 