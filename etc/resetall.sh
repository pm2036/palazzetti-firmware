#!/bin/sh

/etc/init.d/plzwatchdog stop

logger "reset..."
ash /etc/setwifi.sh default
ash /etc/seteth.sh default

/etc/init.d/plzwatchdog start

