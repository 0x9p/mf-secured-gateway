# MF Secured Gateway Network Installation Script

A bash script for setting up a triple WiFi interface device to act as a **Dual Secured Gateway**. This script connects one interface to an internet source and creates two highly secured access points on the remaining interfaces with enterprise-grade security features.

## 🚀 **Key Features**

- 🛡️ **Enhanced Security**: WPA2-PSK, AES-CCMP, RSN security protocols
- 📝 **Professional Design**: Follows bash scripting best practices with proper error handling
- 🎨 **Comprehensive Logging**: All operations are logged with colored output and saved to log files
- ⚙️ **Configuration Management**: Supports both config files and interactive input
- 🔒 **Security**: Proper input validation, error checking, and secure defaults
- 🎯 **Flexibility**: Command-line options and customizable settings
- 📱 **Triple Interface Support**: Designed for devices with three WiFi interfaces

## 📋 **Requirements**

- **Operating System**: Linux (tested on Ubuntu/Debian, Raspberry Pi OS)
- **Hardware**: Device with at least 3 WiFi interfaces (e.g., wlan0, wlan1, wlan2)
- **Permissions**: Root access (use `sudo`)
- **Dependencies**: NetworkManager (`nmcli`)
- **Internet Access**: Required to install packages. If you enable WiFi driver installation, ensure Internet access via a wired Ethernet connection during installation, since WiFi may be unavailable until the driver is installed.

## 🚀 **Quick Start**

1. **Clone or download the script files**
2. **Make the script executable**:
   ```bash
   chmod +x install-mf-gateway.sh
   ```
3. **Run the script**:
   ```bash
   sudo ./install-mf-gateway.sh
   ```

## ⚙️ **Configuration**

### **Option 1: Configuration File (Recommended)**

Edit `mf-gateway.conf` with your network details:

```bash
# Internet Connection Settings
# INTERNET_SSID="YourWiFiNetwork"      # Uplink SSID (case-sensitive)
# INTERNET_PASS="YourWiFiPassword"     # 8-63 chars WPA2/WPA3 passphrase
# INTERNET_INTERFACE="wlan0"           # Interface for internet uplink

# Secured Gateway 1 Settings
# GATEWAY1_SSID="MFSecuredGateway1"      # SSID shown to clients
# GATEWAY1_PASS="SecureGatewayPassword1" # 8-63 chars WPA2-PSK
# GATEWAY1_INTERFACE="wlan1"             # AP interface

# Secured Gateway 2 Settings
# GATEWAY2_SSID="MFSecuredGateway2"      # SSID shown to clients
# GATEWAY2_PASS="SecureGatewayPassword2" # 8-63 chars WPA2-PSK
# GATEWAY2_INTERFACE="wlan2"             # AP interface

# Optional Advanced Settings
# GATEWAY1_MODE="ap"    # Options: ap (access point), ap-hotspot (hotspot mode)
# GATEWAY2_MODE="ap"    # Options: ap (access point), ap-hotspot (hotspot mode)
# GATEWAY1_CHANNEL="1"  # 2.4GHz: 1-13; 5GHz: use 36/40/44/48
# GATEWAY2_CHANNEL="6"  # 2.4GHz: 1-13; 5GHz: use 36/40/44/48
# GATEWAY1_BAND="bg"    # bg (2.4GHz); a (5GHz)
# GATEWAY2_BAND="bg"    # bg (2.4GHz); a (5GHz)

# WiFi Driver Configuration (Optional)
# WIFI_DRIVER_INSTALL="true"
# WIFI_DRIVER_NAME="rtl8188eus"
# WIFI_DRIVER_REPO="https://github.com/aircrack-ng/rtl8188eus.git"
# WIFI_DRIVER_CONFLICT="rtl8xxxu"
```

## 🔐 **VPN Routing via ProtonVPN (WireGuard)**

When enabled, all traffic from the secured access points (`wlan1`, `wlan2`) is routed through a ProtonVPN WireGuard tunnel (`wg0`) over the internet uplink (`wlan0`).

### Requirements
- ProtonVPN account with WireGuard support
- Downloaded WireGuard `.conf` from your ProtonVPN dashboard for Linux/Router
- Active internet access (wired recommended during setup)

### Where to get the WireGuard config (VPN_WG_CONF)
- Sign in to your Proton account and open the ProtonVPN section.
- Go to the area for WireGuard configuration downloads.
- Generate a configuration for your device:
  - Platform: choose Linux or Router
  - Pick your desired server/location and options (e.g., NetShield if available)
- Download the `.conf` file and supply its absolute path to `VPN_WG_CONF`.

### How to Enable
1. Set the following in `mf-gateway.conf`:
   ```bash
   VPN_ENABLE="true"
   VPN_PROVIDER="protonvpn"
   VPN_WG_CONF="/absolute/path/to/proton-wg0.conf"
   VPN_AUTOSTART="true"
   ```
