#!/bin/bash

# Configuration Library
# Contains functions to manage configuration settings

# Configuration directories
if [[ "$REPLIT_ENVIRONMENT" == "true" ]]; then
    # For Replit testing environment, use local directory
    CONF_DIR="data"
    DB_FILE="$CONF_DIR/config.db"
    LOG_FILE="$CONF_DIR/ipv6tunnel.log"
else
    CONF_DIR="/etc/ipv6tunnel"
    DB_FILE="$CONF_DIR/config.db"
    LOG_FILE="/var/log/ipv6tunnel.log"
fi

# Default settings for the tunnel
DEFAULT_SSH_PORT=22
DEFAULT_WIREGUARD_PORT=51820
DEFAULT_TUNNEL_MODE="wireguard"  # Can be wireguard or ssh
DEFAULT_MTU=1420

# Create configuration directory if it doesn't exist
[ ! -d "$CONF_DIR" ] && mkdir -p "$CONF_DIR"

# Function to initialize configuration
init_config() {
    touch "$LOG_FILE"
    chmod 640 "$LOG_FILE"
}

# Function to read a configuration value
get_config() {
    local key="$1"
    local default_value="$2"
    
    # Use the database function to get the value
    local value=$(db_get_config "$key")
    
    # Return default value if not found
    if [ -z "$value" ]; then
        echo "$default_value"
    else
        echo "$value"
    fi
}

# Function to write a configuration value
set_config() {
    local key="$1"
    local value="$2"
    
    # Use the database function to set the value
    db_set_config "$key" "$value"
}

# Function to check if a program is installed
is_installed() {
    command -v "$1" >/dev/null 2>&1
}

# Function to log messages
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    # Also print to stdout if verbose is enabled
    if [ "$(get_config "verbose" "false")" == "true" ]; then
        echo "[$level] $message"
    fi
}

# Get server type (source or destination)
get_server_type() {
    db_get_server_type
}

# Set server type
set_server_type() {
    local type="$1"
    db_set_server_type "$type"
}
