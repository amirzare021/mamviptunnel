#!/bin/bash

# Security Library
# Contains functions for secure tunnel establishment

# Source utility libraries
# For Replit environment, set flag
export REPLIT_ENVIRONMENT="true"

# Use relative paths for library includes
source "lib/config.sh"
source "lib/database.sh"

# Generate WireGuard Keys
generate_wireguard_keys() {
    # Check if WireGuard is installed
    if ! command -v wg >/dev/null 2>&1; then
        log_message "ERROR" "WireGuard is not installed"
        return 1
    fi
    
    log_message "INFO" "Generating WireGuard keys"
    
    # Create a temporary directory for key generation
    local temp_dir=$(mktemp -d)
    
    # Generate private key
    wg genkey > "$temp_dir/private.key"
    
    # Generate public key
    cat "$temp_dir/private.key" | wg pubkey > "$temp_dir/public.key"
    
    # Store keys in database
    local private_key=$(cat "$temp_dir/private.key")
    local public_key=$(cat "$temp_dir/public.key")
    
    db_set_wg_private_key "$private_key"
    db_set_wg_public_key "$public_key"
    
    # Display public key for manual setup
    echo "WireGuard Public Key: $public_key"
    echo "Please provide this key to the other server."
    
    # Clean up
    rm -rf "$temp_dir"
    
    return 0
}

# Set remote WireGuard public key
set_remote_wireguard_public_key() {
    local key="$1"
    
    # Validate key format (base64, 44 characters)
    if [[ "$key" =~ ^[A-Za-z0-9+/]{43}=$ ]]; then
        db_set_remote_wg_public_key "$key"
        log_message "INFO" "Remote WireGuard public key set"
        return 0
    else
        log_message "ERROR" "Invalid WireGuard public key format"
        return 1
    fi
}

# Generate SSH key
generate_ssh_key() {
    local key_file="$1"
    
    # Create .ssh directory if it doesn't exist
    mkdir -p "$(dirname "$key_file")"
    
    # Generate SSH key
    ssh-keygen -t rsa -b 4096 -f "$key_file" -N "" -C "ipv6tunnel"
    
    # Display public key for manual setup
    echo "SSH Public Key:"
    cat "${key_file}.pub"
    echo "Please add this key to ~/.ssh/authorized_keys on the remote server."
    
    return 0
}

# Configure authorized keys for SSH tunnel
configure_authorized_keys() {
    local public_key="$1"
    local auth_keys_file="/root/.ssh/authorized_keys"
    
    # Create .ssh directory if it doesn't exist
    mkdir -p "/root/.ssh"
    chmod 700 "/root/.ssh"
    
    # Append the public key if it doesn't exist
    if ! grep -q "$public_key" "$auth_keys_file" 2>/dev/null; then
        echo "$public_key" >> "$auth_keys_file"
        chmod 600 "$auth_keys_file"
        log_message "INFO" "Added public key to authorized_keys"
    else
        log_message "INFO" "Public key already exists in authorized_keys"
    fi
    
    return 0
}

# Setup source server
setup_source_server() {
    # Prompt for destination server
    read -p "Enter IPv6 address of destination server: " remote_server
    
    # Validate IPv6 address
    if [[ ! "$remote_server" =~ ^[0-9a-fA-F:]+$ ]]; then
        echo "Invalid IPv6 address format. Please enter a valid IPv6 address."
        exit 1
    fi
    
    # Store in database
    db_set_remote_server "$remote_server"
    
    # Prompt for tunnel mode
    echo "Select tunnel mode:"
    echo "1) WireGuard (recommended)"
    echo "2) SSH"
    read -p "Enter your choice [1-2]: " tunnel_mode_choice
    
    case "$tunnel_mode_choice" in
        1)
            # WireGuard tunnel mode
            db_set_config "tunnel_mode" "wireguard"
            
            # Generate WireGuard keys
            generate_wireguard_keys
            
            # Prompt for remote public key
            read -p "Enter the destination server's WireGuard public key: " remote_public_key
            set_remote_wireguard_public_key "$remote_public_key"
            ;;
        2)
            # SSH tunnel mode
            db_set_config "tunnel_mode" "ssh"
            
            # Generate SSH key
            generate_ssh_key "/root/.ssh/id_rsa"
            
            # Prompt for SSH username
            read -p "Enter the username for SSH connection (default: root): " ssh_user
            ssh_user=${ssh_user:-root}
            db_set_config "ssh_user" "$ssh_user"
            
            # Prompt for SSH port
            read -p "Enter the SSH port on destination server (default: 22): " ssh_port
            ssh_port=${ssh_port:-22}
            db_set_config "ssh_port" "$ssh_port"
            
            echo "Please add the displayed public key to the authorized_keys file on the destination server."
            echo "Once completed, press Enter to continue..."
            read dummy
            ;;
        *)
            echo "Invalid choice. Using default (WireGuard)."
            db_set_config "tunnel_mode" "wireguard"
            ;;
    esac
    
    # Enable IP forwarding
    enable_ipv6_forwarding
    
    # Apply network performance optimizations
    optimize_network_performance
    
    echo "Source server setup complete."
}

# Setup destination server
setup_destination_server() {
    # Prompt for tunnel mode
    echo "Select tunnel mode:"
    echo "1) WireGuard (recommended)"
    echo "2) SSH"
    read -p "Enter your choice [1-2]: " tunnel_mode_choice
    
    case "$tunnel_mode_choice" in
        1)
            # WireGuard tunnel mode
            db_set_config "tunnel_mode" "wireguard"
            
            # Generate WireGuard keys
            generate_wireguard_keys
            
            # Prompt for remote public key
            read -p "Enter the source server's WireGuard public key: " remote_public_key
            set_remote_wireguard_public_key "$remote_public_key"
            
            # Setup NAT masquerading
            setup_destination_nat
            ;;
        2)
            # SSH tunnel mode
            db_set_config "tunnel_mode" "ssh"
            
            # Prompt for public key
            echo "Enter the public SSH key from the source server (paste below, then press Ctrl+D):"
            public_key=$(cat)
            
            # Configure authorized keys
            configure_authorized_keys "$public_key"
            
            # Setup NAT masquerading
            setup_destination_nat
            ;;
        *)
            echo "Invalid choice. Using default (WireGuard)."
            db_set_config "tunnel_mode" "wireguard"
            ;;
    esac
    
    # Apply network performance optimizations
    optimize_network_performance
    
    echo "Destination server setup complete."
}
