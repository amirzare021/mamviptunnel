#!/bin/bash

# Network Management Library
# Contains functions to manage network settings and routing

# Source utility libraries
# For Replit environment, set flag
export REPLIT_ENVIRONMENT="true"

# Use relative paths for library includes
source "lib/config.sh"
source "lib/database.sh"
source "lib/utils.sh"

# Check if IPv6 is enabled
check_ipv6() {
    if [ ! -f /proc/sys/net/ipv6/conf/all/disable_ipv6 ] || [ "$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6)" == "1" ]; then
        log_message "ERROR" "IPv6 is not enabled on this system"
        return 1
    fi
    return 0
}

# Get the primary interface
get_primary_interface() {
    # Try to determine the default interface
    local interface
    interface=$(ip -6 route | grep default | awk '{print $5}' | head -n 1)
    
    # If no default route found, try to get any interface with IPv6
    if [ -z "$interface" ]; then
        interface=$(ip -6 addr show | grep -v lo | grep -v "scope link" | grep -oP '(?<=: )[^:]+' | head -n 1)
    fi
    
    echo "$interface"
}

# Get the primary IPv6 address
get_primary_ipv6() {
    local interface=$(get_primary_interface)
    local ipv6
    
    if [ -n "$interface" ]; then
        ipv6=$(ip -6 addr show dev "$interface" scope global | grep -v temporary | grep -oP '(?<=inet6 )[0-9a-fA-F:]+')
        
        # If not found, try any IPv6 address on the interface
        if [ -z "$ipv6" ]; then
            ipv6=$(ip -6 addr show dev "$interface" | grep -oP '(?<=inet6 )[0-9a-fA-F:]+' | head -n 1)
        fi
    fi
    
    echo "$ipv6"
}

# Enable IPv6 forwarding
enable_ipv6_forwarding() {
    log_message "INFO" "Enabling IPv6 forwarding"
    sysctl -w net.ipv6.conf.all.forwarding=1 >/dev/null
    echo "net.ipv6.conf.all.forwarding=1" > /etc/sysctl.d/30-ipv6-forwarding.conf
    sysctl -p /etc/sysctl.d/30-ipv6-forwarding.conf >/dev/null
}

# Setup NAT masquerading on destination server
setup_destination_nat() {
    local interface=$(get_primary_interface)
    
    log_message "INFO" "Setting up NAT masquerading on $interface"
    
    # Enable forwarding
    enable_ipv6_forwarding
    
    # Setup masquerading
    ip6tables -t nat -C POSTROUTING -o "$interface" -j MASQUERADE 2>/dev/null || 
    ip6tables -t nat -A POSTROUTING -o "$interface" -j MASQUERADE
    
    # Make iptables rules persistent
    if command -v netfilter-persistent >/dev/null 2>&1; then
        netfilter-persistent save
    elif [ -d /etc/iptables ]; then
        mkdir -p /etc/iptables
        ip6tables-save > /etc/iptables/rules.v6
    fi
}

# Add a port to the exception list
add_port_exception() {
    local port="$1"
    local server_type=$(db_get_server_type)
    
    # Add port to database
    db_add_excluded_port "$port"
    
    # Update iptables rules
    if [ "$server_type" == "source" ]; then
        # For source server, don't route excluded ports through the tunnel
        ip6tables -t mangle -C PREROUTING -p tcp --dport "$port" -j MARK --set-mark 1 2>/dev/null ||
        ip6tables -t mangle -A PREROUTING -p tcp --dport "$port" -j MARK --set-mark 1
        
        ip6tables -t mangle -C PREROUTING -p udp --dport "$port" -j MARK --set-mark 1 2>/dev/null ||
        ip6tables -t mangle -A PREROUTING -p udp --dport "$port" -j MARK --set-mark 1
    else
        # For destination server, don't masquerade excluded ports
        local interface=$(get_primary_interface)
        
        ip6tables -t nat -C POSTROUTING -o "$interface" -p tcp --dport "$port" -j RETURN 2>/dev/null ||
        ip6tables -t nat -A POSTROUTING -o "$interface" -p tcp --dport "$port" -j RETURN
        
        ip6tables -t nat -C POSTROUTING -o "$interface" -p udp --dport "$port" -j RETURN 2>/dev/null ||
        ip6tables -t nat -A POSTROUTING -o "$interface" -p udp --dport "$port" -j RETURN
    fi
    
    # Make iptables rules persistent
    if command -v netfilter-persistent >/dev/null 2>&1; then
        netfilter-persistent save
    elif [ -d /etc/iptables ]; then
        mkdir -p /etc/iptables
        ip6tables-save > /etc/iptables/rules.v6
    fi
    
    log_message "INFO" "Added port $port to exceptions"
}

