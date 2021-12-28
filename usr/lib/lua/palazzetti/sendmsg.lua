#!/usr/bin/lua

local cjson = require "cjson"
local utils = require "palazzetti.utils"
local bledev = require "palazzetti.bledev"
local timer = require "palazzetti.timer"

local sendmsg = {}

function sendmsg:set_jtmr(arg)
	local mycmd = arg.command
	local data = arg.payload

	local filepath = utils:gettmpfile("settimer")
	-- location of temporary file for timer writing
	utils:writeinfile(filepath, utils:trim(data))

	local output = timer:set{command="settimer", path=filepath}
	-- cleanup existing temporary writing
	exec("rm -f /tmp/*settimer")

	return output
end

function sendmsg:get_jtmr(arg)
	local mycmd = arg.command
	local data = arg.payload
	-- cleanup existing temporary writing
	utils:exec("rm -f /tmp/*settimer")
	-- redirect to syscmd
	local output = timer:get{command="gettimer", path=filepath}
	return output
end

function sendmsg:set_cdev(arg)
	-- local _bleactions = cjson.decode(readfile("/etc/bleactions.json"))
	local mycmd = arg.command
	local data = arg.payload

	print(data)
	print(data:match("(%w+)(.+)"))
	local _action = string.upper(utils:trim(data:match("%w+ [%w%d]+ *")))

	print(_action)
end

function sendmsg:get_ldev(arg)
	local mycmd = arg.command
	local data = arg.payload
	
	return bledev:get(data)
end

function sendmsg:set_ldev(arg)
	return bledev:update(arg)
end

function sendmsg:get_lstd(arg)
	local output = utils:readfile("/tmp/staticdata.json")
	return output
end

function sendmsg:get_lall(arg)
	local output = utils:readfile("/tmp/alivedata.json")
	return output
end

function sendmsg:get_jall(arg)
	local output = utils:readfile("/tmp/alivedata.json")
	return output
end

