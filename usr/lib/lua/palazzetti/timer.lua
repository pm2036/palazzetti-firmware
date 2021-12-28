#!/usr/bin/lua

local cjson = require "cjson"
local utils = require "palazzetti.utils"

local timer = {}

function timer:init(jtimer,jstatic)
	-- need to reset the timer!!
	if (jtimer == nil) then
		jtimer = {}
	end

	local applid = ((jstatic~=nil and jstatic["DATA"]~=nil and jstatic["DATA"]["SPLMIN"]~=nil) and (jstatic["DATA"]["SPLMIN"] .. "_" .. jstatic["DATA"]["SPLMAX"]) or "")

	if (applid == "") then
		return nil
	end

	jtimer["applid"] = applid

	if ((jtimer ~= nil) and (jtimer["enabled"] ~= nil)) then
		jtimer["enabled"] = (jtimer["enabled"] or false)
	else
		jtimer["enabled"] = false
	end

	jtimer["sync_clock_enabled"] = false
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

	if (jtimer["scheduler"] == nil) then
		jtimer["scheduler"] = {}
	end

	return jtimer
end

function timer:product_waiting(jtimer, jdata)
	if (	-- Spento
			(tonumber(jdata["LSTATUS"])==0) or
			-- MF: Spento
			(tonumber(jdata["LSTATUS"])==501)
		) then

		return true
	end

	return false
end

function timer:product_burning(jtimer, jdata)
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
			-- MF: Accensione a pellet
			(tonumber(jdata["LSTATUS"])==509)
		) then

		return true
	end

	return false
end

function timer:checkpoint_set(programID)
	if (programID == nil) then
		programID = "PROGRAM_NOMATCH_OFF"
	end

	utils:writeinfile("/tmp/timer_currentprg", programID)
	utils:writeinfile("/etc/timer_currentprg", programID)
end

function timer:enabled()
	if (utils:file_exists("/tmp/timer.json")==false) then return false end
	local jtimer = cjson.decode(utils:readfile("/tmp/timer.json"))
	return ((jtimer["enabled"] == true) and true or false)
end

function timer:enabled_clock()
	-- if (file_exists("/tmp/timer.json")==false) then return false end
	-- local jtimer = cjson.decode(readfile("/tmp/timer.json"))
	-- return (((jtimer["sync_clock_enabled"] == nil) or (jtimer["sync_clock_enabled"] == true)) and true or false)
	return false
end

function timer:set(arg)
	local mycmd = arg.command

	if (utils:empty(arg.path)) then return utils:getERRORJson(mycmd,"empty path location") end
	if (utils:file_exists(arg.path) == false) then return utils:getERRORJson(mycmd,"writing stage file doesn't exists") end

	local jstatic = cjson.decode(utils:readfile("/tmp/staticdata.json"))
	local jtimer = cjson.decode(utils:decstring(utils:readfile(arg.path)))

	-- Wipe read-only properties that would not be stored
	jtimer["last_program"] = nil
	jtimer["curr_timezone"] = nil
	jtimer["curr_timezone_country"] = nil
	-- Update Timer Appliance Identifier
	jtimer["applid"] = ((jstatic~=nil and jstatic["DATA"]~=nil and jstatic["DATA"]["SPLMIN"]~=nil) and (jstatic["DATA"]["SPLMIN"] .. "_" .. jstatic["DATA"]["SPLMAX"]) or "")
	-- Try writing to Timer RAM file
	utils:writeinfile("/tmp/timer.json", cjson.encode(jtimer))

	-- Cleanup file
	utils:exec("rm -f /tmp/*settimer")

	-- If writing not succeded
	if (utils:fsize("/tmp/timer.json") <= 0) then
		-- Restore previous situation
		utils:exec("cp /etc/timer.json /tmp/timer.json")
		return utils:getERRORJson(mycmd,"Timer format is not valid. Please, try again.")
	end

	if (jstatic~=nil and jstatic["DATA"]~=nil and jstatic["DATA"]["ICONN"]~=nil) then
		-- Internet Connection not available
		if(jstatic["DATA"]["ICONN"] == 0) and (jtimer["last_edit"]~=nil) and (jtimer["last_edit"]~="") then
			-- Set date as last edit date and transfer time to appliance
			-- shell_exec("date -s '" .. jtimer["last_edit"]:gsub("T", " ") .. "'")
			-- sendmsg:execute{command="SET TIME"}
		end
	end

	-- Store timer succesfully
	utils:exec("cp /tmp/timer.json /etc/timer.json")

	-- *************** TO DO ***************
	-- Se manca connessione ad internet utilizzo il campo last-modified del jsontimer
	-- per forzare la data ed ora di sistema e della stufa
	-- Al reboot sarà attiva la procedura di sync dell'orologio tra stufa e cbox senza NTP



	return utils:getOKJson(mycmd, "settimer OK")
end

function timer:get(arg)
	local mycmd = arg.command
	local jtimer = cjson.decode(utils:readfile("/tmp/timer.json"))
		-- read which is the last applied program
		jtimer["last_program"] = utils:readfile("/tmp/timer_currentprg")
		jtimer["curr_timezone"] = utils:readfile("/tmp/curr_timezone")
		jtimer["curr_timezone_country"] = utils:readfile("/tmp/curr_timezone_country")

		-- jtimer["ecostart_mode_enabled"] = ((jtimer["ecostart_mode_enabled"] == nil) and false or jtimer["ecostart_mode_enabled"])
		-- jtimer["sync_clock_enabled"] = ((jtimer["sync_clock_enabled"] == nil) and true or jtimer["sync_clock_enabled"])

	local jsonout = {}
		jsonout["SUCCESS"] = true

		jsonout["INFO"] = {}
		jsonout["INFO"]["CMD"] = mycmd
		jsonout["INFO"]["TS"] = utils:getTS("sec")
		jsonout["INFO"]["RSP"] = "OK"

		jsonout["DATA"] = {}
		jsonout["DATA"]["TIMER"] = utils:encstring(cjson.encode(jtimer))

		return (cjson.encode(jsonout))
end

return timer