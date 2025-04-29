#!/bin/bash

# Database Management Library
# Contains functions to manage the SQLite database

# Database file
if [[ "$REPLIT_ENVIRONMENT" == "true" ]]; then
    # For Replit testing environment, use local directory
    CONF_DIR="data"
    DB_FILE="$CONF_DIR/config.db"
else
    CONF_DIR="/etc/ipv6tunnel"
    DB_FILE="$CONF_DIR/config.db"
fi

# Function to initialize the database
db_init() {
    local server_type="$1"
    
    # Create conf directory if it doesn't exist
    mkdir -p "$CONF_DIR"
    
    # Check if sqlite3 is installed
    if ! command -v sqlite3 >/dev/null 2>&1; then
        echo "Error: sqlite3 is not installed. Please install sqlite3 package."
        exit 1
    fi
    
    # Create the database if it doesn't exist
    if [ ! -f "$DB_FILE" ]; then
        sqlite3 "$DB_FILE" <<EOF
CREATE TABLE config (
    key TEXT PRIMARY KEY,
    value TEXT
);

CREATE TABLE excluded_ports (
    port INTEGER PRIMARY KEY
);
EOF
        # Set initial values
        db_set_server_type "$server_type"
        db_set_config "tunnel_mode" "wireguard"
        db_set_config "mtu" "1420"
        db_set_config "verbose" "false"
    fi
    
    # Set permissions
    chmod 640 "$DB_FILE"
}

# Function to get a config value
db_get_config() {
    local key="$1"
    
    sqlite3 "$DB_FILE" "SELECT value FROM config WHERE key='$key';" 2>/dev/null
}

# Function to set a config value
db_set_config() {
    local key="$1"
    local value="$2"
    
    sqlite3 "$DB_FILE" "INSERT OR REPLACE INTO config (key, value) VALUES ('$key', '$value');"
}

# Function to get server type
db_get_server_type() {
    db_get_config "server_type"
}

# Function to set server type
db_set_server_type() {
    local type="$1"
    db_set_config "server_type" "$type"
}

# Function to get remote server
db_get_remote_server() {
    db_get_config "remote_server"
}

# Function to set remote server
db_set_remote_server() {
    local server="$1"
    db_set_config "remote_server" "$server"
}

# Function to get all excluded ports
db_get_excluded_ports() {
    sqlite3 "$DB_FILE" "SELECT port FROM excluded_ports ORDER BY port;" 2>/dev/null | tr '\n' ',' | sed 's/,$//'
}

# Function to add an excluded port
db_add_excluded_port() {
    local port="$1"
    
    sqlite3 "$DB_FILE" "INSERT OR IGNORE INTO excluded_ports (port) VALUES ($port);"
}

# Function to remove an excluded port
db_remove_excluded_port() {
    local port="$1"
    
    sqlite3 "$DB_FILE" "DELETE FROM excluded_ports WHERE port=$port;"
}

# Function to check if a port is excluded
db_is_port_excluded() {
    local port="$1"
    local count
    
    count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM excluded_ports WHERE port=$port;")
    
    [ "$count" -gt 0 ]
}

# Function to get WireGuard private key
db_get_wg_private_key() {
    db_get_config "wg_private_key"
}

# Function to set WireGuard private key
db_set_wg_private_key() {
    local key="$1"
    db_set_config "wg_private_key" "$key"
}

# Function to get WireGuard public key
db_get_wg_public_key() {
    db_get_config "wg_public_key"
}

# Function to set WireGuard public key
db_set_wg_public_key() {
    local key="$1"
    db_set_config "wg_public_key" "$key"
}

# Function to get remote WireGuard public key
db_get_remote_wg_public_key() {
    db_get_config "remote_wg_public_key"
}

# Function to set remote WireGuard public key
db_set_remote_wg_public_key() {
    local key="$1"
    db_set_config "remote_wg_public_key" "$key"
}
