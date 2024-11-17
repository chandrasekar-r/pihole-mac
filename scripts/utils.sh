#!/bin/bash

# Function to get timezone
timezone() {
    if [[ "$(uname)" == "Darwin" ]]; then
        sudo systemsetup -gettimezone | awk '{print $3}'
    else
        cat /etc/timezone
    fi
}

# Function to get system-specific network tool
get_network_tool() {
    if [[ "$(uname)" == "Darwin" ]]; then
        echo "ifconfig"
    else
        echo "ip"
    fi
}

# Function to list network interfaces based on OS
list_network_interfaces() {
    if [[ "$(uname)" == "Darwin" ]]; then
        networksetup -listallhardwareports | grep -A 1 "Hardware Port" | grep "Device:" | awk '{print $2}'
    else
        ip link show | grep -v "lo:" | awk -F': ' '{print $2}' | cut -d'@' -f1
    fi
}

# Function to get IP address based on OS
get_ip_address() {
    local interface=$1
    if [[ "$(uname)" == "Darwin" ]]; then
        ifconfig "$interface" 2>/dev/null | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}'
    else
        ip addr show "$interface" 2>/dev/null | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | cut -d'/' -f1
    fi
}

# Function to get network gateway based on OS
get_gateway() {
    local interface=$1
    if [[ "$(uname)" == "Darwin" ]]; then
        netstat -nr | grep default | grep "$interface" | awk '{print $2}' | head -n1
    else
        ip route | grep default | grep "$interface" | awk '{print $3}'
    fi
}

# Function to check if Docker is running
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        echo "Error: Docker is not running"
        return 1
    fi
    return 0
}

# Function to create required directories
create_directories() {
    local base_dir=$1
    mkdir -p "$base_dir"/{etc-pihole,etc-dnsmasq.d}
    chmod -R 755 "$base_dir"
}