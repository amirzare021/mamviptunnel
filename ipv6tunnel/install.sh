#!/bin/bash

# IPv6 Tunnel Installation Script
# This script installs and configures the IPv6 tunneling service
# on either the source or destination server.

# Source utility libraries
BASE_DIR="$(dirname "$(readlink -f "$0")")"
source "$BASE_DIR/lib/utils.sh"
source "$BASE_DIR/lib/database.sh"
source "$BASE_DIR/lib/network.sh"
source "$BASE_DIR/lib/security.sh"
source "$BASE_DIR/lib/tunnel.sh"

# Display header
clear
display_header "IPv6 Tunneling Service Installation"
echo "This script will install and configure the IPv6 tunneling service."
echo "You will need to run this script on both the source and destination servers."
echo ""

# Check if running as root
check_root

# Check system requirements
check_requirements

# Initialize database directory
CONF_DIR="/etc/ipv6tunnel"
mkdir -p "$CONF_DIR" 2>/dev/null

# Create installation directory
INSTALL_DIR="/opt/ipv6tunnel"
mkdir -p "$INSTALL_DIR" 2>/dev/null

# Copy files to installation directory
echo "Installing files..."
cp -r "$BASE_DIR"/* "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR"/*.sh
chmod +x "$INSTALL_DIR/lib"/*.sh

# Create symbolic links for panel
ln -sf "$INSTALL_DIR/panel.sh" /usr/local/bin/ipv6tunnel

# Prompt for installation type
echo ""
echo "Please select the server type for installation:"
echo "1) Source Server (Client) - Traffic originates here"
echo "2) Destination Server (Server) - Traffic exits through this server"
read -p "Enter your choice [1-2]: " server_type

case "$server_type" in
    1)
        db_init "source"
        setup_source_server
        ;;
    2)
        db_init "destination"  
        setup_destination_server
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

# Install systemd service
echo "Installing systemd service..."
cp "$INSTALL_DIR/tunnel.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable tunnel.service
systemctl start tunnel.service

# Final steps
echo ""
echo "Installation complete!"
echo "You can manage the tunnel using: ipv6tunnel"
echo "Service can be controlled with: systemctl {start|stop|restart|status} tunnel"
echo ""

if [ "$server_type" -eq 1 ]; then
    echo "IMPORTANT: Make sure to also install this software on your destination server!"
fi

exit 0
