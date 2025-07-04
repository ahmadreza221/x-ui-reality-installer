# 🚀 Fully Automated VPN Deployment with 3x-ui (Sanaei Panel)

A production-grade, fully automated installation script for deploying a VPN server using **3x-ui panel** with **VLESS + TCP + Reality protocol** over IPv4 and IPv6 with domain-based SSL configuration.

## ✨ Features

- 🔐 **VLESS + TCP + Reality Protocol** - Advanced traffic obfuscation
- 🌐 **Domain-based Access** - No direct IP exposure
- 🔒 **Automatic SSL/TLS** - Let's Encrypt certificates
- 📱 **IPv4 & IPv6 Support** - Dual-stack networking
- 🛡️ **Secure Firewall** - UFW with proper rules
- 🔄 **Auto-renewal** - SSL certificates and services
- 📊 **Web-based Management** - 3x-ui admin panel
- 🎯 **Production Ready** - Complete automation

## 📋 Prerequisites

- **Ubuntu 20.04+** server
- **Domain name** pointing to your server
- **Root access** to the server
- **Ports available**: 22 (SSH), 80, 443, 54321

## 🚀 Quick Installation

### 1. Clone the Repository
```bash
git clone https://github.com/yourusername/x-ui-reality-installer.git
cd x-ui-reality-installer
```

### 2. Run the Installation Script
```bash
DOMAIN=yourdomain.com EMAIL=you@example.com ./setup.sh
```

**Optional Parameters:**
```bash
DOMAIN=yourdomain.com \
EMAIL=you@example.com \
ADMIN_USERNAME=admin \
ADMIN_PASSWORD=mypassword \
./setup.sh
```

### 3. Wait for Installation
The script will automatically:
- Update system packages
- Install Docker and dependencies
- Configure firewall (UFW)
- Obtain SSL certificate
- Install and configure 3x-ui panel
- Set up Reality protocol
- Configure Nginx reverse proxy
- Set up auto-renewal

## 📊 What Gets Installed

### System Components
- **Docker** - Container runtime
- **Nginx** - Reverse proxy
- **UFW** - Firewall
- **Certbot** - SSL certificates
- **3x-ui Panel** - VPN management

### Network Configuration
- **Port 22** - SSH access
- **Port 80** - HTTP (redirects to HTTPS)
- **Port 443** - HTTPS + Reality protocol
- **Port 54321** - 3x-ui panel (internal)

### Security Features
- **Let's Encrypt SSL** - Automatic certificates
- **Reality Protocol** - Traffic obfuscation
- **Domain-only Access** - IP hiding
- **Secure Firewall** - Minimal open ports

## 🔧 Post-Installation

### 1. Access the Admin Panel
- **URL**: `https://yourdomain.com`
- **Username**: `admin` (or custom)
- **Password**: Generated during installation

### 2. Check Installation Status
```bash
# Check 3x-ui service
systemctl status x-ui

# Check Nginx service
systemctl status nginx

# View logs
journalctl -u x-ui -f
```

### 3. View Configuration
```bash
cat /root/vpn-info.txt
```

## 📱 Client Configuration

