#!/bin/bash
#
# MF Secured Gateway Network Installation Script
# =============================================
# This script installs and sets up a dual WiFi interface device to act as a secure gateway.
# It connects one interface to an internet source and creates a secured access point
# on the second interface.
#
# Author: 0x9p
# Version: 2.0.0
# License: MIT
#

set -euo pipefail  # Strict error handling

# Script Configuration
# ===================
readonly SCRIPT_NAME="$(basename "${0}")"
readonly SCRIPT_VERSION="2.0.0"
readonly CONFIG_FILE="./mf-gateway.conf"
readonly LOG_FILE="./mf-gateway-setup.log"

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Default values
INTERNET_SSID=""
INTERNET_PASS=""
INTERNET_INTERFACE=""
GATEWAY_SSID=""
GATEWAY_PASS=""
GATEWAY_INTERFACE=""
GATEWAY_CHANNEL="1"
GATEWAY_BAND="bg"
GATEWAY_MODE="ap"

# Logging Functions
# =================
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# Utility Functions
# =================
print_banner() {
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              MF Secured Gateway Installation                 ║"
    echo "║                        Version $SCRIPT_VERSION                        ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo
}

print_usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Options:
    -c, --config FILE    Configuration file path (default: $CONFIG_FILE)
    -h, --help          Show this help message
    -v, --version       Show version information


Examples:
    $SCRIPT_NAME                    # Use default config file
    $SCRIPT_NAME -c myconfig.conf   # Use custom config file


EOF
}

