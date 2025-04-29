#!/bin/bash

# IPv6 Tunnel Management Panel
# Terminal-based management interface for the IPv6 tunneling service
# Modified version for Replit testing environment

# Set flag for Replit environment
export REPLIT_ENVIRONMENT="true"

# Initialize demo data (only in Replit)
mkdir -p "data"
TEMP_DB="data/config.db"

# Check if database exists, if not create it
if [ ! -f "$TEMP_DB" ]; then
    # Create a temporary SQLite database
    sqlite3 "$TEMP_DB" <<EOF
CREATE TABLE config (
    key TEXT PRIMARY KEY,
    value TEXT
);

CREATE TABLE excluded_ports (
    port INTEGER PRIMARY KEY
);

-- Initialize with sample data
INSERT INTO config (key, value) VALUES ('server_type', 'destination');
INSERT INTO config (key, value) VALUES ('tunnel_mode', 'wireguard');
INSERT INTO config (key, value) VALUES ('remote_server', '2001:db8:1234:5678::1');
INSERT INTO config (key, value) VALUES ('mtu', '1420');
INSERT INTO config (key, value) VALUES ('verbose', 'true');

-- Add some port exceptions
INSERT INTO excluded_ports (port) VALUES (22);
INSERT INTO excluded_ports (port) VALUES (80);
INSERT INTO excluded_ports (port) VALUES (443);
EOF

    chmod 644 "$TEMP_DB"
    echo "Demo database initialized at $TEMP_DB"
fi

# Source utility libraries using relative paths
source "lib/utils.sh"
source "lib/database.sh"
source "lib/network.sh"
source "lib/tunnel.sh"

# Function for main menu
show_main_menu() {
    clear
    display_header "IPv6 Tunneling Service Management Panel"
    
    # Get tunnel status
    local status="Simulated (Replit Environment)"
    local server_type=$(db_get_server_type)
    local remote_server=$(db_get_remote_server)
    
    echo "Server Type: $([ "$server_type" == "source" ] && echo "Source (Client)" || echo "Destination (Server)")"
    echo "Remote Server: $remote_server"
    echo "Tunnel Status: $status"
    echo ""
    
    echo "Available Commands:"
    echo "1) Start Tunnel (Simulated)"
    echo "2) Stop Tunnel (Simulated)"
    echo "3) Restart Tunnel (Simulated)"
    echo "4) View Logs (Simulated)"
    echo "5) Manage Port Exceptions"
    echo "6) View Connection Status (Simulated)"
    echo "7) Configure Remote Server"
    echo "8) Performance Tuning (Simulated)"
    echo "9) Exit"
    echo ""
    
    read -p "Enter your choice [1-9]: " choice
    
    case "$choice" in
        1) echo "Simulating tunnel start..."; sleep 2; show_main_menu ;;
        2) echo "Simulating tunnel stop..."; sleep 2; show_main_menu ;;
        3) echo "Simulating tunnel restart..."; sleep 2; show_main_menu ;;
        4) view_logs ;;
        5) manage_port_exceptions ;;
        6) view_connection_status ;;
        7) configure_remote_server ;;
        8) performance_tuning ;;
        9) clear; exit 0 ;;
        *) echo "Invalid option"; sleep 2; show_main_menu ;;
    esac
}

# Function to view logs
view_logs() {
    clear
    display_header "Tunnel Logs (Simulated)"
    
    echo "Simulated logs in Replit environment:"
    echo "[2025-04-29 12:00:00] [INFO] Tunnel started"
    echo "[2025-04-29 12:01:30] [INFO] IPv6 forwarding enabled"
    echo "[2025-04-29 12:01:35] [INFO] NAT masquerading configured"
    echo "[2025-04-29 12:05:42] [INFO] Port 443 added to exceptions"
    echo ""
    
    read -p "Press Enter to return to the main menu..." dummy
    show_main_menu
}

