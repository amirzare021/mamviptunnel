#!/bin/bash

# IPv6 Tunnel Setup Script
# This script installs and configures the complete IPv6 tunneling service

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root."
    exit 1
fi

# Display header
clear
echo "======================================================================="
echo "                 IPv6 Tunneling Service Installation                   "
echo "======================================================================="
echo ""

# Set colors for better readability
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Install dependencies based on distribution
install_dependencies() {
    echo -e "${BLUE}Installing required dependencies...${NC}"
    
    # Detect distribution
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu
        apt-get update
        apt-get install -y iproute2 iptables ip6tables sqlite3 socat openssl curl net-tools
    elif [ -f /etc/redhat-release ]; then
        # CentOS/RHEL/Fedora
        if command -v dnf &>/dev/null; then
            dnf install -y iproute iptables-services sqlite socat openssl curl net-tools
        else
            yum install -y iproute iptables-services sqlite socat openssl curl net-tools
        fi
    else
        echo -e "${YELLOW}Unsupported distribution. Installing packages manually...${NC}"
        for pkg in iproute2 iptables ip6tables sqlite3 socat openssl curl net-tools; do
            if command -v apt-get &>/dev/null; then
                apt-get install -y $pkg
            elif command -v yum &>/dev/null; then
                yum install -y $pkg
            elif command -v dnf &>/dev/null; then
                dnf install -y $pkg
            elif command -v pacman &>/dev/null; then
                pacman -S --noconfirm $pkg
            else
                echo -e "${RED}Unable to install package $pkg. Please install it manually.${NC}"
            fi
        done
    fi
    
    echo -e "${GREEN}Dependency installation completed.${NC}"
}

# Enable IPv6
enable_ipv6() {
    echo -e "${BLUE}Checking IPv6 status...${NC}"
    
    # Check if IPv6 is disabled
    if [ -f /proc/sys/net/ipv6/conf/all/disable_ipv6 ] && [ "$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6)" == "1" ]; then
        echo -e "${YELLOW}IPv6 is disabled. Enabling it now...${NC}"
        
        # Enable IPv6 temporarily
        sysctl -w net.ipv6.conf.all.disable_ipv6=0
        
        # Enable IPv6 permanently
        echo "net.ipv6.conf.all.disable_ipv6=0" > /etc/sysctl.d/99-ipv6.conf
        echo "net.ipv6.conf.default.disable_ipv6=0" >> /etc/sysctl.d/99-ipv6.conf
        sysctl -p /etc/sysctl.d/99-ipv6.conf
        
        if [ "$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6)" == "1" ]; then
            echo -e "${RED}Failed to enable IPv6. Please enable it manually.${NC}"
            return 1
        else
            echo -e "${GREEN}IPv6 successfully enabled.${NC}"
        fi
    else
        echo -e "${GREEN}IPv6 is already enabled.${NC}"
    fi
    
    return 0
}

# Create directories
create_directories() {
    echo -e "${BLUE}Creating directories...${NC}"
    
    # Main directories
    mkdir -p /etc/ipv6tunnel
    mkdir -p /opt/ipv6tunnel
    mkdir -p /var/log/ipv6tunnel
    
    # Set permissions
    chmod 755 /etc/ipv6tunnel
    chmod 755 /opt/ipv6tunnel
    chmod 755 /var/log/ipv6tunnel
    
    echo -e "${GREEN}Directories created.${NC}"
}

# Create database
create_database() {
    echo -e "${BLUE}Creating database...${NC}"
    
    # Database file
    DB_FILE="/etc/ipv6tunnel/config.db"
    
    # Check if database already exists
    if [ -f "$DB_FILE" ]; then
        echo -e "${YELLOW}Database already exists. Backing up...${NC}"
        cp "$DB_FILE" "${DB_FILE}.bak.$(date +%s)"
    fi
    
    # Create new database
    sqlite3 "$DB_FILE" <<EOF
CREATE TABLE IF NOT EXISTS config (
    key TEXT PRIMARY KEY,
    value TEXT
);

CREATE TABLE IF NOT EXISTS excluded_ports (
    port INTEGER PRIMARY KEY
);
EOF
    
    # Set permissions
    chmod 644 "$DB_FILE"
    
    echo -e "${GREEN}Database created.${NC}"
}

# Generate SSL certificates
generate_certificates() {
    echo -e "${BLUE}Generating SSL certificates for encrypted tunnel...${NC}"
    
    # Certificate files
    CERT_FILE="/etc/ipv6tunnel/tunnel.crt"
    KEY_FILE="/etc/ipv6tunnel/tunnel.key"
    
    # Check if certificates already exist
    if [ -f "$CERT_FILE" ] && [ -f "$KEY_FILE" ]; then
        echo -e "${YELLOW}Certificates already exist. Generating new ones...${NC}"
    fi
    
    # Generate self-signed certificate
    openssl req -x509 -newkey rsa:4096 -keyout "$KEY_FILE" -out "$CERT_FILE" -days 3650 -nodes -subj "/CN=ipv6tunnel" 2>/dev/null
    
    # Set permissions
    chmod 600 "$KEY_FILE"
    chmod 644 "$CERT_FILE"
    
    echo -e "${GREEN}SSL certificates generated:${NC}"
    echo "Certificate: $CERT_FILE"
    echo "Key: $KEY_FILE"
}

