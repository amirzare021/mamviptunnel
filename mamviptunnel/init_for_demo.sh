#!/bin/bash

# Initialize demo data for testing the panel
# This script is for development purposes only

# Create data directory for SQLite database
mkdir -p "data"
TEMP_DB="data/config.db"

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
echo "Now you can run the panel for testing"