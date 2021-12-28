#!/usr/bin/lua

dofile "/etc/main.lib.lua"
dofile "/etc/param.lib.lua"

local API_KEY=CBOXPARAMS["API-KEY"]
local API_ENDPOINT=CBOXPARAMS["API-ENDPOINT"]
local MAC=CBOXPARAMS["MAC"]
local DELAY=CBOXPARAMS["MQTT_APIPING_DELAY"]

CBOXPARAMS = nil
collectgarbage()

function manageNotificationsUpdate(url)
	local _notificationsPath = "/etc/notifications.json"

	if ((file_exists(_notificationsPath)==true) and (string.find(trim(shell_exec("curl --cacert /etc/cacerts.pem -s -I -X HEAD -H \"If-Modified-Since: " .. trim(shell_exec("date -r " .. _notificationsPath .. " -u +%a,\\ %d\\ %b\\ %Y\\ %H:%M:%S\\ GMT")) .. "\" -H \"Cache-Control: max-age=0\" " .. url)),"HTTP/1.1 200 OK") == nil)) then return end

	local _result, _jdata = pcall(cjson.decode, shell_exec("curl -s --cacert /etc/cacerts.pem " .. url))
	if ((_result == false) or (_jdata == nil)) then return end

	writeinfile(_notificationsPath, cjson.encode(_jdata))
end

while 1 do

	sleep(DELAY)
	output = shell_exec("curl -s --cacert /etc/cacerts.pem --header \"x-api-key: " .. API_KEY .. "\" " .. API_ENDPOINT .. "/thing/" .. MAC .. "")
	if (output:len()>0) then
		jsonrsp = cjson.decode(output)

		if jsonrsp["DATA"]["MacAddress_StatusConnected"]==1 then
			-- THING CONNECTED
			-- print ("THING CONNECTED")

			-- Check for eventually updates regarding Notifications Configuration
			if (jsonrsp["DATA"]["Platform_NotificationsConfigPath"]~=nil) then
				manageNotificationsUpdate(jsonrsp["DATA"]["Platform_NotificationsConfigPath"])
			end

			-- Check for eventually needs to perform another enrollment against IoT Platform
			-- It could happened when there are policy changes or other similar stuff
			if ((jsonrsp["DATA"]["MacAddress_NeedEnrollment"]~=nil) and (jsonrsp["DATA"]["MacAddress_NeedEnrollment"] == true)) then
				-- Cleanup Enrollment files
				os.execute("rm -rf aws-*")
				-- Let the plzwatchdog Restart MQTT services
				-- os.execute("kill -9 `ps | grep [m]qtt.lua | awk '{print $1}'`")
				os.execute("pkill -9 -f \"[m]qtt.*lua\"")
			end

		else
			-- THING DISCONNECTED
			print ("THING DISCONNECTED")
			syslogger("APIPING", "THING DISCONNECTED")
			-- Restart MQTT channels
			-- os.execute("kill -9 `ps | grep [m]qtt.lua | awk '{print $1}'`")
			os.execute("pkill -9 -f \"[m]qtt.*lua\"")
		end
	else
		print("apiping: offline")
	end

end
