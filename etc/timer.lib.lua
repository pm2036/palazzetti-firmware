#!/usr/bin/lua

cjson = require "cjson"

function isTimerProductBurning(jtimer, jdata)
	if (	-- In funzione
			(tonumber(jdata["LSTATUS"])==6) or
			-- In funzione – Modulazione
			(tonumber(jdata["LSTATUS"])==7) or
			-- Stand-By / Cool-Fluid
			(tonumber(jdata["LSTATUS"])==9) or
			-- Ecomode
			(tonumber(jdata["LSTATUS"])==51) or
			-- MF: In Funzione
			(tonumber(jdata["LSTATUS"])==504) or
			-- MF: Esaurimento Legna
			(tonumber(jdata["LSTATUS"])==505) or
			-- MF: Pulizia braciere
			(tonumber(jdata["LSTATUS"])==509)
		) then

		return true
	end

	return false
end

function isTimerProductWaiting(jtimer, jdata)
	if (	-- In funzione
			(tonumber(jdata["LSTATUS"])==0) or
			-- MF: Spento
			(tonumber(jdata["LSTATUS"])==501)
		) then

		return true
	end

	return false
end

function handleProgramNoMatch(jtimer, jdata, programID)
	-- Program ID when timer send OFF

	if (programID == nil) then
		programID = "PROGRAM_NOMATCH_OFF"
	end

	-- Se ho già lanciato il comando di spegnimento almeno una volta
	if (programID == readfile("/tmp/timer_currentprg")) then
		-- Non lo lancio nuovamente in quanto l'utente potrebbe aver acceso la stufa manualmente
		-- E questa deve continuare a lavorare
		return
	end

	-- check if the logic status is not in error
	if (	-- Spento
			(tonumber(jdata["LSTATUS"])==0) or
			-- Spento da Timer
			(tonumber(jdata["LSTATUS"])==1) or
			-- In funzione
			(tonumber(jdata["LSTATUS"])==6) or
			-- In funzione – Modulazione
			(tonumber(jdata["LSTATUS"])==7) or
			-- Stand-By / Cool-Fluid
			(tonumber(jdata["LSTATUS"])==9) or
			-- Pulizia braciere
			(tonumber(jdata["LSTATUS"])==11) or
			-- Attesa raffreddamento
			(tonumber(jdata["LSTATUS"])==12) or
			-- Ecomode
			(tonumber(jdata["LSTATUS"])==51) or
			-- MF: Spento
			(tonumber(jdata["LSTATUS"])==501) or
			-- MF: In Funzione
			(tonumber(jdata["LSTATUS"])==504) or
			-- MF: Esaurimento Legna
			(tonumber(jdata["LSTATUS"])==505) or
			-- MF: Raffreddamento
			(tonumber(jdata["LSTATUS"])==506) or
			-- MF: Pulizia Braciere
			(tonumber(jdata["LSTATUS"])==507) or
			-- MF: Pulizia Braciere
			(tonumber(jdata["LSTATUS"])==509)
		) then

		-- we have to switch OFF!
		local _powerOffCommandResult, _powerOffCommandData = pcall(cjson.decode, sendmsg("CMD OFF"))

		if (
			(_powerOffCommandResult ~= false) and
			(_powerOffCommandData ~= nil) and
			(_powerOffCommandData["INFO"] ~= nil) and
			(_powerOffCommandData["INFO"]["RSP"] == "OK") and
			(_powerOffCommandData["DATA"]~=nil)
		) then
			syslogger("TIMER", "CMD OFF")
			writeinfile("/tmp/timer_currentprg", programID)
		else
			syslogger("TIMER", "CMD OFF FAILED")
		end

	end

end

function isTimerEnabled()
	if (file_exists("/tmp/timer.json")==false) then return false end
	local jtimer = cjson.decode(readfile("/tmp/timer.json"))
	return ((jtimer["enabled"] == true) and true or false)
end

function isTimerSyncClockFeatureEnabled()
	if (file_exists("/tmp/timer.json")==false) then return false end
	local jtimer = cjson.decode(readfile("/tmp/timer.json"))
	return (((jtimer["sync_clock_enabled"] == nil) or (jtimer["sync_clock_enabled"] == true)) and true or false)
end