### V2RayN (Windows)
1. Download [V2RayN](https://github.com/2dust/v2rayN/releases)
2. Add new server with these settings:
   - **Protocol**: VLESS
   - **Address**: `yourdomain.com`
   - **Port**: `443`
   - **UUID**: Generated UUID
   - **Encryption**: `none`
   - **Transport**: `tcp`
   - **Security**: `reality`
   - **SNI**: `www.google.com`
   - **Public Key**: Generated public key
   - **Flow**: `xtls-rprx-vision`

### V2RayNG (Android)
1. Download [V2RayNG](https://github.com/2dust/v2rayNG/releases)
2. Import the VLESS connection string from `/root/vpn-info.txt`
3. Or manually configure with the same settings as V2RayN

### Shadowrocket (iOS)
1. Download [Shadowrocket](https://apps.apple.com/app/shadowrocket/id932747118)
2. Add new configuration:
   - **Type**: VLESS
   - **Server**: `yourdomain.com`
   - **Port**: `443`
   - **UUID**: Generated UUID
   - **Encryption**: `none`
   - **Transport**: `tcp`
   - **Security**: `reality`
   - **SNI**: `www.google.com`
   - **Public Key**: Generated public key
   - **Flow**: `xtls-rprx-vision`

### Clash (Cross-platform)
```yaml
proxies:
  - name: "VPN-Server"
    type: vless
    server: yourdomain.com
    port: 443
    uuid: your-uuid-here
    network: tcp
    tls: true
    udp: true
    reality-opts:
      public-key: your-public-key-here
      short-id: ""
    client-fingerprint: chrome
    flow: xtls-rprx-vision
```

## 🔧 Management Commands

### Service Management
```bash
# Restart 3x-ui panel
systemctl restart x-ui

# Check 3x-ui status
systemctl status x-ui

# View 3x-ui logs
journalctl -u x-ui -f

# Restart Nginx
systemctl restart nginx

# Check SSL certificate
certbot certificates
```

### SSL Certificate Management
```bash
# Manual renewal
certbot renew

# Check renewal status
systemctl status certbot.timer

# View renewal logs
journalctl -u certbot.timer
```

### Firewall Management
```bash
# Check UFW status
ufw status

# Allow additional ports
ufw allow 8080

# Deny ports
ufw deny 8080
```

## 📊 Monitoring and Logs

### View Real-time Logs
```bash
# 3x-ui panel logs
journalctl -u x-ui -f

# Nginx logs
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log

# System logs
journalctl -f
```

### Check Resource Usage
```bash
# System resources
htop

# Disk usage
df -h

# Memory usage
free -h

# Network connections
netstat -tulpn
```

## 🔒 Security Best Practices

### 1. Regular Updates
```bash
# Update system packages
apt update && apt upgrade -y

# Update 3x-ui panel
cd /usr/local/x-ui
wget -O x-ui-linux-amd64.tar.gz https://github.com/MHSanaei/3x-ui/releases/latest/download/x-ui-linux-amd64.tar.gz
tar -xzf x-ui-linux-amd64.tar.gz
systemctl restart x-ui
```

### 2. Backup Configuration
```bash
# Backup 3x-ui database
cp /usr/local/x-ui/x-ui.db /root/x-ui-backup-$(date +%Y%m%d).db

# Backup SSL certificates
cp -r /etc/letsencrypt/live/yourdomain.com /root/ssl-backup-$(date +%Y%m%d)
```

### 3. Monitor Access
```bash
# Check failed login attempts
grep "Failed login" /var/log/auth.log

# Monitor SSH access
grep "sshd" /var/log/auth.log
```

## 🐛 Troubleshooting

### Common Issues

#### 1. SSL Certificate Issues
```bash
# Check certificate status
certbot certificates

# Renew manually
certbot renew --force-renewal

# Check Nginx configuration
nginx -t
```

#### 2. 3x-ui Panel Not Accessible
```bash
# Check service status
systemctl status x-ui

# Check port binding
netstat -tulpn | grep 54321

# Restart service
systemctl restart x-ui
```

#### 3. Reality Protocol Not Working
```bash
# Check Xray configuration
cat /usr/local/x-ui/config.json

# Check logs
journalctl -u x-ui -f

# Verify keys
echo "Private Key: $(grep privateKey /usr/local/x-ui/config.json)"
echo "Public Key: $(grep publicKey /usr/local/x-ui/config.json)"
```

#### 4. Firewall Issues
```bash
# Check UFW status
ufw status verbose

# Reset firewall
ufw --force reset

# Reconfigure firewall
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 54321/tcp
ufw --force enable
```

## 📈 Performance Optimization

### 1. System Tuning
```bash
# Optimize network settings
echo 'net.core.default_qdisc=fq' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_congestion_control=bbr' >> /etc/sysctl.conf
sysctl -p
```

### 2. Nginx Optimization
```bash
# Edit Nginx configuration
nano /etc/nginx/nginx.conf

# Add to http block:
# worker_processes auto;
# worker_connections 1024;
# keepalive_timeout 65;
```

### 3. Database Optimization
```bash
# Optimize SQLite database
sqlite3 /usr/local/x-ui/x-ui.db "VACUUM;"
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [MHSanaei](https://github.com/MHSanaei/3x-ui) - 3x-ui panel
- [Project X](https://github.com/XTLS/Xray-core) - Xray core
- [Let's Encrypt](https://letsencrypt.org/) - SSL certificates

## 📞 Support

If you encounter any issues:

1. Check the [troubleshooting section](#-troubleshooting)
2. Review the logs using the commands above
3. Open an issue on GitHub with detailed information
4. Include your system information and error logs

---

**⚠️ Disclaimer**: This tool is for educational and legitimate use only. Users are responsible for complying with local laws and regulations. 