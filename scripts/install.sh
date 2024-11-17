#!/bin/bash

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLOCKLIST_FILE="$SCRIPT_DIR/config/block-lists.txt"
source "$SCRIPT_DIR/utils.sh"

# Configuration file
SETUP_CONF="/opt/pihole/config/setup.conf"

# Function to configure macOS DNS
configure_macos_dns() {
    local interface=$1
    local old_dns

    # Get current DNS servers
    old_dns=$(networksetup -getdnsservers "$interface")

    # Backup current DNS settings if not already backed up
    if [ ! -f "/opt/pihole/dns_backup_${interface}" ]; then
        echo "$old_dns" > "/opt/pihole/dns_backup_${interface}"
        echo "Backed up original DNS settings for $interface"
    fi

    echo "Configuring DNS for $interface..."
    sudo networksetup -setdnsservers "$interface" 127.0.0.1

    # Flush DNS cache
    sudo dscacheutil -flushcache
    sudo killall -HUP mDNSResponder

    echo "DNS configured for $interface to use Pi-hole (127.0.0.1)"
}

# Function to restore macOS DNS
restore_macos_dns() {
    local interface=$1
    if [ -f "/opt/pihole/dns_backup_${interface}" ]; then
        local old_dns=$(cat "/opt/pihole/dns_backup_${interface}")
        if [ "$old_dns" = "There aren't any DNS Servers set on Wi-Fi." ]; then
            sudo networksetup -setdnsservers "$interface" empty
        else
            sudo networksetup -setdnsservers "$interface" $old_dns
        fi
        echo "Restored original DNS settings for $interface"
        rm "/opt/pihole/dns_backup_${interface}"
    fi
}

# Check if config exists
if [ ! -f "$SETUP_CONF" ]; then
    echo "Configuration file not found. Please run 'make configure' first."
    exit 1
fi

# Source the configuration
source "$SETUP_CONF"

echo "Starting Pi-hole installation..."

# Stop and remove existing container if it exists
docker stop pihole >/dev/null 2>&1 || true
docker rm pihole >/dev/null 2>&1 || true

# Create network
echo "Creating Docker network..."
docker network create pihole_network >/dev/null 2>&1 || true

# Create required directories
sudo mkdir -p /opt/pihole/etc-pihole
sudo mkdir -p /opt/pihole/etc-dnsmasq.d

# Set proper permissions
sudo chmod -R 755 /opt/pihole
sudo chown -R $(id -u):$(id -g) /opt/pihole

# Fix database permissions first
if [ -f "/opt/pihole/etc-pihole/gravity.db" ]; then
    echo "Fixing existing database permissions..."
    sudo chmod 644 /opt/pihole/etc-pihole/gravity.db
fi

echo "Starting Pi-hole container..."
docker run -d \
    --name pihole \
    --hostname pi.hole \
    --network pihole_network \
    --restart=unless-stopped \
    -e TZ="$(timezone)" \
    -e WEBPASSWORD="${WEBPASSWORD}" \
    -e INTERFACE="${PIHOLE_INTERFACE}" \
    -e ServerIP="${PIHOLE_IP}" \
    -e FTLCONF_LOCAL_IPV4="${PIHOLE_IP}" \
    -e DNS1="8.8.8.8" \
    -e DNS2="8.8.4.4" \
    -e DNSMASQ_LISTENING=all \
    -e WEBTHEME="default-dark" \
    -e VIRTUAL_HOST="pi.hole" \
    -e DNS_FQDN_REQUIRED=true \
    -e REV_SERVER=true \
    -e REV_SERVER_TARGET="${PIHOLE_GATEWAY}" \
    -e REV_SERVER_CIDR="192.168.31.0/24" \
    -p 5353:53/tcp \
    -p 5353:53/udp \
    -p 80:80/tcp \
    -p 4443:443/tcp \
    -v "/opt/pihole/etc-pihole:/etc/pihole" \
    -v "/opt/pihole/etc-dnsmasq.d:/etc/dnsmasq.d" \
    --cap-add=NET_ADMIN \
    pihole/pihole:latest || {
    echo "Failed to start Pi-hole container"
    exit 1
}

# Copy block-lists.txt to the Pi-hole container
if [ -f "$BLOCKLIST_FILE" ]; then
    echo "Adding custom blocklists from $BLOCKLIST_FILE..."
    docker cp "$BLOCKLIST_FILE" pihole:/etc/pihole/block-lists.txt

    # Append blocklists to adlists.list inside the container
    docker exec pihole bash -c "while read -r url; do echo \$url >> /etc/pihole/adlists.list; done < /etc/pihole/block-lists.txt"

    # Update the Gravity database
    echo "Regenerating Gravity database with new blocklists..."
    docker exec pihole pihole -g
else
    echo "No blocklist file found at $BLOCKLIST_FILE. Skipping custom blocklists."
fi

# Wait for container to start
echo "Waiting for Pi-hole to start..."
for i in {1..30}; do
    if docker exec pihole pihole status &>/dev/null; then
        echo "Pi-hole is running!"
        echo "You can access the admin interface at: http://localhost/admin"
        echo "Alternative URLs:"
        echo "- http://pi.hole/admin (if DNS is working)"
        echo "- http://${PIHOLE_IP}/admin"
        echo "Password: ${WEBPASSWORD}"

        # Fix database permissions
        echo "Setting up gravity database..."
        docker exec pihole bash -c 'rm -f /etc/pihole/gravity.db*'
        docker exec pihole pihole -g
        docker exec pihole bash -c 'chmod 644 /etc/pihole/gravity.db'
        docker exec pihole bash -c 'chown pihole:pihole /etc/pihole/gravity.db'

        # Restart DNS service
        echo "Restarting DNS service..."
        docker exec pihole pihole restartdns
        docker exec pihole bash -c 'pihole -a -i local'

        # Configure DNS for macOS
        if [ "$(uname)" = "Darwin" ]; then
            # Get all active network services
            echo "Configuring DNS for macOS..."
            network_services=$(networksetup -listallnetworkservices | grep -v '*')
            while IFS= read -r service; do
                # Check if service has an IP address
                if networksetup -getinfo "$service" | grep -q "IP address"; then
                    echo "Configuring DNS for $service..."
                    configure_macos_dns "$service"
                fi
            done <<< "$network_services"

            echo "DNS configuration complete for all active interfaces"
        fi

        echo "Testing DNS resolution..."
        sleep 5
        if nslookup -port=5353 google.com 127.0.0.1 >/dev/null 2>&1; then
            echo "✓ DNS resolution working"
        else
            echo "✗ DNS resolution failed"
        fi

        echo "Testing DNS blocking..."
        if nslookup -port=5353 doubleclick.net 127.0.0.1 2>&1 | grep -q "NXDOMAIN\|0.0.0.0\|refused\|blocked"; then
            echo "✓ DNS blocking working"
        else
            echo "✗ DNS blocking test failed"
        fi

        # Set up local DNS
        if ! grep -q "127.0.0.1 pi.hole" /etc/hosts; then
            echo "Adding pi.hole to /etc/hosts..."
            echo "127.0.0.1 pi.hole" | sudo tee -a /etc/hosts >/dev/null
        fi

        echo -e "\nPi-hole has been configured as your DNS server"
        echo "DNS settings have been automatically updated for your Mac"
        echo "Original DNS settings have been backed up to /opt/pihole/dns_backup_*"

        exit 0
    fi
    echo -n "."
    sleep 2
done

echo "Timed out waiting for Pi-hole to start"
exit 1