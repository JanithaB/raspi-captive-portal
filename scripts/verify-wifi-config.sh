#!/bin/bash

# Script to verify WiFi configuration and troubleshoot connection issues

echo "======================================"
echo "WiFi Configuration Verification"
echo "======================================"
echo ""

# Check wpa_supplicant.conf
echo "1. Checking wpa_supplicant.conf..."
if [ -f "/etc/wpa_supplicant/wpa_supplicant.conf" ]; then
    echo "✓ File exists"
    echo ""
    echo "Configuration preview (passwords hidden):"
    sudo cat /etc/wpa_supplicant/wpa_supplicant.conf | sed 's/psk=.*/psk=***HIDDEN***/g'
    echo ""
    
    # Check for plain text passwords (which can cause issues)
    if sudo grep -q 'psk="' /etc/wpa_supplicant/wpa_supplicant.conf; then
        echo "⚠ WARNING: Found plain text password in config"
        echo "  Plain text passwords (psk=\"password\") may not work reliably"
        echo "  The config should use hashed PSK (psk=hex...)"
        echo ""
    fi
else
    echo "✗ wpa_supplicant.conf NOT FOUND"
fi

# Check saved credentials
echo "2. Checking saved WiFi credentials..."
if [ -f "/etc/raspi-captive-portal/wifi_ssid" ]; then
    SAVED_SSID=$(sudo cat /etc/raspi-captive-portal/wifi_ssid)
    echo "✓ Saved SSID: $SAVED_SSID"
else
    echo "✗ No saved SSID"
fi

if [ -f "/etc/raspi-captive-portal/wifi_password" ]; then
    echo "✓ Saved password exists"
else
    echo "✗ No saved password"
fi

echo ""

# Check wpa_supplicant service
echo "3. Checking wpa_supplicant service..."
if systemctl is-active wpa_supplicant &> /dev/null; then
    echo "✓ wpa_supplicant is running"
else
    echo "✗ wpa_supplicant is NOT running"
fi

if systemctl is-enabled wpa_supplicant &> /dev/null; then
    echo "✓ wpa_supplicant is enabled"
else
    echo "⚠ wpa_supplicant is NOT enabled (won't start on boot)"
fi

# Check interface-specific service
if systemctl list-unit-files | grep -q "wpa_supplicant@wlan0.service"; then
    echo ""
    echo "Interface-specific service found:"
    if systemctl is-active wpa_supplicant@wlan0 &> /dev/null; then
        echo "✓ wpa_supplicant@wlan0 is running"
    else
        echo "✗ wpa_supplicant@wlan0 is NOT running"
    fi
    
    if systemctl is-enabled wpa_supplicant@wlan0 &> /dev/null; then
        echo "✓ wpa_supplicant@wlan0 is enabled"
    else
        echo "⚠ wpa_supplicant@wlan0 is NOT enabled"
    fi
fi

echo ""

# Check current WiFi connection
echo "4. Checking current WiFi connection..."
if iwgetid wlan0 &> /dev/null; then
    CURRENT_SSID=$(iwgetid wlan0 -r)
    echo "✓ Connected to: $CURRENT_SSID"
else
    echo "✗ Not connected to any network"
fi

# Check IP address
if ip addr show wlan0 | grep -q "inet "; then
    IP_ADDR=$(ip addr show wlan0 | grep "inet " | awk '{print $2}')
    echo "✓ IP Address: $IP_ADDR"
else
    echo "⚠ No IP address assigned"
fi

echo ""

# Check internet connectivity
echo "5. Checking internet connectivity..."
if ping -c 1 -W 5 8.8.8.8 &> /dev/null; then
    echo "✓ Internet is reachable"
else
    echo "✗ No internet connectivity"
fi

echo ""

# Show wpa_supplicant status
echo "6. wpa_supplicant status:"
wpa_cli -i wlan0 status 2>/dev/null || echo "✗ Could not get wpa_supplicant status"

echo ""
echo "======================================"
echo "Recommendations"
echo "======================================"
echo ""

# Check if password is plain text
if [ -f "/etc/wpa_supplicant/wpa_supplicant.conf" ]; then
    if sudo grep -q 'psk="' /etc/wpa_supplicant/wpa_supplicant.conf; then
        echo "⚠ Issue: Plain text password detected"
        echo "  Solution: Reconfigure WiFi using the captive portal or run:"
        echo "  sudo /usr/local/bin/switch-to-wifi-client.sh \"YourSSID\" \"YourPassword\""
        echo ""
    fi
fi

# Check if services are enabled
if ! systemctl is-enabled wpa_supplicant &> /dev/null; then
    echo "⚠ Issue: wpa_supplicant not enabled for boot"
    echo "  Solution: sudo systemctl enable wpa_supplicant"
    echo ""
fi

echo "To reconfigure WiFi from scratch:"
echo "  1. Switch back to AP mode: sudo /usr/local/bin/switch-to-ap-mode.sh"
echo "  2. Connect to AP and use captive portal to enter credentials"
echo ""
