#!/bin/bash

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration file
SETUP_CONF="/opt/pihole/config/setup.conf"

# Function to print success message
print_success() {
    echo -e "${GREEN}[✓] $1${NC}"
}

# Function to print error message
print_error() {
    echo -e "${RED}[✗] $1${NC}"
}

# Verify Pi-hole container
verify_container() {
    echo "Checking Pi-hole container..."
    if docker ps | grep -q pihole; then
        print_success "Pi-hole container is running"
        return 0
    else
        print_error "Pi-hole container is not running"
        return 1
    fi
}

# Verify DNS service
verify_dns() {
    echo "Checking DNS service..."
    if docker exec pihole pihole status | grep -q "FTL is listening on port 53"; then
        print_success "DNS service is running"
        return 0
    else
        print_error "DNS service is not running"
        return 1
    fi
}

# Verify gravity database
verify_gravity() {
    echo "Checking gravity database..."
    if docker exec pihole test -f "/etc/pihole/gravity.db"; then
        local count=$(docker exec pihole sqlite3 "/etc/pihole/gravity.db" "SELECT COUNT(*) FROM gravity;" 2>/dev/null)
        if [ -n "$count" ] && [ "$count" -gt 0 ]; then
            print_success "Gravity database is present with $count domains"
            return 0
        fi
    fi
    print_error "Gravity database not found or empty"
    return 1
}

# Update the verify_web_interface function
verify_web_interface() {
    echo "Checking web interface..."
    local response

    # Try localhost first
    response=$(curl -s --head "http://localhost/admin/")
    if echo "$response" | grep -q "X-Pi-hole: The Pi-hole Web interface is working!"; then
        print_success "Web interface is accessible at http://localhost/admin/"
        return 0
    fi

    # Try pi.hole if localhost failed
    response=$(curl -s --head "http://pi.hole/admin/")
    if echo "$response" | grep -q "X-Pi-hole: The Pi-hole Web interface is working!"; then
        print_success "Web interface is accessible at http://pi.hole/admin/"
        return 0
    fi

    print_error "Web interface is not accessible"
    return 1
}

# Update the test_dns_blocking function
test_dns_blocking() {
    echo "Testing DNS blocking..."
    local test_domain="doubleclick.net"
    local result=$(nslookup -port=5353 "$test_domain" 127.0.0.1 2>&1)

    if echo "$result" | grep -q "NXDOMAIN\|0.0.0.0\|blocked"; then
        print_success "DNS blocking is working (tested with $test_domain)"
        return 0
    else
        print_error "DNS blocking test failed"
        return 1
    fi
}

# Verify Docker network
verify_network() {
    echo "Checking Docker network..."
    if docker network inspect pihole_network >/dev/null 2>&1; then
        print_success "Docker network is configured"
        return 0
    else
        print_error "Docker network is not configured"
        return 1
    fi
}

# Run all verifications
echo "Starting Pi-hole verification..."
echo "--------------------------------"

failures=0

verify_container || ((failures++))
verify_web_interface || ((failures++))
verify_dns || ((failures++))
verify_gravity || ((failures++))
verify_network || ((failures++))
test_dns_blocking || ((failures++))

echo "--------------------------------"
if [ $failures -eq 0 ]; then
    print_success "All checks passed successfully!"
    exit 0
else
    print_error "$failures check(s) failed. Please check the errors above."

    echo -e "\nTroubleshooting suggestions:"
    echo "1. If container is not running:"
    echo "   - Run 'docker start pihole'"
    echo "   - Check logs with 'docker logs pihole'"

    echo "2. If web interface is not accessible:"
    echo "   - Verify firewall settings"
    echo "   - Check if container ports are mapped correctly"

    echo "3. If DNS service is not running:"
    echo "   - Check if port 53 is free"
    echo "   - Restart the container with 'docker restart pihole'"

    echo "4. If gravity database is missing:"
    echo "   - Run 'docker exec pihole pihole -g' to update gravity"

    echo "5. If DNS blocking is not working:"
    echo "   - Check if Pi-hole is set as your DNS server"
    echo "   - Verify no other DNS servers are configured"

    echo -e "\nFor more detailed logs, run:"
    echo "docker logs pihole"
    echo "docker exec pihole pihole -d"

    exit 1
fi