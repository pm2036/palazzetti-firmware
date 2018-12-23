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

			-- invia dati statici
			if (fsize("/tmp/staticdata.json")>0) then
				payload = readfile("/tmp/staticdata.json")
				jdata = cjson.decode(payload)
				jdata['INFO']['CMD'] = "DISCOVERY"
				-- Added on bridge to be cross-compatible with GET STDT request
				assert(udp:sendto(cjson.encode(jdata), msg_or_ip, port_or_nil))
			end

		elseif data == (CBOXPARAMS["BRANDPREFIX"] .. "bridge?GET ALLS") then

			-- invia dati dinamici
			if (fsize("/tmp/alivedata.json")>0) then
				payload = readfile("/tmp/alivedata.json")
				jdata = cjson.decode(payload)
				jdata['INFO']['CMD'] = "GET ALLS"
				-- Added on bridge to be cross-compatible with GET ALLS request
				assert(udp:sendto(cjson.encode(jdata), msg_or_ip, port_or_nil))
			end

		end
    end
    socket.sleep(0.1)
end

udp:close()
print "bye"