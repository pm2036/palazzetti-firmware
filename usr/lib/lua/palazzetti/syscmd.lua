#!/usr/bin/lua

local cjson = require "cjson"
local socket = require "socket"
local utils = require "palazzetti.utils"
local sendmsg = require "palazzetti.sendmsg"
local bledev = require "palazzetti.bledev"
local network = require "palazzetti.network"
local timer = require "palazzetti.timer"

local syscmd = {}

function syscmd:cboxtest(arg)
	-- utils:exec("/etc/init.d/fstab restart")

	local cboxparams = utils:getenvparams()
	local jsonout = {}
	jsonout["SUCCESS"] = true

	jsonout["INFO"] = {}
	jsonout["INFO"]["CMD"] = "cboxtest"
	jsonout["INFO"]["TS"] = utils:getTS()
	jsonout["INFO"]["RSP"] = "OK"

	jdata = cjson.decode(sendmsg:execute{command="GET STAT"})

	if (jdata.INFO.RSP ~= "OK") then
		-- got timeout or error!
		jsonout["DATA"] = network:net_data()
		jsonout["DATA"]["APLCONN"] = 0
	else
		jsonout = cjson.decode(sendmsg:execute{command="GET STDT"})
		jdata['DATA']['APLCONN'] = 1
		jsonout["INFO"]["CMD"] = "cboxtest"
	end

	-- parse wifi list devices
	wliststr = utils:shell_exec("iwinfo wlan0 scan")
	wliststr = wliststr:gsub("%\n\n", "#")
	result = {}
	local i=1
	for block in wliststr:gmatch("[^#]+") do
		ssid=block:match('%b""')

		-- Hidden Network doesn't have a SSID
		if (ssid~=nil) then

			ssid=ssid:sub(2, ssid:len()-1)

			channel = block:match('Channel: (%d+)')
			signal = block:match('Signal: (-%d+)')
			enc = block:match('Encryption: (%w+)')

			if ((enc ~= nil and enc ~= "") and enc:find("WPA2")) then
				enc = "psk2"
			elseif ((enc ~= nil and enc ~= "") and enc:find("mixed")) then
				enc = "psk2"
			elseif ((enc ~= nil and enc ~= "") and enc:find("WPA")) then
				enc = "psk"
			elseif ((enc ~= nil and enc ~= "") and enc:find("WEP")) then
				enc = "wep"
			else
				enc = "none"
			end

			result[i] = {}
			result[i]["essid"] = ssid
			result[i]["channel"] = channel
			result[i]["signal"] = signal
			result[i]["enc_type"] = enc

			i = i + 1
		end
	end
	jsonout["DATA"]["WLIST"] = result
	jsonout["DATA"]['USB'] = utils:file_exists("/mnt/sda1/USB_NOT_MOUNTED") and "0" or "1"

	jsonout["DATA"]["ICONN"] = utils:checkInternet("", "www.baidu.com") and 1 or 0

	local payload = {}
	payload["payload"] = jsonout["DATA"]
	payload["mac"] = jsonout["DATA"]["MAC"]

	-- cmd = "curl -k -H 'x-api-key: tSsxwjWStT8SyeqoTGcP72S4VgDDyrat2VmSc83k' -H 'Content-Type: application/json; charset=utf-8' -X POST -d '" .. cjson.encode(payload) .. "' https://iot.api.palazzetti.it/staging/qatest"

	CMD="curl -s --cacert /etc/cacerts.pem -XPOST -H 'x-api-key: " .. cboxparams["API-KEY"] .. "' -H \"Content-type: application/json; charset=utf-8\" -d '" .. cjson.encode(payload) .. "' '" .. cboxparams["API-ENDPOINT"] .. "/qatest" .. "'"

	utils:exec(CMD)

	return (cjson.encode(payload))
end

function syscmd:delcsvfile(arg)
	local mycmd = arg.command

	if (utils:empty(arg.csvfile)) then
		return utils:getERRORJson(mycmd, "empty csvfile")
	end

	utils:exec("rm /mnt/sda1/"..arg.csvfile)
	return utils:getOKJson(mycmd, "delcsvfile ok")
end

