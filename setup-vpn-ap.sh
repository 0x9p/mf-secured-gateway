#!/bin/bash
set -e

# ====================================================
# Raspberry Pi 5: VPN + Dual Wi-Fi Access Points Setup
# ====================================================
# Features:
# 1. Connect wlan0 to internet provider
# 2. Login to ProtonVPN CLI (2FA OTP required)
# 3. Connect to a specific ProtonVPN country
# 4. Setup two Wi-Fi access points (wlan1, wlan2)
# 5. Route client traffic through VPN
# Supports reading parameters from setup.conf
# ====================================================

#!/bin/bash
set -e

CONFIG_FILE="$HOME/setup.conf"

# --------- Load Parameters from .conf if it exists ---------
if [ -f "$CONFIG_FILE" ]; then
    echo "Loading parameters from $CONFIG_FILE..."
    source "$CONFIG_FILE"
else
    echo "No config file found. You will be prompted for input."
fi

# --------- User Input (fallback if variables not set) ---------
: "${INTERNET_WIFI:=$(read -p 'Enter your Wi-Fi network name (SSID) for internet connection: ' ans && echo $ans)}"
: "${INTERNET_PASS:=$(read -s -p 'Enter your Wi-Fi password: ' ans && echo $ans; echo)}"
: "${VPN_COUNTRY:=$(read -p 'Enter ProtonVPN country code (e.g., PL, NL, US): ' ans && echo $ans)}"
: "${SSID1:=$(read -p 'SSID for first access point (wlan1): ' ans && echo $ans)}"
: "${PASS1:=$(read -p 'Password for first AP: ' ans && echo $ans)}"
: "${SSID2:=$(read -p 'SSID for second access point (wlan2): ' ans && echo $ans)}"
: "${PASS2:=$(read -p 'Password for second AP: ' ans && echo $ans)}"

# --------- Install Required Packages ---------
sudo apt update
sudo apt install -y network-manager python3-venv python3-pip python3-setuptools openvpn dialog

# --------- Setup Python Virtual Environment ---------
VENV_DIR="$HOME/protonvpn-env"
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
fi
source "$VENV_DIR/bin/activate"
pip install --upgrade pip
pip install protonvpn

# --------- Connect wlan0 to Internet ---------
echo "Connecting wlan0 to Wi-Fi network $INTERNET_WIFI..."
sudo nmcli device wifi connect "$INTERNET_WIFI" password "$INTERNET_PASS" ifname wlan0

# --------- ProtonVPN Initialization (first-time) ---------
if ! protonvpn status >/dev/null 2>&1; then
    echo "Initializing ProtonVPN CLI..."
    sudo protonvpn init
    echo "Please complete the initialization steps, including 2FA."
    read -p "Press Enter after ProtonVPN initialization is complete..."
fi

# --------- Connect to ProtonVPN server in chosen country ---------
echo "Connecting to ProtonVPN server in $VPN_COUNTRY..."
sudo protonvpn connect --fastest --cc "$VPN_COUNTRY"

# --------- Setup Access Point on wlan1 ---------
echo "Creating first access point ($SSID1)..."
sudo nmcli connection delete "$SSID1" 2>/dev/null || true
sudo nmcli connection add type wifi ifname wlan1 con-name "$SSID1" autoconnect yes ssid "$SSID1"
sudo nmcli connection modify "$SSID1" 802-11-wireless.mode ap 802-11-wireless.band bg ipv4.method shared wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$PASS1"
sudo nmcli connection up "$SSID1"

# --------- Setup Access Point on wlan2 ---------
echo "Creating second access point ($SSID2)..."
sudo nmcli connection delete "$SSID2" 2>/dev/null || true
sudo nmcli connection add type wifi ifname wlan2 con-name "$SSID2" autoconnect yes ssid "$SSID2"
sudo nmcli connection modify "$SSID2" 802-11-wireless.mode ap 802-11-wireless.band bg ipv4.method shared wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$PASS2"
sudo nmcli connection up "$SSID2"

# --------- Enable Auto-Connect for APs ---------
sudo nmcli connection modify "$SSID1" connection.autoconnect yes
sudo nmcli connection modify "$SSID2" connection.autoconnect yes

# --------- Create Systemd Service for VPN Auto-Connect ---------
SERVICE_FILE="/etc/systemd/system/protonvpn-auto.service"
sudo tee $SERVICE_FILE > /dev/null <<EOF
[Unit]
Description=ProtonVPN Auto Connect
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$VENV_DIR/bin/protonvpn connect --fastest --cc $VPN_COUNTRY
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable protonvpn-auto.service
sudo systemctl start protonvpn-auto.service

# --------- Status Summary ---------
echo "=============================================="
echo "Setup complete! Current device status:"
nmcli device status
echo "ProtonVPN will auto-connect on system startup."
echo "All access points are now routing traffic through VPN."
echo "=============================================="
