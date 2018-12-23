#!/usr/bin/lua
require "socket"
dofile "/etc/maindef.lua"

function readMTConnect()
	local sample = shell_exec("curl -s -m 4 " .. CBOXPARAMS["MTCONNECT_HOST"] .. ":" .. CBOXPARAMS["MTCONNECT_PORT"])
	local ts=""

	local jsonout = {}
	jsonout["INFO"] = {}
	jsonout["INFO"]["CMD"] = "GET ALLS"
	jsonout["INFO"]["TS"] = getTS("sec")
	jsonout["INFO"]["RSP"] = "OK"

	local dataout = {}
	dataout["STATUS"] = 0
	dataout["VER"] = 0
	dataout["IPPOR"] = CBOXPARAMS["MTCONNECT_PORT"]
	dataout["IPADD"] = CBOXPARAMS["MTCONNECT_HOST"]

	for line in sample:gmatch("[^\r\n]+") do
		mytable=line:split("|")
		if (ts=="") then
			ts=mytable[1]
		end

		if (mytable[1]==ts) then
			local idx
			for i = 1, #mytable do
				mystr = mytable[i]

				if mystr:find("^execution%d+$") then idx=mystr:match("%d+$") i=i+1 dataout["EX" .. idx]=mytable[i]
				elseif mystr:find("^program%d+$") then idx=mystr:match("%d+$") i=i+1 dataout["PRG" .. idx]=mytable[i]
				elseif mystr:find("^block%d+$") then idx=mystr:match("%d+$") i=i+1 dataout["BLC" .. idx]=mytable[i]
				elseif mystr:find("^part_count%d+$") then idx=mystr:match("%d+$") i=i+1 dataout["PAC" .. idx]=mytable[i]

				end

			end
		end
	end

	jsonout["DATA"] = dataout

	return cjson.encode(jsonout)
end

function mqttsub(broker)
	local tenantid, clientid

	tenantid = readfline("/etc/aws-thing-client-id.prefix")
	clientid = tenantid .. "." .. CBOXPARAMS["MAC"] .. "." .. getTS("sec")

	cmd="mosquitto_sub -t " .. CBOXPARAMS["MAC"] .. "/C -t " .. tenantid .. " -i " .. clientid .. " -k " .. CBOXPARAMS["MQTT_KEEPALIVE_SUB"] .. " --will-topic " .. CBOXPARAMS["MAC"] .. "/LWT --will-payload 'CIAO' --cert /etc/aws-thing.pem --key /etc/aws-thing-key.prv --cafile /etc/aws-thing-rootCA.crt -h " .. broker .. " -p 8883 " .. " > " .. CBOXPARAMS["MQTT_RXFIFO"] .. " &"

	print("Listening from " .. broker)
	vprint(cmd)
	syslogger("MQTT", "mqttsub " .. broker .. " " .. CBOXPARAMS["MAC"] .. " " .. tenantid)
	os.execute(cmd)
end

function mqttpub(broker, pubtype, outputJsonFile, encrypted)

	local cmd=""
	local clientid = readfline("/etc/aws-thing-client-id.prefix") .. "." .. CBOXPARAMS["MAC"] .. "." .. getTS("sec")
	local mqttopic = "D"

	if pubtype=="notification" then
		mqttopic = "N"
	end

	if encrypted==true then
		JOUT=readfline(outputJsonFile)
		i, j = JOUT:find("\"DATA\":{")
		-- b64(gzip(DATA))
		writeinfile(outputJsonFile, "{" .. JOUT:sub(j+1, JOUT:len()-2) .. "}")
		writeinfile(outputJsonFile, JOUT:sub(0, j-1) .. "\"" .. encdata(outputJsonFile) .. "\"}\n")

	end

	if (pubtype == "persistent") then
		local output = trim(shell_exec("ps | grep \"[tail] -f " .. CBOXPARAMS["MQTT_TXFIFO"] .. "\""))

		if (output=="" or output==nil) then
			-- start persistent publisher
			print("start persistent mosquitto_pub .. ")
			-- open socket mqttpub
			cmd="tail -f " .. CBOXPARAMS["MQTT_TXFIFO"] .. " | mosquitto_pub -t " .. CBOXPARAMS["MAC"] .. "/D "
			if (CBOXPARAMS["MQTT_VERBOSE"]==1) then cmd = cmd .. " -d " end
			cmd = cmd .. "-i " .. clientid .. " -k " .. CBOXPARAMS["MQTT_KEEPALIVE_PUB"] .. " --cert /etc/aws-thing.pem --key /etc/aws-thing-key.prv --cafile /etc/aws-thing-rootCA.crt -h " .. broker .. " -p 8883 -l &"
			vprint(cmd)
			os.execute(cmd)
		end

		CBOXPARAMS["MQTT_TS_ACTIVITY"] = getTS("sec")

		-- enqueue in fifo
		os.execute("cat " .. outputJsonFile .. " > " .. CBOXPARAMS["MQTT_TXFIFO"])
		return true
	else
		cmd="mosquitto_pub -t " .. CBOXPARAMS["MAC"] .. "/" .. mqttopic .. " -i " .. clientid .. " --cert /etc/aws-thing.pem --key /etc/aws-thing-key.prv --cafile /etc/aws-thing-rootCA.crt -h " .. broker .. " -p 8883 -f " .. outputJsonFile
		os.execute(cmd)
	end

	vprint(cmd)

end

function writejsonpar(key, value)
	CBOXPARAMS[key] = value
	writeinfile(CBOXPR_FILE, cjson.encode(CBOXPARAMS))
	writeinfile(CBOXPR_TMPFILE, cjson.encode(CBOXPARAMS))
end

function vprint(msg)
	if (CBOXPARAMS["MQTT_VERBOSE"]==1) then print(msg) end
end

