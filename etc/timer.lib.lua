#!/usr/bin/lua

local cjson = require "cjson"
local sendmsg = require "palazzetti.sendmsg"
local timer = require "palazzetti.timer"

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
			-- MF: Passaggio a Pellet
			(tonumber(jdata["LSTATUS"])==509)
		) then

		-- we have to switch OFF!
		local _powerOffCommandResult, _powerOffCommandData = pcall(cjson.decode, sendmsg:execute{command="CMD OFF"})

		if (
			(_powerOffCommandResult ~= false) and
			(_powerOffCommandData ~= nil) and
			(_powerOffCommandData["INFO"] ~= nil) and
			(_powerOffCommandData["INFO"]["RSP"] == "OK") and
			(_powerOffCommandData["DATA"]~=nil)
		) then
			syslogger("TIMER", "CMD OFF")
			timer:checkpoint_set(programID)
		else
			syslogger("TIMER", "CMD OFF FAILED")
		end
	end
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

	-- minutes not valid
	if (currentMinutes == -1) then
		return false
	end

	if (file_exists("/tmp/timer_currentcmd")~=false) then

		local _appliedCommandsResult, _appliedCommandsData = pcall(cjson.decode, readfile("/tmp/timer_currentcmd"))
		if ((_appliedCommandsResult ~= false) and (_appliedCommandsData ~= nil)) then
			applied_commands = _appliedCommandsData
		end
	end

	local myapplid = ((jstatic~=nil and jstatic["DATA"]~=nil and jstatic["DATA"]["SPLMIN"]~=nil) and (jstatic["DATA"]["SPLMIN"] .. "_" .. jstatic["DATA"]["SPLMAX"]) or "")

		if ((jtimer["applid"] ~= myapplid) and (myapplid ~= "") or
			(jtimer["scenarios"] == nil) or 
			(jtimer["scenarios"]["comfort"] == nil) or
			(jtimer["scenarios"]["comfort"]["settings"] == nil)) then

			syslogger("TIMER", "Reset Appliance Identifier: " .. myapplid)

			jtimer = timer:init(jtimer,jstatic)

			if (jtimer == nil) then
				return false
			end

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
			sendmsg:execute{command="SET CSST 0"}
		end

		-- Se il timer è abilitato e non esiste alcuna programmazione per la giornata attuale
		if (jtimer["scheduler"][tostring(currentWDAY)]==nil) then
			handleProgramNoMatch(jtimer, jdata, nil)
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
				
				-- Il programID calcolato è uguale a quello già applicato
				-- Non proseguire oltre
				if (programID == readfile("/tmp/timer_currentprg")) then 
					-- print("timer have been previously applied")
					return
				end

				-- Attendi 5 secondi prima di effettuare la lettura di verifica dell'orario
				sleep(5)

				local _checkDateTimeCommandResult, _checkDateTimeCommandData = pcall(cjson.decode, sendmsg:execute{command="GET TIME"})

				if ((_checkDateTimeCommandResult == true) and (_checkDateTimeCommandData ~= nil) and (_checkDateTimeCommandData["DATA"] ~= nil)) then 

					-- print(cjson.encode(_checkDateTimeCommandData))
					-- print(_checkDateTimeCommandData["DATA"]["STOVE_WDAY"])
					-- print(_checkDateTimeCommandData["DATA"]["STOVE_DATETIME"])

					local checkDateTime_currWeekday = (tonumber(_checkDateTimeCommandData["DATA"]["STOVE_WDAY"]) - 1)
					local checkDateTime_currMinutes = tonumber(getMinutes(_checkDateTimeCommandData["DATA"]["STOVE_DATETIME"]))
					-- Ultima data letta per convalida - Data letta in precedenza
					local checkDateTime_validateRange = ((checkDateTime_currWeekday * 24 * 60) + checkDateTime_currMinutes) - ((currentWDAY * 24 * 60) + currentMinutes)

					-- La lettura della data è errata se il DELTA tra la data letta e quella in input NON è compreso tra 0 e 2 minuti
					if (checkDateTime_validateRange < 0 or checkDateTime_validateRange > 2) then return end
				else
					-- La lettura della data per la convalida del timeframe è fallita
					-- Pertanto non si può procedere con le operazioni
					return
				end

				-- ####################
				-- execute all settings
				-- ####################
				-- print("TIMER execute all settings")
				for k,v in pairs(commands) do
					local applycmd = false
					cmd = k .. " " .. commands[k]
					if (k == "SET SETP") then
						applycmd = true
					elseif (k == "SET POWR") then
						applycmd = true
					elseif (k == "SET RFAN") then
						applycmd = true
					elseif (k == "SET FN3L") then
						applycmd = true
					elseif (k == "SET FN4L") then
						applycmd = true
					elseif (k == "SET SLNT") then
						applycmd = true
					end

					-- If command has been applied
					if ((k ~= nil) and (applied_commands["" .. k] ~= nil) and (applied_commands["" .. k] == programID)) then
						-- Skip command apply
						applycmd = false
					end

					if (applycmd==true) then
						applied_commands["" .. k] = programID
						syslogger("TIMER", cmd)
						sendmsg:execute{command=cmd}
					end
				end

				-- If scenario is forced OFF
				if ((currentProgram["scenario"] ~= nil) and (currentProgram["scenario"] == "off")) then
					-- Force off depending on status
					handleProgramNoMatch(jtimer, jdata, programID)
				-- Else if product could be switched on
				elseif (timer:product_waiting(jtimer, jdata) or timer:product_burning(jtimer, jdata)) then

					-- we have to switch ON!
					if (timer:product_waiting(jtimer, jdata) == true) then
						local _powerOnCommandResult, _powerOnCommandData = pcall(cjson.decode, sendmsg:execute{command="CMD ON"})

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
							timer:checkpoint_set(programID)
						else
							syslogger("TIMER", "CMD ON FAILED")
						end
					else
						syslogger("TIMER", "CMD ON")
						applied_commands["CMD ON"] = programID
						timer:checkpoint_set(programID)
					end
				end

				-- Store applied commands into temporary file
				writeinfile("/tmp/timer_currentcmd", cjson.encode(applied_commands))
			end
		end

		if (program_match==false) then 
			handleProgramNoMatch(jtimer, jdata, nil)
		end

end