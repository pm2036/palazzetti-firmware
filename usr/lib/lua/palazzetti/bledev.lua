#!/usr/bin/lua

local cjson = require "cjson"
local socket = require "socket"
local utils = require "palazzetti.utils"

local bledev = {}

function bledev:get(data)

	local jdevices = {}

	if (utils:file_exists("/etc/devices.json") == true) then
		local _result, _jdevices = pcall(cjson.decode, utils:readfile("/etc/devices.json"))
		if ((_result ~= false) and (_jdevices ~= nil)) then
			jdevices = _jdevices
		end
	end

	local _devicemac = string.upper(utils:trim(data):gsub(":", "_"))
	local _cstatus_filepath = "/tmp/devices/" .. _devicemac .. ".json"

	local _cstatus_result, _cstatus = pcall(cjson.decode, utils:readfile(_cstatus_filepath))

	if ((string.lower(cjson.encode(jdevices))):find(string.lower(utils:trim(data))) == nil) then
		return utils:getERRORJson(mycmd, "Device not found in list")
	end

	if (((_cstatus_result == false) or (_cstatus == nil)) 
	 and ((string.lower(cjson.encode(jdevices))):find(string.lower(utils:trim(data))) == nil)) then
		return utils:getERRORJson(mycmd, "Status not found")
	end

	local _output = cjson.decode(utils:getOKJson(mycmd, ""))
	_output["DATA"] = (_cstatus["DATA"] or {ONLINE=false})

	return cjson.encode(_output)
end

function bledev:action_sync()
	local mycmd = arg.command or "actionsync"
	local actions = {}

	if (utils:file_exists("/etc/bleactions.json") == true) then
		actions = cjson.decode(utils:readfile("/etc/bleactions.json"))
	else
		return utils:getERRORJson(mycmd, "Action map not found.")
	end

	local _devices_result, _devices_data = pcall(cjson.decode, self:list{ONLINE=true})

	if (_devices_result == true and _devices_data ~= nil and _devices_data["DATA"] ~= nil) then
		_devices_data = _devices_data["DATA"]
	end

	local listOfActions = {}

	for k,v in pairs(_devices_data) do

		local _devicetype = string.upper((v["TYPE"] or ""))

		if (actions[_devicetype] ~= nil) then

			for i,j in pairs(actions[_devicetype]) do

				utils:syslogger(DEBUG, "BLELOOP_ACTION_SYNC " .. v["MAC"] .. " perform action "..j)
				local _actionResult, _actionData = pcall(cjson.decode, self:action({MAC=v["MAC"], ACTION=j}))

				if (_actionResult == true and _actionData ~= nil and _actionData["DATA"] ~= nil) then
					table.insert(listOfActions, _actionData["DATA"]["COMMAND"])
				end
			end
		end
	end

	print("Lista azioni")
	print(cjson.encode(listOfActions))

	local _output = utils:getStandardJson(mycmd, listOfActions, "actionsync OK")
	return cjson.encode(_output)
end

