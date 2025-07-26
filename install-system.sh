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
echo "  • Configure Apache2 reverse proxy (optional)"
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

read -p "Do you want to install Apache2 reverse proxy? [y/N]: " INSTALL_NGINX
read -p "Do you want to enable editing capabilities? [y/N]: " ENABLE_EDITING

if [[ $INSTALL_NGINX =~ ^[Yy]$ ]]; then
    read -p "Do you want to set up SSL with Let's Encrypt? [y/N]: " SETUP_SSL
    if [[ $SETUP_SSL =~ ^[Yy]$ ]]; then
        read -p "Enter email address for Let's Encrypt notifications: " CERTBOT_EMAIL
        if [[ -z "$CERTBOT_EMAIL" ]]; then
            print_error "Email address is required for Let's Encrypt"
            exit 1
        fi
    fi
fi

echo
print_info "Installing with the following configuration:"
echo "  • Domain: ${DOMAIN_NAME:-localhost}"
echo "  • Port: $APP_PORT"
echo "  • Apache2: ${INSTALL_NGINX:-No}"
echo "  • SSL: ${SETUP_SSL:-No}"
if [[ $SETUP_SSL =~ ^[Yy]$ ]]; then
    echo "  • SSL Email: $CERTBOT_EMAIL"
fi
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
PACKAGES="python3 python3-pip python3-venv apache2 logrotate"
if [[ $SETUP_SSL =~ ^[Yy]$ ]]; then
    PACKAGES="$PACKAGES certbot python3-certbot-apache"
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

# Fix Flask to listen on all interfaces for Apache2 proxy
print_info "Configuring Flask to listen on all interfaces..."
sed -i "s/app.run(debug=True)/app.run(debug=True, host='0.0.0.0', port=$APP_PORT)/" $APP_DIR/api.py
print_success "Flask configured to listen on all interfaces"

print_success "Application files installed"

# Create virtual environment
print_info "Creating Python virtual environment..."
if [[ ! -d "$APP_DIR/venv" ]]; then
    sudo -u $APP_USER python3 -m venv $APP_DIR/venv
fi
sudo -u $APP_USER $APP_DIR/venv/bin/pip install --upgrade pip
sudo -u $APP_USER $APP_DIR/venv/bin/pip install -r $APP_DIR/requirements.txt
print_success "Virtual environment created and dependencies installed"

# Move data file to data directory
if [[ -f "$APP_DIR/enumbers.json" ]]; then
    # Check if it's already a symlink or if the target already exists
    if [[ -L "$APP_DIR/enumbers.json" ]]; then
        print_info "Data file already linked to $DATA_DIR"
    elif [[ -f "$DATA_DIR/enumbers.json" ]]; then
        # Target already exists, just create symlink
        rm -f $APP_DIR/enumbers.json
        ln -sf $DATA_DIR/enumbers.json $APP_DIR/enumbers.json
        print_success "Data file linked to $DATA_DIR"
    else
        # Move the file and create symlink
        mv $APP_DIR/enumbers.json $DATA_DIR/
        chown $APP_USER:$APP_GROUP $DATA_DIR/enumbers.json
        ln -sf $DATA_DIR/enumbers.json $APP_DIR/enumbers.json
        print_success "Data file moved to $DATA_DIR"
    fi
fi

# Create configuration file
print_info "Creating configuration file..."
mkdir -p $CONFIG_DIR
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

# Set up Apache2 if requested
if [[ $INSTALL_NGINX =~ ^[Yy]$ ]]; then
    print_info "Configuring Apache2 reverse proxy..."
    
    # Enable required Apache modules
    a2enmod proxy
    a2enmod proxy_http
    a2enmod headers
    a2enmod rewrite
    
    cat > /etc/apache2/sites-available/enumbers.conf << EOF
<VirtualHost *:80>
    ServerName ${DOMAIN_NAME:-localhost}
    ServerAdmin webmaster@${DOMAIN_NAME:-localhost}
    
    # Security headers
    Header always set X-Frame-Options DENY
    Header always set X-Content-Type-Options nosniff
    Header always set X-XSS-Protection "1; mode=block"
    Header always set Referrer-Policy "strict-origin-when-cross-origin"
    
    # Logs
    ErrorLog \${APACHE_LOG_DIR}/enumbers_error.log
    CustomLog \${APACHE_LOG_DIR}/enumbers_access.log combined
    
    # Proxy to Flask application
    ProxyPreserveHost On
    ProxyPass / http://127.0.0.1:$APP_PORT/
    ProxyPassReverse / http://127.0.0.1:$APP_PORT/
    
    # Static files caching
    <LocationMatch "\.(css|js|png|jpg|jpeg|gif|ico|svg)$">
        Header set Cache-Control "public, max-age=31536000, immutable"
    </LocationMatch>
