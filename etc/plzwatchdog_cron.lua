#!/usr/bin/lua

dofile "/etc/main.lib.lua"
dofile "/etc/param.lib.lua"

PID=shell_exec("ps | grep [plzwatch]dog.lua")
if PID=="" then
	print("Restart Plzwatchdog")

	os.execute("kill -9 `ps | grep [mosqui]tto | awk '{print $1}'`")
	os.execute("kill -9 `ps | grep [mqtt].lua | awk '{print $1}'`")

	os.execute("/etc/init.d/plzwatchdog stop")
	os.execute("/etc/init.d/plzwatchdog start")
else
	print("watchdog is alive")
end
