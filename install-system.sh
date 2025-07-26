#!/bin/bash

# E-Numbers Application System Installer
# This script installs the application as a systemd service

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }

# Configuration
APP_NAME="enumbers"
APP_USER="enumbers"
APP_GROUP="enumbers"
APP_DIR="/opt/enumbers"
LOG_DIR="/var/log/enumbers"
DATA_DIR="/var/lib/enumbers"
CONFIG_DIR="/etc/enumbers"
SYSTEMD_DIR="/etc/systemd/system"
NGINX_AVAILABLE="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"

echo "============================================================"
echo "E-Numbers Application System Installer"
echo "============================================================"
echo
print_info "This installer will:"
echo "  • Create system user and group"
echo "  • Install application to $APP_DIR"
echo "  • Create systemd service"
echo "  • Set up log rotation"
echo "  • Configure nginx reverse proxy (optional)"
echo "  • Set up SSL with Let's Encrypt (optional)"
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root (use sudo)"
   exit 1
fi

# Check if systemd is available
if ! systemctl --version &> /dev/null; then
    print_error "systemd is not available on this system"
    exit 1
fi

print_success "Running as root with systemd available"

# Get configuration from user
read -p "Enter domain name for the application (e.g., enumbers.example.com): " DOMAIN_NAME
read -p "Enter port for the application [5000]: " APP_PORT
APP_PORT=${APP_PORT:-5000}

read -p "Do you want to install nginx reverse proxy? [y/N]: " INSTALL_NGINX
read -p "Do you want to enable editing capabilities? [y/N]: " ENABLE_EDITING

if [[ $INSTALL_NGINX =~ ^[Yy]$ ]]; then
    read -p "Do you want to set up SSL with Let's Encrypt? [y/N]: " SETUP_SSL
fi

echo
print_info "Installing with the following configuration:"
echo "  • Domain: ${DOMAIN_NAME:-localhost}"
echo "  • Port: $APP_PORT"
echo "  • Nginx: ${INSTALL_NGINX:-No}"
echo "  • SSL: ${SETUP_SSL:-No}"
echo "  • Editing: ${ENABLE_EDITING:-No}"
echo

read -p "Continue with installation? [y/N]: " CONFIRM
if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    print_warning "Installation cancelled"
    exit 0
fi

# Update system packages
print_info "Updating system packages..."
apt update && apt upgrade -y
print_success "System packages updated"

# Install required system packages
print_info "Installing required system packages..."
PACKAGES="python3 python3-pip python3-venv nginx logrotate"
if [[ $SETUP_SSL =~ ^[Yy]$ ]]; then
    PACKAGES="$PACKAGES certbot python3-certbot-nginx"
fi
apt install -y $PACKAGES
print_success "System packages installed"

# Create application user and group
print_info "Creating application user and group..."
if ! getent group $APP_GROUP > /dev/null 2>&1; then
    groupadd --system $APP_GROUP
    print_success "Created group: $APP_GROUP"
fi

if ! getent passwd $APP_USER > /dev/null 2>&1; then
    useradd --system --gid $APP_GROUP --shell /bin/false \
            --home-dir $APP_DIR --create-home $APP_USER
    print_success "Created user: $APP_USER"
fi

# Create application directories
print_info "Creating application directories..."
mkdir -p $APP_DIR $LOG_DIR $DATA_DIR $CONFIG_DIR
chown $APP_USER:$APP_GROUP $APP_DIR $LOG_DIR $DATA_DIR
chmod 755 $APP_DIR $CONFIG_DIR
chmod 750 $LOG_DIR $DATA_DIR
print_success "Application directories created"

