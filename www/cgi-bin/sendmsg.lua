
if ((arg ~= nil) and (arg[1] ~= nil)) then
	dofile "/etc/main.lib.lua"
	cjson = require "cjson"
	qstring = {}
	qstring.cmd = urldecode(arg[1])
end

-- 26/01/2018 - Support "command" to retrofit compatibility with Cloud Architecture (Mobile App purpose)
if (qstring.cmd==nil and qstring.command==nil) then
	return getERRORJson()
end

local mycmd = (qstring.cmd==nil and qstring.command or qstring.cmd)

local data = mycmd:match("%w+ [%w%d]+ (.*)")

if (data == nil) then data = "" end
mycmd = string.upper(trim(mycmd:match("%w+ [%w%d]+ *")))

if (mycmd == "SET JTMR") then
	-- redirect to syscmd
	local filepath = gettmpfile("settimer")
	-- location of temporary file for timer writing
	writeinfile(filepath, trim(data))

	local output = shell_exec("lua /www/cgi-bin/syscmd.lua \"cmd=settimer&path=" .. filepath .. "\"")
	-- cleanup existing temporary writing
	exec("rm -f /tmp/*settimer")

	if ((arg ~= nil) and (arg[1] ~= nil)) then
		print(output)
		return
	else
		return output
	end

elseif (mycmd == "GET JTMR") then
	-- cleanup existing temporary writing
	exec("rm -f /tmp/*settimer")
	-- redirect to syscmd
	local output = shell_exec("lua /www/cgi-bin/syscmd.lua cmd=gettimer")
	if ((arg ~= nil) and (arg[1] ~= nil)) then
		print(output)
		return
	else
		return output
	end

elseif (mycmd == "SET LABL") then

	writeinfile("/etc/appliancelabel", data)
	out = cjson.decode(readfile("/tmp/staticdata.json"))
	if out["DATA"] ~= nil then
		out["DATA"]["LABEL"] = data
		out = cjson.encode(out)
		writeinfile("/tmp/staticdata.json", out)
	end

	out = getStandardJson(mycmd, {LABEL=data})
	if ((arg ~= nil) and (arg[1] ~= nil)) then
		print(cjson.encode(out))
		return
	else
		return cjson.encode(out)
	end
end

-- call sendmsg
local ok, out = pcall(cjson.decode, shell_exec("sendmsg \"" .. mycmd .. (data:len()>0 and " " .. data or "") .. "\" 2>/dev/null"))

if ok==false or out==nil then
	out = cjson.decode("{\"INFO\":{\"RSP\":\"TIMEOUT\"}}")
end
out["SUCCESS"] = true
out["INFO"]["CMD"] = mycmd
out["INFO"]["TS"] = getTS("sec")

if (out["INFO"]["RSP"]~="OK") then
	out["SUCCESS"] = false
	out["DATA"] = {}
	out["DATA"]["NODATA"] = true
end

if (mycmd:upper() == "GET STDT") then
	-- Don't write to file if there isn't valid data
	if (out["SUCCESS"] == true) then writeinfile("/tmp/staticdata.json", cjson.encode(out)) end
end

if ((arg ~= nil) and (arg[1] ~= nil)) then
	print(cjson.encode(out))
else
	return cjson.encode(out)
end