#!/bin/bash

# Emergency fix script for wpa_supplicant configuration issues
# Run this if WiFi password keeps being asked after reboot

echo "======================================"
echo "WPA Supplicant Configuration Fix"
echo "======================================"
echo ""

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (sudo)"
    exit 1
fi

# Check if credentials exist
if [ ! -f "/etc/raspi-captive-portal/wifi_ssid" ] || [ ! -f "/etc/raspi-captive-portal/wifi_password" ]; then
    echo "Error: No saved WiFi credentials found."
    echo "Please connect to WiFi first using the captive portal."
    exit 1
fi

SSID=$(cat /etc/raspi-captive-portal/wifi_ssid)
PASSWORD=$(cat /etc/raspi-captive-portal/wifi_password)

echo "Found saved credentials for SSID: $SSID"
echo ""

# Get country code from hostapd.conf
COUNTRY_CODE="LK"
if [ -f "/etc/hostapd/hostapd.conf" ]; then
    HOSTAPD_COUNTRY=$(grep "^country_code=" /etc/hostapd/hostapd.conf | cut -d'=' -f2)
    if [ -n "$HOSTAPD_COUNTRY" ]; then
        COUNTRY_CODE="$HOSTAPD_COUNTRY"
    fi
fi

echo "Using country code: $COUNTRY_CODE"
echo ""

# Backup existing config
if [ -f "/etc/wpa_supplicant/wpa_supplicant.conf" ]; then
    echo "Backing up existing wpa_supplicant.conf..."
    cp /etc/wpa_supplicant/wpa_supplicant.conf "/etc/wpa_supplicant/wpa_supplicant.conf.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Create fresh wpa_supplicant.conf
echo "Creating new wpa_supplicant.conf..."
cat > /etc/wpa_supplicant/wpa_supplicant.conf << EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=$COUNTRY_CODE

EOF

# Generate network config with hashed PSK
echo "Generating hashed PSK..."
wpa_passphrase "$SSID" "$PASSWORD" >> /etc/wpa_supplicant/wpa_supplicant.conf

# Add priority
sed -i '$s/}/\tpriority=1\n}/' /etc/wpa_supplicant/wpa_supplicant.conf

# Set proper permissions
chmod 600 /etc/wpa_supplicant/wpa_supplicant.conf
chown root:root /etc/wpa_supplicant/wpa_supplicant.conf
chmod 755 /etc/wpa_supplicant

echo ""
echo "=== New wpa_supplicant.conf content (password hidden) ==="
cat /etc/wpa_supplicant/wpa_supplicant.conf | sed 's/psk=.*/psk=***HIDDEN***/g'
echo "=== End ==="
echo ""

# Make config immutable (prevent changes)
echo "Making config file immutable to prevent overwrites..."
chattr +i /etc/wpa_supplicant/wpa_supplicant.conf 2>/dev/null || {
    echo "Note: Could not make file immutable (chattr not available)"
    echo "This is optional - config should still work"
}

# Restart wpa_supplicant
echo "Restarting wpa_supplicant..."
killall wpa_supplicant 2>/dev/null || true
sleep 2
systemctl enable wpa_supplicant
systemctl restart wpa_supplicant

# Try interface-specific service
if systemctl list-unit-files | grep -q "wpa_supplicant@wlan0.service"; then
    systemctl enable wpa_supplicant@wlan0
    systemctl restart wpa_supplicant@wlan0
fi

sleep 3

# Force reload
wpa_cli -i wlan0 reconfigure 2>/dev/null || true
sleep 2

# Check status
echo ""
echo "=== Connection Status ==="
if iwgetid wlan0 &> /dev/null; then
    CONNECTED_SSID=$(iwgetid wlan0 -r)
    echo "✓ Connected to: $CONNECTED_SSID"
    
    if ping -c 1 -W 5 8.8.8.8 &> /dev/null; then
        echo "✓ Internet connectivity confirmed"
    else
        echo "⚠ Connected but no internet"
    fi
else
    echo "✗ Not connected yet (may take a moment)"
    echo "  Wait 30 seconds and check: iwgetid wlan0"
fi

echo ""
echo "======================================"
echo "Done!"
echo "======================================"
echo ""
echo "The configuration is now saved and should persist across reboots."
echo ""
echo "To verify:"
echo "  1. Check connection: iwgetid wlan0"
echo "  2. Reboot: sudo reboot"
echo "  3. After reboot, check: iwgetid wlan0"
echo ""
echo "To remove immutable flag (if you need to edit the config later):"
echo "  sudo chattr -i /etc/wpa_supplicant/wpa_supplicant.conf"
echo ""
