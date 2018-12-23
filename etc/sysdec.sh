#!/bin/sh

/etc/init.d/plzwatchdog stop
echo `cat /etc/key`$2 > /tmp/key
killall lighttpd
openssl aes-256-cbc -d -in $1 -out $1.dec -pass file:/tmp/key
rm $1
sysupgrade -n $1.dec

