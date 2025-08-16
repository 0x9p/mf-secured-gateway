# MF Secured Gateway Network Installation Script

A bash script for setting up a dual WiFi interface device to act as a **Secured Gateway**. This script connects one interface to an internet source and creates a highly secured access point on the second interface with enterprise-grade security features.

## 🚀 **Key Features**

- 🛡️ **Enhanced Security**: WPA2-PSK, AES-CCMP, RSN security protocols
- 📝 **Professional Design**: Follows bash scripting best practices with proper error handling
- 🎨 **Comprehensive Logging**: All operations are logged with colored output and saved to log files
- ⚙️ **Configuration Management**: Supports both config files and interactive input
- 🔒 **Security**: Proper input validation, error checking, and secure defaults
- 🎯 **Flexibility**: Command-line options and customizable settings
- 📱 **Dual Interface Support**: Designed for devices with multiple WiFi interfaces

## 📋 **Requirements**

- **Operating System**: Linux (tested on Ubuntu/Debian, Raspberry Pi OS)
- **Hardware**: Device with at least 2 WiFi interfaces (e.g., wlan0, wlan1)
- **Permissions**: Root access (use `sudo`)
- **Dependencies**: NetworkManager (`nmcli`)

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
INTERNET_SSID="YourWiFiNetwork"
INTERNET_PASS="YourWiFiPassword"
INTERNET_INTERFACE="wlan1"

# Secured Gateway Settings
GATEWAY_SSID="MFSecuredGateway"
GATEWAY_PASS="SecureGatewayPassword"
GATEWAY_INTERFACE="wlan2"

# Optional Advanced Settings
# GATEWAY_CHANNEL="6"
# GATEWAY_BAND="bg"  # Options: bg (2.4GHz), a (5GHz)
# GATEWAY_MODE="ap"  # Options: ap, ap-hotspot
```

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

## 🌐 **Network Topology**

```
Internet Router
      │
      ▼
   [wlan1] ← Internet Connection
      │
   Device/Raspberry Pi
      │
   [wlan2] ← Secured Gateway
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
