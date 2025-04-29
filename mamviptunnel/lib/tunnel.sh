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

# WireGuard interface name
WG_INTERFACE="wg0"

# Function to start the tunnel
start_tunnel() {
    local server_type=$(db_get_server_type)
    local tunnel_mode=$(db_get_config "tunnel_mode" "wireguard")
    
    log_message "INFO" "Starting IPv6 tunnel in $tunnel_mode mode as $server_type server"
    
    if [ "$tunnel_mode" == "wireguard" ]; then
        start_wireguard_tunnel
    elif [ "$tunnel_mode" == "ssh" ]; then
        start_ssh_tunnel
    else
        log_message "ERROR" "Unknown tunnel mode: $tunnel_mode"
        return 1
    fi
    
    # Apply port exceptions
    apply_port_exceptions
    
    log_message "INFO" "Tunnel started successfully"
    return 0
}

# Function to stop the tunnel
stop_tunnel() {
    local tunnel_mode=$(db_get_config "tunnel_mode" "wireguard")
    
    log_message "INFO" "Stopping IPv6 tunnel in $tunnel_mode mode"
    
    if [ "$tunnel_mode" == "wireguard" ]; then
        stop_wireguard_tunnel
    elif [ "$tunnel_mode" == "ssh" ]; then
        stop_ssh_tunnel
    else
        log_message "ERROR" "Unknown tunnel mode: $tunnel_mode"
        return 1
    fi
    
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

# Function to start a WireGuard tunnel
start_wireguard_tunnel() {
    local server_type=$(db_get_server_type)
    
    # Check if WireGuard is installed
    if ! command -v wg >/dev/null 2>&1; then
        log_message "ERROR" "WireGuard is not installed"
        return 1
    fi
    
    # Generate WireGuard keys if they don't exist
    if [ -z "$(db_get_wg_private_key)" ]; then
        generate_wireguard_keys
    fi
    
    # Get configuration values
    local private_key=$(db_get_wg_private_key)
    local remote_public_key=$(db_get_remote_wg_public_key)
    local remote_server=$(db_get_remote_server)
    local listen_port=$(db_get_config "wg_port" "$DEFAULT_WIREGUARD_PORT")
    local mtu=$(db_get_config "mtu" "$DEFAULT_MTU")
    
    # Create WireGuard configuration directory
    mkdir -p /etc/wireguard
    
    if [ "$server_type" == "source" ]; then
        # Source server configuration
        if [ -z "$remote_server" ] || [ -z "$remote_public_key" ]; then
            log_message "ERROR" "Remote server or public key not configured"
            return 1
        fi
        
        # Create WireGuard configuration for source
        cat > /etc/wireguard/$WG_INTERFACE.conf <<EOF
[Interface]
PrivateKey = $private_key
Address = fd00:1234:5678::2/64
MTU = $mtu

[Peer]
PublicKey = $remote_public_key
AllowedIPs = ::/0
Endpoint = [$remote_server]:$listen_port
PersistentKeepalive = 25
EOF
    else
        # Destination server configuration
        cat > /etc/wireguard/$WG_INTERFACE.conf <<EOF
[Interface]
PrivateKey = $private_key
Address = fd00:1234:5678::1/64
ListenPort = $listen_port
MTU = $mtu

# Enable IPv6 forwarding
PostUp = sysctl -w net.ipv6.conf.all.forwarding=1
# Setup NAT masquerading
PostUp = ip6tables -t nat -A POSTROUTING -o $(get_primary_interface) -j MASQUERADE
# Apply port exceptions
PostUp = bash -c 'for port in $(sqlite3 /etc/ipv6tunnel/config.db "SELECT port FROM excluded_ports"); do ip6tables -t nat -A POSTROUTING -o $(get_primary_interface) -p tcp --dport $port -j RETURN; ip6tables -t nat -A POSTROUTING -o $(get_primary_interface) -p udp --dport $port -j RETURN; done'
# Cleanup rules when stopping
PostDown = ip6tables -t nat -D POSTROUTING -o $(get_primary_interface) -j MASQUERADE
EOF
    fi
    
    # Start WireGuard
    ip link del $WG_INTERFACE 2>/dev/null || true
    wg-quick up $WG_INTERFACE
    
    # Setup routing for source server
    if [ "$server_type" == "source" ]; then
        # Mark traffic for routing through the tunnel, except excluded ports
        ip6tables -t mangle -F
        ip6tables -t mangle -A PREROUTING -m mark --mark 1 -j ACCEPT
        ip6tables -t mangle -A PREROUTING -j MARK --set-mark 2
        
        # Add routing rules
        ip -6 rule add fwmark 1 table main priority 1000
        ip -6 rule add fwmark 2 table 200 priority 2000
        ip -6 route add default dev $WG_INTERFACE table 200
        
        # Add exception for the tunnel traffic itself
        ip6tables -t mangle -A OUTPUT -o $WG_INTERFACE -j MARK --set-mark 1
    fi
    
    # Make sure IPv6 forwarding is enabled
    enable_ipv6_forwarding
    
    return 0
}

# Function to stop a WireGuard tunnel
stop_wireguard_tunnel() {
    local server_type=$(db_get_server_type)
    
    # Check if WireGuard is running
    if ip link show $WG_INTERFACE >/dev/null 2>&1; then
        # Stop WireGuard
        wg-quick down $WG_INTERFACE || ip link del $WG_INTERFACE
        
        # Clean up routing rules for source server
        if [ "$server_type" == "source" ]; then
            ip -6 rule del fwmark 1 table main priority 1000 2>/dev/null || true
            ip -6 rule del fwmark 2 table 200 priority 2000 2>/dev/null || true
            ip6tables -t mangle -F 2>/dev/null || true
        fi
    else
        log_message "INFO" "WireGuard interface $WG_INTERFACE is not running"
    fi
    
    return 0
}

# Function to start an SSH tunnel
start_ssh_tunnel() {
    local server_type=$(db_get_server_type)
    local remote_server=$(db_get_remote_server)
    local ssh_port=$(db_get_config "ssh_port" "$DEFAULT_SSH_PORT")
    local ssh_key=$(db_get_config "ssh_key" "/root/.ssh/id_rsa")
    local ssh_user=$(db_get_config "ssh_user" "root")
    
    if [ "$server_type" == "source" ]; then
        # Check if remote server is configured
        if [ -z "$remote_server" ]; then
            log_message "ERROR" "Remote server not configured"
            return 1
        fi
        
        # Check if SSH key exists
        if [ ! -f "$ssh_key" ]; then
            log_message "INFO" "SSH key not found, generating a new one"
            generate_ssh_key "$ssh_key"
        fi
        
        # Create tun device
        ip tuntap add mode tun tun0
        ip link set dev tun0 up
        ip -6 addr add fd00:1234:5678::2/64 dev tun0
        
        # Start SSH tunnel
        ssh -i "$ssh_key" -o StrictHostKeyChecking=no -o BatchMode=yes \
            -o ServerAliveInterval=30 -o ExitOnForwardFailure=yes \
            -w 0:0 "$ssh_user@$remote_server" -p "$ssh_port" \
            "ip tuntap add mode tun tun0; ip link set dev tun0 up; ip -6 addr add fd00:1234:5678::1/64 dev tun0" &
        
        # Setup routing
        ip -6 route add default via fd00:1234:5678::1 dev tun0
        
        # Mark traffic for routing through the tunnel, except excluded ports
        ip6tables -t mangle -F
        ip6tables -t mangle -A PREROUTING -m mark --mark 1 -j ACCEPT
        ip6tables -t mangle -A PREROUTING -j MARK --set-mark 2
        
        # Add routing rules
        ip -6 rule add fwmark 1 table main priority 1000
        ip -6 rule add fwmark 2 table 200 priority 2000
        ip -6 route add default dev tun0 table 200
        
        # Add exception for the tunnel traffic itself
        ip6tables -t mangle -A OUTPUT -o tun0 -j MARK --set-mark 1
    else
        # Destination server shouldn't start the SSH tunnel, it's initiated by the source
        log_message "INFO" "Destination server: SSH tunnel will be established by the source server"
        
        # Setup NAT masquerading for forwarded traffic
        setup_destination_nat
    fi
    
    return 0
}

# Function to stop an SSH tunnel
stop_ssh_tunnel() {
    local server_type=$(db_get_server_type)
    
    # Kill SSH tunnel process
    pkill -f "ssh -i .* -o .* -w 0:0" || true
    
    # Remove tun device
    ip link set dev tun0 down || true
    ip tuntap del mode tun tun0 || true
    
    if [ "$server_type" == "source" ]; then
        # Clean up routing rules
        ip -6 rule del fwmark 1 table main priority 1000 2>/dev/null || true
        ip -6 rule del fwmark 2 table 200 priority 2000 2>/dev/null || true
        ip6tables -t mangle -F 2>/dev/null || true
    fi
    
    return 0
}

# Function to get tunnel status
get_tunnel_status() {
    local tunnel_mode=$(db_get_config "tunnel_mode" "wireguard")
    local interface
    
    if [ "$tunnel_mode" == "wireguard" ]; then
        interface="$WG_INTERFACE"
    else
        interface="tun0"
    fi
    
    if ip link show dev "$interface" >/dev/null 2>&1; then
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
    local tunnel_mode=$(db_get_config "tunnel_mode" "wireguard")
    
    if [ "$tunnel_mode" == "wireguard" ]; then
        echo "$WG_INTERFACE"
    else
        echo "tun0"
    fi
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