function bledev:action(arg)
	local mycmd = arg.command or "SET CDEV"
	local actions = {}
	
	local _devicemac = arg.MAC
	local _action = arg.ACTION

	if (utils:file_exists("/etc/bleactions.json") == true) then
		actions = cjson.decode(utils:readfile("/etc/bleactions.json"))
	else
		return utils:getERRORJson(mycmd, "Action map not found.")
	end

	local _currDevice_result, _currDevice_data = pcall(cjson.decode, self:list{MAC=_devicemac})

	if (_currDevice_data ~= nil and _currDevice_data["DATA"] ~= nil) then
		_currDevice_data = _currDevice_data["DATA"]
		_currDevice_data = _currDevice_data[0] and _currDevice_data[0] or _currDevice_data[1]
	end

	if ((_currDevice_result == false) or (_currDevice_data == nil)) then
		return utils:getERRORJson(mycmd, "Given mac address is not valid for any device in list.")
	end

	local _devicetype = string.upper((_currDevice_data["TYPE"] or ""))
	local _devicelocation = _currDevice_data["LOCATION"]

	local _action__type = ("" .. _devicetype .. "_" .. _action)
	local _action__location = ("" .. _action__type .. "_" .. _devicelocation)

	local _action_payload = {}

	if (actions ~= nil) then
		_action_payload = (
			( actions[_action__location] or
			actions[_action__type] ) or 
			{} )
	end

	if (_action_payload == nil) then
		return utils:getERRORJson(mycmd, "Nothing to do for this action")
	end

	-- print("sonoqui")
	-- print(_action__location)
	-- print(_action__type)
	-- print(cjson.encode(_action_payload))

	local _action_flagImmediate = (_action_payload["immediate"] or false)
	local _action_command = (_action_payload["command"])
	local _action_formula = (_action_payload["formula"])

	if ((_action_command ~= nil) and 
		(_action_command:find("[VALUE]") ~= nil) and
		(tonumber(_currDevice_data[_action]) ~= nil)) then

		local _value = tonumber(_currDevice_data[_action])

		if (_action_formula ~= nil and _action_formula ~= "") then
			local _computeFormula=assert(loadstring(_action_formula))
			setfenv(_computeFormula,{val=_value})
			_value = _computeFormula()
		end

		_action_command=_action_command:gsub("%[VALUE%]", math.ceil(_value))
	else
		_action_command = nil
	end

	if (_action_command == nil) then
		return utils:getERRORJson(mycmd, "Not a valid action payload")
	end

	local _data = {
		COMMAND=_action_command,
		IMMEDIATE=_action_flagImmediate
	}

	local _output = utils:getStandardJson(mycmd, _data, "Perform action based on map")
	return cjson.encode(_output)

end

function bledev:list(arg)
	local mycmd = arg.command or "listbledev"
	local jdevices = {}

	if (utils:file_exists("/etc/devices.json") == true) then
		local _result, _jdevices = pcall(cjson.decode, utils:readfile("/etc/devices.json"))
		if ((_result ~= false) and (_jdevices ~= nil)) then
			jdevices = _jdevices
		end
	end

	local jsonout = {}
		jsonout["SUCCESS"] = true

		jsonout["INFO"] = {}
		jsonout["INFO"]["CMD"] = mycmd
		jsonout["INFO"]["TS"] = utils:getTS("sec")
		jsonout["INFO"]["RSP"] = "OK"

		jsonout["DATA"] = {}

		for k,v in pairs(jdevices and jdevices or {}) do

			local _isValidDevice = true
			local _currDevice_result, _currDevice_data = pcall(cjson.decode, self:get(v["MAC"]))

			if ((_currDevice_result == false) 
			 or (_currDevice_data == nil) 
			 or ((_currDevice_data["SUCCESS"] or false) ~= true)) then
				_currDevice_data = {}
			else
				_currDevice_data = _currDevice_data["DATA"]
			end

			if ((arg.ONLINE ~= nil) 
			and ((_currDevice_data["ONLINE"] or false) ~= arg.ONLINE)) then
				_isValidDevice = false
			end

			if ((arg.LOCATION ~= nil) 
			and (string.upper(v["LOCATION"] or "") ~= string.upper(arg.LOCATION))) then
				_isValidDevice = false
			end

			if ((arg.MAC ~= nil) 
			and (string.upper(v["MAC"] or "") ~= string.upper(arg.MAC))) then
				_isValidDevice = false
			end

			if ((arg.DELETED ~= nil) 
			and ((v["DELETED"] or false) ~= arg.DELETED)) then
				_isValidDevice = false
			end

			if ((arg.DELETED == nil)
			and	((_currDevice_data["DELETED"] or false) == true)) then
				self:del{command="delbledev", MAC=v["MAC"]}
				_isValidDevice = false
			end

			for i,j in pairs(_currDevice_data) do v[i] = j end

			if (_isValidDevice == true) then
				-- print(cjson.encode(v))
				table.insert(jsonout["DATA"], v)
			end
		end

	return (cjson.encode(jsonout))
