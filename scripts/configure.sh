#!/bin/bash

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Configuration
CONFIG_DIR="/opt/pihole/config"
mkdir -p "$CONFIG_DIR"

# Setup configuration file
SETUP_CONF="$CONFIG_DIR/setup.conf"

echo "Configuring Pi-hole for $(uname)..."

# Create configuration directories
create_directories "/opt/pihole"

# Check Docker
if ! check_docker; then
    echo "Please start Docker and try again"
    exit 1
fi

# Get and display network interfaces with their IP addresses
echo "Available network interfaces:"
echo "-------------------------"
declare -a interfaces=()
declare -a active_interfaces=()
declare -a ip_addresses=()

while IFS= read -r interface; do
    ip_addr=$(ifconfig "$interface" 2>/dev/null | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}')
    if [ ! -z "$ip_addr" ]; then
        echo "[$((${#active_interfaces[@]} + 1))] $interface (IP: $ip_addr)"
        active_interfaces+=("$interface")
        ip_addresses+=("$ip_addr")
    fi
done < <(networksetup -listallhardwareports | grep "Device:" | awk '{print $2}')

if [ ${#active_interfaces[@]} -eq 0 ]; then
    echo "No active network interfaces found"
    exit 1
fi

# Let user select the interface
echo ""
echo -n "Please select the network interface to use for Pi-hole (1-${#active_interfaces[@]}): "
read -r selection </dev/tty

# Validate selection
if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#active_interfaces[@]} ]; then
    echo "Invalid selection: $selection"
    exit 1
fi

# Get selected interface and IP
PRIMARY_INTERFACE=${active_interfaces[$((selection-1))]}
IP_ADDRESS=${ip_addresses[$((selection-1))]}

# Get gateway for the selected interface
GATEWAY=$(netstat -nr | grep default | grep "$PRIMARY_INTERFACE" | awk '{print $2}' | head -n1)
if [ -z "$GATEWAY" ]; then
    echo -n "Could not determine gateway. Please enter gateway address manually: "
    read -r GATEWAY </dev/tty
fi

# Create configuration file
cat > "$SETUP_CONF" << EOF
PIHOLE_INTERFACE=$PRIMARY_INTERFACE
PIHOLE_DNS_1=8.8.8.8
PIHOLE_DNS_2=8.8.4.4
PIHOLE_IP=$IP_ADDRESS
PIHOLE_GATEWAY=$GATEWAY
WEBPASSWORD=admin
EOF

echo ""
echo "Configuration completed:"
echo "Interface: $PRIMARY_INTERFACE"
echo "IP Address: $IP_ADDRESS"
echo "Gateway: $GATEWAY"
echo "Configuration saved to $SETUP_CONF"