function syscmd:logger(arg)
	local out = cjson.decode(sendmsg:execute{command="GET ALLS"})
	local ts = utils:getTS("sec")
	local row = utils:getTS() .. ";"
	local title = "timestamp;"
	for k,v in pairs(out.DATA) do
		if type(v) ~= "table" then
			title = title .. k .. ";"
			row = row .. v .. ";"
		end
	end

	-- check if is splitperiod
	loggersplitsec = utils:readfile("/tmp/loggersplitsec")
	if (loggersplitsec:len()>0) then
		loggersplitsec = tonumber(loggersplitsec)
		local timeFirst = tonumber(utils:readfile("/tmp/loggerTS"))
		local diff = (ts-timeFirst)

		if (diff > loggersplitsec) then
			-- stop logger
			utils:exec("kill `ps | grep [/etc/log]ger | awk '{print $1}' | head -n1`")
			-- start logger
			os.execute("lua /etc/syslogger.lua >/dev/null 2>/dev/null &")
			utils:writeinfile("/tmp/loggerTS", ts)
		end
	end

	return row
end

function syscmd:setloggersplit(arg)
	local mycmd = arg.command

	if (utils:empty(arg.splitperiod)) then 
		return utils:getERRORJson(mycmd, "empty splitsec")
	end
	-- splitperiod comes in days. have to save in seconds
	utils:writeinfile("/tmp/loggersplitsec", arg.splitperiod*86400)

	return utils:getOKJson(mycmd, "setloggersplit ok")
end

function syscmd:loggerhead(arg)
	local out = cjson.decode(sendmsg:execute{command="GET ALLS"})
	local ts = utils:getTS("sec")
	local row = utils:getTS() .. ";"
	local title = "timestamp;"

	--[[
	local fields={}
	if (file_exists("/www/fields.csv")) then
		-- Open file for read
		local fh, local err = io.open("/www/fields.csv", "r")

		-- line by line
		while true do
			line = fh:read()
			if line == nil then break end
			fields
		end
	end
	--]]

	if (out.DATA==nil) then return "" end

	for k,v in pairs(out.DATA) do
		if type(v) ~= "table" then
			title = title .. k .. ";"
			row = row .. v .. ";"
		end
	end

	-- check if is splitperiod
	loggersplitsec = utils:readfile("/tmp/loggersplitsec")
	if (loggersplitsec:len()>0) then
		loggersplitsec = tonumber(loggersplitsec)
		local timeFirst = tonumber(utils:readfile("/tmp/loggerTS"))
		local diff = (ts-timeFirst)

		if (diff > loggersplitsec) then
			-- stop logger
			utils:exec("kill `ps | grep [/etc/log]ger | awk '{print $1}' | head -n1`")
			-- start logger
			os.execute("lua /etc/syslogger.lua >/dev/null 2>/dev/null &")
			utils:writeinfile("/tmp/loggerTS", ts)
		end
	end

	return title
end

function syscmd:eventlogger(arg)
	local tmpfile = os.tmpname()
	os.execute("logread -e SYSLOG > " .. tmpfile)

	jdata = {}
	jdata["TS"] = utils:getTS("sec")
	jdata["LOGITEMS"] = {}

	for line in io.lines(tmpfile) do
		i, j = line:find(" user.notice SYSLOG: ")
		ts = line:sub(1, i-1)
		ts = utils:trim(utils:shell_exec("date -D \"" .. ts .. "\" +%s"))
		line = line:sub(j+1)
		i, j = line:find(" ")
		logtype = line:sub(1,i-1)
		msg = line:sub(j+1)
		jnewlog = {}
		jnewlog["LOGTS"] = ts
		jnewlog["LOGTYPE"] = logtype
		jnewlog["LOGMSG"] = msg
		table.insert(jdata["LOGITEMS"], jnewlog)

	end
	os.execute("rm " .. tmpfile)

	jdata = utils:encstring(cjson.encode(jdata))
	-- Restarting log services will truncate logs circual buffer
	os.execute("/etc/init.d/log restart")

	return cjson.encode(utils:getStandardJson("eventlogger", {LOGS=jdata}))
end

