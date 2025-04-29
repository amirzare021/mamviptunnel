#!/bin/bash

# Service Management Library
# Contains functions for managing the IP6 tunnel service

# Source utility libraries
export BASE_DIR="/opt/ipv6tunnel"
source "$BASE_DIR/lib/config.sh"
source "$BASE_DIR/lib/network.sh"
source "$BASE_DIR/lib/tunnel.sh"

# Start the tunnel service
service_start() {
    log_message "INFO" "Starting IPv6 tunnel service"
    
    # Check if already running
    if is_tunnel_running; then
        log_message "INFO" "Service is already running"
        return 0
    fi
    
    # Enable IPv6 forwarding
    enable_ipv6_forwarding
    
    # Start tunnel based on server type
    start_tunnel
    
    # Apply excluded ports
    apply_port_exceptions
    
    log_message "INFO" "IPv6 tunnel service started"
    return 0
}

# Stop the tunnel service
service_stop() {
    log_message "INFO" "Stopping IPv6 tunnel service"
    
    # Check if running
    if ! is_tunnel_running; then
        log_message "INFO" "Service is not running"
        return 0
    fi
    
    # Stop tunnel
    stop_tunnel
    
    log_message "INFO" "IPv6 tunnel service stopped"
    return 0
}

# Restart the tunnel service
service_restart() {
    log_message "INFO" "Restarting IPv6 tunnel service"
    
    service_stop
    sleep 2
    service_start
    
    return $?
}

# Get service status
service_status() {
    local status=$(get_tunnel_status)
    local interface=$(get_tunnel_interface)
    local server_type=$(db_get_server_type)
    local remote_server=$(db_get_remote_server)
    
    echo "IPv6 Tunnel Service Status"
    echo "-------------------------"
    echo "Service Status: $status"
    echo "Server Type: $server_type"
    echo "Tunnel Interface: $interface"
    
    if [ "$server_type" == "source" ]; then
        echo "Remote Server: $remote_server"
    fi
    
    if [ "$status" == "Running" ]; then
        # Show additional information when running
        show_tunnel_stats
    fi
    
    return 0
}

# If script is called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "$1" in
        start)
            service_start
            ;;
        stop)
            service_stop
            ;;
        restart)
            service_restart
            ;;
        status)
            service_status
            ;;
        *)
            echo "Usage: $0 {start|stop|restart|status}"
            exit 1
            ;;
    esac
fi