print_version() {
    echo "$SCRIPT_NAME version $SCRIPT_VERSION"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

check_dependencies() {
    local missing_deps=()
    
    for cmd in nmcli systemctl; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_error "Please install NetworkManager: sudo apt install network-manager"
        exit 1
    fi
}

check_wifi_interfaces() {
    local interfaces=()
    
    # Check for WiFi interfaces
    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*([^[:space:]]+)[[:space:]]+wifi ]]; then
            interfaces+=("${BASH_REMATCH[1]}")
        fi
    done < <(nmcli device)
    
    if [[ ${#interfaces[@]} -lt 2 ]]; then
        log_error "This script requires at least 2 WiFi interfaces"
        log_error "Found: ${interfaces[*]:-none}"
        exit 1
    fi
    
    log_info "Found WiFi interfaces: ${interfaces[*]}"
}

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        log_info "Loading configuration from $CONFIG_FILE"
        
        # Source the config file safely
        if ! source "$CONFIG_FILE"; then
            log_error "Failed to load configuration file"
            exit 1
        fi
        
        # Validate required variables
        local required_vars=("INTERNET_SSID" "INTERNET_PASS" "GATEWAY_SSID" "GATEWAY_PASS" "INTERNET_INTERFACE" "GATEWAY_INTERFACE")
        local missing_vars=()
        
        for var in "${required_vars[@]}"; do
            if [[ -z "${!var:-}" ]]; then
                missing_vars+=("$var")
            fi
        done
        
        if [[ ${#missing_vars[@]} -gt 0 ]]; then
            log_warning "Missing required variables in config: ${missing_vars[*]}"
            log_info "Will prompt for missing values"
        fi
    else
        log_warning "Configuration file not found: $CONFIG_FILE"
        log_info "Will prompt for all required values"
    fi
}

get_user_input() {
    echo
    log_info "Please provide the required configuration:"
    echo
    
    # Internet connection details
    if [[ -z "$INTERNET_SSID" ]]; then
        read -p "Enter SSID for internet connection: " INTERNET_SSID
    fi
    
    if [[ -z "$INTERNET_PASS" ]]; then
        read -s -p "Enter password for internet connection: " INTERNET_PASS
        echo
    fi
    
    # Gateway details
    if [[ -z "$GATEWAY_SSID" ]]; then
        read -p "Enter SSID for secured gateway: " GATEWAY_SSID
    fi
    
    if [[ -z "$GATEWAY_PASS" ]]; then
        read -s -p "Enter password for secured gateway: " GATEWAY_PASS
        echo
    fi
    
    # Interface configuration
    if [[ -z "$INTERNET_INTERFACE" ]]; then
        read -p "Enter interface name for internet connection (e.g., wlan1): " INTERNET_INTERFACE
    fi
    
    if [[ -z "$GATEWAY_INTERFACE" ]]; then
        read -p "Enter interface name for secured gateway (e.g., wlan2): " GATEWAY_INTERFACE
    fi
    
    # Validate input
    if [[ -z "$INTERNET_SSID" || -z "$INTERNET_PASS" || -z "$GATEWAY_SSID" || -z "$GATEWAY_PASS" || -z "$INTERNET_INTERFACE" || -z "$GATEWAY_INTERFACE" ]]; then
        log_error "All fields are required"
        exit 1
    fi
    
    # Confirm configuration
    echo
    log_info "Configuration summary:"
    echo "  Internet SSID: $INTERNET_SSID"
    echo "  Internet Interface: $INTERNET_INTERFACE"
    echo "  Gateway SSID: $GATEWAY_SSID"
    echo "  Gateway Interface: $GATEWAY_INTERFACE"
    echo "  Gateway Band: $GATEWAY_BAND"
    echo "  Gateway Channel: $GATEWAY_CHANNEL"
    echo
    
    read -p "Proceed with this configuration? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "Installation cancelled by user"
        exit 0
    fi
}

install_packages() {
    log_info "Updating package list..."
    apt update
    
    log_info "Installing required packages..."
    apt install -y network-manager
    
    log_success "Package installation completed"
}

setup_internet_connection() {
    local interface="$INTERNET_INTERFACE"
    
    log_info "Setting up internet connection on $interface..."
    
    # Check if interface exists
    if ! nmcli device show "$interface" &> /dev/null; then
        log_error "Interface $interface not found"
        exit 1
    fi
    
    # Disconnect existing connections
    nmcli device disconnect "$interface" 2>/dev/null || true
    
    # Connect to WiFi network
    if nmcli device wifi connect "$INTERNET_SSID" password "$INTERNET_PASS" ifname "$interface"; then
        log_success "Successfully connected to $INTERNET_SSID"
    else
        log_error "Failed to connect to $INTERNET_SSID"
        exit 1
    fi
}

setup_secured_gateway() {
    local interface="$GATEWAY_INTERFACE"
    
    log_info "Setting up secured gateway on $interface..."
    
    # Check if interface exists
    if ! nmcli device show "$interface" &> /dev/null; then
        log_error "Interface $interface not found"
        exit 1
    fi
    
    # Set interface to managed mode
    nmcli device set "$interface" managed yes
    
    # Remove existing connection if it exists
    nmcli connection delete "$GATEWAY_SSID" 2>/dev/null || true
    
    # Create new secured gateway connection
    nmcli connection add \
        type wifi \
        ifname "$interface" \
        con-name "$GATEWAY_SSID" \
        autoconnect yes \
        ssid "$GATEWAY_SSID"
    
    # Configure secured gateway settings with enhanced security
    nmcli connection modify "$GATEWAY_SSID" \
        connection.interface-name "$interface" \
        802-11-wireless.mode "$GATEWAY_MODE" \
        802-11-wireless.band "$GATEWAY_BAND" \
        802-11-wireless.channel "$GATEWAY_CHANNEL" \
        ipv4.method shared \
        wifi-sec.key-mgmt wpa-psk \
        wifi-sec.psk "$GATEWAY_PASS" \
        wifi-sec.pairwise ccmp \
        wifi-sec.group ccmp \
        wifi-sec.proto rsn
    
    # Enable the connection
    if nmcli connection up "$GATEWAY_SSID"; then
        log_success "Secured gateway $GATEWAY_SSID is now active"
    else
        log_error "Failed to activate secured gateway"
        exit 1
    fi
}

show_status() {
    echo
    log_info "MF Secured Gateway installation completed successfully! Current status:"
    echo "══════════════════════════════════════════════════════════════"
    
    # Show device status
    nmcli device status
    
    echo
    echo "══════════════════════════════════════════════════════════════"
    
    # Show connection details
    log_info "Connection details:"
    nmcli connection show --active
    
    echo
    log_success "MF Secured Gateway installation is complete!"
    log_info "Clients can now connect to '$GATEWAY_SSID' for secure access"
    
    echo
    log_info "Security features enabled:"
    log_info "  - WPA2-PSK encryption"
    log_info "  - AES-CCMP cipher suite"
    log_info "  - RSN security protocol"
}

main() {
    # Initialize log file
    echo "$(date): Starting $SCRIPT_NAME v$SCRIPT_VERSION" > "$LOG_FILE"
    
    print_banner
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -h|--help)
                print_usage
                exit 0
                ;;
            -v|--version)
                print_version
                exit 0
                ;;

            *)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done
    
    # Pre-flight checks
    check_root
    check_dependencies
    check_wifi_interfaces
    
    # Load configuration and get user input
    load_config
    get_user_input
    

    
    # Perform installation
    install_packages
    setup_internet_connection
    setup_secured_gateway
    show_status
    
    log_success "MF Secured Gateway installation completed successfully!"
}

# Trap errors and cleanup
trap 'log_error "Script failed at line $LINENO"; exit 1' ERR

# Run main function
main "$@" 