end

function bledev:del(arg)
	local mycmd = arg.command or "delbledev"
	local jdevices = {}

	if (utils:file_exists("/etc/devices.json") == true) then
		local _result, _jdevices = pcall(cjson.decode, utils:readfile("/etc/devices.json"))
		if ((_result ~= false) and (_jdevices ~= nil)) then
			jdevices = _jdevices
		end
	end

	jdevices[arg.MAC] = nil

	-- Cleanup file
	utils:exec("rm -f /tmp/devices.json")

	-- Try writing to Devices RAM file
	utils:writeinfile("/tmp/devices.json", cjson.encode(jdevices))

	-- If writing not succeded
	if (utils:fsize("/tmp/devices.json") <= 0) then
		utils:exec("rm -f /tmp/devices.json")
		return utils:getERRORJson(mycmd, "Device format is not valid. Please, try again.")
	end

	-- Store devices succesfully
	utils:exec("cp /tmp/devices.json /etc/devices.json && rm -f /tmp/devices.json")

	-- Cleanup ble device shadow
	local _devicemac = string.upper(utils:trim(arg.MAC):gsub(":", "_"))
	local _cstatus_filepath = "/tmp/devices/" .. _devicemac .. ".json"

	utils:exec("rm -f " .. _cstatus_filepath)

	return utils:getOKJson(mycmd, "delbledev OK")
end

