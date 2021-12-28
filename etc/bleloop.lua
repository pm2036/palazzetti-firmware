local cjson = require "cjson"
local utils = require "palazzetti.utils"
local sendmsg = require "palazzetti.sendmsg"
local syscmd = require "palazzetti.syscmd"
local bledev = require "palazzetti.bledev"
local ubus = require "palazzetti.ubus".ubus

if (utils:getenvparams()["BLELOOP_ENABLED"] ~= 1) then
	utils:syslogger(DEBUG, "BLELOOP_ENABLED false. Loop wont start")
	print("BLELOOP_ENABLED false. Loop wont start")
	os.exit()
end

if (utils:file_exists("/tmp/devices/upgrade.json") == true) then
	bledev:upgrade()
	return
end

local socket = require "socket"
local rserial = io.open(utils:getenvparams()["BLELOOP_DEVICE"], "r+")

if (rserial == nil) then
	utils:syslogger(DEBUG, "BLELOOP Serial Device not found. Loop wont start")
	print("BLELOOP Serial Device not found. Loop wont start")
	os.exit()
end

local WIFI_NAME
local WIFI_KEY
local WIFI_ENC

local BLELOOP_PID=utils:trim(utils:shell_exec("echo $PPID"))
utils:shell_exec("pgrep -f bleloop.lua | grep -v " .. BLELOOP_PID .. "  | xargs kill -9")

-- Initialize serial with proper Baud Rate
utils:init_serial(utils:getenvparams()["BLELOOP_DEVICE"], utils:getenvparams()["BLELOOP_BAUDRATE"])
-- Second parameter used as local flag instead of Baud Rate (setup by previous line)
utils:init_serial(utils:getenvparams()["BLELOOP_DEVICE"], "-echo")
-- Transform new line to carridge return + new line
-- utils:init_serial(utils:getenvparams()["BLELOOP_DEVICE"], "-onlcr")

-- Initialize serial communication sending welcome to counterpart
-- Await 3 space character char(32) + following text
rserial:write("   WELCOME TO PALAZZETTI\n")

-- Cleanup BLE temporary device status
bledev:clean()

