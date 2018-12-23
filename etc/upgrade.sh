#!/bin/sh

# Stop Services
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
	WLAN0_KEY=`uci get wireless.@wifi-iface[0].key`
	WLAN0_ENC=`uci get wireless.@wifi-iface[].encryption`

	WLAN0_IPADDR=`uci get network.wlan.ipaddr`
	WLAN0_MASK=`uci get network.wlan.netmask`
	WLAN0_GTW=`uci get network.wlan.gateway`

	echo "ash /etc/setwifi.sh $WLAN0_MODE $WLAN0_SSID $WLAN0_ENC $WLAN0_KEY $WLAN0_PROTO $WLAN0_IPADDR $WLAN0_MASK $WLAN0_GTW" >> "/etc/upgrade_config.sh"
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

# Store File that have to be preserved
TIMER_LINE='/etc/timer.json'
UPGRADE_LINE='/etc/upgrade_config.sh'
FILE=/etc/sysupgrade.conf

grep -qF -- "$TIMER_LINE" "$FILE" || echo "$TIMER_LINE" >> "$FILE"
grep -qF -- "$UPGRADE_LINE" "$FILE" || echo "$UPGRADE_LINE" >> "$FILE"


TESTSYSUPGRADE=$(sysupgrade -T /tmp/firmware.bin)
if [ -n "$TESTSYSUPGRADE" ]; then 
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