#!/bin/bash

#############################################################################
# Nginx Installation Script
# Description: Automatically detects Linux distribution and installs nginx
# Author: System Administrator
# Date: $(date)
# Usage: sudo ./install_nginx.sh
#############################################################################

set -e  # Exit on any error
set -u  # Exit on undefined variables

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Check if running as root or with sudo
check_privileges() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root or with sudo privileges"
        echo "Usage: sudo $0"
        exit 1
    fi
}

# Detect Linux distribution
detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
    elif [[ -f /etc/redhat-release ]]; then
        DISTRO="rhel"
    elif [[ -f /etc/debian_version ]]; then
        DISTRO="debian"
    else
        error "Unable to detect Linux distribution"
        exit 1
    fi
    
    log "Detected distribution: $DISTRO"
}

# Update package repositories
update_packages() {
    log "Updating package repositories..."
    
    case $DISTRO in
        ubuntu|debian)
            apt update -y
            ;;
        centos|rhel|fedora|rocky|almalinux)
            if command -v dnf &> /dev/null; then
                dnf update -y
            else
                yum update -y
            fi
            ;;
        arch|manjaro)
            pacman -Sy
            ;;
        opensuse*|sles)
            zypper refresh
            ;;
        *)
            warning "Unknown distribution: $DISTRO. Attempting generic installation..."
            ;;
    esac
}

# Install nginx based on distribution
install_nginx() {
    log "Installing nginx..."
    
    case $DISTRO in
        ubuntu|debian)
            apt install -y nginx
            ;;
        centos|rhel|rocky|almalinux)
            if command -v dnf &> /dev/null; then
                dnf install -y nginx
            else
                yum install -y nginx
            fi
            ;;
        fedora)
            dnf install -y nginx
            ;;
        arch|manjaro)
            pacman -S --noconfirm nginx
            ;;
        opensuse*|sles)
            zypper install -y nginx
            ;;
        *)
            error "Unsupported distribution for automatic installation: $DISTRO"
            exit 1
            ;;
    esac
}

# Configure firewall for nginx
configure_firewall() {
    log "Configuring firewall for nginx..."
    
    # Check if ufw is available (Ubuntu/Debian)
    if command -v ufw &> /dev/null; then
        ufw allow 'Nginx Full' 2>/dev/null || ufw allow 80/tcp && ufw allow 443/tcp
        info "UFW firewall rules added for nginx"
    # Check if firewalld is available (CentOS/RHEL/Fedora)
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-service=https
        firewall-cmd --reload
        info "Firewalld rules added for nginx"
    # Check if iptables is available
    elif command -v iptables &> /dev/null; then
        iptables -A INPUT -p tcp --dport 80 -j ACCEPT
        iptables -A INPUT -p tcp --dport 443 -j ACCEPT
        info "Iptables rules added for nginx"
    else
        warning "No firewall detected or unable to configure automatically"
        warning "Please manually configure your firewall to allow HTTP (80) and HTTPS (443) traffic"
    fi
}

# Start and enable nginx service
start_nginx() {
    log "Starting and enabling nginx service..."
    
    systemctl start nginx
    systemctl enable nginx
    
    if systemctl is-active --quiet nginx; then
        log "Nginx service is running successfully"
    else
        error "Failed to start nginx service"
        exit 1
    fi
}

# Test nginx installation
test_nginx() {
    log "Testing nginx installation..."
    
    # Test nginx configuration
    if nginx -t &> /dev/null; then
        log "Nginx configuration test passed"
    else
        error "Nginx configuration test failed"
        nginx -t
        exit 1
    fi
    
    # Test if nginx is responding on port 80
    if curl -s http://localhost &> /dev/null; then
        log "Nginx is responding on port 80"
    else
        warning "Nginx may not be responding on port 80. Check your configuration."
    fi
}

# Display installation summary
show_summary() {
    echo
    echo "=============================================="
    log "Nginx Installation Complete!"
    echo "=============================================="
    echo
    info "Nginx version: $(nginx -v 2>&1 | cut -d' ' -f3)"
    info "Nginx status: $(systemctl is-active nginx)"
    info "Nginx enabled: $(systemctl is-enabled nginx)"
    echo
    info "Configuration file: /etc/nginx/nginx.conf"
    info "Default document root: /var/www/html (may vary by distribution)"
    info "Access logs: /var/log/nginx/access.log"
    info "Error logs: /var/log/nginx/error.log"
    echo
    info "Useful commands:"
    echo "  - Start nginx:     sudo systemctl start nginx"
    echo "  - Stop nginx:      sudo systemctl stop nginx"
    echo "  - Restart nginx:   sudo systemctl restart nginx"
    echo "  - Reload config:   sudo systemctl reload nginx"
    echo "  - Test config:     sudo nginx -t"
    echo "  - Check status:    sudo systemctl status nginx"
    echo
    info "You can now access your web server at: http://$(hostname -I | awk '{print $1}')"
    echo
}

# Cleanup function for error handling
cleanup() {
    if [[ $? -ne 0 ]]; then
        error "Installation failed. Please check the error messages above."
        echo
        info "You can try running the script again or install nginx manually:"
        echo "  Ubuntu/Debian: sudo apt install nginx"
        echo "  CentOS/RHEL:   sudo yum install nginx"
        echo "  Fedora:        sudo dnf install nginx"
    fi
}

# Set trap for cleanup
trap cleanup EXIT

# Main installation process
main() {
    echo "=============================================="
    log "Starting Nginx Installation"
    echo "=============================================="
    echo
    
    check_privileges
    detect_distro
    update_packages
    install_nginx
    configure_firewall
    start_nginx
    test_nginx
    show_summary
}

# Run main function
main "$@"