function syscmd:startlogger(arg)
	local mycmd = arg.command
	local DEFAULT_LOGGERSPLITSEC = 604800 -- 1 week

	utils:exec("lua /etc/syslogger.lua &")
	utils:exec("echo \"" .. utils:getTS("sec") .. "\" > /tmp/loggerTS")

	if (utils:readfile('/tmp/loggersplitsec')=="") then
		utils:writeinfile("/tmp/loggersplitsec", DEFAULT_LOGGERSPLITSEC)
	end

	return utils:getOKJson(mycmd, "startlogger ok")
end

function syscmd:stoplogger(arg)
	local mycmd = arg.command

	utils:exec("kill `ps | grep [/etc/log]ger | awk '{print $1}' | head -n1`")
	utils:exec("rm /tmp/seqcurrent")
	return utils:getOKJson(mycmd, "stoplogger ok")
end		

function syscmd:wifiscan(arg)
	local mycmd = arg.command

	local jsonout = {}
	jsonout["SUCCESS"] = true

	jsonout["INFO"] = {}
	jsonout["INFO"]["CMD"] = mycmd
	jsonout["INFO"]["TS"] = utils:getTS()
	jsonout["INFO"]["RSP"] = "OK"

	local result = {}
	local i=1
	local attempts=1

	repeat
		-- parse wifi list devices
		wliststr = utils:shell_exec("iwinfo wlan0 scan")
		wliststr = wliststr:gsub("%\n\n", "#")

		for block in wliststr:gmatch("[^#]+") do
			ssid=block:match('%b""')

			-- Hidden Network doesn't have a SSID
			if (ssid~=nil) then

				ssid=ssid:sub(2, ssid:len()-1)

				channel = block:match('Channel: (%d+)')
				signal = block:match('Signal: (-%d+)')
				enc = block:match('Encryption: (%w+)')

				if ((enc ~= nil and enc ~= "") and enc:find("WPA2")) then
					enc = "psk2"
				elseif ((enc ~= nil and enc ~= "") and enc:find("mixed")) then
					enc = "psk2"
				elseif ((enc ~= nil and enc ~= "") and enc:find("WPA")) then
					enc = "psk"
				elseif ((enc ~= nil and enc ~= "") and enc:find("WEP")) then
					enc = "wep"
				else
					enc = "none"
				end

				result[i] = {}
				result[i]["essid"] = ssid
				result[i]["channel"] = channel
				result[i]["signal"] = signal
				result[i]["enc_type"] = enc

				i = i + 1
			end
		end

		attempts = attempts + 1
		-- Wait certain amount of time to retry
		if (#result <= 0) then 
			print("no result")
			socket.sleep(10)
		end
	until ((#result > 0) or (attempts > 3))

	jsonout["DATA"] = {}
	jsonout["DATA"]["WLIST"] = result

	return (cjson.encode(jsonout))
end

function syscmd:netrestore(arg)
	local mycmd = arg.command

	if (utils:file_exists("/etc/network_config") == false) then
		return false
	end

	local _netconfig = utils:readfile("/etc/network_config")
	local _params = {}

	for s in _netconfig:gmatch("[^\r\n]+") do

		local _key = utils:trim(string.sub(s, 1, 9))
		local _value = string.sub(s, 11)

		if (string.len(_value) > 0) then
			_params[_key] = _value
		end
	end

	_params["command"] = mycmd
	
	pcall(cjson.decode, self:seteth(_params))
	pcall(cjson.decode, self:setwifi(_params))

	return utils:getOKJson(mycmd, "netrestore ok")
end

function syscmd:seteth(arg)
	local mycmd = arg.command

	if (utils:empty(arg.EPR)) then 
		return utils:getERRORJson(mycmd,"empty EPR") 
	end

	if (arg.EPR=="dhcp") then

		return (network:eth_dhcp()
			and utils:getOKJson(mycmd, "seteth dhcp ok")
			or 	utils:getERRORJson(mycmd, "Failed to set DHCP network")
			)

	elseif (arg.EPR=="static") then
		if (utils:empty(arg.EMSK)) then return utils:getERRORJson(mycmd,"empty EMSK") end
		if (utils:empty(arg.EADR)) then return utils:getERRORJson(mycmd,"empty EADR") end
		if (utils:empty(arg.EGW)) then return utils:getERRORJson(mycmd,"empty EGW") end

		return (network:eth_static{ipaddr=arg.EADR,netmask=arg.EMSK,gateway=arg.EGW}
			and utils:getOKJson(mycmd, "seteth static ok")
			or 	utils:getERRORJson(mycmd, "Failed to set static network")
			)
	else
		return utils:getERRORJson(mycmd,"unrecognized EPR")
	end
end

function syscmd:setwifi(arg)
	local mycmd = arg.command

	if (utils:empty(arg.WMODE)) then 
		return utils:getERRORJson("empty WMODE")
	end

	if (arg.WMODE=='default') then

		return (network:wifi_default() 
			and utils:getOKJson(mycmd) 
			or 	utils:getERRORJson(mycmd, "Failed to set default network")
			)

	elseif (arg.WMODE=='off') then
		return (network:wifi_off() 
			and utils:getOKJson(mycmd) 
			or 	utils:getERRORJson(mycmd, "Failed to switch off Wi-Fi interface")
			)

	elseif (arg.WMODE=='ap') then
		return (network:wifi_ap{
					ssid=arg.WSSID,
					key=arg.WIFI_KEY,
					encryption=arg.WENC,
					channel=arg.WCH
				}
			and utils:getOKJson(mycmd) 
			or 	utils:getERRORJson(mycmd, "Failed to put Wi-Fi on AP mode")
			)
	end

	return (network:wifi_sta{
					ssid=arg.WSSID,
					key=arg.WIFI_KEY,
					encryption=arg.WENC,
					channel=arg.WCH,
					protocol=arg.WPR,
					ipaddr=arg.WADR,
					netmask=arg.WMSK,
					gateway=arg.WGW
				}
			and utils:getOKJson(mycmd) 
			or 	utils:getERRORJson(mycmd, "Failed to put Wi-Fi on STA mode")
			)
end

function syscmd:netdata(arg)
	local mycmd = arg.command
	
	return cjson.encode(utils:getStandardJson(mycmd, network:net_data()))
end

function syscmd:nwdata(arg)
	local jdata = cjson.decode(sendmsg:execute{command="GET STAT"})

	if (jdata.INFO.RSP ~= "OK") then
		-- got timeout or error!
		jdata = cjson.decode(self:netdata(arg))
		jdata["DATA"]["APLCONN"] = 0
	else
		jdata = cjson.decode(sendmsg:execute{command="GET STDT"})
		jdata['DATA']['APLCONN'] = 1
	end
	return cjson.encode(jdata)
end

function syscmd:getparams(arg)
	local mycmd = arg.command

	local cboxparams = utils:getenvparams()
	cboxparams["API-ENDPOINT"] = ""
	cboxparams["API-KEY"] = ""
	cboxparams["OTA-UPGRADE-URL"] = ""
	cboxparams["MQTT_BROKER"] = ""

	return cjson.encode(utils:getStandardJson(mycmd, cboxparams))
end

function syscmd:dwlcsv(arg)
	local mycmd = arg.command

	if (utils:empty(arg.csvfile)) then 
		return utils:getERRORJson(mycmd,"empty csvfile") 
	end

	-- download csv file
	local myfile = "/mnt/sda1/"..arg.csvfile
	if (not utils:file_exists(myfile)) then 
		return utils:getERRORJson(mycmd,"csvfile not exists") 
	end

	local output = utils:readfile(myfile)

	local out = "Content-Description: File Transfer\r\n"
	out = out .. "Content-Disposition: attachment;filename=\""..arg.csvfile.."\"\r\n"
	out = out .. "Expires: 0\r\n"
	out = out .. "Cache-Control: must-revalidate\r\n"
	out = out .. "Pragma: public\r\n"
	out = out .. "Content-Length: " .. output:len() .. "\r\n"
	out = out .. "Content-Type: application/octet-stream\r\n\r\n"
	out = out .. output

	return out
end

function syscmd:settz(arg)
	local mycmd = arg.command

	if (utils:empty(arg.tz)) then 
		return utils:getERRORJson(mycmd,"empty tz") 
	end

	utils:writeinfile("/etc/TZ", arg.tz)
	utils:shell_exec("uci set system.@system[0].timezone=\"" .. arg.tz .. "\" && uci commit")
	utils:shell_exec("/etc/init.d/sysntpd restart")

	return utils:getOKJson(mycmd, "update tz OK")
end

function syscmd:settimer(arg)
	return timer:set(arg)
end

function syscmd:gettimer(arg)
	return timer:get(arg)
end

function syscmd:listbledev(arg)
	return bledev:list(arg)
end

function syscmd:setbledev(arg)
	return bledev:set(arg)
end

function syscmd:delbledev(arg)
	local output = bledev:update{command="delbledev",payload=cjson.encode({MAC=arg.MAC, DATA={MAC=arg.MAC, DELETED=true}})}

	-- Enforce cron execution to prevent loop on disconnected and deleted devices
	utils:shell_exec("lua /etc/bleloop_cron.lua > /dev/null &")

	return output
end

function syscmd:upgradebledev(arg)
	return bledev:upgrade(arg)
end

function syscmd:upgradeinitbledev(arg)
	return bledev:upgrade_init(arg)
end

function syscmd:upgradeabortbledev(arg)
	return bledev:upgrade_abort(arg)
end

function syscmd:upgradegetbledev(arg)
	return bledev:upgrade_get(arg)
end

function syscmd:execute(arg)
	arg = arg or {}

	local output_destination = arg.dest

	if (utils:empty(output_destination) ~= true) then
		arg.dest = nil
		local _output = self:execute(arg)
		utils:writeinfile(output_destination, _output)
		return _output
	end

	local mycmd = arg.command

	-- Exit if command is not present
	if (mycmd==nil) then
		return utils:getERRORJson()
	end

	local data = mycmd:match("%w+ (.*)")

	if (data == nil) then data = "" end

	mycmd = mycmd:match("%w+ *")
	-- Exit if command parse failed
	if (mycmd==nil) then
		return utils:getERRORJson()
	end
	mycmd = string.lower(utils:trim(mycmd))

	local _data_result, _data = pcall(cjson.decode, utils:trim((data or "")))

	if (_data_result == true and _data ~= nil) then
		for i, v in pairs(_data) do
			arg[i] = v
	    end
	end

	-- Cleanup parameters from command
	arg.command = mycmd

	if (mycmd == "delcsvfile") then
		return self:delcsvfile(arg)
	elseif (mycmd == "dwlcsv") then
		return self:dwlcsv(arg)
	elseif (mycmd == "netrestore") then
		return self:netrestore(arg)
	elseif (mycmd == "getparams") then
		return self:getparams(arg)
	elseif (mycmd == "setloggersplit") then
		return self:setloggersplit(arg)
	elseif (mycmd == "eventlogger") then
		return self:eventlogger(arg)
	elseif (mycmd == "startlogger") then
		return self:startlogger(arg)
	elseif (mycmd == "stoplogger") then
		return self:stoplogger(arg)
	elseif (mycmd == "netdata") then
		return self:netdata(arg)
	elseif (mycmd == "nwdata") then
		return self:nwdata(arg)
	elseif (mycmd == "setwifi") then
		return self:setwifi(arg)
	elseif (mycmd == "seteth") then
		return self:seteth(arg)
	elseif (mycmd == "wifiscan") then
		return self:wifiscan(arg)
	elseif (mycmd == "gettimer") then
		return self:gettimer(arg)
	elseif (mycmd == "settimer") then
		return self:settimer(arg)
	elseif (mycmd == "logger") then
		return self:logger(arg)
	elseif (mycmd == "loggerhead") then
		return self:loggerhead(arg)
	elseif (mycmd == "settz") then
		return self:settz(arg)
	elseif (mycmd == "listbledev") then
		return self:listbledev(arg)
	elseif (mycmd == "delbledev") then
		return self:delbledev(arg)
	elseif (mycmd == "setbledev") then
		return self:setbledev(arg)
	elseif (mycmd == "upgradebledev") then
		return self:upgradebledev(arg)
	elseif (mycmd == "upgradeinitbledev") then
		return self:upgradeinitbledev(arg)
	elseif (mycmd == "upgradeabortbledev") then
		return self:upgradeabortbledev(arg)
	elseif (mycmd == "upgradegetbledev") then
		return self:upgradegetbledev(arg)
	elseif (mycmd == "cboxtest") then
		return self:cboxtest(arg)
	end

	return utils:getERRORJson("command not found")
end

return syscmd