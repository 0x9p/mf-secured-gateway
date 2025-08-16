#!/bin/bash
#
# MF Secured Gateway Uninstall Script
# ===================================
# This script safely removes the secured gateway configuration created by install-mf-gateway.sh
#
# Author: 0x9p
# Version: 1.0.0
# License: MIT
#

set -euo pipefail

readonly SCRIPT_NAME="$(basename "${0}")"
readonly LOG_FILE="./uninstall-mf-gateway.log"

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging Functions
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

print_banner() {
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              MF Secured Gateway Uninstall                   ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo
}

print_usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Options:
    -h, --help          Show this help message
    -v, --version       Show version information


Examples:
    $SCRIPT_NAME                    # Remove secured gateway configuration


EOF
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

get_gateway_connections() {
    local gateway_connections=()
    
    # Find gateway connections
    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*([^[:space:]]+)[[:space:]]+wifi ]]; then
            local conn_name="$line"
            # Check if this is a gateway connection
            if nmcli connection show "$conn_name" | grep -q "802-11-wireless.mode: ap"; then
                gateway_connections+=("$conn_name")
            fi
        fi
    done < <(nmcli connection)
    
    echo "${gateway_connections[@]}"
}

remove_gateway_connections() {
    local gateway_connections=($(get_gateway_connections))
    
    if [[ ${#gateway_connections[@]} -eq 0 ]]; then
        log_info "No gateway connections found to remove"
        return 0
    fi
    
    log_info "Found gateway connections: ${gateway_connections[*]}"
    
    for conn in "${gateway_connections[@]}"; do
        log_info "Removing connection: $conn"
        
        # Bring down the connection first
        nmcli connection down "$conn" 2>/dev/null || true
        
        # Delete the connection
        if nmcli connection delete "$conn"; then
            log_success "Removed connection: $conn"
        else
            log_warning "Failed to remove connection: $conn"
        fi
    done
}

reset_wifi_interfaces() {
    log_info "Resetting WiFi interfaces to managed mode..."
    
    # Reset wlan2 to managed mode (common gateway interface)
    for interface in wlan2 wlan1; do
        if nmcli device show "$interface" &> /dev/null; then
            log_info "Resetting $interface to managed mode"
            nmcli device set "$interface" managed yes 2>/dev/null || true
        fi
    done
}

show_status() {
    echo
    log_info "Uninstall completed! Current status:"
    echo "══════════════════════════════════════════════════════════════"
    
    # Show device status
    nmcli device status
    
    echo
    echo "══════════════════════════════════════════════════════════════"
    
    # Show remaining connections
    log_info "Remaining connections:"
    nmcli connection show --active
    
    echo
    log_success "MF Secured Gateway configuration has been removed!"
    log_info "Your device is now back to normal WiFi client mode"
}

main() {
    # Initialize log file
    echo "$(date): Starting $SCRIPT_NAME" > "$LOG_FILE"
    
    print_banner
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                print_usage
                exit 0
                ;;
            -v|--version)
                echo "$SCRIPT_NAME version 1.0.0"
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
    
    # Confirm uninstall
    echo
    log_warning "This will remove all MF Secured Gateway configurations!"
    echo "Your device will return to normal WiFi client mode."
    echo
    
    read -p "Are you sure you want to continue? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "Uninstall cancelled by user"
        exit 0
    fi
    

    
    # Perform uninstall
    remove_gateway_connections
    reset_wifi_interfaces
    show_status
    
    log_success "Uninstall completed successfully!"
}

# Trap errors and cleanup
trap 'log_error "Script failed at line $LINENO"; exit 1' ERR

# Run main function
main "$@" 