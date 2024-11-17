# Pi-hole Docker Installation Script for macOS

This project provides a streamlined installation and management system for running Pi-hole in a Docker container on macOS, with automatic DNS configuration and management tools.

## Features

- Automated Pi-hole installation with Docker
- Automatic DNS configuration for macOS
- Web interface access at `http://localhost:8088/admin`
- DNS blocking and ad filtering
- Monitoring and maintenance tools
- Backup and restore capabilities
- Network interface auto-detection
- Dark theme by default

## Prerequisites

- macOS
- OrbStack or Docker Desktop
- Homebrew (optional, for dependency installation)

## Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd <repository-name>
```

2. Install Pi-hole:
```bash
sudo make install
```

The installation process will:
- Check system compatibility
- Install required dependencies
- Configure network settings
- Set up Pi-hole in a Docker container
- Configure DNS settings automatically
- Provide web interface access

## Usage

### Basic Commands

```bash
# Show all available commands
make help

# Check system compatibility
make check-os

# Check dependencies
make check-deps

# Install dependencies
make install-deps

# Monitor Pi-hole
make monitor

# View Pi-hole status
make status

# Generate system report
make report

# Show alerts
make alerts
```

### Web Interface

Access the Pi-hole admin interface at:
- `http://localhost:8088/admin`
- Default password: `admin`

### DNS Configuration

The DNS settings are automatically configured during installation. The script:
- Backs up your current DNS settings
- Sets Pi-hole as your DNS server
- Configures all active network interfaces
- Restores original settings during uninstall

### Maintenance

```bash
# Update Pi-hole
make update

# Verify installation
make verify

# Create backup
make backup

# Restore from backup
make restore FILE=<backup_file>

# List available backups
make list-backups
```

### Uninstallation

```bash
sudo make uninstall
```
This will:
- Stop and remove the Pi-hole container
- Restore original DNS settings
- Remove all Pi-hole files

## Directory Structure

```
.
├── Makefile               # Main build and management file
├── scripts/              # Shell scripts for various operations
│   ├── utils.sh          # Utility functions
│   ├── configure.sh      # Configuration script
│   ├── install.sh        # Installation script
│   ├── monitor.sh        # Monitoring script
│   ├── verify.sh         # Verification script
│   └── cleanup.sh        # Cleanup script
├── config/               # Configuration files
└── monitor/              # Monitoring reports and data
```

## Port Usage

- DNS (TCP/UDP): 5353
- Web Interface: 8088
- HTTPS: 4443

## Troubleshooting

### Common Issues

1. Web Interface Not Accessible
    - Check if ports are available
    - Verify firewall settings
    - Ensure container is running

2. DNS Not Working
    - Check if port 5353 is free
    - Verify DNS settings are properly configured
    - Run `make verify` for diagnostics

3. Container Issues
    - Check container logs: `docker logs pihole`
    - Verify port mappings: `docker port pihole`
    - Restart container: `docker restart pihole`

### Diagnostic Commands

```bash
# View Pi-hole logs
docker logs pihole

# Check DNS resolution
nslookup google.com 127.0.0.1 -port=5353

# Test blocking
nslookup doubleclick.net 127.0.0.1 -port=5353

# Verify DNS settings
networksetup -getdnsservers Wi-Fi
```

## Backup and Recovery

The script automatically backs up:
- Original DNS settings
- Pi-hole configuration
- Custom lists and settings

To restore DNS settings manually:
```bash
networksetup -setdnsservers Wi-Fi empty
```

## Updates and Maintenance

Regular maintenance tasks:
1. Update Pi-hole: `make update`
2. Check system status: `make status`
3. Monitor performance: `make monitor`
4. Review logs: `docker logs pihole`

## Security Notes

- Default web interface password is 'admin'
- Change password after installation
- Regular updates recommended
- Monitor system logs for issues

## Contributing

Feel free to submit issues and enhancement requests!
# pihole-mac
