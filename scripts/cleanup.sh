#!/bin/bash

echo "Cleaning up Pi-hole installation..."

# Only remove Docker resources
if docker ps -a | grep -q pihole; then
    echo "Stopping Pi-hole container..."
    docker stop pihole
    echo "Removing Pi-hole container..."
    docker rm pihole
fi

if docker network ls | grep -q pihole_network; then
    echo "Removing Docker network..."
    docker network rm pihole_network
fi

# Remove only /opt/pihole directory
if [ -d "/opt/pihole" ]; then
    echo "Removing /opt/pihole directory..."
    sudo rm -rf "/opt/pihole"
fi

echo "Cleanup complete"