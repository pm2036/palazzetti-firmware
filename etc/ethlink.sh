#!/bin/sh

if [ ! -z $1 ]; then
	if [ $1 = "-v" ]; then
		VERBOSE=1
	else
		VERBOSE=0
	fi
fi

MYBOARD=$(echo `ash /etc/myboard.sh`)
if [ "$MYBOARD" == "miniembplug" -o "$MYBOARD" == "omni-plug" ]; then
	LINK=$(echo `swconfig dev switch0 port 4 get link | cut -d' ' -f2 | cut -d':' -f2`)
else
	LINK=$(echo `swconfig dev switch0 port 3 get link | cut -d' ' -f2 | cut -d':' -f2`)
fi


STATUS=$(echo `ifstatus lan | grep '"up":' | cut -d':' -f2 | cut -d',' -f1`)


if [ "$LINK" = "down" -a "$STATUS" = "true" ]; then
	ifdown lan
	wifi down && wifi && kill -9 `ps | grep [mqtt].lua | awk '{print $1}'`
	if [ "$VERBOSE" ]; then
		echo "down"
	fi
	exit
fi

if [ "$LINK" = "up" -a "$STATUS" = "false" ]; then
	ifup lan && kill -9 `ps | grep [mqtt].lua | awk '{print $1}'`
	if [ "$VERBOSE" ]; then
		echo "up"
	fi
	exit
fi

if [ "$LINK" = "up" -a "$STATUS" = "true" ]; then
	if [ "$VERBOSE" ]; then
		echo "up"
	fi
else
	if [ "$VERBOSE" ]; then
		echo "down"
	fi
fi