# Create scripts
create_scripts() {
    echo -e "${BLUE}Installing scripts...${NC}"
    
    # Source directory
    SRC_DIR="$(dirname "$(readlink -f "$0")")"
    
    # Copy all files from lib directory
    cp -r "$SRC_DIR/lib" /opt/ipv6tunnel/
    chmod -R 755 /opt/ipv6tunnel/lib
    
    # Create main executable script
    cat > /usr/local/bin/ipv6tunnel <<EOF
#!/bin/bash
# IPv6 Tunnel Management Script

# Forward to the actual script
/opt/ipv6tunnel/panel.sh "\$@"
EOF
    
    # Copy panel script
    cp "$SRC_DIR/panel.sh" /opt/ipv6tunnel/
    chmod 755 /opt/ipv6tunnel/panel.sh
    
    # Set permission for the executable
    chmod 755 /usr/local/bin/ipv6tunnel
    
    echo -e "${GREEN}Scripts installed.${NC}"
}

# Create systemd service
create_service() {
    echo -e "${BLUE}Creating systemd service...${NC}"
    
    # Service file
    SERVICE_FILE="/etc/systemd/system/ipv6tunnel.service"
    
    # Create service file
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=IPv6 Tunneling Service
After=network.target

[Service]
Type=simple
ExecStart=/opt/ipv6tunnel/lib/tunnel.sh start
ExecStop=/opt/ipv6tunnel/lib/tunnel.sh stop
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd
    systemctl daemon-reload
    
    echo -e "${GREEN}Service created.${NC}"
}

# Configure server type
configure_server_type() {
    echo -e "${BLUE}Server configuration:${NC}"
    echo ""
    echo "Please select the server type:"
    echo "1) Source Server (Client) - Traffic originates here"
    echo "2) Destination Server (Server) - Traffic exits through this server"
    echo ""
    
    read -p "Enter your choice [1-2]: " server_choice
    
    case "$server_choice" in
        1)
            echo -e "${BLUE}Configuring as source server...${NC}"
            
            # Set server type in database
            sqlite3 /etc/ipv6tunnel/config.db "INSERT OR REPLACE INTO config (key, value) VALUES ('server_type', 'source')"
            
            # Get destination server
            read -p "Enter the IPv6 address of the destination server: " dest_server
            
            # Validate IPv6 address format
            if [[ ! "$dest_server" =~ ^[0-9a-fA-F:]+$ ]]; then
                echo -e "${RED}Invalid IPv6 address format. Please enter a valid IPv6 address.${NC}"
                exit 1
            fi
            
            # Set destination server in database
            sqlite3 /etc/ipv6tunnel/config.db "INSERT OR REPLACE INTO config (key, value) VALUES ('remote_server', '$dest_server')"
            
            # Get tunnel port
            read -p "Enter the tunnel port on destination server (default: 5000): " tunnel_port
            tunnel_port=${tunnel_port:-5000}
            
            # Set tunnel port in database
            sqlite3 /etc/ipv6tunnel/config.db "INSERT OR REPLACE INTO config (key, value) VALUES ('tunnel_port', '$tunnel_port')"
            
            echo -e "${GREEN}Source server configuration complete.${NC}"
            ;;
        2)
            echo -e "${BLUE}Configuring as destination server...${NC}"
            
            # Set server type in database
            sqlite3 /etc/ipv6tunnel/config.db "INSERT OR REPLACE INTO config (key, value) VALUES ('server_type', 'destination')"
            
            # Get tunnel port
            read -p "Enter the tunnel port to listen on (default: 5000): " tunnel_port
            tunnel_port=${tunnel_port:-5000}
            
            # Set tunnel port in database
            sqlite3 /etc/ipv6tunnel/config.db "INSERT OR REPLACE INTO config (key, value) VALUES ('tunnel_port', '$tunnel_port')"
            
            echo -e "${GREEN}Destination server configuration complete.${NC}"
            ;;
        *)
            echo -e "${RED}Invalid choice. Exiting.${NC}"
            exit 1
            ;;
    esac
}

# Start the service
start_service() {
    echo -e "${BLUE}Starting IPv6 tunnel service...${NC}"
    
    # Enable the service to start at boot
    systemctl enable ipv6tunnel.service
    
    # Start the service
    systemctl start ipv6tunnel.service
    
    # Check if service started successfully
    if systemctl is-active --quiet ipv6tunnel.service; then
        echo -e "${GREEN}Service started successfully.${NC}"
    else
        echo -e "${YELLOW}Service failed to start. Please check logs with: journalctl -u ipv6tunnel.service${NC}"
    fi
}

# Main installation process
main() {
    echo "This script will install the IPv6 tunneling service on this server."
    echo "You will need to run this script on both the source and destination servers."
    echo ""
    read -p "Press Enter to continue or Ctrl+C to abort..."
    
    # Install dependencies
    install_dependencies
    
    # Enable IPv6
    enable_ipv6
    
    # Create directories
    create_directories
    
    # Create database
    create_database
    
    # Generate SSL certificates
    generate_certificates
    
    # Create scripts
    create_scripts
    
    # Create systemd service
    create_service
    
    # Configure server type
    configure_server_type
    
    # Start the service
    start_service
    
    echo ""
    echo -e "${GREEN}Installation complete!${NC}"
    echo "You can manage the tunnel using the command: ipv6tunnel"
    echo "Service status can be checked with: systemctl status ipv6tunnel"
    echo ""
    
    if [ "$(sqlite3 /etc/ipv6tunnel/config.db "SELECT value FROM config WHERE key='server_type'")" == "source" ]; then
        echo -e "${YELLOW}IMPORTANT: Make sure to also run this script on your destination server!${NC}"
    fi
}

# Run the main function
main

exit 0