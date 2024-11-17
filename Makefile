INSTALL_DIR=~/Documents/Scripts/Pihole
SCRIPTS_DIR=$(INSTALL_DIR)/scripts
CONFIG_DIR=$(INSTALL_DIR)/config
MONITOR_DIR=$(INSTALL_DIR)/monitor

# Detect OS
OS_NAME := $(shell uname -s)
ifeq ($(OS_NAME),Darwin)
	OS_TYPE=mac
	PACKAGE_MANAGER=brew
	NETWORK_TOOL=ifconfig
else ifeq ($(OS_NAME),Linux)
	OS_TYPE=linux
	ifeq ($(shell which apt 2>/dev/null),)
		ifeq ($(shell which yum 2>/dev/null),)
			PACKAGE_MANAGER=unknown
		else
			PACKAGE_MANAGER=yum
		endif
	else
		PACKAGE_MANAGER=apt
	endif
	NETWORK_TOOL=ip
endif

.PHONY: all help check-os check-deps install-deps init configure install cleanup update uninstall test verify monitor status report alerts backup restore list-backups

all: help

help:
	@echo "Pi-hole Setup Commands:"
	@echo "make check-os    - Check OS compatibility"
	@echo "make check-deps  - Check required dependencies"
	@echo "make install-deps - Install required dependencies"
	@echo "make install     - Full Pi-hole installation"
	@echo "make cleanup     - Clean up failed installation"
	@echo "make update      - Update Pi-hole"
	@echo "make uninstall   - Remove Pi-hole completely"
	@echo "make test        - Run system tests"
	@echo "make verify      - Verify installation"
	@echo ""
	@echo "Monitoring and Maintenance:"
	@echo "make monitor     - Start system monitoring"
	@echo "make status      - Show current system status"
	@echo "make report      - Generate system report"
	@echo "make alerts      - Show system alerts"
	@echo "make backup      - Create system backup"
	@echo "make restore FILE=<backup_file> - Restore from backup"
	@echo "make list-backups - List available backups"
	@echo ""
	@echo "Detected OS: $(OS_NAME)"
	@echo "Package Manager: $(PACKAGE_MANAGER)"

check-os:
	@if [ "$(OS_TYPE)" = "mac" ]; then \
		echo "macOS detected. Some features might be limited."; \
		echo "Note: Docker Desktop for Mac is required."; \
	elif [ "$(OS_TYPE)" = "linux" ]; then \
		echo "Linux detected. Full functionality available."; \
	else \
		echo "ERROR: Unsupported operating system: $(OS_NAME)"; \
		exit 1; \
	fi

check-deps:
	@missing_deps=""; \
	if ! command -v docker >/dev/null; then \
		missing_deps="$$missing_deps docker"; \
	fi; \
	if ! command -v $(NETWORK_TOOL) >/dev/null; then \
		missing_deps="$$missing_deps $(NETWORK_TOOL)"; \
	fi; \
	if ! command -v sqlite3 >/dev/null; then \
		missing_deps="$$missing_deps sqlite3"; \
	fi; \
	if [ ! -z "$$missing_deps" ]; then \
		echo "Missing dependencies:$$missing_deps"; \
		if [ "$(OS_TYPE)" = "mac" ]; then \
			echo "Run: brew install$$missing_deps"; \
		elif [ "$(PACKAGE_MANAGER)" = "apt" ]; then \
			echo "Run: sudo apt-get install -y$$missing_deps"; \
		elif [ "$(PACKAGE_MANAGER)" = "yum" ]; then \
			echo "Run: sudo yum install -y$$missing_deps"; \
		fi; \
		read -p "Install dependencies? [y/N] " answer; \
		if [ "$$answer" = "y" ]; then \
			$(MAKE) install-deps; \
		else \
			echo "ERROR: Required dependencies not installed"; \
			exit 1; \
		fi; \
	else \
		echo "All dependencies satisfied."; \
	fi

install-deps:
	@if [ "$(OS_TYPE)" = "mac" ]; then \
		brew update && brew install docker sqlite3 || exit 1; \
		echo "Please ensure Docker Desktop is installed."; \
	elif [ "$(PACKAGE_MANAGER)" = "apt" ]; then \
		sudo apt-get update && sudo apt-get install -y docker.io iproute2 sqlite3 || exit 1; \
	elif [ "$(PACKAGE_MANAGER)" = "yum" ]; then \
		sudo yum install -y docker iproute sqlite3 || exit 1; \
		sudo systemctl start docker || exit 1; \
		sudo systemctl enable docker || exit 1; \
	else \
		echo "ERROR: Unsupported package manager"; \
		exit 1; \
	fi

init:
	@echo "Initializing Pi-hole setup..."
	@mkdir -p $(INSTALL_DIR)/{scripts,config,etc-pihole,etc-dnsmasq.d,monitor} || exit 1
	@chmod -R 755 $(SCRIPTS_DIR) || exit 1
	@chmod +x $(SCRIPTS_DIR)/*.sh || exit 1
	@echo "Initialization complete"

configure: init
	@echo "Configuring Pi-hole..."
	@$(SCRIPTS_DIR)/configure.sh || exit 1

install: check-os check-deps configure
	@echo "Installing Pi-hole..."
	@$(SCRIPTS_DIR)/install.sh || (echo "Installation failed" && $(MAKE) cleanup)

cleanup:
	@echo "Cleaning up Pi-hole installation..."
	@$(SCRIPTS_DIR)/cleanup.sh

update:
	@echo "Updating Pi-hole..."
	@$(SCRIPTS_DIR)/update.sh || exit 1

uninstall:
	@echo "Uninstalling Pi-hole..."
	@if [ "$(shell uname)" = "Darwin" ]; then \
		network_services=$$(networksetup -listallnetworkservices | grep -v '*'); \
		for service in $$network_services; do \
			if [ -f "/opt/pihole/dns_backup_$$service" ]; then \
				echo "Restoring DNS settings for $$service..."; \
				dns=$$(cat "/opt/pihole/dns_backup_$$service"); \
				if [ "$$dns" = "There aren't any DNS Servers set on $$service." ]; then \
					sudo networksetup -setdnsservers "$$service" empty; \
				else \
					sudo networksetup -setdnsservers "$$service" $$dns; \
				fi; \
				rm "/opt/pihole/dns_backup_$$service"; \
			fi; \
		done; \
	fi
	@$(SCRIPTS_DIR)/cleanup.sh
	@sudo rm -rf /opt/pihole
	@echo "Pi-hole uninstalled successfully"

test:
	@echo "Running system tests..."
	@$(SCRIPTS_DIR)/test.sh || exit 1

verify:
	@echo "Verifying installation..."
	@$(SCRIPTS_DIR)/verify.sh || exit 1

monitor:
	@$(SCRIPTS_DIR)/monitor.sh start

status:
	@$(SCRIPTS_DIR)/monitor.sh status

report:
	@$(SCRIPTS_DIR)/monitor.sh report

alerts:
	@$(SCRIPTS_DIR)/monitor.sh alerts

backup:
	@$(SCRIPTS_DIR)/backup.sh backup

restore:
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make restore FILE=<backup_file>"; \
		exit 1; \
	fi
	@$(SCRIPTS_DIR)/backup.sh restore $(FILE)

list-backups:
	@$(SCRIPTS_DIR)/backup.sh list