function bledev:location(arg)

	local _devicelocation = nil

	if (arg["TYPE"] ~= "sweetspot") then
		return _devicelocation
	end

	utils:syslogger(DEBUG, "Going to check empty location for sweetspot pairing...")

	for i=0,2 do
		local _currDevice_location = (i+36)
		local _currDevice_result, _currDevice_data = pcall(cjson.decode, self:list{LOCATION=_currDevice_location})
		
		if ((_currDevice_result == false) or (_currDevice_data == nil) or (#_currDevice_data["DATA"] <= 0)) then
			_devicelocation = _currDevice_location
			utils:syslogger(DEBUG, "Empty location for sweetspot found: " .. _devicelocation)
			break
		end
	end

	return _devicelocation
end

function bledev:set(arg)
	local mycmd = arg.command or "setbledev"
	local jdevices = {}

	if (utils:file_exists("/etc/devices.json") == true) then
		local _result, _jdevices = pcall(cjson.decode, utils:readfile("/etc/devices.json"))
		if ((_result ~= false) and (_jdevices ~= nil)) then
			jdevices = _jdevices
		end
	end

	local _currDevice = {}
	
	_currDevice["TYPE"] = (arg.TYPE and arg.TYPE or "")
	_currDevice["LOCATION"] = tonumber(arg.LOCATION and arg.LOCATION or -1)
	-- _currDevice["MODE"] = (arg.MODE and arg.MODE or "")
	_currDevice["MAC"] = arg.MAC

	if ((string.lower(cjson.encode(jdevices))):find(string.lower(_currDevice["MAC"])) ~= nil) then
		_deviceShadow = jdevices[arg.MAC]

		-- This information could not be changed through API
		_currDevice["TYPE"] = _deviceShadow["TYPE"]
		-- This information could not be changed through API
		_currDevice["MAC"] = _deviceShadow["MAC"]
		_currDevice["LOCATION"] = tonumber(arg.LOCATION and _currDevice["LOCATION"] or _deviceShadow["LOCATION"])

		if ((_deviceShadow ~= nil) and 
			-- Add multiple conditions by OR if needed
			(tonumber(_deviceShadow["LOCATION"]) == tonumber(_currDevice["LOCATION"]))) then
			return utils:getOKJson(mycmd, "setbledev OK")
		end
	end

	if (_currDevice["LOCATION"] == -1) then
		_currDevice["LOCATION"] = (self:location(_currDevice) or _currDevice["LOCATION"])
	end

	jdevices[arg.MAC] = _currDevice

	-- Cleanup file
	utils:exec("rm -f /tmp/devices.json")

	-- Try writing to Devices RAM file
	utils:writeinfile("/tmp/devices.json", cjson.encode(jdevices))

	-- If writing not succeded
	if (utils:fsize("/tmp/devices.json") <= 0) then
		utils:exec("rm -f /tmp/devices.json")
		return utils:getERRORJson(mycmd, "Device format is not valid. Please, try again.")
	end

	-- Store devices succesfully
	utils:exec("cp /tmp/devices.json /etc/devices.json && rm -f /tmp/devices.json")

	return utils:getOKJson(mycmd, "setbledev OK")
end

function bledev:clean()
	local mycmd = "clearbledev"
	utils:exec("rm -f /tmp/devices/*.json")

	return utils:getOKJson(mycmd, "clearbledev OK")
end

function bledev:reset()
	local mycmd = "resetbledev"

	-- Clear device shadow
	utils:exec("rm -rf /tmp/devices")

	-- Clear device associations
	utils:exec("rm -f /tmp/devices.json")
	utils:exec("rm -f /etc/devices.json")

	utils:syslogger(DEBUG, "Clear all cache and data for bluetooth devices by resetbledev")
	return utils:getOKJson(mycmd, "resetbledev OK")
end

function bledev:upgrade()
	local mycmd = "upgradebledev"

	if (utils:file_exists("/tmp/devices/upgrade.json") == false) then
		utils:syslogger(DEBUG, "Failed to detect upgrade semaphore. Upgrade wont start")
		print("Failed to detect upgrade semaphore. Upgrade wont start")
		return utils:getERRORJson(mycmd, "Failed to detect upgrade semaphore. Upgrade wont start")
		-- os.exit()
	end

	local _result, _upgradePayload = pcall(cjson.decode, utils:readfile("/tmp/devices/upgrade.json"))

	if ((_result == false) or (_upgradePayload == nil)) then
		utils:syslogger(DEBUG, "Failed to detect upgrade semaphore. Upgrade wont start")
		print("Failed to detect upgrade semaphore. Upgrade wont start")
		return utils:getERRORJson(mycmd, "Failed to detect upgrade semaphore. Upgrade wont start")
		-- os.exit()
	end

	-- Chunk size
	local _serialPacketChunkSize = 8192
	-- Read file size rounded to next thousand
	local _updateBinaryChunkSize = (math.floor(_serialPacketChunkSize/1000)*1000)
	-- Path to ESP32 Firmware
	local _updateFilePath = (_upgradePayload["UPGRADE_PATH"] or "/tmp/firmware_esp.bin")
	-- Check update firmware file size
	local _updateBinarySize = utils:fsize(_updateFilePath)
	-- Check number of packet that should be transfered for upgrade
	local _updateBinaryTotalPacketNumber = math.ceil(_updateBinarySize / _updateBinaryChunkSize)
	local _updateBinaryCurrentPacketNumber = 0

	utils:init_serial(utils:getenvparams()["BLELOOP_DEVICE"], utils:getenvparams()["BLELOOP_BAUDRATE"])
	-- Second parameter used as local flag instead of Baud Rate (setup by previous line)
	utils:init_serial(utils:getenvparams()["BLELOOP_DEVICE"], "-echo")
	-- Transform new line to carridge return + new line
	-- utils:init_serial(utils:getenvparams()["BLELOOP_DEVICE"], "-onlcr")

	local rserial = io.open(utils:getenvparams()["BLELOOP_DEVICE"], "r+")

	if (rserial == nil) then
		utils:syslogger(DEBUG, "Failed to detect device. Upgrade wont start")
		print("Failed to detect device. Upgrade wont start")
		return utils:getERRORJson(mycmd, "Failed to detect device. Upgrade wont start")
		-- os.exit()
	end

	local _updateBinary = io.open(_updateFilePath, "r")
	
	if (_updateBinary == nil) then
		utils:syslogger(DEBUG, "Failed to detect firmware file. Upgrade wont start")
		print("Failed to detect firmware file. Upgrade wont start")

		rserial:write(string.char(0x23))
		rserial:flush()
		socket.sleep(5)

		-- Cleanup temporary files
		self:upgrade_abort()

		return utils:getERRORJson(mycmd, "Failed to detect firmware file. Upgrade wont start")
	end

	-- Temporary variable to store byte array
	local _updatePacket = nil

	utils:syslogger(DEBUG, "Initial serial write handshake")
	print("Initial serial write handshake")

	print("Write character <")
	_updatePacket = string.char(0x3C)
	rserial:write(_updatePacket)
	rserial:flush()
	socket.sleep(5)

	utils:syslogger(DEBUG, "Begin serial packet")
	print("Begin serial packet")

	-- Init length of firmware packet with 4 bytes of content
	local _bUpdateBinarySize_byte = {}
	_bUpdateBinarySize_byte[0] = utils:bitand(math.floor(_updateBinarySize / math.pow(2,0)), 0xFF)
	_bUpdateBinarySize_byte[1] = utils:bitand(math.floor(_updateBinarySize / math.pow(2,8)), 0xFF)
	_bUpdateBinarySize_byte[2] = utils:bitand(math.floor(_updateBinarySize / math.pow(2,16)), 0xFF)
	_bUpdateBinarySize_byte[3] = utils:bitand(math.floor(_updateBinarySize / math.pow(2,24)), 0xFF)

	-- Write initial procedure character
	-- With 4 bytes for binary file size to Serial for completion check
	_updatePacket = string.char(0x00, 0x00, 0x30, #_bUpdateBinarySize_byte, 0, (_bUpdateBinarySize_byte[0] or 0), (_bUpdateBinarySize_byte[1] or 0), (_bUpdateBinarySize_byte[2] or 0), (_bUpdateBinarySize_byte[3] or 0), 0,0,0,0,0,0)
	rserial:write(utils:rpad(_updatePacket, _serialPacketChunkSize, '0'))
	rserial:flush()
	socket.sleep(5)

	local _fbuffer = nil

	repeat

		-- If serial is no more valid, fire an error
		if (rserial == nil) then
			utils:syslogger(DEBUG, "Failed write operation during upgrade.")
			return utils:getERRORJson(mycmd, "Failed write operation during upgrade.")
		end

		if (sbuffer ~= nil) then
			utils:syslogger(DEBUG, sbuffer)
		end

		if ((sbuffer ~= nil) and (sbuffer:find("^OK") ~= nil)) then
			print("OK Received")
			_fbuffer = _updateBinary:read(_updateBinaryChunkSize)

			if (_fbuffer == nil) then
				print("no more bytes to read from buffer")
			else

				local _hsize = utils:bitand(math.floor(_fbuffer:len() / math.pow(2,8)), 0xFF)
				local _lsize = utils:bitand(math.floor(_fbuffer:len() / math.pow(2,0)), 0xFF)
				print("hsize: " .. tostring(_hsize) .. " | lsize: " .. tostring(_lsize))
				utils:syslogger(DEBUG, "size: " .. tostring(_fbuffer:len()) .. " | hsize: " .. tostring(_hsize) .. " | lsize: " .. tostring(_lsize))

				rserial:write(utils:rpad((string.char(0x00, 0x00, 0x40, _lsize, _hsize) .. _fbuffer), _serialPacketChunkSize, '0'))
				rserial:flush()

				-- _updateBinaryPacketNumber = _updateBinaryPacketNumber - 1
				_updateBinaryCurrentPacketNumber = _updateBinaryCurrentPacketNumber + 1
			end
		end

		if ((sbuffer ~= nil) and (sbuffer:find("^KO") ~= nil)) then
			print("KO Received")
			os.exit()
		end

		print("leggo un pacchetto")
		sbuffer=rserial:read();
		print("ho letto un pacchetto")

		if (sbuffer ~= nil) then
			print("Content here")
			print(sbuffer)
			print(string.len(sbuffer))

			sbuffer=string.gsub(sbuffer, "\n$", "")
			sbuffer=string.gsub(sbuffer, "\r$", "")
		else
			print("Check if BLE device is still connected")
			socket.sleep(5)
		end

		-- TODO: Should compute percentage instead of total number
		_upgradePayload["PROGRESS"] = math.ceil((_updateBinaryCurrentPacketNumber * 100) / _updateBinaryTotalPacketNumber)

		if (utils:file_exists("/tmp/devices/upgrade.json") == true) then
			utils:writeinfile("/tmp/devices/upgrade.json", cjson.encode(_upgradePayload))
		else
			utils:syslogger(DEBUG, "Abort firmware upload due to missing upgrade semaphore.")
			
			_updatePacket = string.char(0x00, 0x00, 0x52, 0,0,0,0,0,0)
			rserial:write(utils:rpad(_updatePacket, _serialPacketChunkSize, '0'))
			rserial:flush()
			socket.sleep(5)
			
			self:upgrade_abort()
			utils:syslogger(DEBUG, "Failed write operation during upgrade.")
			return utils:getERRORJson(mycmd, "Failed write operation during upgrade.")
		end

		print("Part: " .. tostring(_updateBinaryCurrentPacketNumber) .. " | " .. "Total: " .. tostring(_updateBinaryTotalPacketNumber))
		utils:syslogger(DEBUG, "Part: " .. tostring(_updateBinaryCurrentPacketNumber) .. " | " .. "Total: " .. tostring(_updateBinaryTotalPacketNumber))
		socket.sleep(0.1)
	until ((_fbuffer == nil) and (_updateBinaryCurrentPacketNumber > 0))

	-- Close binary file
	_updateBinary:close()
	_updateBinary = nil

	print("Confirm firmware upload")
	_updatePacket = string.char(0x00, 0x00, 0x50, 0,0,0,0,0,0)
	rserial:write(utils:rpad(_updatePacket, _serialPacketChunkSize, '0'))
	rserial:flush()

	print("Going to wait 20 seconds...")
	socket.sleep(20)

	-- Cleanup temporary files
	self:upgrade_abort()

	return utils:getOKJson(mycmd, "upgradebledev OK")
end

function bledev:upgrade_init(arg)

	local mycmd = "upgradeinitbledev"

	utils:init_serial(utils:getenvparams()["BLELOOP_DEVICE"], utils:getenvparams()["BLELOOP_BAUDRATE"])
	-- Second parameter used as local flag instead of Baud Rate (setup by previous line)
	utils:init_serial(utils:getenvparams()["BLELOOP_DEVICE"], "-echo")
	-- Transform new line to carridge return + new line
	utils:init_serial(utils:getenvparams()["BLELOOP_DEVICE"], "-onlcr")

	local rserial = io.open(utils:getenvparams()["BLELOOP_DEVICE"], "r+")

	if (rserial == nil) then
		utils:syslogger(DEBUG, "Failed to detect device. Upgrade wont start")
		print("Failed to detect device. Upgrade wont start")
		return utils:getERRORJson(mycmd, "Failed to detect device. Upgrade wont start")
	end

	utils:syslogger(DEBUG, "Send OTASETUP to device and wait for acknowledge...")
	rserial:write("OTASETUP\n")

	return utils:getOKJson(mycmd, "upgradeinitbledev OK")
end

function bledev:keep_alive(arg)
	local mycmd = "keepalivebledev"
	
	local _keepAlivePayload = {
		TS=utils:getTS("sec")
	}
	-- Ensure devices folder
	utils:shell_exec("mkdir -p /tmp/devices")
	-- Write keep alive file to notify other process of running operation
	utils:writeinfile("/tmp/devices/keepalive.json", cjson.encode(_keepAlivePayload))
	-- Upgrade procedure will start soon
	return utils:getOKJson(mycmd, "keepalivebledev OK")
end

function bledev:upgrade_start(arg)
	local mycmd = "upgradestartbledev"
	
	local _upgradePayload = {
		TS=utils:getTS("sec"),
		PROGRESS=0,
		UPGRADE_PATH=(arg.PATH or "/tmp/firmware_esp.bin")
	}
	-- Ensure devices folder
	utils:shell_exec("mkdir -p /tmp/devices")
	-- Write upgrade fileto notify other process of running operation
	utils:writeinfile("/tmp/devices/upgrade.json", cjson.encode(_upgradePayload))
	-- Kill BLE Loop... The Watchdog will start procedure soon
	utils:shell_exec("pkill -9 -f bleloop.lua 2> /dev/null")
	-- Upgrade procedure will start soon
	return utils:getOKJson(mycmd, "upgradestartbledev OK")
end

function bledev:upgrade_abort()
	local mycmd = "upgradeabortbledev"

	utils:exec("rm -f /tmp/devices/upgrade.json")
	return utils:getOKJson(mycmd, "upgradeabortbledev OK")
end

function bledev:upgrade_get()
	local mycmd = "upgradegetbledev"

	local _result, _upgradePayload = pcall(cjson.decode, utils:readfile("/tmp/devices/upgrade.json"))

	if ((_result == false) or (_upgradePayload == nil)) then
		return utils:getERRORJson(mycmd, "No upgrade process found!")
	end

	return cjson.encode(utils:getStandardJson(mycmd, _upgradePayload, "Retrieve upgrade procedure status"))
end

function bledev:update(arg)
	local mycmd = arg.command
	local data = arg.payload

	local _cstatus = {}
	
	local _ustatus_result, _ustatus = pcall(cjson.decode, utils:trim(data))

	if ((_ustatus_result == nil) or (_ustatus_result == false)) then
		return utils:getERRORJson(mycmd, "Status format is not valid. Please, try again.")
	end

	if ((_ustatus == nil) or (_ustatus == false)) then
		return utils:getERRORJson(mycmd, "Status format is not valid. Please, try again.")
	end

	local _devicemac = string.upper(_ustatus["MAC"]:gsub(":", "_"))

	if (_devicemac == nil) then
		return utils:getERRORJson(mycmd, "Device Mac Address format is not valid. Please, try again.")
	end

	local _cstatus_filepath = "/tmp/devices/" .. _devicemac .. ".json"

	if (utils:file_exists(_cstatus_filepath)) then
		local _cstatus_result, _cstatus_data = pcall(cjson.decode, utils:readfile(_cstatus_filepath))

		if (_cstatus_result == true and (_cstatus_data ~= nil)) then
			_cstatus = _cstatus_data
		end
	end

	_cstatus["MAC"] = _ustatus["MAC"]
	
	_cstatus["INFO"] = (_ustatus["INFO"] ~= nil and _ustatus["INFO"] or {})
	_cstatus["INFO"]["TS"] = utils:getTS("sec")

	_cstatus["DATA"] = (_cstatus["DATA"] ~= nil and _cstatus["DATA"] or {})

	for k,v in pairs(_ustatus["DATA"]) do
		_cstatus["DATA"][k] = v
	end

	if (_cstatus["DATA"]["ONLINE"] ~= nil and _cstatus["DATA"]["ONLINE"] == true) then
		bledev:set(_ustatus)
	end

	-- print(_cstatus_filepath)
	-- print(cjson.encode(_cstatus))
	
	utils:shell_exec("mkdir -p /tmp/devices")
	utils:writeinfile(_cstatus_filepath, cjson.encode(_cstatus))

	return utils:getOKJson(mycmd, "Status update result: OK")
end

return bledev