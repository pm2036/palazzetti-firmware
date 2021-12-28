#!/bin/sh

# Store File that have to be preserved
# Legacy OpenWRT Network Configuration
LEGACY_NETWORK_LINE='/etc/network_config'
# Custom Files
LABEL_LINE='/etc/appliancelabel'
TIMER_LINE='/etc/timer.json'
BLE_DEVICES_LINE='/etc/devices.json'
# Current OpenWRT Network Configuration
NETWORK_LINE='/etc/config/network'
WIRELESS_LINE='/etc/config/wireless'
DHCP_LINE='/etc/config/dhcp'
# Default Sysupgrade config file
FILE=/etc/sysupgrade.conf

# Stop Services
/etc/init.d/cron stop
/etc/init.d/plzwatchdog stop
killall lua
killall mosquitto_sub
killall mosquitto_pub

# Make led blinking
swconfig dev rt305x port 4 set led 10
swconfig dev rt305x set apply

rm -f "$LEGACY_NETWORK_LINE"

# Flag that upgrade operation is in progress to prevent default mode for Wi-Fi and Ethernet
echo "UPGRADE_CONFIG_SECTION" >> "$LEGACY_NETWORK_LINE"

if [ ! -f "/etc/systemver" ] || [ "$(cat /etc/systemver | cut -c 1-2)" = '1.' ] || [ "$(cat /etc/systemver | cut -c 1-2)" = '2.' ]; then
	# Save Wi-Fi Network Configurations

	WLAN0_MODE=`uci get wireless.@wifi-iface[0].mode`
	WLAN0_ISDISABLE=`uci get wireless.radio0.disabled`
	WLAN0_PROTO=`uci get network.wlan.proto`

	if [ $WLAN0_MODE = "ap" ]; then
		WLAN0_MODE="default"
	fi

	if [ $WLAN0_ISDISABLE = "1" ]; then
		WLAN0_MODE="off"
	fi

	echo "WIRELESS_CONFIG_SECTION" >> "$LEGACY_NETWORK_LINE"
	echo "WMODE    |$WLAN0_MODE" >> "$LEGACY_NETWORK_LINE"

	if [ $WLAN0_MODE = "sta" ]; then
		WLAN0_SSID=`uci get wireless.@wifi-iface[0].ssid`
		WLAN0_KEY=`uci get wireless.@wifi-iface[0].key | sed -r 's/[$]+/\\$/g'` # escape special char $
		WLAN0_ENC=`uci get wireless.@wifi-iface[].encryption`

		WLAN0_IPADDR=`uci get network.wlan.ipaddr`
		WLAN0_MASK=`uci get network.wlan.netmask`
		WLAN0_GTW=`uci get network.wlan.gateway`

		echo "WSSID    |$WLAN0_SSID" >> "$LEGACY_NETWORK_LINE"
		echo "WIFI_KEY |$WLAN0_KEY" >> "$LEGACY_NETWORK_LINE"
		echo "WENC     |$WLAN0_ENC" >> "$LEGACY_NETWORK_LINE"
		echo "WPR      |$WLAN0_PROTO" >> "$LEGACY_NETWORK_LINE"
		echo "WADR     |$WLAN0_IPADDR" >> "$LEGACY_NETWORK_LINE"
		echo "WGW      |$WLAN0_GTW" >> "$LEGACY_NETWORK_LINE"
		echo "WMSK     |$WLAN0_MASK" >> "$LEGACY_NETWORK_LINE"
	fi

	# Save Ethernet Network Configurations

	LAN0_PROTO=`uci get network.lan.proto`
	LAN0_IPADDR=`uci get network.lan.ipaddr`

	if [ $LAN0_IPADDR = "192.168.0.177" ]; then
		LAN0_PROTO="dhcp"
	fi

	echo "ETHERNET_CONFIG_SECTION" >> "$LEGACY_NETWORK_LINE"
	echo "EPR      |$LAN0_PROTO" >> "$LEGACY_NETWORK_LINE"

	if [ $LAN0_PROTO = "static" ]; then
		LAN0_MASK=`uci get network.lan.netmask`
		LAN0_GTW=`uci get network.lan.gateway`

		echo "EADR     |$LAN0_IPADDR" >> "$LEGACY_NETWORK_LINE"
		echo "EMSK     |$LAN0_MASK" >> "$LEGACY_NETWORK_LINE"
		echo "EGW      |$LAN0_GTW" >> "$LEGACY_NETWORK_LINE"
	fi
else
	# Save Network Configurations
	
	grep -qF -- "$DHCP_LINE" "$FILE" || echo "$DHCP_LINE" >> "$FILE"
	grep -qF -- "$NETWORK_LINE" "$FILE" || echo "$NETWORK_LINE" >> "$FILE"
	grep -qF -- "$WIRELESS_LINE" "$FILE" || echo "$WIRELESS_LINE" >> "$FILE"
fi

grep -qF -- "$LABEL_LINE" "$FILE" || echo "$LABEL_LINE" >> "$FILE"
grep -qF -- "$TIMER_LINE" "$FILE" || echo "$TIMER_LINE" >> "$FILE"
grep -qF -- "$BLE_DEVICES_LINE" "$FILE" || echo "$BLE_DEVICES_LINE" >> "$FILE"
grep -qF -- "$LEGACY_NETWORK_LINE" "$FILE" || echo "$LEGACY_NETWORK_LINE" >> "$FILE"

if [ ! -f /tmp/firmware.md5 ] || [ ! -f /tmp/firmware.bin ]; then
	# Clean temporary upgrade configuration file
	rm -f "$LEGACY_NETWORK_LINE"
	# Restart service
	/etc/init.d/plzwatchdog start
	echo ERROR: /tmp/firmware.md5 or /tmp/firmware.bin not exists
	exit 1
fi

if [ "$(md5sum /tmp/firmware.bin | cut -d' ' -f 1 | xargs)" != "$(cat /tmp/firmware.md5)" ]; then
    # Clean temporary upgrade configuration file
    rm -f "$LEGACY_NETWORK_LINE"
    # Restart service
    /etc/init.d/cron start
	/etc/init.d/plzwatchdog start
	echo ERROR: /tmp/firmware.md5 not match with md5sum of /tmp/firmware.bin
	exit 1
fi

TESTSYSUPGRADE=$(sysupgrade -T /tmp/firmware.bin)
if [ ! -z "$TESTSYSUPGRADE" ]; then
	# Clean temporary upgrade configuration file
	rm -f "$LEGACY_NETWORK_LINE"
	# Restart service
	/etc/init.d/cron start
	/etc/init.d/plzwatchdog start
	echo ERROR: /tmp/firmware.bin is not a valid upgrade file
	exit 1
fi

# Cleanup Mac Address
rm -f /etc/macaddr

# Cleanup Default Keep.d files to prevent unexpected file restore after the upgrade
rm -f /lib/upgrade/keep.d/*

# Cleanup Password File
rm -f /etc/shadow

# Start Sysupgrade
sysupgrade /tmp/firmware.bin