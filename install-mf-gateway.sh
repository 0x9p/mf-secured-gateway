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
GATEWAY1_SSID=""
GATEWAY1_PASS=""
GATEWAY1_INTERFACE=""
GATEWAY1_CHANNEL="1"
GATEWAY1_BAND="bg"
GATEWAY1_MODE="ap"
GATEWAY2_SSID=""
GATEWAY2_PASS=""
GATEWAY2_INTERFACE=""
GATEWAY2_CHANNEL="6"
GATEWAY2_BAND="bg"
GATEWAY2_MODE="ap"

# WiFi Driver Configuration
WIFI_DRIVER_INSTALL="false"
WIFI_DRIVER_NAME=""
WIFI_DRIVER_REPO=""
WIFI_DRIVER_CONFLICT=""

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
    
    if [[ ${#interfaces[@]} -lt 3 ]]; then
        log_error "This script requires at least 3 WiFi interfaces"
        log_error "Found: ${interfaces[*]:-none}"
        exit 1
    fi
    
    log_info "Found WiFi interfaces: ${interfaces[*]}"
}

install_wifi_driver() {
    if [[ "$WIFI_DRIVER_INSTALL" != "true" || -z "$WIFI_DRIVER_NAME" ]]; then
        log_info "WiFi driver installation skipped"
        return 0
    fi
    
    log_info "Installing WiFi driver: $WIFI_DRIVER_NAME"
    
    # Check if driver is already loaded
    if lsmod | grep -q "$WIFI_DRIVER_NAME"; then
        log_info "Driver $WIFI_DRIVER_NAME is already loaded"
        return 0
    fi
    
    # Unload conflicting driver if specified
    if [[ -n "$WIFI_DRIVER_CONFLICT" ]]; then
        log_info "Unloading conflicting driver: $WIFI_DRIVER_CONFLICT"
        if lsmod | grep -q "$WIFI_DRIVER_CONFLICT"; then
            modprobe -r "$WIFI_DRIVER_CONFLICT" 2>/dev/null || true
            log_success "Unloaded conflicting driver: $WIFI_DRIVER_CONFLICT"
        else
            log_info "Conflicting driver $WIFI_DRIVER_CONFLICT not loaded"
        fi
    fi
    
    # Install required packages for driver compilation
    log_info "Installing build dependencies..."
    apt install -y build-essential git dkms linux-headers-$(uname -r)
    
    # Clone driver repository if specified
    if [[ -n "$WIFI_DRIVER_REPO" ]]; then
        local driver_dir="/tmp/wifi-driver-${WIFI_DRIVER_NAME}"
        
        log_info "Cloning driver repository..."
        if git clone "$WIFI_DRIVER_REPO" "$driver_dir"; then
            log_success "Driver repository cloned successfully"
        else
            log_error "Failed to clone driver repository"
            return 1
        fi
        
        # Build and install driver
        cd "$driver_dir"
        if [[ -f "Makefile" ]]; then
            log_info "Building driver..."
            if make clean && make; then
                log_success "Driver built successfully"
                
                # Install driver
                if make install; then
                    log_success "Driver installed successfully"
                else
                    log_error "Failed to install driver"
                    return 1
                fi
            else
                log_error "Failed to build driver"
                return 1
            fi
        elif [[ -f "dkms.conf" ]]; then
            log_info "Installing driver using DKMS..."
            if dkms add . && dkms build "$WIFI_DRIVER_NAME" && dkms install "$WIFI_DRIVER_NAME"; then
                log_success "Driver installed successfully using DKMS"
            else
                log_error "Failed to install driver using DKMS"
                return 1
            fi
        else
            log_error "No Makefile or dkms.conf found in driver directory"
            return 1
        fi
        
        # Clean up
        cd /
        rm -rf "$driver_dir"
    else
        # Try to install from package manager
        log_info "Attempting to install driver from package manager..."
        if apt install -y "$WIFI_DRIVER_NAME" 2>/dev/null; then
            log_success "Driver installed from package manager"
        else
            log_warning "Driver not available in package manager, skipping"
        fi
    fi
    
    # Load the driver
    log_info "Loading driver: $WIFI_DRIVER_NAME"
    if modprobe "$WIFI_DRIVER_NAME"; then
        log_success "Driver $WIFI_DRIVER_NAME loaded successfully"
    else
        log_error "Failed to load driver $WIFI_DRIVER_NAME"
        return 1
    fi
    
    # Make driver persistent after reboot
    log_info "Making driver persistent after reboot..."
    if ! grep -q "$WIFI_DRIVER_NAME" /etc/modules; then
        echo "$WIFI_DRIVER_NAME" >> /etc/modules
        log_success "Driver added to /etc/modules for persistence"
    fi
    
    # Blacklist conflicting driver if specified
    if [[ -n "$WIFI_DRIVER_CONFLICT" ]]; then
        log_info "Blacklisting conflicting driver: $WIFI_DRIVER_CONFLICT"
        if ! grep -q "$WIFI_DRIVER_CONFLICT" /etc/modprobe.d/blacklist.conf; then
            echo "blacklist $WIFI_DRIVER_CONFLICT" >> /etc/modprobe.d/blacklist.conf
            log_success "Conflicting driver blacklisted"
        fi
    fi
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
        local required_vars=("INTERNET_SSID" "INTERNET_PASS" "GATEWAY1_SSID" "GATEWAY1_PASS" "GATEWAY2_SSID" "GATEWAY2_PASS" "INTERNET_INTERFACE" "GATEWAY1_INTERFACE" "GATEWAY2_INTERFACE")
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
    
    # Gateway 1 details
    if [[ -z "$GATEWAY1_SSID" ]]; then
        read -p "Enter SSID for first secured gateway: " GATEWAY1_SSID
    fi
    
    if [[ -z "$GATEWAY1_PASS" ]]; then
        read -s -p "Enter password for first secured gateway: " GATEWAY1_PASS
        echo
    fi
    
    # Gateway 2 details
    if [[ -z "$GATEWAY2_SSID" ]]; then
        read -p "Enter SSID for second secured gateway: " GATEWAY2_SSID
    fi
    
    if [[ -z "$GATEWAY2_PASS" ]]; then
        read -s -p "Enter password for second secured gateway: " GATEWAY2_PASS
        echo
    fi
    
    # Interface configuration
    if [[ -z "$INTERNET_INTERFACE" ]]; then
        read -p "Enter interface name for internet connection (e.g., wlan0): " INTERNET_INTERFACE
    fi
    
    if [[ -z "$GATEWAY1_INTERFACE" ]]; then
        read -p "Enter interface name for first secured gateway (e.g., wlan1): " GATEWAY1_INTERFACE
    fi
    
    if [[ -z "$GATEWAY2_INTERFACE" ]]; then
        read -p "Enter interface name for second secured gateway (e.g., wlan2): " GATEWAY2_INTERFACE
    fi
    
    # WiFi driver configuration
    echo
    log_info "WiFi Driver Configuration"
    echo "This will install custom WiFi drivers and unload conflicting ones."
    echo
    log_warning "If you proceed with driver installation, you need active Internet access."
    log_warning "Use a wired Ethernet connection because WiFi may be unavailable until the driver is installed."
    
    read -p "Install custom WiFi driver? (y/N): " install_driver
    if [[ "$install_driver" =~ ^[Yy]$ ]]; then
        WIFI_DRIVER_INSTALL="true"
        
        if [[ -z "$WIFI_DRIVER_NAME" ]]; then
            read -p "Enter WiFi driver name (e.g., rtl8188eus): " WIFI_DRIVER_NAME
        fi
        
        if [[ -z "$WIFI_DRIVER_REPO" ]]; then
            read -p "Enter driver repository URL (optional, press Enter to skip): " WIFI_DRIVER_REPO
        fi
        
        if [[ -z "$WIFI_DRIVER_CONFLICT" ]]; then
            read -p "Enter conflicting driver to unload (e.g., rtl8xxxu, press Enter to skip): " WIFI_DRIVER_CONFLICT
        fi
    fi
    
    # Validate input
    if [[ -z "$INTERNET_SSID" || -z "$INTERNET_PASS" || -z "$GATEWAY1_SSID" || -z "$GATEWAY1_PASS" || -z "$GATEWAY2_SSID" || -z "$GATEWAY2_PASS" || -z "$INTERNET_INTERFACE" || -z "$GATEWAY1_INTERFACE" || -z "$GATEWAY2_INTERFACE" ]]; then
        log_error "All fields are required"
        exit 1
    fi
    
    # Validate WiFi driver configuration if enabled
    if [[ "$WIFI_DRIVER_INSTALL" == "true" && -z "$WIFI_DRIVER_NAME" ]]; then
        log_error "WiFi driver name is required when driver installation is enabled"
        exit 1
    fi
    
    # Confirm configuration
    echo
    log_info "Configuration summary:"
    echo "  Internet SSID: $INTERNET_SSID"
    echo "  Internet Interface: $INTERNET_INTERFACE"
    echo "  Gateway 1 SSID: $GATEWAY1_SSID"
    echo "  Gateway 1 Interface: $GATEWAY1_INTERFACE"
    echo "  Gateway 1 Channel: $GATEWAY1_CHANNEL"
    echo "  Gateway 2 SSID: $GATEWAY2_SSID"
    echo "  Gateway 2 Interface: $GATEWAY2_INTERFACE"
    echo "  Gateway 2 Channel: $GATEWAY2_CHANNEL"
    
    if [[ "$WIFI_DRIVER_INSTALL" == "true" ]]; then
        echo "  WiFi Driver: $WIFI_DRIVER_NAME"
        if [[ -n "$WIFI_DRIVER_REPO" ]]; then
            echo "  Driver Repository: $WIFI_DRIVER_REPO"
        fi
        if [[ -n "$WIFI_DRIVER_CONFLICT" ]]; then
            echo "  Conflicting Driver: $WIFI_DRIVER_CONFLICT"
        fi
    fi
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
    log_info "Setting up secured gateways..."
    
    # Setup Gateway 1
    setup_single_gateway "$GATEWAY1_INTERFACE" "$GATEWAY1_SSID" "$GATEWAY1_PASS" "$GATEWAY1_CHANNEL" "$GATEWAY1_BAND" "$GATEWAY1_MODE" "1"
    
    # Setup Gateway 2
    setup_single_gateway "$GATEWAY2_INTERFACE" "$GATEWAY2_SSID" "$GATEWAY2_PASS" "$GATEWAY2_CHANNEL" "$GATEWAY2_BAND" "$GATEWAY2_MODE" "2"
}

setup_single_gateway() {
    local interface="$1"
    local ssid="$2"
    local password="$3"
    local channel="$4"
    local band="$5"
    local mode="$6"
    local gateway_num="$7"
    
    log_info "Setting up secured gateway $gateway_num on $interface..."
    
    # Check if interface exists
    if ! nmcli device show "$interface" &> /dev/null; then
        log_error "Interface $interface not found"
        exit 1
    fi
    
    # Set interface to managed mode
    nmcli device set "$interface" managed yes
    
    # Remove existing connection if it exists
    nmcli connection delete "$ssid" 2>/dev/null || true
    
    # Create new secured gateway connection
    nmcli connection add \
        type wifi \
        ifname "$interface" \
        con-name "$ssid" \
        autoconnect yes \
        ssid "$ssid"
    
    # Configure secured gateway settings with enhanced security
    nmcli connection modify "$ssid" \
        connection.interface-name "$interface" \
        802-11-wireless.mode "$mode" \
        802-11-wireless.band "$band" \
        802-11-wireless.channel "$channel" \
        ipv4.method shared \
        wifi-sec.key-mgmt wpa-psk \
        wifi-sec.psk "$password" \
        wifi-sec.pairwise ccmp \
        wifi-sec.group ccmp \
        wifi-sec.proto rsn
    
    # Enable the connection
    if nmcli connection up "$ssid"; then
        log_success "Secured gateway $gateway_num ($ssid) is now active"
    else
        log_error "Failed to activate secured gateway $gateway_num"
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
    log_info "Clients can now connect to '$GATEWAY1_SSID' and '$GATEWAY2_SSID' for secure access"
    
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
    
    # Install WiFi driver first if enabled
    if [[ "$WIFI_DRIVER_INSTALL" == "true" ]]; then
        install_wifi_driver
    fi
    
    setup_internet_connection
    setup_secured_gateway
    show_status
    
    log_success "MF Secured Gateway installation completed successfully!"
}

# Trap errors and cleanup
trap 'log_error "Script failed at line $LINENO"; exit 1' ERR

# Run main function
main "$@" 