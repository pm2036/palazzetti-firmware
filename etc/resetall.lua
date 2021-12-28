#!/usr/bin/lua

local network = require "palazzetti.network"
local utils = require "palazzetti.utils"

-- logger "reset..."
utils:shell_exec("/etc/init.d/plzwatchdog stop")

network:wifi_default(true)
network:eth_default(true)

utils:shell_exec("/etc/init.d/plzwatchdog start > /dev/null &")