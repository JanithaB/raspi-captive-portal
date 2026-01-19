# WiFi Password Issue After Reboot

## Problem
After manually testing the WiFi switch script and rebooting, the system asks for the SSID password again instead of automatically connecting.

## Root Cause
The issue was that WiFi passwords were being saved in **plain text format** in `wpa_supplicant.conf` using:
```
psk="plainTextPassword"
```

This format is not reliably persistent across reboots on some Raspberry Pi configurations. The correct format is to use a **hashed PSK** (pre-shared key).

## Solution Implemented

### 1. Updated `switch-to-wifi-client.sh`
Changed the script to use `wpa_passphrase` command which:
- Generates a properly hashed PSK from the SSID and password
- Creates a secure configuration that persists across reboots
- Is the recommended way to configure WPA/WPA2 networks

**Old code (problematic):**
```bash
cat >> "$WPA_SUPPLICANT_CONF" << EOF
network={
    ssid="$SSID"
    psk="$PASSWORD"
    priority=1
}
EOF
```

**New code (fixed):**
```bash
# Use wpa_passphrase to generate proper PSK hash
wpa_passphrase "$SSID" "$PASSWORD" >> "$WPA_SUPPLICANT_CONF"

# Add priority to the network block
sed -i '$s/}/    priority=1\n}/' "$WPA_SUPPLICANT_CONF"
```

### 2. Enhanced wpa_supplicant Service Management
Added proper service management to ensure wpa_supplicant runs correctly:
- Enable both generic and interface-specific services
- Force configuration reload using `wpa_cli -i wlan0 reconfigure`
- Support for `wpa_supplicant@wlan0.service` (interface-specific service)

## How wpa_passphrase Works

The `wpa_passphrase` command generates a network configuration with a hashed PSK:

```bash
# Input:
wpa_passphrase "MyNetwork" "mypassword"

# Output:
network={
    ssid="MyNetwork"
    #psk="mypassword"
    psk=5f4dcc3b5aa765d61d8327deb882cf99f0e5b4c0e5c8e7e3c0e5b4c0e5c8e7e3
}
```

The hex string (`psk=hex...`) is a secure hash that:
- Cannot be reversed to get the original password
- Is unique to the SSID+password combination
- Persists properly across reboots

## Verification

### Check if Your Config is Correct

Run the verification script:
```bash
sudo bash scripts/verify-wifi-config.sh
```

This will show:
- ✓ If you have hashed PSK (good)
- ⚠ If you have plain text password (problematic)

You can also manually check:
```bash
# View config (passwords will be shown)
sudo cat /etc/wpa_supplicant/wpa_supplicant.conf
```

**Good configuration (hashed PSK):**
```
network={
    ssid="MyNetwork"
    psk=5f4dcc3b5aa765d61d8327deb882cf99f0e5b4c0e5c8e7e3c0e5b4c0e5c8e7e3
    priority=1
}
```

**Bad configuration (plain text):**
```
network={
    ssid="MyNetwork"
    psk="mypassword"
    priority=1
}
```

### Fix Existing Configuration

If you already have a plain text password in your config:

**Option 1: Use the captive portal again**
1. Switch back to AP mode:
   ```bash
   sudo /usr/local/bin/switch-to-ap-mode.sh
   ```
2. Connect to the AP
3. Submit WiFi credentials through the captive portal
   - The updated script will now use `wpa_passphrase`

**Option 2: Run the script manually**
```bash
sudo /usr/local/bin/switch-to-wifi-client.sh "YourSSID" "YourPassword"
```
The updated script will now generate a hashed PSK.

**Option 3: Manually generate the hash**
```bash
# Generate the network config
wpa_passphrase "YourSSID" "YourPassword" | sudo tee -a /etc/wpa_supplicant/wpa_supplicant.conf

# Edit to add priority
sudo nano /etc/wpa_supplicant/wpa_supplicant.conf
# Add "priority=1" before the closing brace

# Restart wpa_supplicant
sudo systemctl restart wpa_supplicant
sudo wpa_cli -i wlan0 reconfigure
```

## Testing

After fixing the configuration:

1. **Test immediate connection:**
   ```bash
   sudo wpa_cli -i wlan0 reconfigure
   sleep 10
   iwgetid wlan0
   ```
   Should show your SSID if connected.

2. **Test after reboot:**
   ```bash
   sudo reboot
   ```
   Wait 2 minutes, then:
   ```bash
   iwgetid wlan0
   ping -c 3 8.8.8.8
   ```
   Should show connection without asking for password.

3. **Check logs:**
   ```bash
   sudo journalctl -u wpa_supplicant -n 50
   sudo journalctl -u wifi-reconnect-on-boot -n 50
   ```

## Additional Improvements

### Interface-Specific Service
Some Raspberry Pi configurations use `wpa_supplicant@wlan0.service` instead of the generic `wpa_supplicant.service`. The scripts now handle both:
```bash
# Enable both services
sudo systemctl enable wpa_supplicant
sudo systemctl enable wpa_supplicant@wlan0  # if it exists

# Check which is running
systemctl status wpa_supplicant
systemctl status wpa_supplicant@wlan0
```

### Configuration Reload
The script now forces wpa_supplicant to reload its configuration:
```bash
wpa_cli -i wlan0 reconfigure
```
This ensures changes take effect immediately without requiring a reboot.

## Why Plain Text Passwords Don't Work Reliably

1. **Permission Issues**: Plain text passwords in config files can have permission problems
2. **Service Startup**: wpa_supplicant may not parse plain text passwords correctly on some versions
3. **Security**: Plain text passwords are less secure
4. **Compatibility**: Hashed PSKs are the standard and more compatible

## Summary

- ✅ **Fixed**: Now uses `wpa_passphrase` to generate hashed PSK
- ✅ **Fixed**: Proper wpa_supplicant service management
- ✅ **Fixed**: Configuration reload after changes
- ✅ **Added**: Verification script to check configuration
- ✅ **Added**: Support for interface-specific wpa_supplicant service

The WiFi credentials should now persist correctly across reboots without asking for the password again.
