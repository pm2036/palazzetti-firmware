#!/bin/sh

# for all platform is correct eth0.1!
MYETH0="eth0.1"
if [ ! -f /etc/appliancelabel ]; then
touch /etc/appliancelabel
fi

if [ $# -gt 0 ]; then
	echo -n "{\"DATA\":{"
fi

echo -n "\"LABEL\":\"`cat /etc/appliancelabel`\","
echo -n "\"SYSTEM\":\"`cat /etc/systemver`\","
ISPLZBRIDGE=`plzbridge -v 2>/dev/null`
if [ -z "$ISPLZBRIDGE" ]; then
	echo -n "\"oembridge\":\"`oembridge -v`\","
else
	echo -n "\"plzbridge\":\"`plzbridge -v`\","
fi

echo -n "\"sendmsg\":\"`sendmsg -v`\","
echo -n "\"CBTYPE\":\"`ash /etc/myboard.sh`\","

#verify internet connection
#OUTPUT=`curl -q --head http://clients3.google.com/generate_204 2>/dev/null`
if [ -e "/tmp/isICONN" ]; then
	echo -n "\"ICONN\":1,"
else
	echo -n "\"ICONN\":0,"
fi

echo -n "\"GWDEVICE\":\"`route -n | grep UG | head -n1 | awk '{print$8}'`\","
echo -n "\"GATEWAY\":\"`route -n | grep UG | head -n1 | awk '{print$2}'`\""

echo -n ","

DNS_ADDR=`cat /tmp/resolv.conf | grep nameserver | awk -vORS=, '{ print "\""$2"\"" }' | sed 's/,$/\n/'`
echo -n "\"DNS\":[$DNS_ADDR],"

ETH0_PROTO=`uci get network.lan.proto`
ETH0_CABLE=$(echo `ash /etc/ethlink.sh -v`)

if [ $ETH0_PROTO = "dhcp" ]; then
	if [ $ETH0_CABLE = "up" ]; then
		ETH0_GW=`route -n | grep $MYETH0 | grep UG | awk '/default|0.0.0.0/ { print $2 }' | head -n 1`
		ETH0_ADDR=`ifconfig $MYETH0 | grep "inet addr" | awk '{print $2}' | cut -d':' -f2`
		ETH0_MASK=`ifconfig $MYETH0 | grep "Mask:" | awk '{print $4}' | cut -d':' -f2`
	else
		ETH0_GW=`uci get network.lan.gateway`
		ETH0_ADDR="0.0.0.0"
		ETH0_MASK="0.0.0.0"
		EBCST="0.0.0.0"
	fi
else
	ETH0_GW=`uci get network.lan.gateway`
	ETH0_ADDR=`uci get network.lan.ipaddr`
	ETH0_MASK=`uci get network.lan.netmask`
fi
ETH0_BCAST=`ifconfig $MYETH0 2>/dev/null | grep Bcast | awk '{print $3}' | cut -d':' -f2`
ETH0_MAC=`cat /sys/class/net/eth0/address | tr '[a-z]' '[A-Z]'`


echo -n "\"MAC\":\"$ETH0_MAC\","

echo -n "\"EADR\":\"$ETH0_ADDR\","
echo -n "\"EBCST\":\"$ETH0_BCAST\","
echo -n "\"EMSK\":\"$ETH0_MASK\","
echo -n "\"EMAC\":\"$ETH0_MAC\","
echo -n "\"EPR\":\"$ETH0_PROTO\","
echo -n "\"EGW\":\"$ETH0_GW\","
echo -n "\"ECBL\":\"$ETH0_CABLE\","

echo -n "\"CLOUD_ENABLED\":true,"

OUTPUT=`ifconfig wlan0 2>&1 | grep "inet addr:"`

WLAN0_PROTO=`uci get network.wlan.proto`
WLAN0_MODE=`uci get wireless.@wifi-iface[0].mode`
WLAN0_ISDISABLE=`uci get wireless.radio0.disabled`
if [ $WLAN0_ISDISABLE = "1" ]; then
	WLAN0_MODE="off"
fi

if [ $WLAN0_MODE = "sta" ]; then
	IWINFO=`iw dev wlan0 link 2>&1`
	WLAN0_ADDR=`ifconfig wlan0 | grep "inet addr" | awk '{print $2}' | cut -d':' -f2`
	WLAN0_BCAST=`ifconfig wlan0 | grep Bcast | awk '{print $3}' | cut -d':' -f2`
	WLAN0_MASK=`ifconfig wlan0 | grep Mask | awk '{print $4}' | cut -d':' -f2`
	WLAN0_MAC=`ifconfig wlan0 | grep HWaddr | awk '{print $5}'`
	WLAN0_SSID=$(echo `echo "$IWINFO" | grep -i ssid | cut -d':' -f2`)
	WLAN0_CHANNEL=`iw dev wlan0 info | grep channel | cut -d' ' -f2`
	WLAN0_POWER=$(echo `echo "$IWINFO" | grep signal | cut -d ':' -f 2`)
elif [ $WLAN0_MODE = "off" ]; then
	WLAN0_ADDR=''
	WLAN0_MASK=''
	WLAN0_MAC=''
	WLAN0_BCAST=''
	WLAN0_SSID=''
	WLAN0_CHANNEL=''
	WLAN0_POWER=''
else
	# access point mode
	WLAN0_ADDR=`uci get network.wlan.ipaddr`
	WLAN0_MASK=`uci get network.wlan.netmask`
	WLAN0_MAC=`ifconfig br-wlan | grep HWaddr | awk '{print $5}'`
	WLAN0_BCAST=`ifconfig br-wlan | grep Bcast | awk '{print $3}' | cut -d':' -f2`
	WLAN0_SSID=`uci get wireless.@wifi-iface[0].ssid`
	WLAN0_CHANNEL=`uci get wireless.radio0.channel`
	WLAN0_POWER=''
fi

WLAN0_ENC=`uci get wireless.@wifi-iface[].encryption`
WLAN0_GW=`route -n | grep wlan0 | grep UG | awk '/default|0.0.0.0/ { print $2 }' | head -n 1`

echo -n "\"WADR\":\"$WLAN0_ADDR\","
echo -n "\"WBCST\":\"$WLAN0_BCAST\","
echo -n "\"WMSK\":\"$WLAN0_MASK\","
echo -n "\"WMAC\":\"$WLAN0_MAC\","
echo -n "\"WPR\":\"$WLAN0_PROTO\","
echo -n "\"WGW\":\"$WLAN0_GW\","
echo -n "\"WMODE\":\"$WLAN0_MODE\","
echo -n "\"WCH\":\"$WLAN0_CHANNEL\","
echo -n "\"WSSID\":\"$WLAN0_SSID\","
echo -n "\"WENC\":\"$WLAN0_ENC\","
echo -n "\"WPWR\":\"$WLAN0_POWER\""

if [ $# -gt 0 ]; then
	echo -n "}}"
fi
