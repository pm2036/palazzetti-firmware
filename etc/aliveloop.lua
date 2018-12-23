#!/usr/bin/lua
dofile "/etc/main.lib.lua"
dofile "/etc/param.lib.lua"
dofile "/etc/timer.lib.lua"

CURRENT_BROKER = CBOXPARAMS["MQTT_BROKER"][1]
ALIVELOOP_SAMPLETIME = tonumber(CBOXPARAMS["ALIVELOOP_SAMPLETIME"])

-- 				 	 type		val  	deltaSec    TS 		error_code     isNotified   deltaSec_afterNotif
-- TRIGGER["T1"] = 	{"gt",		"80", 		10, 	 0,    "OVERTEMP_T1", 		0, 			    900}
-- TRIGGER["STATUS"] = {"gt",		"200", 		10, 	 0,    "STATUS_ERROR", 		0, 			    900}
-- TRIGGER["T1"] = 	{"lt",		"10", 		10, 	 0,    "FREEZEALERT_T1", 	0, 			    900}
-- TRIGGER["T3"] = 	{"lt",		"5", 		10, 	 0,    "FREEZEALERT_T3", 	0, 			    900}

local TRIGGER = nil
local NOTIFICATION = {}
local notifcount = 0

local tmpfile
local count
local isTrigger
local APLCONN=0
local ICONN=0

if (fsize("/tmp/staticdata.json")==0) then os.exit() end
-- update static
sendmsg("GET STDT", "/dev/null")

function checkClock(jdata)

	-- If Internet connection available and timezone not identified (checking temporary timezone file)
	if ((ICONN == 1) and (file_exists("/tmp/curr_timezone")==false)) then
		-- Detect and translate timezone into OpenWRT format
		local detectedTimezone = getTimezone()
		vprint("Detected timezone")
		vprint(detectedTimezone)
		-- If timezone is valid
		if (detectedTimezone ~= false) then
			-- If timezone is already present inside the file
			if (readfile("/etc/TZ") == detectedTimezone) then
				vprint("Already persisted to TZ, store in RAM")
				-- Write to temporary timezone file
				writeinfile("/tmp/curr_timezone", detectedTimezone)
			else
				-- Persist to system via System Command
				local output = cjson.decode(trim(shell_exec("lua /www/cgi-bin/syscmd.lua \"cmd=settz&tz=" .. detectedTimezone .. "\"")))
				vprint("Persistd to Timezone")
				-- If persist attempt is OK
				if (output["SUCCESS"] == true) then
					-- Write to temporary timezone file
					vprint("Persistd to curr_timezone")
					writeinfile("/tmp/curr_timezone", detectedTimezone)
				end
			end
		end
	end

	if jdata["APLTS"] == nil then return false end
	if APLCONN~=1 then return false end

	-- internet connected
	if (ICONN == 1) then
		if (isTimerSyncClockFeatureEnabled() and (os.date("%Y-%m-%d %H:%M") ~= jdata["APLTS"]:sub(1,16))) then
			syslogger("CLOCK", "Syncronize CBOX->APPLIANCE")
			sendmsg("SET TIME")
		end
	-- internet not connected
	else		
		-- check if syncronize clock from appliance to CBOX
		if (os.date("%Y-%m-%d %H:%M") ~= jdata["APLTS"]:sub(1,16)) then
			syslogger("CLOCK", "Syncronize APPLIANCE->CBOX")
			os.execute("date +\"%Y-%m-%d %H:%M\" -s \"" .. jdata["APLTS"]:sub(1,16) .. "\"")
		end
	end
end

-- Wait for bridge initialization
sleep(10)

