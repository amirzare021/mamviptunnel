#!/bin/bash

# IPv6 Tunnel Management Panel
# Terminal-based management interface for the IPv6 tunneling service

# Source utility libraries
BASE_DIR="$(pwd)"
# For testing in Replit environment, use relative paths
source "lib/utils.sh"
source "lib/database.sh"
source "lib/network.sh"
source "lib/tunnel.sh"

# Check if running as root
check_root

# Function for main menu
show_main_menu() {
    clear
    display_header "IPv6 Tunneling Service Management Panel"
    
    # Get tunnel status
    local status=$(get_tunnel_status)
    local server_type=$(db_get_server_type)
    local remote_server=$(db_get_remote_server)
    
    echo "Server Type: $([ "$server_type" == "source" ] && echo "Source (Client)" || echo "Destination (Server)")"
    echo "Remote Server: $remote_server"
    echo "Tunnel Status: $status"
    echo ""
    
    # Show network stats if tunnel is running
    if [ "$status" == "Running" ]; then
        show_tunnel_stats
    fi
    
    echo ""
    echo "Available Commands:"
    echo "1) Start Tunnel"
    echo "2) Stop Tunnel"
    echo "3) Restart Tunnel"
    echo "4) View Logs"
    echo "5) Manage Port Exceptions"
    echo "6) View Connection Status"
    echo "7) Configure Remote Server"
    echo "8) Performance Tuning"
    echo "9) Exit"
    echo ""
    
    read -p "Enter your choice [1-9]: " choice
    
    case "$choice" in
        1) start_tunnel; sleep 2; show_main_menu ;;
        2) stop_tunnel; sleep 2; show_main_menu ;;
        3) restart_tunnel; sleep 2; show_main_menu ;;
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
    display_header "Tunnel Logs"
    
    echo "Press Ctrl+C to return to the main menu"
    echo ""
    
    # Use journalctl to follow logs from the tunnel service
    journalctl -u tunnel -f
    
    # We'll never reach here normally, but just in case
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
                add_port_exception "$port"
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
                remove_port_exception "$port"
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
    display_header "Connection Status"
    
    echo "IPv6 Network Status:"
    echo "--------------------"
    ip -6 addr show
    
    echo ""
    echo "Current Routing Table:"
    echo "---------------------"
    ip -6 route show
    
    echo ""
    echo "Tunnel Status:"
    echo "--------------"
    
    if is_tunnel_running; then
        echo "Tunnel is ACTIVE"
        
        # Show tunnel statistics
        echo ""
        show_tunnel_stats
    else
        echo "Tunnel is INACTIVE"
    fi
    
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
    display_header "Performance Tuning"
    
    echo "Current Network Performance Settings:"
    echo "------------------------------------"
    
    # Display current sysctl values
    echo "IPv6 Forwarding: $(sysctl -n net.ipv6.conf.all.forwarding)"
    echo "TCP Window Scaling: $(sysctl -n net.ipv4.tcp_window_scaling)"
    echo "TCP Timestamps: $(sysctl -n net.ipv4.tcp_timestamps)"
    echo "TCP SACK: $(sysctl -n net.ipv4.tcp_sack)"
    echo "TCP MTU Probing: $(sysctl -n net.ipv4.tcp_mtu_probing)"
    echo "TCP Congestion Control: $(sysctl -n net.ipv4.tcp_congestion_control)"
    
    echo ""
    echo "Options:"
    echo "1) Apply Optimized Network Settings"
    echo "2) Reset to Default Settings"
    echo "3) Return to Main Menu"
    echo ""
    
    read -p "Enter your choice [1-3]: " choice
    
    case "$choice" in
        1)
            optimize_network_performance
            echo "Applied optimized network settings"
            echo "Changes will take effect immediately"
            ;;
        2)
            reset_network_performance
            echo "Reset network settings to default"
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