function sendmsg:get_guia(arg)
	local mycmd = arg.command

	if ((utils:file_exists("/tmp/alivedata.json") == false) or 
		(utils:file_exists("/tmp/staticdata.json") == false) or 
		(utils:fsize("/tmp/alivedata.json") <= 0) or 
		(utils:fsize("/tmp/staticdata.json") <= 0)) then

		return utils:getERRORJson(mycmd, "Missing data for GUI init")
	end

	out = cjson.decode(utils:readfile("/tmp/alivedata.json"))
	outs = cjson.decode(utils:readfile("/tmp/staticdata.json"))

	if (out["DATA"] ~= nil and outs["DATA"] ~= nil) then
		-- SETP
		loc_setp={}
		if out["DATA"]["SETP"] ~= 0 then 
			loc_setp={outs["DATA"]["SPLMIN"],outs["DATA"]["SPLMAX"],1,out["DATA"]["SETP"]}
		end
		-- POWR
		if outs["DATA"]["STOVETYPE"] ~= 8 then
			loc_powr={1,5,1,out["DATA"]["PWR"]}
		end
		-- ON/OFF
		if (outs["DATA"]["CBTYPE"] ~= "ET4W" and outs["DATA"]["CBTYPE"] ~= "VxxET") then
		-- if (outs["DATA"]["STOVETYPE"] ~= 7 and outs["DATA"]["STOVETYPE"] ~= 8) then
			if (out["DATA"]["LSTATUS"] == 0 or out["DATA"]["LSTATUS"] == 1 or out["DATA"]["LSTATUS"] == 6 or out["DATA"]["LSTATUS"] == 7 or out["DATA"]["LSTATUS"] == 9 or out["DATA"]["LSTATUS"] == 11 or out["DATA"]["LSTATUS"] == 12 or out["DATA"]["LSTATUS"] == 51 or out["DATA"]["LSTATUS"] == 501 or out["DATA"]["LSTATUS"] == 504 or out["DATA"]["LSTATUS"] == 505 or out["DATA"]["LSTATUS"] == 506 or out["DATA"]["LSTATUS"] == 507) then	
				if (out["DATA"]["STATUS"] ~= 0 and out["DATA"]["STATUS"] ~= 1) then
					btn_onoff={1,1}
				else
					btn_onoff={1,0}
				end
			else
				btn_onoff={0,0}
			end
		end
		-- CONNECTIONS
		conn= {outs["DATA"]["APLCONN"],outs["DATA"]["ICONN"],outs["DATA"]["GWDEVICE"],outs["DATA"]["WPWR"]}
		-- AIR STOVE ?
		if (outs["DATA"]["STOVETYPE"] ~= 2 and outs["DATA"]["STOVETYPE"] ~= 4 and outs["DATA"]["STOVETYPE"] ~= 6) then
			-- FAN 1
			if outs["DATA"]["FAN2TYPE"] > 1 then
				loc_fan1={out["DATA"]["FANLMINMAX"][1],out["DATA"]["FANLMINMAX"][2],1,out["DATA"]["F2L"]}
			end
			-- FAN 2
			if outs["DATA"]["FAN2TYPE"] > 2 then
				loc_fan2={out["DATA"]["FANLMINMAX"][3],out["DATA"]["FANLMINMAX"][4],1,out["DATA"]["F3L"]}
			end
			-- FAN 3
			if outs["DATA"]["FAN2TYPE"] > 3 then
				loc_fan3={out["DATA"]["FANLMINMAX"][5],out["DATA"]["FANLMINMAX"][6],1,out["DATA"]["F4L"]}
			end
			-- SILENT
			if outs["DATA"]["FAN2TYPE"] > 2 then
				if (out["DATA"]["F2L"]==0) then
					btn_silent = {1,1}
				else
					btn_silent = {1,0}
				end
			end
			-- MAIN TEMP
			if outs["DATA"]["MAINTPROBE"] == 0 then
				tm={10,out["DATA"]["T1"]}
			elseif (outs["DATA"]["MAINTPROBE"] == 1) then
				tm={10,out["DATA"]["T2"]}
			elseif (outs["DATA"]["MAINTPROBE"] == 2) then
				tm={10,out["DATA"]["T3"]}
			elseif (outs["DATA"]["MAINTPROBE"] == 3) then
				tm={10,out["DATA"]["T4"]}
			elseif (outs["DATA"]["MAINTPROBE"] == 4) then
				tm={10,out["DATA"]["T5"]}
			end
		else
			-- IDRO STOVE
			-- FAN 1
			if outs["DATA"]["FAN2TYPE"] > 1 then
				loc_fan1={out["DATA"]["FANLMINMAX"][1],out["DATA"]["FANLMINMAX"][2],1,out["DATA"]["F2L"]}
			end
			-- TM
			if outs["DATA"]["MAINTPROBE"] == 0 then
				tm={outs["DATA"]["UICONFIG"],out["DATA"]["T1"]}
			elseif (outs["DATA"]["MAINTPROBE"] == 1) then
				tm={outs["DATA"]["UICONFIG"],out["DATA"]["T2"]}
			elseif (outs["DATA"]["MAINTPROBE"] == 2) then
				tm={outs["DATA"]["UICONFIG"],out["DATA"]["T3"]}
			elseif (outs["DATA"]["MAINTPROBE"] == 3) then
				tm={outs["DATA"]["UICONFIG"],out["DATA"]["T4"]}
			elseif (outs["DATA"]["MAINTPROBE"] == 4) then
				tm={outs["DATA"]["UICONFIG"],out["DATA"]["T5"]}
			end
			-- Txx OTHER RELEVANT TEMPERATURES
			tx={out["DATA"]["T1"],out["DATA"]["T2"]}
		end
	end

	out = utils:getStandardJson(mycmd, {CONN=conn,TM=tm,TX=tx,LSTATUS=out["DATA"]["LSTATUS"],SETP=loc_setp,POWR=loc_powr,FAN1=loc_fan1,FAN2=loc_fan2,FAN3=loc_fan3,ONOFF=btn_onoff,SIL=btn_silent})
	return cjson.encode(out)
end

