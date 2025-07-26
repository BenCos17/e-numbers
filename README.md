# E-Numbers Lookup Application

A web application for looking up E-number food additives with data from Open Food Facts.

## 🚀 Quick Installation

### **Windows (Development)**
```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/YOUR_USERNAME/e-numbers/main/install.bat" -OutFile "install.bat"; .\install.bat
```

### **Linux (Production Server)**
```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/e-numbers/main/install-system.sh | sudo bash
```

## 📦 Manual Installation

### **Clone Repository**
```bash
git clone https://github.com/YOUR_USERNAME/e-numbers.git
cd e-numbers
```

### **Windows**
```batch
install.bat
```

### **Linux Production**
```bash
sudo ./install-system.sh
```

## 🔧 Development Setup

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Run the application:
```bash
# Basic mode
python api.py

# With editing capabilities
python api.py --allow-editing
```

3. Open browser to: `http://localhost:5000/enumbers.html`

## 🛡️ Security Features

- Content Security Policy (CSP) headers
- Input sanitization and validation
- XSS protection
- CSRF protection
- Rate limiting
- Secure headers (X-Frame-Options, X-Content-Type-Options, etc.)

## 📊 Production Features (Linux)

- Systemd service with auto-restart
- Nginx reverse proxy with SSL
- Log rotation
- Automated backups
- Security hardening
- Management commands

## 🎯 Management Commands (Production)

```bash
enumbers-status    # Show service status
enumbers-logs      # Follow logs
enumbers-restart   # Restart service
enumbers-backup    # Create backup
enumbers-uninstall # Remove everything
```

## 📝 API Endpoints

- `GET /api/enumbers` - Get all E-numbers
- `GET /api/enumbers?q=search` - Search E-numbers
- `POST /api/enumbers` - Create new E-number (editing mode)
- `PUT /api/enumbers/<code>` - Update E-number (editing mode)
- `DELETE /api/enumbers/<code>` - Delete E-number (editing mode)

## 🔄 Data Updates

The application automatically fetches the latest E-number data from Open Food Facts daily.

Manual update:
```bash
POST /api/update_enumbers_from_off_additives
```

## 📄 License

See [LICENSE](license) file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request 