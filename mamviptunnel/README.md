# IPv6 Tunneling Service

A Linux-based IPv6 tunneling service that routes traffic from a source server through a destination server with terminal-based management.

## Overview

This IPv6 tunneling solution allows you to route traffic from a source server (e.g., in a restricted location) through a destination server (e.g., in a location with unrestricted internet access). The traffic appears to originate from the destination server, effectively bypassing filtering or restrictions on the source server's network.

## Features

- IPv6 traffic routing through tunneling
- Two server roles: source (client) and destination (server)
- Terminal-based management interface
- Configurable port exceptions (bypass specific ports from tunneling)
- Support for WireGuard and SSH tunnel modes
- Systemd service for automatic startup
- SQLite database for configuration storage
- Performance optimization settings
- Secure encrypted connections

## Requirements

- Linux server with IPv6 connectivity
- Root access on both servers
- Required packages:
  - ip / iproute2
  - ip6tables
  - sqlite3
  - WireGuard (recommended) or SSH
  - bash

## Installation

1. Clone this repository or copy the files to both the source and destination servers.

2. Run the installation script on both servers:

   ```bash
   cd ipv6tunnel
   sudo bash install.sh
   ```

3. Follow the interactive prompts in the installation script:
   - Select the server role (source or destination)
   - Configure tunnel mode (WireGuard or SSH)
   - For WireGuard, exchange public keys between servers
   - For SSH, transfer the public key to the destination server

4. Once installation is complete, the tunnel service will be started automatically.

## Usage

### Terminal Panel

Access the terminal-based management panel:

```bash
sudo ipv6tunnel