function sendmsg:set_labl(arg)
	local mycmd = arg.command
	local data = arg.payload

	utils:writeinfile("/etc/appliancelabel", data)
	out = cjson.decode(utils:readfile("/tmp/staticdata.json"))
	if out["DATA"] ~= nil then
		out["DATA"]["LABEL"] = data
		out = cjson.encode(out)
		utils:writeinfile("/tmp/staticdata.json", out)
	end

	out = utils:getStandardJson(mycmd, {LABEL=data})
	return cjson.encode(out)
end

function sendmsg:update_alivedata(jdata)

	if (utils:file_exists("/tmp/alivedata.json")==true) then
		local _astatus, _adata = pcall(cjson.decode, utils:readfile("/tmp/alivedata.json"))
		if (_astatus == true and _adata ~= nil and _adata["DATA"] ~= nil) then
			for k,v in pairs(jdata) do
				-- Update only existing properties of alive data
				if (_adata["DATA"][k] ~= nil) then
					_adata["DATA"][k] = v
				end
			end
			_adata = cjson.encode(_adata)
			utils:writeinfile("/tmp/alivedata.json", _adata)
		end
	end

end

function sendmsg:execute(arg)

	local output_destination = arg.dest

	if (output_destination ~= nil and output_destination ~= "") then
		local _output = self:execute{command=arg.command, payload=arg.payload}
		utils:writeinfile(output_destination, _output)
		return _output
	end

	local mycmd = arg.command

	-- Exit if command is not present
	if (mycmd==nil) then
		return utils:getERRORJson()
	end

	local data = (arg.payload ~= nil and arg.payload or mycmd:match("%w+ [%w%d]+ (.*)"))

	if (data == nil) then data = "" end

	mycmd = mycmd:match("%w+ [%w%d]+ *")
	-- Exit if command parse failed
	if (mycmd==nil) then
		return utils:getERRORJson()
	end
	mycmd = string.upper(utils:trim(mycmd))

	if (mycmd == "SET JTMR") then
		return self:set_jtmr{command=mycmd, payload=data}
	elseif (mycmd == "SET CDEV") then
		return self:set_cdev{command=mycmd, payload=data}
	elseif (mycmd == "GET LDEV") then
		return self:get_ldev{command=mycmd, payload=data}
	elseif (mycmd == "SET LDEV") then
		return self:set_ldev{command=mycmd, payload=data}
	elseif (mycmd == "GET LSTD") then
		return self:get_lstd{command=mycmd, payload=data}
	-- elseif (mycmd == "GET LALL") then
	-- 	return self:get_lall{command=mycmd, payload=data}
	elseif (mycmd == "GET JALL") then
		return self:get_jall{command=mycmd, payload=data}
	elseif (mycmd == "GET GUIA") then
		return self:get_guia{command=mycmd, payload=data}
	elseif (mycmd == "GET JTMR") then
		return self:get_jtmr{command=mycmd, payload=data}
	elseif (mycmd == "SET LABL") then
		return self:set_labl{command=mycmd, payload=data}
	end

	-- call sendmsg
	local ok, out = pcall(cjson.decode, utils:shell_exec("sendmsg \"" .. mycmd .. (data:len()>0 and " " .. data or "") .. "\" 2>/dev/null"))

	if ok==false or out==nil then
		out = cjson.decode("{\"INFO\":{\"RSP\":\"TIMEOUT\"}}")
	end
	out["SUCCESS"] = true
	out["INFO"]["CMD"] = mycmd
	out["INFO"]["TS"] = utils:getTS("sec")

	if (out["INFO"]["RSP"]~="OK") then
		out["SUCCESS"] = false
		out["DATA"] = {}
		out["DATA"]["NODATA"] = true
	end

	if (mycmd:upper() == "GET STDT") then
		-- Don't write to file if there isn't valid data
		if (out["SUCCESS"] == true) then utils:writeinfile("/tmp/staticdata.json", cjson.encode(out)) end
	end

	if ((out["DATA"] ~= nil) and 
		(out["SUCCESS"]==true) and
		(mycmd:upper() ~= "GET STDT") and 
		(mycmd:upper() ~= "GET ALLS")
		) 
	then
		-- Prevent command failure in case of error to store alive data update
		pcall(function() self:update_alivedata(out["DATA"]) end)
	end

	return cjson.encode(out)
end

return sendmsg