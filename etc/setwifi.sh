#!/bin/sh

DEFAULT_SSIDPREFIX="connbox"
DEFAULT_WIFIPASSWD="connbox000"

MYETH0="eth0.1"
if [ ! -s /etc/macaddr ]; then
	cat /sys/class/net/$MYETH0/address | tr '[a-z]' '[A-Z]' > /etc/macaddr
fi

WLAN0_ISDISABLE=`uci get wireless.radio0.disabled`

# -----------------------------------
# default

if [ "$1" = "default" ]
then

logger -t SYSLOG "Set wifi interface to default..."
MAC=`cat /etc/macaddr | sed 's/://g' | tail -c 6`

if [ $WLAN0_ISDISABLE = "1" ]; then
	uci set wireless.radio0.disabled=0
	uci commit wireless && wifi
fi

uci delete wireless.radio0.ht_capab
uci set wireless.radio0=wifi-device
uci set wireless.radio0.type=mac80211
uci set wireless.radio0.channel=`lua /etc/bestchannel.lua`
uci set wireless.radio0.hwmode='11ng'
uci set wireless.radio0.path='10180000.wmac'
uci add_list wireless.radio0.ht_capab=GF
uci add_list wireless.radio0.ht_capab=SHORT-GI-20
uci add_list wireless.radio0.ht_capab=SHORT-GI-40
uci add_list wireless.radio0.ht_capab=RX-STBC1
uci set wireless.radio0.htmode=HT20
uci set wireless.radio0.disabled=0
uci set wireless.@wifi-iface[0]=wifi-iface
uci set wireless.@wifi-iface[0].device=radio0
uci set wireless.@wifi-iface[0].network=wlan
uci set wireless.@wifi-iface[0].mode=ap
uci set wireless.@wifi-iface[0].ssid=${DEFAULT_SSIDPREFIX}$MAC
uci set wireless.@wifi-iface[0].encryption=psk2
uci set wireless.@wifi-iface[0].key=$DEFAULT_WIFIPASSWD

uci set network.wlan.proto=static
uci set network.wlan.netmask='255.255.255.0'
uci set network.wlan.ipaddr='192.168.10.1'
uci set network.wlan.ifname='wlan0'
uci set network.wlan.type='bridge'
uci delete network.wlan.gateway

#enable dhcp server
uci set dhcp.@dhcp[0].ignore=0

uci commit
/etc/init.d/network reload

#reset any configuration files
rm -f /tmp/apply_netconfig.sh

#reset wifi
wifi down && wifi up


exit 0

fi

# -----------------------------------
# Access point

if [ "$1" = "ap" ]
then

logger -t SYSLOG "SETWIFI Set wifi interface to access point, ssid: " $2 ", encryption: " $3 ", channel: " $4 ", key: " $5 ", ..."

if [ $WLAN0_ISDISABLE = "1" ]; then
	uci set wireless.radio0.disabled=0
	uci commit wireless && wifi
fi

uci set wireless.@wifi-iface[0].mode=ap
uci set wireless.@wifi-iface[0]=wifi-iface
uci set wireless.@wifi-iface[0].device=radio0
uci set wireless.@wifi-iface[0].network=wlan
uci set wireless.@wifi-iface[0].ssid="$2"
uci set wireless.@wifi-iface[0].encryption=$3
uci set wireless.@wifi-iface[0].key="$5"
uci set wireless.radio0.channel=$4
uci set wireless.@wifi-iface[0].network=wlan

uci set network.wlan.proto=static
uci set network.wlan.netmask='255.255.255.0'
uci set network.wlan.ipaddr='192.168.10.1'
uci set network.wlan.ifname='wlan0'
uci set network.wlan.type='bridge'
uci delete network.wlan.gateway

#enable dhcp server
uci set dhcp.@dhcp[0].ignore=0

uci commit
/etc/init.d/network reload

#reset wifi
wifi down && wifi up

exit 0

fi

# -----------------------------------
# scanning wifi

if [ "$1" = "scan" ]
then

logger -t SYSLOG "SETWIFI Scanning wifi..."
if [ $WLAN0_ISDISABLE = "1" ]; then
	uci set wireless.radio0.disabled=0
	uci commit wireless && wifi up
fi
iw dev wlan0 scan

#wifi down
#iw phy phy0 interface add scan0 type station > /dev/null
#ifconfig scan0 up > /dev/null
#iwlist scan0 scan > /tmp/wlist
#iw dev scan0 del > /dev/null
#wifi down > /dev/null

exit 0

fi

# -----------------------------------
# client configuration

if [ "$1" = "sta" ]
then

logger -t SYSLOG "SETWIFI Set wireless to client wifi ssid: $2, encryption: $3, key: $4, proto: $5, ipaddr: $6, netmask: $7, gateway: $8"

MAC=`cat /etc/macaddr | sed 's/://g' | tail -c 6`

if [ $WLAN0_ISDISABLE = "1" ]; then
	uci set wireless.radio0.disabled=0
	uci commit wireless && wifi