while true do

	local retry=3

	-- Check Notification File Exists and Empty Trigger Object
	if ((fsize("/etc/notifications.json")>0) and (TRIGGER == nil)) then
		TRIGGER = cjson.decode(readfile("/etc/notifications.json"))
	end

	while(retry > 0) do
		sendmsg("GET ALLS", "/tmp/alivedata.json")
		jdata = cjson.decode(readfile("/tmp/alivedata.json"))
		retry = ((jdata["DATA"]~=nil) and (jdata["SUCCESS"]~=nil) and (jdata["SUCCESS"] ~= false)) and -1 or retry - 1
		if (retry~=-1) then sleep(5) end
	end

	if (retry >= 0) then

		mutex(function() exec("sed -i -e 's/\"APLCONN\":1/\"APLCONN\":0/g' /tmp/staticdata.json") end, "/tmp/lockjstatic")
		os.execute("kill -9 $(pidof plzbridge) && plzbridge &")
		-- Wait because it doesn't reach the end of the loop
		sleep(ALIVELOOP_SAMPLETIME)
		break
	end
	-- If handshake is still running, there could be case that appliance connected status is not reliable
	-- in that case, proceed by udpate the flag and reload static data about appliance
	if tonumber(trim(shell_exec("cat /tmp/staticdata.json | grep -c \"\\\"APLCONN\\\":0\"")))==1 then
		-- Ensure that, when connection with asset is UP, status is updated on static data
		-- This will ensure that cloud would be notified about those changes
		mutex(function() exec("sed -i -e 's/\"APLCONN\":0/\"APLCONN\":1/g' /tmp/staticdata.json") end, "/tmp/lockjstatic")
		sendmsg("GET STDT", "/dev/null")
	end

	if tonumber(trim(shell_exec("cat /tmp/staticdata.json | grep -c \"\\\"ICONN\\\":0\"")))==1 then
		ICONN=0
	else
		ICONN=1
	end

	APLCONN=1

	if (isTimerEnabled() == true) then
		-- check CLOCK settings
		checkClock(jdata["DATA"])
	end

	-- check Timer Chrono termostat
	checkTimer(jdata["DATA"])

	for key,value in pairs(((TRIGGER==nil) and {} or TRIGGER)) do
		if (jdata["DATA"][key]~=nil) then
			--check if trigger value
			isTrigger=false
			if (TRIGGER[key][1] == "eq") then
				if (tostring(jdata["DATA"][key]) == tostring(TRIGGER[key][2])) then isTrigger=true end
			elseif (TRIGGER[key][1] == "gt") then
				if (tonumber(jdata["DATA"][key]) > tonumber(TRIGGER[key][2])) then isTrigger=true end
			elseif (TRIGGER[key][1] == "lt") then
				if (tonumber(jdata["DATA"][key]) < tonumber(TRIGGER[key][2])) then isTrigger=true end
			end

			if (isTrigger==true) then
				if (tonumber(TRIGGER[key][4]) == 0) then
					TRIGGER[key][4] = getTS("sec")
				end

				-- check if timeout
				if ((tonumber(getTS("sec"))-tonumber(TRIGGER[key][4]))>=tonumber(TRIGGER[key][3])) then
					-- check if already notified
					if (tonumber(TRIGGER[key][6])==1) then
						if ((tonumber(getTS("sec"))-tonumber(TRIGGER[key][4]))>=tonumber(TRIGGER[key][7])) then
							-- it's time to notify!
							NOTIFICATION[TRIGGER[key][5]] = TRIGGER[key][4]
							TRIGGER[key][6]=1
							notifcount = notifcount + 1
						end
					else
						-- it's time to notify!
						TRIGGER[key][6]=1
						NOTIFICATION[TRIGGER[key][5]] = TRIGGER[key][4]
						notifcount = notifcount + 1
					end
				end

			else
				--reset timer
				-- NOTE: timestamp affects GUID!
				TRIGGER[key][4] = 0
				TRIGGER[key][6] = 0
			end
		end

	end


	if (notifcount>0) then

		count = 1

		jdata["INFO"]["CMD"] = "IOT_REQ_NOTIFICATION"
		newdata = {}

		for key,value in pairs(NOTIFICATION) do

			newdata[count] = cjson.decode(cjson.encode(jdata["DATA"]))
			newdata[count]["NCODE"] = readfline("/etc/aws-thing-client-id.prefix") .. "." .. key
			newdata[count]["LABEL"] = trim(readfile("/etc/appliancelabel"))
			newdata[count]["TS"] = NOTIFICATION[key]
			newdata[count]["GUID"] = newdata[count]["NCODE"] .. "." .. newdata[count]["TS"]
			count = count + 1
		end

		tmpfile = os.tmpname()
		vprint(cjson.encode(newdata))
		writeinfile(tmpfile, cjson.encode(newdata))
		jdata["DATA"] = encdata(tmpfile)
		writeinfile(tmpfile, cjson.encode(jdata))

		mqttpub(CURRENT_BROKER, "notification", tmpfile, false)
		os.execute("rm -f " .. tmpfile)

		NOTIFICATION = {}
		notifcount = 0

	end

	sleep(ALIVELOOP_SAMPLETIME)

end
