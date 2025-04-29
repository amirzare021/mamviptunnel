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

# Install required packages
install_required_packages() {
    echo "Installing required packages..."
    
    # For Replit environment, skip package installation
    if [[ "$REPLIT_ENVIRONMENT" == "true" ]]; then
        echo "Skipping package installation in Replit environment"
        return 0
    fi
    
    # Detect package manager
    if command -v apt-get &> /dev/null; then
        # Debian/Ubuntu
        apt-get update
        apt-get install -y iproute2 iptables sqlite3 openssh-client openssh-server socat
    elif command -v yum &> /dev/null; then
        # CentOS/RHEL
        yum install -y iproute iptables sqlite socat openssh-clients openssh-server
    elif command -v dnf &> /dev/null; then
        # Fedora
        dnf install -y iproute iptables sqlite socat openssh-clients openssh-server
    elif command -v zypper &> /dev/null; then
        # openSUSE
        zypper install -y iproute2 iptables sqlite3 socat openssh
    elif command -v pacman &> /dev/null; then
        # Arch Linux
        pacman -Sy --noconfirm iproute2 iptables sqlite socat openssh
    else
        echo "Warning: Unsupported package manager. Please install required packages manually:"
        echo "- iproute2/iproute"
        echo "- iptables"
        echo "- sqlite3/sqlite"
        echo "- openssh-client/openssh-clients"
        echo "- openssh-server"
        echo "- socat"
    fi
    
    echo "Package installation completed."
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
        "ssh"
        "socat"
    )
    
    echo "Checking system requirements..."
    
    # Check if IPv6 is enabled
    if [ -f /proc/sys/net/ipv6/conf/all/disable_ipv6 ] && [ "$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6)" == "1" ]; then
        echo "Warning: IPv6 is disabled on this system."
        echo "Attempting to enable IPv6..."
        
        # For Replit environment, skip IPv6 enabling
        if [[ "$REPLIT_ENVIRONMENT" != "true" ]]; then
            sysctl -w net.ipv6.conf.all.disable_ipv6=0
            
            # Make the change permanent
            echo "net.ipv6.conf.all.disable_ipv6=0" > /etc/sysctl.d/99-ipv6.conf
            sysctl -p /etc/sysctl.d/99-ipv6.conf
            
            if [ "$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6)" == "1" ]; then
                echo "Error: Failed to enable IPv6. Please enable it manually."
                missing=1
            else
                echo "IPv6 successfully enabled!"
            fi
        fi
    fi
    
    # Check if we need to install packages
    local need_install=false
    
    # Check required commands
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "Required command '$cmd' is not installed."
            need_install=true
        fi
    done
    
    # Install required packages if needed
    if [ "$need_install" = true ] && [ "$REPLIT_ENVIRONMENT" != "true" ]; then
        install_required_packages
        
        # Recheck required commands after installation
        missing=0
        for cmd in "${required_commands[@]}"; do
            if ! command -v "$cmd" >/dev/null 2>&1; then
                echo "Error: Required command '$cmd' is still not installed after attempting installation."
                missing=1
            fi
        done
    fi
    
    # Exit if any requirements are still missing
    if [ "$missing" -eq 1 ]; then
        echo ""
        echo "Please fix the remaining issues and try again."
        exit 1
    fi
    
    echo "All system requirements met or will be installed during setup."
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