2. Run the installer. You can also enable and provide the path interactively.

### What the script does
- Installs `wireguard` and `iptables-persistent`
- Deploys your config to `/etc/wireguard/wg0.conf` with `chmod 600`
- Brings up `wg0` via `wg-quick up wg0` and optionally enables it on boot
- Enables IPv4 forwarding and configures NAT/forwarding so clients on `wlan1` and `wlan2` egress via `wg0`

### Notes
- Your WireGuard config should include `AllowedIPs = 0.0.0.0/0, ::/0` to route all traffic
- DNS in the config will apply to the device; client DNS is handled by NetworkManager sharing
- To disable VPN routing later, set `VPN_ENABLE="false"` and re-run, or bring down with `wg-quick down wg0`

### **Option 2: Interactive Input**

If no configuration file is found or values are missing, the script will prompt you for input.

## 📖 **Usage**

### **Basic Usage**

```bash
# Use default configuration
sudo ./install-mf-gateway.sh

# Use custom configuration file
sudo ./install-mf-gateway.sh -c myconfig.conf


```

### **Command Line Options**

| Option | Description |
|--------|-------------|
| `-c, --config FILE` | Specify configuration file path |
| `-h, --help` | Show help message |
| `-v, --version` | Show version information |


### **Examples**

```bash
# Standard secured gateway installation
sudo ./install-mf-gateway.sh

# Custom config file
sudo ./install-mf-gateway.sh -c /path/to/config.conf



# Show help
./install-mf-gateway.sh --help

# Show version
./install-mf-gateway.sh --version
```

## 🌐 **Dual Gateway Setup**

This script creates two separate secured access points, providing enhanced network flexibility and capacity:

### **Gateway Configuration**
- **Gateway 1**: Primary secured access point on wlan1
- **Gateway 2**: Secondary secured access point on wlan2
- **Internet**: Single internet connection on wlan0

### **Benefits of Dual Gateway**
- **Load Balancing**: Distribute client connections across two networks
- **Network Segmentation**: Separate networks for different purposes
- **Redundancy**: Backup network if one gateway fails
- **Capacity**: Handle more concurrent connections

### **Channel Configuration**
- **Gateway 1**: Default channel 1 (2.4GHz)
- **Gateway 2**: Default channel 6 (2.4GHz)
- **Non-overlapping**: Channels configured to avoid interference

## 🔧 **WiFi Driver Installation**

> Important: Driver installation occurs before WiFi is configured and requires Internet access for package installation and source downloads (apt, git). Ensure a wired Ethernet connection is active during this step.

The script supports custom WiFi driver installation for compatibility with various WiFi adapters:

### **Features**
- **Universal Driver Support**: Install any WiFi driver from source or package manager
- **Conflict Resolution**: Automatically unload conflicting drivers (e.g., rtl8xxxu)
- **Persistence**: Drivers persist after reboot via `/etc/modules`
- **Blacklisting**: Conflicting drivers are blacklisted to prevent conflicts

### **Supported Installation Methods**
- **Source Compilation**: Clone from Git repository and compile
- **DKMS**: Dynamic Kernel Module Support for automatic rebuilds
- **Package Manager**: Install pre-compiled drivers when available

### **Example: RTL8188EUS Driver**
```bash
# Enable WiFi driver installation
WIFI_DRIVER_INSTALL="true"

# Specify driver name
WIFI_DRIVER_NAME="rtl8188eus"

# Git repository for driver source
WIFI_DRIVER_REPO="https://github.com/aircrack-ng/rtl8188eus.git"

# Conflicting driver to unload
WIFI_DRIVER_CONFLICT="rtl8xxxu"
```

### **Installation Process**
1. **Build Dependencies**: Installs required compilation tools
2. **Driver Source**: Clones and compiles driver from repository
3. **Driver Loading**: Loads the new driver into kernel
4. **Persistence**: Adds driver to `/etc/modules` for boot loading
5. **Conflict Resolution**: Unloads and blacklists conflicting drivers

## 🌐 **Network Topology**

```
Internet Router
      │
      ▼
   [wlan0] ← Internet Connection
      │
   Device/Raspberry Pi
      │
   [wlan1] ← Secured Gateway 1
      │
   [wlan2] ← Secured Gateway 2
      │
   Client Devices
```

### **Debug Mode**

The script creates a log file (`mf-gateway-setup.log`) with detailed information about all operations.

### **Checking Status**

```bash
# View device status
nmcli device status

# View active connections
nmcli connection show --active

# View connection details
nmcli connection show "YourGatewayName"
```

## 🗑️ **Uninstallation**

To remove the MF secured gateway installation:

```bash
sudo ./uninstall-mf-gateway.sh
```

This will:
- Remove all gateway connections
- Reset WiFi interfaces to managed mode
- Restore normal WiFi client functionality