# Install application files
print_info "Installing application files..."
cp -r . $APP_DIR/
chown -R $APP_USER:$APP_GROUP $APP_DIR
chmod +x $APP_DIR/*.py

# Create virtual environment
print_info "Creating Python virtual environment..."
sudo -u $APP_USER python3 -m venv $APP_DIR/venv
sudo -u $APP_USER $APP_DIR/venv/bin/pip install --upgrade pip
sudo -u $APP_USER $APP_DIR/venv/bin/pip install -r $APP_DIR/requirements.txt
print_success "Virtual environment created and dependencies installed"

# Move data file to data directory
if [[ -f "$APP_DIR/enumbers.json" ]]; then
    mv $APP_DIR/enumbers.json $DATA_DIR/
    chown $APP_USER:$APP_GROUP $DATA_DIR/enumbers.json
    ln -sf $DATA_DIR/enumbers.json $APP_DIR/enumbers.json
    print_success "Data file moved to $DATA_DIR"
fi

# Create configuration file
print_info "Creating configuration file..."
cat > $CONFIG_DIR/enumbers.conf << EOF
# E-Numbers Application Configuration
PORT=$APP_PORT
HOST=127.0.0.1
DEBUG=false
ALLOW_EDITING=${ENABLE_EDITING,,}
DATA_FILE=$DATA_DIR/enumbers.json
LOG_FILE=$LOG_DIR/enumbers.log
LOG_LEVEL=INFO
EOF
chown root:$APP_GROUP $CONFIG_DIR/enumbers.conf
chmod 640 $CONFIG_DIR/enumbers.conf
print_success "Configuration file created"

# Create systemd service file
print_info "Creating systemd service..."
cat > $SYSTEMD_DIR/enumbers.service << EOF
[Unit]
Description=E-Numbers Application
After=network.target
Wants=network.target

[Service]
Type=simple
User=$APP_USER
Group=$APP_GROUP
WorkingDirectory=$APP_DIR
Environment=PATH=$APP_DIR/venv/bin
ExecStart=$APP_DIR/venv/bin/python api.py$([ "$ENABLE_EDITING" = "y" ] && echo " --allow-editing" || echo "")
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=enumbers

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=$DATA_DIR $LOG_DIR
ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true

[Install]
WantedBy=multi-user.target
EOF
print_success "Systemd service created"

# Create log rotation configuration
print_info "Setting up log rotation..."
cat > /etc/logrotate.d/enumbers << EOF
$LOG_DIR/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    copytruncate
    create 644 $APP_USER $APP_GROUP
}
EOF
print_success "Log rotation configured"

# Set up nginx if requested
if [[ $INSTALL_NGINX =~ ^[Yy]$ ]]; then
    print_info "Configuring nginx reverse proxy..."
    
    cat > $NGINX_AVAILABLE/enumbers << EOF
server {
    listen 80;
    server_name ${DOMAIN_NAME:-localhost};
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Referrer-Policy strict-origin-when-cross-origin;
    
    # Logs
    access_log /var/log/nginx/enumbers_access.log;
    error_log /var/log/nginx/enumbers_error.log;
    
    # Rate limiting
    location / {
        limit_req zone=general burst=10 nodelay;
        proxy_pass http://127.0.0.1:$APP_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # Static files caching
    location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

    # Create rate limiting zone in nginx.conf if not exists
    if ! grep -q "limit_req_zone" /etc/nginx/nginx.conf; then
        sed -i '/http {/a\\tlimit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;' /etc/nginx/nginx.conf
    fi
    
    # Enable the site
    ln -sf $NGINX_AVAILABLE/enumbers $NGINX_ENABLED/
    
    # Test nginx configuration
    if nginx -t; then
        print_success "Nginx configuration is valid"
    else
        print_error "Nginx configuration has errors"
        exit 1
    fi
fi

# Enable and start services
print_info "Enabling and starting services..."
systemctl daemon-reload
systemctl enable enumbers.service
systemctl start enumbers.service

if [[ $INSTALL_NGINX =~ ^[Yy]$ ]]; then
    systemctl enable nginx
    systemctl restart nginx
fi

# Wait for service to start
sleep 3

# Check service status
if systemctl is-active --quiet enumbers.service; then
    print_success "E-Numbers service is running"
else
    print_error "E-Numbers service failed to start"
    print_info "Check logs with: journalctl -u enumbers.service"
    exit 1
fi

# Set up SSL if requested
if [[ $SETUP_SSL =~ ^[Yy]$ && $INSTALL_NGINX =~ ^[Yy]$ ]]; then
    print_info "Setting up SSL certificate..."
    certbot --nginx -d $DOMAIN_NAME --non-interactive --agree-tos --email admin@$DOMAIN_NAME
    if [[ $? -eq 0 ]]; then
        print_success "SSL certificate installed"
    else
        print_warning "SSL certificate installation failed"
    fi
fi

# Create management scripts
print_info "Creating management scripts..."
cat > /usr/local/bin/enumbers-status << 'EOF'
#!/bin/bash
echo "E-Numbers Application Status"
echo "=========================="
systemctl status enumbers.service
echo
echo "Recent logs:"
journalctl -u enumbers.service --no-pager -n 10
EOF

cat > /usr/local/bin/enumbers-logs << 'EOF'
#!/bin/bash
journalctl -u enumbers.service -f
EOF

cat > /usr/local/bin/enumbers-restart << 'EOF'
#!/bin/bash
systemctl restart enumbers.service
echo "E-Numbers service restarted"
EOF

chmod +x /usr/local/bin/enumbers-*
print_success "Management scripts created"

# Create backup script
print_info "Creating backup script..."
cat > /usr/local/bin/enumbers-backup << EOF
#!/bin/bash
BACKUP_DIR="/var/backups/enumbers"
DATE=\$(date +%Y%m%d-%H%M%S)
mkdir -p \$BACKUP_DIR
tar -czf \$BACKUP_DIR/enumbers-\$DATE.tar.gz -C $DATA_DIR .
find \$BACKUP_DIR -name "enumbers-*.tar.gz" -mtime +30 -delete
echo "Backup created: \$BACKUP_DIR/enumbers-\$DATE.tar.gz"
EOF
chmod +x /usr/local/bin/enumbers-backup

# Add backup to crontab
(crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/enumbers-backup") | crontab -
print_success "Backup script created and scheduled"

# Create uninstall script
cat > /usr/local/bin/enumbers-uninstall << EOF
#!/bin/bash
echo "Uninstalling E-Numbers Application..."
systemctl stop enumbers.service
systemctl disable enumbers.service
rm -f $SYSTEMD_DIR/enumbers.service
rm -f $NGINX_ENABLED/enumbers
rm -f $NGINX_AVAILABLE/enumbers
rm -rf $APP_DIR $LOG_DIR $CONFIG_DIR
userdel $APP_USER
groupdel $APP_GROUP
rm -f /etc/logrotate.d/enumbers
rm -f /usr/local/bin/enumbers-*
crontab -l | grep -v enumbers-backup | crontab -
systemctl daemon-reload
systemctl reload nginx
echo "E-Numbers Application uninstalled"
EOF
chmod +x /usr/local/bin/enumbers-uninstall

echo
echo "============================================================"
print_success "Installation completed successfully!"
echo "============================================================"
echo
print_info "Application Information:"
echo "  • Service: enumbers.service"
echo "  • Status: systemctl status enumbers"
echo "  • Logs: journalctl -u enumbers -f"
echo "  • Config: $CONFIG_DIR/enumbers.conf"
echo "  • Data: $DATA_DIR/"
echo
print_info "Management Commands:"
echo "  • enumbers-status    - Show service status"
echo "  • enumbers-logs      - Follow logs"
echo "  • enumbers-restart   - Restart service"
echo "  • enumbers-backup    - Create backup"
echo "  • enumbers-uninstall - Remove everything"
echo
print_info "Access URLs:"
if [[ $INSTALL_NGINX =~ ^[Yy]$ ]]; then
    if [[ $SETUP_SSL =~ ^[Yy]$ ]]; then
        echo "  • https://${DOMAIN_NAME}/enumbers.html"
    else
        echo "  • http://${DOMAIN_NAME}/enumbers.html"
    fi
else
    echo "  • http://localhost:$APP_PORT/enumbers.html"
fi
echo
print_success "E-Numbers Application is now running as a system service!" 