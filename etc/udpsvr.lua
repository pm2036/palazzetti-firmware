#!/usr/bin/lua
local socket = require "socket"
dofile "/etc/maindef.lua"
dofile "/etc/main.lib.lua"

-- begin
local udp = socket.udp()
local port = 54549

assert(udp:settimeout(-1))
assert(udp:setsockname('*', port))
local data
local running = true


print "Beginning server loop."
while running do

    data, msg_or_ip, port_or_nil = udp:receivefrom()
    if data then

		if data == (CBOXPARAMS["BRANDPREFIX"] .. "bridge?") then
			-- risponde alla richiesta
			-- print(data)
			--[[
			local f = assert(io.open("/etc/macaddr", "r"))
			local payload = f:read("*all")
			payload = CBOXPARAMS["BRANDPREFIX"] .. "-" .. payload:sub(1, (payload:len() - 1))
			f:close()
			--]]

			-- invia dati statici

			if (fsize("/tmp/staticdata.json")>0) then
				payload = readfile("/tmp/staticdata.json")
				jdata = cjson.decode(payload)
				jdata['INFO']['CMD'] = "DISCOVERY"
				-- Added on bridge to be cross-compatible with GET STDT request
				
				assert(udp:sendto(cjson.encode(jdata), msg_or_ip, port_or_nil))
			end
			-- Send response to UDP request only when static data are available
			-- In case of Debug, Cbox won't response if staticdata.json file is not present
			-- So, we have to invite customer to make a reset of the Cbox and connect to it
			-- On the default Ethernet debug address
			-- else
			-- 	jdata = {}
			-- 	jdata['INFO'] = {}
			-- 	jdata['DATA'] = {}
			-- 	jdata['INFO']['CMD'] = "DISCOVERY"
			-- 	jdata['DATA']['MAC'] = CBOXPARAMS["MAC"]
			-- end

			-- assert(udp:sendto(cjson.encode(jdata), msg_or_ip, port_or_nil))
		end
    end
    socket.sleep(0.1)
end

udp:close()
print "bye"