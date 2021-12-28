#!/bin/bash
MYETH0="eth0.1"


# -----------------------------------
# default

if [ "$1" = "default" ]
then

MAC=`cat /etc/macaddr | sed 's/://g' | tail -c 6`

echo "Set eth0 interface to default..."
uci set network.lan.hostname=CBOX$MAC

uci set network.lan.ifname=$MYETH0
uci set network.lan.netmask='255.255.255.0'
uci set network.lan.ipaddr='192.168.0.177'
uci delete network.lan.dns
uci delete network.lan.ip6assign
uci set network.lan.gateway="192.168.0.116"
uci set network.lan.proto=static

uci commit network

ifdown lan
ifup lan

wifi up radio0

exit 0

fi

# -----------------------------------
# dhcp

if [ "$1" = "dhcp" ]
then

MAC=`cat /etc/macaddr | sed 's/://g' | tail -c 6`

echo "Set eth interface to dhcp..."
uci set network.lan.hostname=CBOX$MAC

uci set network.lan.ifname=$MYETH0
uci delete network.lan.netmask
uci delete network.lan.ipaddr
uci delete network.lan.dns
uci delete network.lan.ip6assign
uci set network.lan.gateway="0.0.0.0"
uci set network.lan.proto=dhcp
uci commit network

ifdown lan
ifup lan

wifi up radio0

exit 0

fi

# -----------------------------------
# static configuration

if [ "$1" = "static" ]
then

MAC=`cat /etc/macaddr | sed 's/://g' | tail -c 6`

echo "Set eth to static ETH0_MASK:" $2 ", ETH0_ADDR: " $3 ", ETH0_GW: " $4 "..."
uci set network.lan.hostname=CBOX$MAC

uci set network.lan.ifname=$MYETH0
uci set network.lan.netmask=$2
uci set network.lan.ipaddr=$3
uci set network.lan.dns=''
uci set network.lan.proto=static
uci set network.lan.gateway=$4
uci commit network

ifdown lan
ifup lan

wifi up radio0

route add default gw $4

exit 0
fi

echo "Command not recognized"