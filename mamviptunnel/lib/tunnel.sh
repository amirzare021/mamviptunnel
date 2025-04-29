#!/bin/bash

# Tunnel Management Library
# Contains functions to manage the tunnel setup and operation

# Source utility libraries
# For Replit environment, set flag
export REPLIT_ENVIRONMENT="true"

# Use relative paths for library includes
source "lib/config.sh"
source "lib/database.sh"
source "lib/network.sh"
source "lib/security.sh"

# Tunnel interface name
TUN_INTERFACE="tun0"

# Default tunnel port
DEFAULT_TUNNEL_PORT=5000

# Function to start the tunnel
start_tunnel() {
    local server_type=$(db_get_server_type)
    
    log_message "INFO" "Starting IPv6 tunnel as $server_type server"
    
    start_ip6tables_tunnel
    
    # Apply port exceptions
    apply_port_exceptions
    
    log_message "INFO" "Tunnel started successfully"
    return 0
}

# Function to stop the tunnel
stop_tunnel() {
    log_message "INFO" "Stopping IPv6 tunnel"
    
    stop_ip6tables_tunnel
    
    log_message "INFO" "Tunnel stopped successfully"
    return 0
}

# Function to restart the tunnel
restart_tunnel() {
    log_message "INFO" "Restarting IPv6 tunnel"
    
    stop_tunnel
    sleep 2
    start_tunnel
    
    return $?
}

# Function to start the tunnel using ip6tables and socat
start_ip6tables_tunnel() {
    local server_type=$(db_get_server_type)
    local remote_server=$(db_get_remote_server)
    local tunnel_port=$(db_get_config "tunnel_port" "$DEFAULT_TUNNEL_PORT")
    local ssl_cert="/etc/ipv6tunnel/tunnel.crt"
    local ssl_key="/etc/ipv6tunnel/tunnel.key"
    
    # Make sure IPv6 forwarding is enabled
    enable_ipv6_forwarding
    
    # Create TUN device
    ip tuntap add mode tun $TUN_INTERFACE 2>/dev/null || true
    ip link set dev $TUN_INTERFACE up
    
    # Generate SSL certificates if they don't exist
    if [ ! -f "$ssl_cert" ] || [ ! -f "$ssl_key" ]; then
        log_message "INFO" "Generating SSL certificates for secure tunnel"
        # Create directory if it doesn't exist
        mkdir -p "$(dirname "$ssl_cert")"
        # Generate self-signed certificate
        openssl req -x509 -newkey rsa:4096 -keyout "$ssl_key" -out "$ssl_cert" -days 3650 -nodes -subj "/CN=ipv6tunnel" 2>/dev/null
        chmod 600 "$ssl_key"
    fi
    
    if [ "$server_type" == "source" ]; then
        # Source server configuration
        if [ -z "$remote_server" ]; then
            log_message "ERROR" "Remote server not configured"
            return 1
        fi
        
        # Assign IPv6 address to TUN interface
        ip -6 addr add fd00:1234:5678::2/64 dev $TUN_INTERFACE
        
        # Start encrypted tunnel using socat
        log_message "INFO" "Starting encrypted tunnel to $remote_server:$tunnel_port"
        socat TUN,up,tun-name=$TUN_INTERFACE OPENSSL:[$remote_server]:$tunnel_port,cert=$ssl_cert,key=$ssl_key,verify=0,forever,reuseaddr,fork &
        
        # Wait for tunnel to be ready
        sleep 3
        
        # Setup routing
        log_message "INFO" "Setting up routing for source server"
        # Mark traffic for routing through the tunnel, except excluded ports
        ip6tables -t mangle -F
        ip6tables -t mangle -A PREROUTING -m mark --mark 1 -j ACCEPT
        ip6tables -t mangle -A PREROUTING -j MARK --set-mark 2
        
        # Add routing rules
        ip -6 rule add fwmark 1 table main priority 1000 2>/dev/null || true
        ip -6 rule add fwmark 2 table 200 priority 2000 2>/dev/null || true
        ip -6 route add default dev $TUN_INTERFACE table 200
        
        # Add exception for the tunnel traffic itself
        ip6tables -t mangle -A OUTPUT -o $TUN_INTERFACE -j MARK --set-mark 1
        
    else
        # Destination server configuration
        
        # Assign IPv6 address to TUN interface
        ip -6 addr add fd00:1234:5678::1/64 dev $TUN_INTERFACE
        
        # Start socat listener for the tunnel
        log_message "INFO" "Starting encrypted tunnel listener on port $tunnel_port"
        socat OPENSSL-LISTEN:$tunnel_port,cert=$ssl_cert,key=$ssl_key,verify=0,reuseaddr,fork TUN,up,tun-name=$TUN_INTERFACE &
        
        # Setup NAT masquerading for forwarded traffic
        setup_destination_nat
    fi
    
    return 0
}

# Function to stop the ip6tables tunnel
stop_ip6tables_tunnel() {
    local server_type=$(db_get_server_type)
    
    # Kill socat processes
    log_message "INFO" "Stopping tunnel processes"
    pkill -f "socat .* TUN,up,tun-name=$TUN_INTERFACE" 2>/dev/null || true
    pkill -f "socat OPENSSL-LISTEN.*TUN,up,tun-name=$TUN_INTERFACE" 2>/dev/null || true
    
    # Clean up routing rules for source server
    if [ "$server_type" == "source" ]; then
        log_message "INFO" "Cleaning up routing rules"
        ip -6 rule del fwmark 1 table main priority 1000 2>/dev/null || true
        ip -6 rule del fwmark 2 table 200 priority 2000 2>/dev/null || true
        ip6tables -t mangle -F 2>/dev/null || true
    fi
    
    # Remove TUN device
    ip link set dev $TUN_INTERFACE down 2>/dev/null || true
    ip tuntap del mode tun $TUN_INTERFACE 2>/dev/null || true
    
    return 0
}

# Function to get tunnel status
get_tunnel_status() {
    if ip link show dev "$TUN_INTERFACE" >/dev/null 2>&1; then
        echo "Running"
    else
        echo "Stopped"
    fi
}

# Function to check if tunnel is running
is_tunnel_running() {
    [ "$(get_tunnel_status)" == "Running" ]
}

# Function to get tunnel interface
get_tunnel_interface() {
    echo "$TUN_INTERFACE"
}

# If this script is called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "$1" in
        start)
            start_tunnel
            ;;
        stop)
            stop_tunnel
            ;;
        restart)
            restart_tunnel
            ;;
        status)
            status=$(get_tunnel_status)
            echo "Tunnel status: $status"
            
            if [ "$status" == "Running" ]; then
                show_tunnel_stats
            fi
            ;;
        *)
            echo "Usage: $0 {start|stop|restart|status}"
            exit 1
            ;;
    esac
fi
