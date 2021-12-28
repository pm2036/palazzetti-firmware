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

local sendmsg = require "palazzetti.sendmsg"
qstring.command = (qstring.cmd==nil and qstring.command or qstring.cmd)
local output = sendmsg:execute(qstring)

if ((arg ~= nil) and (arg[1] ~= nil)) then
	print(output)
else
	return output
end