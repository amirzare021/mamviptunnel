#!/bin/bash

# Utility Library
# Contains general utility functions

# Display a header
display_header() {
    local title="$1"
    local width=70
    local title_length=${#title}
    local padding=$(( (width - title_length) / 2 ))
    
    echo ""
    echo "$(printf '=%.0s' $(seq 1 $width))"
    echo "$(printf ' %.0s' $(seq 1 $padding))$title"
    echo "$(printf '=%.0s' $(seq 1 $width))"
    echo ""
}

# Check if script is run as root
check_root() {
    # For Replit testing environment, skip root check
    if [[ "$REPLIT_ENVIRONMENT" == "true" ]]; then
        return 0
    fi
    
    if [ "$(id -u)" -ne 0 ]; then
        echo "Error: This script must be run as root." >&2
        exit 1
    fi
}

# Check system requirements
check_requirements() {
    local missing=0
    local required_commands=(
        "ip"
        "ip6tables"
        "sysctl"
        "sqlite3"
        "grep"
        "awk"
        "sed"
    )
    
    echo "Checking system requirements..."
    
    # Check if IPv6 is enabled
    if [ -f /proc/sys/net/ipv6/conf/all/disable_ipv6 ] && [ "$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6)" == "1" ]; then
        echo "Error: IPv6 is disabled on this system."
        echo "Please enable IPv6 with: sysctl -w net.ipv6.conf.all.disable_ipv6=0"
        missing=1
    fi
    
    # Check required commands
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "Error: Required command '$cmd' is not installed."
            missing=1
        fi
    done
    
    # Check if WireGuard is installed
    if ! command -v wg >/dev/null 2>&1; then
        echo "Warning: WireGuard is not installed."
        echo "Install WireGuard for optimal tunneling performance."
        echo "You can still use SSH tunneling without WireGuard."
    fi
    
    # Exit if any requirements are missing
    if [ "$missing" -eq 1 ]; then
        echo ""
        echo "Please install the missing requirements and try again."
        exit 1
    fi
    
    echo "All system requirements met."
}

# Check if a string contains a substring
contains() {
    local string="$1"
    local substring="$2"
    
    if [[ "$string" == *"$substring"* ]]; then
        return 0
    else
        return 1
    fi
}

# Join array elements with a delimiter
join_by() {
    local IFS="$1"
    shift
    echo "$*"
}

# Get a random port in the high range
get_random_port() {
    shuf -i 10000-65000 -n 1
}