function checkTimer(jdata)
	local k, v

	if (file_exists("/tmp/timer.json")==false) then return end
	if fsize("/tmp/timer.json")<10 then return end
	local jtimer = cjson.decode(readfile("/tmp/timer.json"))
	local jstatic = cjson.decode(readfile("/tmp/staticdata.json"))

	-- local currentWDAY = tonumber(os.date("*t").wday)==1 and 6 or tonumber(os.date("*t").wday) - 2
	-- local currentWDAY = tonumber(os.date("*t").wday)==1 and 6 or tonumber(os.date("*t").wday) - 2
    local currentWDAY = (tonumber(jdata["APLWDAY"]) - 1)
	-- local currentMinutes = tonumber(getMinutes())
	local currentMinutes = tonumber(getMinutes(jdata["APLTS"]))
	local currentProgram
	local currentScenario
	local commands = {}
	local cmd
	local program_match = false
	local programID = ""

	local applied_commands = {}

	if (file_exists("/tmp/timer_currentcmd")~=false) then

		local _appliedCommandsResult, _appliedCommandsData = pcall(cjson.decode, readfile("/tmp/timer_currentcmd"))
		if ((_appliedCommandsResult ~= false) and (_appliedCommandsData ~= nil)) then
			applied_commands = _appliedCommandsData
		end
	end

	local myapplid = ((jstatic~=nil and jstatic["DATA"]~=nil and jstatic["DATA"]["SPLMIN"]~=nil) and (jstatic["DATA"]["SPLMIN"] .. "_" .. jstatic["DATA"]["SPLMAX"]) or "")

		if ((jtimer["applid"] ~= myapplid) and (myapplid ~= "")) then

			syslogger("TIMER", "Reset Appliance Identifier: " .. myapplid)

			-- need to reset the timer!!
			if (jtimer == nil) then
				jtimer = {}
			end

			jtimer["applid"] = myapplid
			jtimer["enabled"] = false

			jtimer["sync_clock_enabled"] = true
			jtimer["ecostart_mode_enabled"] = false

			jtimer["scenarios"] = {}
			jtimer["scenarios"]["comfort"] = {}
			jtimer["scenarios"]["economy"] = {}
			jtimer["scenarios"]["warm"] = {}
			jtimer["scenarios"]["off"] = {}

			jtimer["scenarios"]["comfort"]["settings"] = {}
			jtimer["scenarios"]["economy"]["settings"] = {}
			jtimer["scenarios"]["warm"]["settings"] = {}
			jtimer["scenarios"]["off"]["settings"] = {}

			-- Don't check SPLMAX and SPLMIN because we assume that condition is already satisfied by myapplid empty check

			local newsetpoint = math.floor((tonumber(jstatic["DATA"]["SPLMAX"]) + tonumber(jstatic["DATA"]["SPLMIN"]))/2)
			jtimer["scenarios"]["comfort"]["settings"]["SET SETP"] = newsetpoint
			jtimer["scenarios"]["economy"]["settings"]["SET SETP"] = newsetpoint
			jtimer["scenarios"]["warm"]["settings"]["SET SETP"] = newsetpoint
			-- jtimer["scenarios"]["off"]["settings"]["CMD"] = "OFF"

			-- Do not reset scheduler choosen by user
			-- jtimer["scheduler"] = {}
			jtimer["off_when_nomatch"] = true

			os.execute("rm -f /tmp/timer.json")
			writeinfile("/etc/timer.json", cjson.encode(jtimer))
			os.execute("cp /etc/timer.json /tmp/timer.json")

			return false
		end

		-- Timer disabilitato
		if (jtimer["enabled"]==false) then return end

		if ((jdata["CHRSTATUS"]~=nil) and (jdata["CHRSTATUS"] ~= 0)) then
			-- check inside jdata for chrono key
			syslogger("TIMER", "SET CSST 0")
			sendmsg("SET CSST 0")
		end

		-- Se il timer è abilitato e non esiste alcuna programmazione per la giornata attuale
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

					-- If command has been applied
					if ((k ~= nil) and (applied_commands["" .. k] ~= nil) and (applied_commands["" .. k] == programID)) then
						-- Skip command apply
						applycmd = false
					end

					if (applycmd==true) then
						applied_commands["" .. k] = programID
						syslogger("TIMER", cmd)
						sendmsg(cmd)
					end
				end

				-- If scenario is forced OFF
				if ((currentProgram["scenario"] ~= nil) and (currentProgram["scenario"] == "off")) then
					-- Force off depending on status
					handleProgramNoMatch(jtimer, jdata, programID)
				-- Else if product could be switched on
				elseif (isTimerProductWaiting(jtimer, jdata) or isTimerProductBurning(jtimer, jdata)) then

					local maintemp = "T" .. tostring(tonumber(jstatic["DATA"]["MAINTPROBE"])+1)

					if ((
						-- Se la modalità Eco-start è impostata e ci sono i presupposti per accendere
						(jtimer["ecostart_mode_enabled"] ~= nil) and
						(jtimer["ecostart_mode_enabled"] == true) and
						(tonumber(jdata[maintemp])<tonumber(commands["SET SETP"]))
					) or (
						-- Oppure se la modalità Eco-start non è impostata
						(jtimer["ecostart_mode_enabled"] == nil) or
						(jtimer["ecostart_mode_enabled"] == false)
					) or (
						-- Oppure se il prodotto è già in funzione
						isTimerProductBurning(jtimer, jdata) == true
					)) then

						-- we have to switch ON!
						if (isTimerProductWaiting(jtimer, jdata) == true) then
							local _powerOnCommandResult, _powerOnCommandData = pcall(cjson.decode, sendmsg("CMD ON"))

							if (
								(_powerOnCommandResult ~= false) and
								(_powerOnCommandData ~= nil) and
								(_powerOnCommandData["INFO"] ~= nil) and
								(_powerOnCommandData["INFO"]["RSP"] == "OK") and
								(_powerOnCommandData["DATA"]~=nil) and
								(_powerOnCommandData["DATA"]["STATUS"]>1)
							) then
								syslogger("TIMER", "CMD ON")
								applied_commands["CMD ON"] = programID
								writeinfile("/tmp/timer_currentprg", programID)
							else
								syslogger("TIMER", "CMD ON FAILED")
							end
						else
							syslogger("TIMER", "CMD ON")
							applied_commands["CMD ON"] = programID
							writeinfile("/tmp/timer_currentprg", programID)
						end
					end
				end

				-- Store applied commands into temporary file
				writeinfile("/tmp/timer_currentcmd", cjson.encode(applied_commands))
			end
		end

		if (program_match==false) then handleProgramNoMatch(jtimer, jdata) end

end