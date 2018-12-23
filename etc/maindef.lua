#!/usr/bin/lua
cjson = require "cjson"
CBOXPR_FILE = "/etc/cboxparams.json"
CBOXPR_TMPFILE = "/tmp/cboxparams.json"

if (CBOXPARAMS == nil) then
	local f = io.open(CBOXPR_TMPFILE)
	jsondata = f:read("*a")
	f:close()
	CBOXPARAMS = cjson.decode(jsondata)
	if (CBOXPARAMS["MQTT_VERBOSE"]==1) then print("read cboxparams.json OK") end
end