# Function to manage port exceptions
manage_port_exceptions() {
    clear
    display_header "Manage Port Exceptions"
    
    echo "Current Port Exceptions:"
    echo ""
    
    # Get and display excluded ports
    local excluded_ports=$(db_get_excluded_ports)
    
    if [ -z "$excluded_ports" ]; then
        echo "No port exceptions configured"
    else
        echo "Excluded Ports: $excluded_ports"
    fi
    
    echo ""
    echo "Options:"
    echo "1) Add port exception"
    echo "2) Remove port exception"
    echo "3) Return to main menu"
    echo ""
    
    read -p "Enter your choice [1-3]: " choice
    
    case "$choice" in
        1)
            read -p "Enter port to exclude from tunneling: " port
            if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
                db_add_excluded_port "$port"
                echo "Port $port added to exceptions"
                sleep 2
            else
                echo "Invalid port number"
                sleep 2
            fi
            manage_port_exceptions
            ;;
        2)
            read -p "Enter port to remove from exceptions: " port
            if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
                db_remove_excluded_port "$port"
                echo "Port $port removed from exceptions"
                sleep 2
            else
                echo "Invalid port number"
                sleep 2
            fi
            manage_port_exceptions
            ;;
        3)
            show_main_menu
            ;;
        *)
            echo "Invalid option"
            sleep 2
            manage_port_exceptions
            ;;
    esac
}

# Function to view connection status
view_connection_status() {
    clear
    display_header "Connection Status (Simulated)"
    
    echo "IPv6 Network Status (Simulated):"
    echo "--------------------"
    echo "eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500"
    echo "    inet6 2001:db8:1234:5678::2/64 scope global"
    echo "    inet6 fe80::1/64 scope link"
    echo ""
    echo "wg0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1420"
    echo "    inet6 fd00:1234:5678::2/64 scope global"
    
    echo ""
    echo "Current Routing Table (Simulated):"
    echo "---------------------"
    echo "default via fe80::1 dev eth0 proto static"
    echo "::/0 dev wg0 proto static"
    echo "fd00:1234:5678::/64 dev wg0 proto kernel"
    echo "2001:db8:1234:5678::/64 dev eth0 proto kernel"
    
    echo ""
    echo "Tunnel Status:"
    echo "--------------"
    echo "Tunnel is ACTIVE (Simulated)"
    
    echo ""
    echo "Tunnel Interface: wg0 (Simulated)"
    echo ""
    echo "Traffic Statistics (Simulated):"
    echo "-----------------"
    echo "Received: 1234 packets, 567890 bytes"
    echo "Transmitted: 5678 packets, 1234567 bytes"
    
    echo ""
    read -p "Press Enter to return to the main menu..." dummy
    show_main_menu
}

# Function to configure remote server
configure_remote_server() {
    clear
    display_header "Remote Server Configuration"
    
    local current_server=$(db_get_remote_server)
    local server_type=$(db_get_server_type)
    
    echo "Current Server Type: $([ "$server_type" == "source" ] && echo "Source (Client)" || echo "Destination (Server)")"
    echo "Current Remote Server: $current_server"
    echo ""
    
    if [ "$server_type" == "source" ]; then
        read -p "Enter IPv6 address of destination server: " new_server
        if [[ "$new_server" =~ ^[0-9a-fA-F:]+$ ]]; then
            db_set_remote_server "$new_server"
            echo "Remote server updated to $new_server"
            echo "You need to restart the tunnel for changes to take effect"
        else
            echo "Invalid IPv6 address format"
        fi
    else
        echo "This is a destination server. There's no need to configure a remote server."
    fi
    
    echo ""
    read -p "Press Enter to return to the main menu..." dummy
    show_main_menu
}

# Function for performance tuning
performance_tuning() {
    clear
    display_header "Performance Tuning (Simulated)"
    
    echo "Current Network Performance Settings (Simulated):"
    echo "------------------------------------"
    
    # Display sample sysctl values
    echo "IPv6 Forwarding: 1"
    echo "TCP Window Scaling: 1"
    echo "TCP Timestamps: 1"
    echo "TCP SACK: 1"
    echo "TCP MTU Probing: 1"
    echo "TCP Congestion Control: bbr"
    
    echo ""
    echo "Options:"
    echo "1) Apply Optimized Network Settings (Simulated)"
    echo "2) Reset to Default Settings (Simulated)"
    echo "3) Return to Main Menu"
    echo ""
    
    read -p "Enter your choice [1-3]: " choice
    
    case "$choice" in
        1)
            echo "Applied optimized network settings (Simulated)"
            echo "Changes will take effect immediately"
            ;;
        2)
            echo "Reset network settings to default (Simulated)"
            echo "Changes will take effect immediately"
            ;;
        3)
            show_main_menu
            return
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to return to the main menu..." dummy
    show_main_menu
}

# Start panel with main menu
show_main_menu