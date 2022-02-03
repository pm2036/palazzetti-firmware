#!/usr/bin/lua

local cjson = require "cjson"
local syscmd = require "palazzetti.syscmd"
local sendmsg = require "palazzetti.sendmsg"
local utils = require "palazzetti.utils"
local bledev = require "palazzetti.bledev"

if (utils:getenvparams()["BLELOOP_ENABLED"] ~= 1) then
	utils:syslogger(DEBUG, "BLELOOP_ENABLED false. Loop cron wont start")
	print("BLELOOP_ENABLED false. Loop cron wont start")
	os.exit()
end

if (utils:file_exists("/tmp/devices/upgrade.json") == true) then
	local _result, _upgrade = pcall(cjson.decode, utils:readfile("/tmp/devices/upgrade.json"))
	if ((_result ~= true) or (_upgrade == nil)) then
		utils:syslogger(DEBUG, "Not valid upgrade status. Abort upgrade procedure")
		print("Not valid upgrade status. Abort upgrade procedure")
		-- Not valid upgrade status
		bledev:upgrade_abort()
		os.exit()
	end

	-- Timeout reached after 10 minutes
	if (math.abs(tonumber(_upgrade["TS"] or utils:getTS("sec")) - utils:getTS("sec")) > (60 * 10)) then
		utils:syslogger(DEBUG, "No more time to perform upgrade")
		print("No more time to perform upgrade")
		-- No more time to perform upgrade
		-- Stop process
		bledev:upgrade_abort()
		os.exit()
	end

	-- Prevent any further action if upgrade is still in progress
	os.exit()
end

-- Check if Bluetooth Loop is available and running
PID=utils:trim(utils:shell_exec("ps | grep [b]leloop.lua"))
if PID~="" then

	utils:syslogger(DEBUG, "BLELOOP_CRON is alive and should check device")
	print("BLELOOP_CRON is alive and should check device")

	-- If keep alive file not found, kill BLE and remove flag
	if ((utils:file_exists("/tmp/devices/keepalive.json") == false) 
	and (utils:fage("/tmp/isUARTBridge") > (1 * 60))) then
		utils:shell_exec("pgrep -f bleloop.lua | xargs kill -9")
		utils:shell_exec("rm -f /tmp/isUARTBridge")
	end

	local _actionResult, _actionData = pcall(cjson.decode, bledev:action_sync())

	if (_actionResult == true and _actionData ~= nil and _actionData["DATA"]) then
		for k,v in pairs(_actionData["DATA"]) do
			sendmsg:execute{command=v,dest="/dev/null"}
		end
	end

	-- Query for devices which are not online
	local _result, _devices = pcall(cjson.decode, syscmd:execute{command="listbledev",ONLINE=false})

	-- if (_result ~= true or _devices == nil or (#_devices["DATA"])<=0) then
	if (_result ~= true or _devices == nil) then
		os.exit()
		return
	end

	-- If one device is not online, pass all devices for reconciliation
	_devices = cjson.decode(syscmd:execute{command="listbledev"})

	local rserial = io.open(utils:getenvparams()["BLELOOP_DEVICE"], "r+")

	utils:syslogger(DEBUG, "BLELOOP_CRON ask for reconnect")
	print("BLELOOP_CRON ask for reconnect")

	-- Ask for reconnection
	local rsequence=utils:lpad("",8,"0")
	rserial:write(rsequence)
	rserial:write("SYSCMD_END" .. cjson.encode(_devices) .. "\n")
	rserial:close()
	return
end