</VirtualHost>
EOF

    # Enable the site
    a2ensite enumbers.conf
    
    # Test Apache configuration
    if apache2ctl configtest; then
        print_success "Apache2 configuration is valid"
    else
        print_error "Apache2 configuration has errors"
        exit 1
    fi
fi

# Enable and start services
print_info "Enabling and starting services..."
systemctl daemon-reload
systemctl enable enumbers.service
systemctl start enumbers.service

if [[ $INSTALL_NGINX =~ ^[Yy]$ ]]; then
    systemctl enable apache2
    systemctl restart apache2
fi

# Wait for service to start
sleep 3

# Check service status
if systemctl is-active --quiet enumbers.service; then
    print_success "E-Numbers service is running"
    
    # Verify Flask is listening on the correct interface
    if netstat -tlnp | grep -q ":$APP_PORT.*LISTEN"; then
        print_success "Flask application is listening on port $APP_PORT"
    else
        print_warning "Flask application may not be listening properly"
    fi
else
    print_error "E-Numbers service failed to start"
    print_info "Check logs with: journalctl -u enumbers.service"
    exit 1
fi

# Set up SSL if requested
if [[ $SETUP_SSL =~ ^[Yy]$ && $INSTALL_NGINX =~ ^[Yy]$ ]]; then
    print_info "Setting up SSL certificate..."
    
    # Ensure Apache2 is running before certbot
    systemctl restart apache2
    
    # Run certbot with proper flags
    certbot --apache -d $DOMAIN_NAME --non-interactive --agree-tos --email $CERTBOT_EMAIL --redirect
    if [[ $? -eq 0 ]]; then
        print_success "SSL certificate installed"
        
        # Verify the SSL configuration
        print_info "Verifying SSL configuration..."
        apache2ctl configtest
        systemctl reload apache2
    else
        print_warning "SSL certificate installation failed"
        print_info "You can manually run: certbot --apache -d $DOMAIN_NAME"
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
a2dissite enumbers.conf
rm -f /etc/apache2/sites-available/enumbers.conf
rm -rf $APP_DIR $LOG_DIR $CONFIG_DIR
userdel $APP_USER
groupdel $APP_GROUP
rm -f /etc/logrotate.d/enumbers
rm -f /usr/local/bin/enumbers-*
crontab -l | grep -v enumbers-backup | crontab -
systemctl daemon-reload
systemctl reload apache2
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
        echo "  • https://${DOMAIN_NAME}/ (redirects to enumbers.html)"
    else
        echo "  • http://${DOMAIN_NAME}/enumbers.html"
        echo "  • http://${DOMAIN_NAME}/ (redirects to enumbers.html)"
    fi
else
    echo "  • http://localhost:$APP_PORT/enumbers.html"
    echo "  • http://localhost:$APP_PORT/ (redirects to enumbers.html)"
fi
echo
print_success "E-Numbers Application is now running as a system service!"

echo
print_info "Troubleshooting Commands:"
echo "  • Check service status: systemctl status enumbers.service"
echo "  • View recent logs: journalctl -u enumbers.service -n 20"
echo "  • Check if Flask is listening: netstat -tlnp | grep :$APP_PORT"
echo "  • Test API directly: curl http://127.0.0.1:$APP_PORT/api/enumbers"
echo "  • Check Apache2 status: systemctl status apache2"
echo "  • Test Apache2 config: apache2ctl configtest"
echo "  • View Apache2 logs: tail -f /var/log/apache2/error.log"
echo
print_info "If you encounter issues:"
echo "  1. Check the service logs: journalctl -u enumbers.service -f"
echo "  2. Verify Flask is listening on 0.0.0.0:$APP_PORT"
echo "  3. Test the API endpoint directly"
echo "  4. Check Apache2 proxy configuration"
echo "  5. Ensure SSL certificate is valid (if using HTTPS)" 