while true do
	-- Open buffer --> each line until \n character
	sbuffer=rserial:read();
	
	-- If buffer received, clean out new line and carrige return characters from buffer
	if (sbuffer ~= nil) then
		sbuffer=string.gsub(sbuffer, "\n$", "")
		sbuffer=string.gsub(sbuffer, "\r$", "")
	else
		print("Check if BLE device is still connected")
		socket.sleep(5)

		if utils:file_exists("/tmp/isUARTBridge")==false then
			utils:syslogger(DEBUG, "Grace quit BLE loop")
			print("Grace quit BLE loop")
			
			bledev:clean()
			os.exit()
		end
	end

	print("[001] received from board: ")
	print(sbuffer)
	
	-- Save Wi-Fi Network Name
	if (sbuffer:find("^WIFI_NAME") ~= nil) then
		utils:syslogger(DEBUG, "WIFI_NAME received")
		print("WIFI_NAME received")

		WIFI_NAME=string.gsub(sbuffer, "WIFI_NAME", "")
		print(WIFI_NAME)
	end

	if (sbuffer:find("^WIFI_KEY") ~= nil) then
		utils:syslogger(DEBUG, "WIFI_KEY received")
		print("WIFI_KEY received")

		WIFI_KEY=string.gsub(sbuffer, "WIFI_KEY", "")
		print(WIFI_KEY)

	end

	if (sbuffer:find("^WIFI_ENC") ~= nil) then
		utils:syslogger(DEBUG, "WIFI_ENC received")
		print("WIFI_ENC received")

		WIFI_ENC=string.gsub(sbuffer, "WIFI_ENC", "")
		print(WIFI_ENC)
	end

	if (sbuffer:find("^WIFI_STATUS") ~= nil) then
		utils:syslogger(DEBUG, "WIFI_STATUS received")
		print("WIFI_STATUS received")
		
		local UBUS_WIFI_STATUS=ubus("network.wireless", "status", {})

		local CURR_WIFI_LINK=0
		if UBUS_WIFI_STATUS["radio0"]["up"] then 
			CURR_WIFI_LINK=1
		end
		
		CURR_WIFI_MODE=UBUS_WIFI_STATUS["radio0"]["interfaces"][1]["config"]["mode"]
		CURR_WIFI_NAME=UBUS_WIFI_STATUS["radio0"]["interfaces"][1]["config"]["ssid"]
		CURR_WIFI_KEY=UBUS_WIFI_STATUS["radio0"]["interfaces"][1]["config"]["key"]

		local UBUS_WLAN_STATUS=ubus("network.interface.wlan", "status", {})
		CURR_WIFI_IPV4=UBUS_WLAN_STATUS["ipv4-address"][1]["address"]
	
		print("WLAN_MODE: " .. CURR_WIFI_MODE)
		print("WIFI_LINK: " .. CURR_WIFI_LINK)

		rserial:write("WLAN_MODE|" .. CURR_WIFI_MODE .. "|WLAN_LINK|" .. CURR_WIFI_LINK .. "|IP|" .. CURR_WIFI_IPV4 .. "|SSID|" .. CURR_WIFI_NAME .."\n")
	end

	if (sbuffer:find("^WIFI_SCAN") ~= nil) then
		utils:syslogger(DEBUG, "WIFI_SCAN received")
		print("WIFI_SCAN received")

		local _result, _list = pcall(cjson.decode, syscmd:execute{command="wifiscan"})
		local _numberOfResult = 0
		
		if (_result==true and _list["SUCCESS"]==true) then
			for k, v in pairs(_list["DATA"]["WLIST"]) do

				if v["essid"]~=nil and v["essid"]~="" then
					_numberOfResult=_numberOfResult+1
				end

				print("SSID" .. k .. v["essid"] .. "<-->" .. v["signal"] .."<-->" .. v["enc_type"] .. "\n")
	  			rserial:write("SSID" .. k .. v["essid"] .. "<-->" .. v["signal"] .."<-->" .. v["enc_type"] .. "\n")
	  			socket.sleep(2)
			end	
		end

		rserial:write("WIFI_SCAN_END|" .. _numberOfResult .. "\n")
	end

	if (sbuffer:find("^WIFI_RESET") ~= nil) then
		utils:syslogger(DEBUG, "WIFI_RESET received")
		print("WIFI_RESET received")

		rserial:write("Resetting WiFi to SoftAP\n")

		WIFI_NAME=nil
		WIFI_KEY=nil
		WIFI_ENC=nil

		local output = syscmd:execute{
			command="setwifi",
			WMODE="default"
		}
		
		print(output)
		output = output:gsub("[\n\r]", " ")
		
		-- print("comando->" .. output .. "<-")
		if (output:find("wifi ap ok") ~= nil) then
			print("SoftAP up and running")
			local UBUS_WIFI_STATUS=ubus("network.wireless", "status", {})
			-- CURR_WIFI_MODE=UBUS_WIFI_STATUS["radio0"]["interfaces"][1]["config"]["mode"]
			CURR_WIFI_NAME=UBUS_WIFI_STATUS["radio0"]["interfaces"][1]["config"]["ssid"]
			CURR_WIFI_KEY=UBUS_WIFI_STATUS["radio0"]["interfaces"][1]["config"]["key"]

			rserial:write("SoftAP up and running: search for SSID:" .. CURR_WIFI_NAME .. " with pw: " .. CURR_WIFI_KEY .. "\n")
		else
			print("command failed!")
			rserial:write("SoftAP setup failed\n")
		end
	end

	if (sbuffer:find("^BLE_RESET") ~= nil) then
		utils:syslogger(DEBUG, "BLE_RESET received")
		print("BLE_RESET received")

		utils:shell_exec("pkill -9 -f bleloop_cron.lua 2> /dev/null")
		bledev:reset({})
		
		os.exit()
	end

	if (sbuffer:find("^OTASETUP") ~= nil) then
		utils:syslogger(DEBUG, "OTASETUP received")
		print("OTASETUP received")

		bledev:upgrade_start({})
		os.exit()
	end

	-- Exit loop if requested by counterpart
	if (sbuffer:find("^BLE_COMM_END") ~= nil) then
		utils:syslogger(DEBUG, "BLE_COMM_END received")
		print("BLE_COMM_END received")

		print("Kill serial interpreter")
		rserial:write("CBox serial interpreter killed. Bye bye!\n")
		os.exit()
	end

	local rsequence = string.sub(sbuffer, 0, 8)
	rsequence=utils:lpad(rsequence,8,"0")

	print("[002] Sequence from board: ")
	print(rsequence)

	sbuffer=string.gsub(sbuffer, "("..rsequence..")", "")

	print("[003] Buffer from board without header: ")
	print(sbuffer)

	-- If recive request to execute product command
	-- Forward request to lua interpreter /www/cgi-bin/sendmsg.lua and give feedback to serial
	if (sbuffer:find("^SENDMSG") ~= nil) then
		utils:syslogger(DEBUG, "SENDMSG received")
		print("SENDMSG received")

		local COMMAND=string.gsub(sbuffer, "SENDMSG", "")
		print("SENDMSG received with command: " .. COMMAND)

		local _result, _payload = pcall(cjson.decode, sendmsg:execute{command=COMMAND})
		print(cjson.encode(_payload))

		if ((_result == false) or (_payload == nil)) then
			rserial:write(rsequence)
			rserial:write("SENDMSG_END\n")
		else
			rserial:write(rsequence)
			rserial:write("SENDMSG_END" .. cjson.encode(_payload) .. "\n")
		end
		socket.sleep(2)
	end

	-- If recive request to execute system command
	-- Forward request to lua interpreter /www/cgi-bin/syscmd.lua and give feedback to serial
	if (sbuffer:find("^SYSCMD") ~= nil) then
		local COMMAND=string.gsub(sbuffer, "SYSCMD", "")

		utils:syslogger(DEBUG, "SYSCMD received: " .. COMMAND)
		print("SYSCMD received: " .. COMMAND)

		local _result, _payload = pcall(cjson.decode, syscmd:execute{command=COMMAND})
		print(cjson.encode(_payload))

		if ((_result == false) or (_payload == nil)) then
			rserial:write(rsequence)
			rserial:write("SYSCMD_END" .. "\n")
		else
			rserial:write(rsequence)
			rserial:write("SYSCMD_END" .. cjson.encode(_payload) .. "\n")
		end
		socket.sleep(2)
	end

	if (WIFI_KEY ~= nil and WIFI_NAME ~= nil and WIFI_ENC ~= nil) then
		utils:syslogger(DEBUG, "WIFI_APPLY procedure start")
		print("WIFI_APPLY procedure start")

		-- rserial:write("Commissioning WiFi: " .. WIFI_NAME .. "\n")

		local output = syscmd:execute{
			command="setwifi",
			WMODE="sta",
			WSSID=WIFI_NAME,
			WENC=WIFI_ENC,
			WPR="dhcp",
			WIFI_KEY=WIFI_KEY
		}

		WIFI_NAME=nil
		WIFI_KEY=nil
		WIFI_ENC=nil

		local _result, _payload = pcall(cjson.decode, output)

		print(output)
		output = output:gsub("[\n\r]", " ")

		if ((_result==true) and (_payload~=nil) and (_payload["SUCCESS"]==true)) then
			-- print("comando: " .. output .. " IP: " .. CURR_WIFI_IPV4)
			-- rserial:write("WiFi setup completed. IP: " .. CURR_WIFI_IPV4 .. "\n")
			print("comando: " .. output)

			-- rserial:write("WiFi setup completed.\n")
			print("WiFi setup completed.\n")

			print("WLAN_MODE|sta\n")
			rserial:flush()
			rserial:write(rsequence)
			rserial:write("WLAN_MODE|sta".."\n")
		else
			print("WiFi setup failed, rolled back to SoftAP")
			-- rserial:write("WiFi setup failed, rolled back to SoftAP\n")

			print("WLAN_MODE|ap\n")
			rserial:flush()
			rserial:write(rsequence)
			rserial:write("WLAN_MODE|ap".."\n")
		end

		-- print(output)
		-- output = output:gsub("[\n\r]", " ")
		
		-- if (output:find("wifi dhcp ok") ~= nil) then
		-- 	local UBUS_WLAN_STATUS=ubus("network.interface.wlan", "status", {})
		-- 	local CURR_WIFI_IPV4=""
		-- 	local attempts=0
		-- 	print("Waiting for IP lease:")
		-- 	-- Wait max 20 seconds for IP lease
		-- 	while (attempts<10) do
		-- 		if (UBUS_WLAN_STATUS["ipv4-address"] ~= nil) then
		-- 			CURR_WIFI_IPV4=UBUS_WLAN_STATUS["ipv4-address"][1]["address"]
		-- 			-- break
		-- 		else
		-- 			print("...")
		-- 			socket.sleep(2)
		-- 			UBUS_WLAN_STATUS=ubus("network.interface.wlan", "status", {})
		-- 		end
		-- 		attempts=attempts+1
		-- 	end
		-- 	print("comando: " .. output .. " IP: " .. CURR_WIFI_IPV4)
		-- 	rserial:write("WiFi setup completed. IP: " .. CURR_WIFI_IPV4 .. "\n")
		-- elseif (output:find("wifi ap ok") ~= nil) then
		-- 	print("WiFi setup failed, rolled back to SoftAP")
		-- 	rserial:write("WiFi setup failed, rolled back to SoftAP\n")
		-- else
		-- 	print("Some error occurred. Check Status.")
		-- 	rserial:write("Some error occurred. Check Status.\n")
		-- end
	end
end