fi

# disable dhcp server
uci set dhcp.@dhcp[0].ignore=1

#uci delete wireless.radio0.htmode
uci set wireless.@wifi-device[].channel=''
uci set wireless.@wifi-iface[].mode=sta
uci set wireless.@wifi-iface[].ssid="$2"
uci set wireless.@wifi-iface[].encryption=$3
uci set wireless.@wifi-iface[].key="$4"

uci set network.wlan.hostname=CBOX$MAC
uci set network.wlan.proto=$5
if [ "$5" = "dhcp" ]
then
uci delete network.wlan.netmask
uci delete network.wlan.ipaddr
uci delete network.wlan.gateway
else
uci set network.wlan.ipaddr=$6
uci set network.wlan.netmask=$7
uci set network.wlan.gateway=$8
fi
# remove bridge between wan
uci delete network.wlan.type

uci commit
/etc/init.d/network reload

#reset wifi
wifi down && wifi up

# cleanup temporary apply file
rm -f /tmp/apply_netconfig.sh

COUNT=10
while [ $COUNT -gt 0 ]
do
	sleep 2
	CONNECTED=`iw dev wlan0 link | grep Connected`
	if [ -z "$CONNECTED" ]; then
		COUNT=$(( COUNT-1 ))
		echo "..."
	else
		echo "Ok"
		exit 0
	fi


done

logger -t SYSLOG "SETWIFI Link not ready. Reset to default..."
ash /etc/setwifi.sh default


exit 0
fi

if [ "$1" = "teststa" ]
then

logger -t SYSLOG "SETWIFI Set wireless to client wifi ssid: $2, encryption: $3, key: $4, proto: $5, ipaddr: $6, netmask: $7, gateway: $8"

if [ $WLAN0_ISDISABLE = "1" ]; then
	uci set wireless.radio0.disabled=0
	uci commit wireless && wifi
fi

if [ -e /tmp/apply_netconfig.sh ]; then
	exit 0
fi

# disable dhcp server
# uci set dhcp.@dhcp[0].ignore=1

# Ensure that previous apply network config have been deleted
rm -f /tmp/apply_netconfig.sh

# Enable Test Network Interface
uci set network.wlantest.disabled=0

# Add Wireless interface because it not exists by default
uci add wireless wifi-iface

#uci delete wireless.radio0.htmode
uci set wireless.@wifi-iface[1].device=radio0
uci set wireless.@wifi-iface[1].network=wlantest
uci set wireless.@wifi-iface[1].mode=sta
uci set wireless.@wifi-iface[1].ssid="$2"
uci set wireless.@wifi-iface[1].encryption=$3
uci set wireless.@wifi-iface[1].key="$4"

uci set network.wlantest.proto=$5
if [ "$5" = "dhcp" ]
then
uci delete network.wlantest.netmask
uci delete network.wlantest.ipaddr
uci delete network.wlantest.gateway
else
uci set network.wlantest.ipaddr=$6
uci set network.wlantest.netmask=$7
uci set network.wlantest.gateway=$8
fi
# remove bridge between wan
uci delete network.wlantest.type

uci commit
# /etc/init.d/network reload

#reset wifi
# wifi down && wifi up
wifi reload

COUNT=10
while [ $COUNT -gt 0 ]
do
	sleep 2
	CONNECTED=`iw dev wlan0 link | grep Connected`
	if [ -z "$CONNECTED" ]; then
		COUNT=$(( COUNT-1 ))
		echo "..."
	else
		echo "sleep 2" > /tmp/apply_netconfig.sh
		echo "wifi down && wifi up" >> /tmp/apply_netconfig.sh

		# Store information for client connection
		if [ "$5" = "dhcp" ]
		then
			echo "ash /etc/setwifi.sh sta \"$2\" \"$3\" \"$4\" $5" >> /tmp/apply_netconfig.sh
		else
			echo "ash /etc/setwifi.sh sta \"$2\" \"$3\" \"$4\" $5 $6 $7 $8" >> /tmp/apply_netconfig.sh
		fi

		# Disable unusued network interface
		uci set network.wlantest.disabled=1

		# Remove new interface to prevent duplicates in the future
		uci delete wireless.@wifi-iface[1]
		uci commit
		# wifi reload
		# /etc/init.d/network reload
		echo "Ok"
		exit 0
	fi


done

# Disable unusued network interface
uci set network.wlantest.disabled=1

# Remove new interface to prevent duplicates in the future
uci delete wireless.@wifi-iface[1]
uci commit

logger -t SYSLOG "SETWIFI Link not ready. Reset to default..."
# ash /etc/setwifi.sh default
# wifi reload
/etc/init.d/network reload
wifi down && wifi up

exit 0
fi

# -----------------------------------
# disable wifi configuration

if [ "$1" = "off" ]
then

uci set wireless.radio0.disabled=1
uci commit wireless && wifi
exit 0
fi
  -t SYSLOG "SETWIFI Command not recognized"