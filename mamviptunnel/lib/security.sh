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

# Generate SSL certificates for encrypted tunnel
generate_ssl_certificates() {
    local cert_file="/etc/ipv6tunnel/tunnel.crt"
    local key_file="/etc/ipv6tunnel/tunnel.key"
    
    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$cert_file")"
    
    # Generate self-signed certificate
    echo "Generating SSL certificates for secure tunnel..."
    openssl req -x509 -newkey rsa:4096 -keyout "$key_file" -out "$cert_file" -days 3650 -nodes -subj "/CN=ipv6tunnel" 2>/dev/null
    
    # Set proper permissions
    chmod 600 "$key_file"
    chmod 644 "$cert_file"
    
    echo "SSL certificates generated successfully."
    echo "Certificate: $cert_file"
    echo "Key: $key_file"
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
    
    # Set tunnel mode to ip6tables_socat
    db_set_config "tunnel_mode" "ip6tables_socat"
    
    # Prompt for tunnel port
    read -p "Enter the tunnel port on destination server (default: 5000): " tunnel_port
    tunnel_port=${tunnel_port:-5000}
    db_set_config "tunnel_port" "$tunnel_port"
    
    # Generate SSL certificates
    generate_ssl_certificates
    
    # Enable IP forwarding
    enable_ipv6_forwarding
    
    # Apply network performance optimizations
    optimize_network_performance
    
    echo "Source server setup complete."
}

# Setup destination server
setup_destination_server() {
    # Set tunnel mode to ip6tables_socat
    db_set_config "tunnel_mode" "ip6tables_socat"
    
    # Prompt for tunnel port
    read -p "Enter the tunnel port to listen on (default: 5000): " tunnel_port
    tunnel_port=${tunnel_port:-5000}
    db_set_config "tunnel_port" "$tunnel_port"
    
    # Generate SSL certificates
    generate_ssl_certificates
    
    # Setup NAT masquerading
    setup_destination_nat
    
    # Apply network performance optimizations
    optimize_network_performance
    
    echo "Destination server setup complete."
}
