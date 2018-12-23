#!/usr/bin/lua

cjson = require "cjson"

function handleProgramNoMatch(jtimer, jdata)

	-- cancel current program
	writeinfile("/tmp/timer_currentprg", "")
	-- Consenti controllo manuale su App Disabilitato
	if (jtimer["off_when_nomatch"]==false) then
		-- print("TIMER program_match = false")
		-- check if the logic status is not in error
		if (	(tonumber(jdata["LSTATUS"])==6) or
				(tonumber(jdata["LSTATUS"])==7) or
				(tonumber(jdata["LSTATUS"])==9) or
				(tonumber(jdata["LSTATUS"])==11) or
				(tonumber(jdata["LSTATUS"])==501) or
				(tonumber(jdata["LSTATUS"])==504) or
				(tonumber(jdata["LSTATUS"])==507)
			) then
			-- print("TIMER sendmsg CMD OFF")
			syslogger("TIMER", "CMD OFF")
			sendmsg("CMD OFF")
		end
	end

end

function checkTimer(jdata)
	local k, v, weekday

	if (file_exists("/tmp/timer.json")==false) then return end
	if fsize("/tmp/timer.json")<10 then return end
	local jtimer = cjson.decode(readfile("/tmp/timer.json"))
	local jstatic = cjson.decode(readfile("/tmp/staticdata.json"))

	local currentWDAY = tonumber(os.date("*t").wday)==1 and 6 or tonumber(os.date("*t").wday) - 2

	local currentMinutes = tonumber(getMinutes())
	local currentProgram
	local currentScenario
	local commands = {}
	local cmd
	local program_match = false
	local programID = ""

	local myapplid = ((jstatic~=nil and jstatic["DATA"]~=nil and jstatic["DATA"]["SPLMIN"]~=nil) and (jstatic["DATA"]["SPLMIN"] .. "_" .. jstatic["DATA"]["SPLMAX"]) or "")

		if (jtimer["applid"] ~= myapplid) then

			syslogger("TIMER", "Reset Appliance Identifier: " .. myapplid)

			-- need to reset the timer!!
			jtimer = {}
			jtimer["applid"] = myapplid
			jtimer["enabled"] = false
			jtimer["scenarios"] = {}
			jtimer["scenarios"]["comfort"] = {}
			jtimer["scenarios"]["economy"] = {}
			jtimer["scenarios"]["warm"] = {}
			jtimer["scenarios"]["off"] = {}

			jtimer["scenarios"]["comfort"]["settings"] = {}
			jtimer["scenarios"]["economy"]["settings"] = {}
			jtimer["scenarios"]["warm"]["settings"] = {}
			jtimer["scenarios"]["off"]["settings"] = {}

			local newsetpoint = math.floor((tonumber(jstatic["DATA"]["SPLMAX"]) + tonumber(jstatic["DATA"]["SPLMIN"]))/2)
			jtimer["scenarios"]["comfort"]["settings"]["SET SETP"] = newsetpoint
			jtimer["scenarios"]["economy"]["settings"]["SET SETP"] = newsetpoint
			jtimer["scenarios"]["warm"]["settings"]["SET SETP"] = newsetpoint
			jtimer["scenarios"]["off"]["settings"]["CMD"] = "OFF"

			jtimer["scheduler"] = {}
			jtimer["off_when_nomatch"] = false

			os.execute("rm /tmp/timer.json")
			writeinfile("/etc/timer.json", cjson.encode(jtimer))
			os.execute("cp /etc/timer.json /tmp/timer.json")

			return false
		end

		if (jtimer["enabled"]==false) then return end

		if ((jdata["CHRSTATUS"]~=nil) and (jdata["CHRSTATUS"] ~= 0)) then
			-- check inside jdata for chrono key 
			syslogger("TIMER", "SET CSST 0")
			sendmsg("SET CSST 0")
		end

		if (jtimer["scheduler"][tostring(currentWDAY)]==nil) then
			handleProgramNoMatch(jtimer, jdata)
			return
		end

		for k, currentProgram in pairs(jtimer["scheduler"][tostring(currentWDAY)]) do

			commands = {}

			currentScenario = jtimer["scenarios"][tostring(currentProgram["scenario"])]

			if (currentMinutes>=tonumber(currentProgram["start_time"])) and (currentMinutes<=tonumber(currentProgram["end_time"])) then
				-- ###### !we are inside a program! ######
				program_match = true
				-- print("TIMER program_match = true")

				-- merge command between scenario and program
				for k,v in pairs(currentScenario["settings"]) do
					commands[k] = v
				end
				-- program settings will OVERWRITE scenario settings
				if (currentProgram["settings"] ~= nil) then
					for k,v in pairs(currentProgram["settings"]) do
						commands[k] = v
					end
				end

				-- check if program is already applied
				if (currentScenario["settings"]["SET SETP"]==nil) then currentScenario["settings"]["SET SETP"] = "" end
				programID = tostring(currentWDAY) .. "_" .. currentProgram["start_time"] .. "_" .. currentProgram["scenario"] .. "_" .. currentScenario["settings"]["SET SETP"]
				if (programID == readfile("/tmp/timer_currentprg")) then break end

				writeinfile("/tmp/timer_currentprg", programID)

				-- ####################
				-- execute all settings
				-- ####################
				-- print("TIMER execute all settings")
				for k,v in pairs(commands) do
					local applycmd = false
					cmd = k .. " " .. commands[k]
					if (k == "SET SETP") then
						if ((jdata["SETP"]~=nil) and (jdata["SETP"] ~= commands[k])) then
						applycmd = true
						end
					elseif (k == "SET RFAN") then
						if ((jdata["F2L"]~=nil) and (jdata["F2L"] ~= commands[k])) then
						applycmd = true
						end
					end

					if (applycmd==true) then
						syslogger("TIMER", cmd)
						sendmsg(cmd)
					end
				end

				-- check if power ON
				if (jdata["STATUS"]==0) then
					local maintemp = "T" .. tostring(tonumber(jstatic["DATA"]["MAINTPROBE"])+1)
					if (tonumber(jdata[maintemp])<tonumber(commands["SET SETP"])) then
						-- we have to switch ON!
						syslogger("TIMER", "CMD ON")
						sendmsg("CMD ON")
					else
						-- print("Skip TIMER ON")
					end
				end

			end
		end

		if (program_match==false) then handleProgramNoMatch(jtimer, jdata) end
end