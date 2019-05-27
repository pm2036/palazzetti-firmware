#!/bin/sh

# Store File that have to be preserved
NETWORK_LINE='/etc/config/network'
WIRELESS_LINE='/etc/config/wireless'
TIMER_LINE='/etc/timer.json'
UPGRADE_LINE='/etc/upgrade_config.sh'
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

rm -f /etc/upgrade_config.sh

# Save Label Data

LABEL=`cat /etc/appliancelabel`
echo "echo -n \"$LABEL\" > /etc/appliancelabel" >> "/etc/upgrade_config.sh"

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

if [ $WLAN0_MODE = "default" ]; then
	echo "ash /etc/setwifi.sh $WLAN0_MODE" >> "/etc/upgrade_config.sh"
else
	WLAN0_SSID=`uci get wireless.@wifi-iface[0].ssid`
	WLAN0_KEY=`uci get wireless.@wifi-iface[0].key | sed -r 's/[$]+/\\$/g'` # escape special char $
	WLAN0_ENC=`uci get wireless.@wifi-iface[].encryption`

	WLAN0_IPADDR=`uci get network.wlan.ipaddr`
	WLAN0_MASK=`uci get network.wlan.netmask`
	WLAN0_GTW=`uci get network.wlan.gateway`

	if [ ! -f "/etc/systemver" ] || [ "$(cat /etc/systemver | cut -c 1-2)" = '1.' ]; then
		echo "ash /etc/setwifi.sh \"$WLAN0_MODE\" \"$WLAN0_SSID\" \"$WLAN0_ENC\" \"$WLAN0_KEY\" $WLAN0_PROTO $WLAN0_IPADDR $WLAN0_MASK $WLAN0_GTW" >> "/etc/upgrade_config.sh"
	else
		grep -qF -- "$NETWORK_LINE" "$FILE" || echo "$NETWORK_LINE" >> "$FILE"
		grep -qF -- "$WIRELESS_LINE" "$FILE" || echo "$WIRELESS_LINE" >> "$FILE"
	fi
fi

# Save Ethernet Network Configurations

LAN0_PROTO=`uci get network.lan.proto`
LAN0_IPADDR=`uci get network.lan.ipaddr`

if [ $LAN0_IPADDR = "192.168.0.177" ]; then
	LAN0_PROTO="dhcp"
fi

if [ $LAN0_PROTO = "static" ]; then
	LAN0_MASK=`uci get network.lan.netmask`
	LAN0_GTW=`uci get network.lan.gateway`

	echo "ash /etc/seteth.sh $LAN0_PROTO $LAN0_MASK $LAN0_IPADDR $LAN0_GTW" >> "/etc/upgrade_config.sh"
else
	echo "ash /etc/seteth.sh $LAN0_PROTO" >> "/etc/upgrade_config.sh"
fi

chmod +x /etc/upgrade_config.sh

grep -qF -- "$TIMER_LINE" "$FILE" || echo "$TIMER_LINE" >> "$FILE"
grep -qF -- "$UPGRADE_LINE" "$FILE" || echo "$UPGRADE_LINE" >> "$FILE"

if [ ! -f /tmp/firmware.md5 ] || [ ! -f /tmp/firmware.bin ]; then
	# Clean temporary upgrade configuration file
	rm -f /etc/upgrade_config.sh
	# Restart service
	/etc/init.d/plzwatchdog start
	echo ERROR: /tmp/firmware.md5 or /tmp/firmware.bin not exists
	exit 1
fi

if [ "$(md5sum /tmp/firmware.bin | cut -d' ' -f 1 | xargs)" != "$(cat /tmp/firmware.md5)" ]; then
    # Clean temporary upgrade configuration file
    rm -f /etc/upgrade_config.sh
    # Restart service
    /etc/init.d/cron start
	/etc/init.d/plzwatchdog start
	echo ERROR: /tmp/firmware.md5 not match with md5sum of /tmp/firmware.bin
	exit 1
fi

TESTSYSUPGRADE=$(sysupgrade -T /tmp/firmware.bin)
if [ ! -z "$TESTSYSUPGRADE" ]; then
	# Clean temporary upgrade configuration file
	rm -f /etc/upgrade_config.sh
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