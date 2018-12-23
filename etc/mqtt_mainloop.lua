#!/usr/bin/lua

dofile "/etc/main.lib.lua"
dofile "/etc/param.lib.lua"

local output, i, j
local USER, PASSWD
local firstError=true
local isError=false

local currentStatus
local lastStatus=-1

local steps=CBOXPARAMS["MQTT_TELEMETRY_STEPS"]

CURRENT_BROKER 	= arg[1]

-- ----------------------------------------
-- ----------------------------------------
-- Main logging loop

CBOXPARAMS["MQTT_TS_ACTIVITY"] = getTS("sec")
CBOXPARAMS["MQTT_TS_SAMPLE"] = getTS("sec")
os.execute("kill -9 $(pidof tail)")

local count=1

while true do

	-- -------------------------------
	-- check if there is no mqtt activity
	vprint("time diff before kill persistent pub " .. os.time()-tonumber(CBOXPARAMS["MQTT_TS_ACTIVITY"]))
	if (os.time()-tonumber(CBOXPARAMS["MQTT_TS_ACTIVITY"])) > tonumber(CBOXPARAMS["MQTT_KEEPPERS_TIME"]) then

		if (trim(shell_exec("ps | grep \"[tail] -f " .. CBOXPARAMS["MQTT_TXFIFO"] .. "\""))~="") then
			vprint("kill persistent pub..")
			os.execute("kill -9 `ps | grep \"[tail] -f /tmp/mqtt_fifotx\" | awk '{print $1}'`")
		end
		CBOXPARAMS["MQTT_TS_ACTIVITY"] = getTS("sec")
	end


	if (os.time()-tonumber(CBOXPARAMS["MQTT_TS_SAMPLE"])) > tonumber(readfline("/tmp/MQTT_SAMPLETIME")) then
		vprint("is time to get sample..")
		outputJsonFile = gettmpfile("mqtttmp")
		sendmsg("GET ALLS", outputJsonFile)
		
		-- writeinfile(outputJsonFile, readMTConnect())

		-- verify type of response
		output = readfline(outputJsonFile)
		CBOXPARAMS["MQTT_TS_SAMPLE"] = getTS("sec")
		if (output==nil or string.find(output, "\"RSP\":\"OK\"")==nil) then
			-- in error
			isError=true
			-- print("isError=true")
		else
			isError=false
			firstError=true

			-- print("isError=false firstError=true")
			--[[
			if (SENDALERTEMAIL) then

				-- ----------------------------------------
				-- ----------------------------------------
				-- Send alert email FEATURE

				-- get current status
				currentStatus = tonumber(string.match(shell_exec("cat " .. outputJsonFile .. " | grep \"STATUS\""), "%d+"))
				if (lastStatus ~= currentStatus) then
					lastStatus = currentStatus
					if (currentStatus >= 200) then
						-- generate alert email
						gmailSendmail("/tmp/mail.txt")
					end
				end
			end
			--]]

		end


		if firstError or (not isError) then
			if (CBOXPARAMS["MQTT_TX_STATUS"]) then

				-- append to telemetry file

				datastep=readfline(outputJsonFile)
				vprint("datastep: " .. datastep)
				i, j = datastep:find("\"DATA\":{")
				if (i~=nil) then
					-- valid datastep
					if count==1 then
						-- first step. create header
						vprint("create header to telemetry file")
						mainheader=datastep:sub(0, j-1)
						writeinfile(CBOXPARAMS["mainJsonHeaderFile"], mainheader)
						os.execute("rm -f " .. CBOXPARAMS["mainJsonDataFile"])
					end

					vprint("append to telemetry file")
					myts = "\\\"TS\\\":\\\"" .. getTS("sec") .. "\\\","
					datastep = "{" .. myts .. datastep:sub(j+1, datastep:len()-2):gsub("\"", "\\\"") .. "}"
					os.execute("echo -n \"" .. datastep .. "\" >> " .. CBOXPARAMS["mainJsonDataFile"])

					if count<steps then
						os.execute("echo -n \",\" >> " .. CBOXPARAMS["mainJsonDataFile"])

						count = count + 1
					else

						writeinfile(CBOXPARAMS["mainJsonDataFile"], "["..readfline (CBOXPARAMS["mainJsonDataFile"]).."]")
						vprint(readfline(CBOXPARAMS["mainJsonDataFile"]))
						writeinfile(outputJsonFile, readfline(CBOXPARAMS["mainJsonHeaderFile"]) .. "\"" .. encdata(CBOXPARAMS["mainJsonDataFile"]) .. "\"}\n")

						-- transmit mqtt
						vprint("Main logging loop: transmit mqtt...")
						vprint(readfline(outputJsonFile))

						if (trim(shell_exec("ps | grep \"[tail] -f " .. CBOXPARAMS["MQTT_TXFIFO"] .. "\""))~="") then
							-- is persistent publisher
							vprint("mainloop TX on persistent mosquitto_pub .. ")

							vprint("cat " .. outputJsonFile .. " > " .. CBOXPARAMS["MQTT_TXFIFO"])
							os.execute("cat " .. outputJsonFile .. " > " .. CBOXPARAMS["MQTT_TXFIFO"])
						else
							-- asynchronous publisher
							vprint("mainloop TX on asynchronous mosquitto_pub .. ")
							mqttpub(CURRENT_BROKER, "", outputJsonFile)
						end

						count = 1
					end
				end
				-- not valid datastep

			end

			CBOXPARAMS["MQTT_TS_MAINLOOP"] = getTS("sec")
			if isError then
				firstError=false
			end
		end

		os.execute("rm " .. outputJsonFile)
	end
	sleep(10)
end