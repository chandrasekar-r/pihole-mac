#!/bin/bash

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Configuration
INSTALL_DIR="$HOME/Documents/Scripts/Pihole"
MONITOR_DIR="$INSTALL_DIR/monitor"
mkdir -p "$MONITOR_DIR"

# Function to get disk usage
get_disk_usage() {
    df -h / | awk 'NR==2 {print $5}' | sed 's/%//'
}

# Function to get memory usage for macOS
get_memory_usage() {
    local total_mem=$(sysctl -n hw.memsize)
    local page_size=$(sysctl -n hw.pagesize)
    local mem_stats=$(vm_stat)

    # Get pages
    local free_pages=$(echo "$mem_stats" | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
    local active_pages=$(echo "$mem_stats" | grep "Pages active" | awk '{print $3}' | sed 's/\.//')
    local inactive_pages=$(echo "$mem_stats" | grep "Pages inactive" | awk '{print $3}' | sed 's/\.//')
    local speculative_pages=$(echo "$mem_stats" | grep "Pages speculative" | awk '{print $3}' | sed 's/\.//')
    local wired_pages=$(echo "$mem_stats" | grep "Pages wired down" | awk '{print $4}' | sed 's/\.//')

    # Convert pages to bytes
    local free_mem=$((free_pages * page_size))
    local used_mem=$((total_mem - free_mem))

    # Calculate percentage
    echo $((used_mem * 100 / total_mem))
}

# Function to get CPU load
get_cpu_load() {
    top -l 1 | grep -E "^CPU" | awk '{print $3}' | sed 's/%//'
}

# Function to check Docker container status
check_docker_status() {
    if ! docker ps | grep -q pihole; then
        echo "ALERT: Pi-hole container is not running"
        return 1
    fi
    return 0
}

# Function to check DNS resolution
check_dns() {
    if ! nslookup google.com > /dev/null 2>&1; then
        echo "ALERT: DNS resolution is not working"
        return 1
    fi
    return 0
}

# Monitor system resources
monitor_system() {
    # Check disk usage
    DISK_USAGE=$(get_disk_usage)
    if [ "$DISK_USAGE" -gt 85 ]; then
        echo "ALERT: Disk usage is at ${DISK_USAGE}%"
    fi

    # Check memory usage
    MEM_USAGE=$(get_memory_usage)
    if [ "$MEM_USAGE" -gt 90 ]; then
        echo "ALERT: High memory usage at ${MEM_USAGE}%"
    fi

    # Check CPU load
    CPU_LOAD=$(get_cpu_load)
    CPU_INT=${CPU_LOAD%.*}
    if [ "$CPU_INT" -gt 80 ]; then
        echo "ALERT: High CPU usage at ${CPU_LOAD}%"
    fi

    # Check Pi-hole container
    if ! check_docker_status; then
        echo "ALERT: Pi-hole container is not running"
    fi

    # Check DNS resolution
    if ! check_dns; then
        echo "ALERT: DNS resolution is not working"
    fi
}

# Function to create full report
create_full_report() {
    echo "System Status Report"
    echo "-------------------"

    DISK_USAGE=$(get_disk_usage)
    echo "Disk Usage: ${DISK_USAGE}%"
    if [ "$DISK_USAGE" -gt 85 ]; then
        echo "ALERT: Disk usage is at ${DISK_USAGE}%"
    fi

    MEM_USAGE=$(get_memory_usage)
    echo "Memory Usage: ${MEM_USAGE}%"
    if [ "$MEM_USAGE" -gt 90 ]; then
        echo "ALERT: High memory usage at ${MEM_USAGE}%"
    fi

    CPU_LOAD=$(get_cpu_load)
    echo "CPU Usage: ${CPU_LOAD}%"
    CPU_INT=${CPU_LOAD%.*}
    if [ "$CPU_INT" -gt 80 ]; then
        echo "ALERT: High CPU usage at ${CPU_LOAD}%"
    fi

    echo "Checking Pi-hole container..."
    if check_docker_status; then
        echo "Pi-hole container is running"
    fi

    echo "Checking DNS resolution..."
    if check_dns; then
        echo "DNS resolution is working"
    fi

    echo "Pi-hole Statistics:"
    if docker ps | grep -q pihole; then
        docker exec pihole pihole status
    else
        echo "Cannot get Pi-hole statistics - container is not running"
    fi
}

# Save report to file
save_report() {
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local report_file="$MONITOR_DIR/report_${timestamp}.txt"
    {
        echo "Pi-hole Monitoring Report - $(date)"
        echo "=================================="
        echo ""
        create_full_report
    } | tee "$report_file"
    echo "Report saved to: $report_file"
}

# Main execution
case "$1" in
    "start")
        save_report
        ;;
    "status")
        docker exec pihole pihole status
        ;;
    "alerts")
        monitor_system
        ;;
    "report")
        ls -l "$MONITOR_DIR"
        ;;
    *)
        echo "Usage: $0 {start|status|alerts|report}"
        exit 1
        ;;
esac