# Remove a port from the exception list
remove_port_exception() {
    local port="$1"
    local server_type=$(db_get_server_type)
    
    # Remove port from database
    db_remove_excluded_port "$port"
    
    # Update iptables rules
    if [ "$server_type" == "source" ]; then
        # For source server, remove exclusion rules
        ip6tables -t mangle -D PREROUTING -p tcp --dport "$port" -j MARK --set-mark 1 2>/dev/null
        ip6tables -t mangle -D PREROUTING -p udp --dport "$port" -j MARK --set-mark 1 2>/dev/null
    else
        # For destination server, remove exclusion rules
        local interface=$(get_primary_interface)
        
        ip6tables -t nat -D POSTROUTING -o "$interface" -p tcp --dport "$port" -j RETURN 2>/dev/null
        ip6tables -t nat -D POSTROUTING -o "$interface" -p udp --dport "$port" -j RETURN 2>/dev/null
    fi
    
    # Make iptables rules persistent
    if command -v netfilter-persistent >/dev/null 2>&1; then
        netfilter-persistent save
    elif [ -d /etc/iptables ]; then
        mkdir -p /etc/iptables
        ip6tables-save > /etc/iptables/rules.v6
    fi
    
    log_message "INFO" "Removed port $port from exceptions"
}

# Apply all port exceptions
apply_port_exceptions() {
    local ports=$(db_get_excluded_ports)
    
    # Skip if no ports are excluded
    [ -z "$ports" ] && return
    
    # Apply each port exception
    IFS=',' read -ra PORT_ARRAY <<< "$ports"
    for port in "${PORT_ARRAY[@]}"; do
        # Skip if port is already added
        if ! db_is_port_excluded "$port"; then
            add_port_exception "$port"
        fi
    done
}

# Optimize network performance
optimize_network_performance() {
    log_message "INFO" "Applying network performance optimizations"
    
    # Enable window scaling
    sysctl -w net.ipv4.tcp_window_scaling=1 >/dev/null
    
    # Enable TCP timestamps
    sysctl -w net.ipv4.tcp_timestamps=1 >/dev/null
    
    # Enable SACK
    sysctl -w net.ipv4.tcp_sack=1 >/dev/null
    
    # Enable MTU probing
    sysctl -w net.ipv4.tcp_mtu_probing=1 >/dev/null
    
    # Use BBR congestion control algorithm if available
    if grep -q bbr /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null; then
        sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null
    fi
    
    # Save settings
    cat > /etc/sysctl.d/99-ipv6tunnel-perf.conf <<EOF
# Optimized network settings for IPv6 tunnel
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_timestamps=1
net.ipv4.tcp_sack=1
net.ipv4.tcp_mtu_probing=1
EOF
    
    # Add BBR if available
    if grep -q bbr /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null; then
        echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.d/99-ipv6tunnel-perf.conf
    fi
    
    # Apply settings
    sysctl -p /etc/sysctl.d/99-ipv6tunnel-perf.conf >/dev/null
}

# Reset network performance settings
reset_network_performance() {
    log_message "INFO" "Resetting network performance settings to defaults"
    
    # Remove our custom settings file
    rm -f /etc/sysctl.d/99-ipv6tunnel-perf.conf
    
    # Reset to default values
    sysctl -w net.ipv4.tcp_window_scaling=1 >/dev/null
    sysctl -w net.ipv4.tcp_timestamps=1 >/dev/null
    sysctl -w net.ipv4.tcp_sack=1 >/dev/null
    sysctl -w net.ipv4.tcp_mtu_probing=0 >/dev/null
    sysctl -w net.ipv4.tcp_congestion_control=cubic >/dev/null
}

# Display tunnel statistics
show_tunnel_stats() {
    local interface=$(get_tunnel_interface)
    
    if [ -z "$interface" ]; then
        echo "Tunnel is not running or interface not found"
        return
    fi
    
    echo "Tunnel Interface: $interface"
    echo ""
    echo "Traffic Statistics:"
    echo "-----------------"
    
    # Get RX/TX stats
    local stats=$(ip -s link show dev "$interface" 2>/dev/null)
    if [ -n "$stats" ]; then
        echo "$stats" | grep -A 1 "RX:" | tail -n 1 | awk '{printf "Received: %s packets, %s bytes\n", $1, $2}'
        echo "$stats" | grep -A 1 "TX:" | tail -n 1 | awk '{printf "Transmitted: %s packets, %s bytes\n", $1, $2}'
    else
        echo "No statistics available for interface $interface"
    fi
}
