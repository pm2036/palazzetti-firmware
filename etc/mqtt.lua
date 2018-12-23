#!/usr/bin/lua

dofile "/etc/main.lib.lua"
dofile "/etc/param.lib.lua"

local f, f2, cmd, output, completecmd, fifoloop, startTime, filename, filename_hash

local url
local words = {}
local CONNID = ""
local HAVETOREBOOT = false
local SYSTEMUPGRADE = false
local OTAUPGRADE = false


i=0
-- reset all previous tasks
os.execute("kill -9 `pgrep -f mqtt_mainloop.lua` 2> /dev/null")
os.execute("killall -s 9 mosquitto_sub 2> /dev/null")
os.execute("killall -s 9 mosquitto_pub 2> /dev/null")

os.execute("rm -f " .. CBOXPARAMS["MQTT_RXFIFO"])
os.execute("mkfifo " .. CBOXPARAMS["MQTT_RXFIFO"])

os.execute("rm -f " .. CBOXPARAMS["MQTT_TXFIFO"])
os.execute("mkfifo " .. CBOXPARAMS["MQTT_TXFIFO"])

os.execute("rm -f /tmp/*mqtttmp 2> /dev/null")

-- reset main loop timer
CBOXPARAMS["MQTT_TS_ACTIVITY"] = getTS("sec")

function checkCmd(strcmd, cmd)
	return string.upper(string.sub(strcmd, 0, string.len(cmd)))==cmd
end

if (CBOXPARAMS["MAC"]=="") then
	CBOXPARAMS["MAC"]=readfline("/etc/macaddr")
	writejsonpar("MAC", CBOXPARAMS["MAC"])
end
print("my MAC is:" .. CBOXPARAMS["MAC"])


-- save sample time in to tmp file
writeinfile("/tmp/MQTT_SAMPLETIME", CBOXPARAMS["MQTT_SAMPLETIME"])

while true do
	output = trim(shell_exec("ps | grep [mosqui]tto_sub"))
	if output==nil or output=='' then
		-- mqtt not working!
		i = i + 1
		if i>table.getn(CBOXPARAMS["MQTT_BROKER"]) then i=1 end

		CURRENT_BROKER = CBOXPARAMS["MQTT_BROKER"][i]

		if file_exists("/etc/aws-thing-client-id.prefix") then
			print("Start subscriber")
			mqttsub(CURRENT_BROKER)
		else
			-- try to auto-enroll
			if (checkInternet()==true) then
				vprint("Try to enroll...")
				syslogger("MQTT", "awsenroll")
				os.execute("lua /etc/awsenroll.lua")
			else
				sleep(30)
			end
		end

	else
		-- ----------------------------------------
		-- ----------------------------------------
		-- mqtt ONLINE!

		-- restart mqtt_mainloop
		print("restart mqtt_mainloop")
		os.execute("kill -9 `ps | grep [mqtt_]mainloop.lua  | awk '{print $1}'` 2>/dev/null")

		os.execute("lua /etc/mqtt_mainloop.lua " .. CURRENT_BROKER .. " &")

		f = io.open(CBOXPARAMS["MQTT_RXFIFO"])
		fifoloop = true
		while fifoloop do
			os.execute("cp /dev/null /tmp/err")

			-- print("HAVETOREBOOT: " .. tostring(HAVETOREBOOT))
			if (HAVETOREBOOT==true) then
				print("Rebooting..")
				syslogger("MQTT", "reboot")
				os.execute("reboot")
			end

			if (SYSTEMUPGRADE==true) then
				print("System upgrading.. " .. filename)
				os.execute("rm /etc/macaddr")
				os.execute("sysupgrade -v /tmp/" .. filename .. "&")
				os.execute("/etc/init.d/plzwatchdog stop")
			end

			-- print("fifoloop...")
			output = f:read("*line")
			if (output == nil) then break end
			if (output=="kill mqtt") then
				fifoloop = false
				break
			end

			-- ----------------------------------------
			-- ----------------------------------------
			-- mqtt packet received!
			-- print(output)

			-- ----------------------------------------
			-- ----------------------------------------
			-- in case, extract CONNID
			words = {}
			CONNID = ""
			for token in string.gmatch(output, "[^#]+") do
			   table.insert(words, token)
			end
			if (tonumber(#words)==2) then
				CONNID = words[1]
				output = words[2]
			end

			completecmd = output
			-- ----------------------------------------
			-- print(CONNID)
			vprint(completecmd)

			-- -----------------------------
			-- report mqtt activity
			CBOXPARAMS["MQTT_TS_ACTIVITY"] = getTS("sec")

			os.execute("rm -f /tmp/*jouttmp")
			outputJsonFile = gettmpfile("jouttmp")
			syslogger("MQTT", output)

			if (checkCmd(completecmd, "MQT")) then
				-- -----------------------------
				-- specific MQTT commands
				-- -----------------------------
				local subcmd = string.sub(output, string.len("MQT ")+1)

				if (checkCmd(subcmd,"SAMP")) then
					-- MQT SAMP
					-- change sample rate
					local samplerate = tonumber(string.sub(subcmd, string.len("SAMP ")))

					if (samplerate ~= nil) and (samplerate>0) then
						writejsonpar("MQTT_SAMPLETIME", samplerate)
						writeinfile ("/tmp/MQTT_SAMPLETIME", samplerate)
						output = getOKJson(completecmd)
					else
						output = getERRORJson(completecmd, "PARSER_ERROR")
					end

				elseif (checkCmd(subcmd,"KILL")) then
					-- MQT KILL
					-- MQTT KILL services
					local keepalive = trim(string.sub(subcmd, string.len("KILL ")))
					writejsonpar("MQTT_ENABLED", 0)
					HAVETOREBOOT=true
					output = getOKJson(completecmd)

				elseif (checkCmd(subcmd,"KEPS")) then
					-- MQT KEPS
					-- Change keepalive SUBSCRIBER parameter
					local keepalive = trim(string.sub(subcmd, string.len("KEPS ")))
					writejsonpar("MQTT_KEEPALIVE_SUB", keepalive)
					os.execute("kill -9 `pgrep -f mqtt_mainloop.lua` 2> /dev/null")
					output = getOKJson(completecmd)

				elseif (checkCmd(subcmd,"KEPP")) then
					-- MQT KEPP
					-- Change keepalive PUBLISHER parameter
					local keepalive = trim(string.sub(subcmd, string.len("KEPP ")))
					writejsonpar("MQTT_KEEPALIVE_PUB", keepalive)
					os.execute("kill -9 `pgrep -f mqtt_mainloop.lua` 2> /dev/null")
					output = getOKJson(completecmd)

				elseif (checkCmd(subcmd,"REBT")) then
					-- MQT REBT
					-- reboot system
					HAVETOREBOOT=true
					output = getOKJson(completecmd)

				elseif (checkCmd(subcmd,"SHEL")) then
					-- MQT SHEL
					-- Shell tunneling
					--[[
					local cmd = string.sub(subcmd, string.len("SHEL "))
					output = shell_exec(cmd)
					--]]
				elseif (checkCmd(subcmd,"GPTC")) then
					-- MQT GPTC
					-- Get patches list
					output = "{\"INFO\":{\"RSP\":\"OK\",\"TS\":\"" .. os.date('%Y-%m-%d %H:%M:%S') .. "\"}"
					if file_exists("/etc/patch") then
						output = output .. ", \"Patches\":{"
						ln = 1
						for line in io.lines("/etc/patch") do
							output = output .. "\"P" .. ln .. "\":\"" .. line .. "\","
							ln = ln + 1
						end
						output = output:sub(1, -2)
						output = output .. "}"
					end
					output = output .. "}"

				elseif (checkCmd(subcmd,"OTAU")) then

					url = string.sub(subcmd, string.len("OTAU "))

					if OTAUPGRADE == false then

						OTAUPGRADE = true

						filename = "firmware.bin"
						filename_hash = "firmware.md5"

						local remotefilename=trim(shell_exec("ash /etc/myboard.sh"))
						if remotefilename=="miniembplug" or remotefilename=="omni-plug" then
							remotefilename="plug"
						else
							remotefilename="unplug"
						end

						-- Cleanup previous Firmware
						os.execute("rm -f /tmp/".. filename)
						-- Cleanup previous MD5 Firmware
						os.execute("rm -f /tmp/".. filename_hash)
						-- Download new Firwmare
						os.execute("wget --ca-certificate=/etc/cacerts.pem -O /tmp/".. filename .. " " .. ((url~=nil and url~="") and trim(url) or CBOXPARAMS["OTA-UPGRADE-URL"]) .. "_".. remotefilename ..".bin 2>/dev/null")
						-- Download new Firmware Content Hash for Validation
						os.execute("wget --ca-certificate=/etc/cacerts.pem -O /tmp/".. filename_hash .. " " .. ((url~=nil and url~="") and trim(url) or CBOXPARAMS["OTA-UPGRADE-URL"]) .. "_".. remotefilename ..".md5 2>/dev/null")

						if (file_exists("/tmp/" .. filename)) then

							vprint("OTA OK!")

							output = getOKJson(completecmd)

							os.execute("sleep 5 && ash /etc/upgrade.sh &")
						else
							OTAUPGRADE = false
							output = getERRORJson(completecmd, "OTA FAILED")
						end
					else
						output = getOKJson(completecmd)
					end

				elseif (checkCmd(subcmd,"PTCH")) then
					-- MQT PTCH
					-- Patch Application

					url = string.sub(subcmd, string.len("PTCH "))

					for token in string.gmatch(url, "[^/]+") do
						table.insert(words, token)
					end
					filename = words[#words]
					filetmp = "/tmp/" .. filename

					print("Patch Application .. ")
					os.execute("curl -sfk -o " .. filetmp .. " " .. url)

					if (file_exists("/tmp/" .. filename)) then
						-- crypted patch
						os.execute("rm /tmp/patchresultok 2>/dev/null")
						os.execute("echo `cat /etc/key`" .. filename .. " > /tmp/key")
						cmd = "openssl aes-256-cbc -d -in " .. filetmp .. " -out " .. filetmp .. ".dec -pass file:/tmp/key" ..
							" && tar zvxf " ..filetmp .. ".dec -C /" ..
							" && echo \"" .. filename .. " " .. os.date('%Y-%m-%d %H:%M:%S') .. "\" >> /etc/patch" ..
							" && touch /tmp/patchresultok"
						vprint(cmd)
						os.execute(cmd)
						--

						os.execute("rm /tmp/" .. filename)
						if (file_exists("/tmp/patchresultok")) then
							vprint("Patch OK!")
							output = getOKJson(completecmd, "Patch OK!")
							HAVETOREBOOT = true
						else
							vprint("Patch FAILED!")
							output = getERRORJson(completecmd, "Patch FAILED!")
						end
						os.execute("rm /tmp/patchresultok")
					else
						output = getERRORJson(completecmd, "Patch FAILED!")
					end

				elseif (checkCmd(subcmd,"SYSU")) then
					-- MQT SYSU
					-- System upgrade

					url = string.sub(subcmd, string.len("SYSU "))

					for token in string.gmatch(url, "[^/]+") do
						table.insert(words, token)
					end
					filename = words[#words]

					vprint("System upgrade .. " .. "curl -sfk -o /tmp/" .. filename .. " -u " .. PATCHSRV_LOGIN .. " " .. url)
					os.execute("curl -sfk -o /tmp/" .. filename .. " -u " .. PATCHSRV_LOGIN .. " " .. url)

					if (file_exists("/tmp/" .. filename)) then
						output = getOKJson(completecmd, "SYSU OK!")
						SYSTEMUPGRADE = true
					else
						output = getERRORJson(completecmd, "SYSU FAILED!")
					end

				elseif (checkCmd(subcmd,"SYSC")) then
					-- MQT SYSC
					-- System commands

					cmd = string.sub(subcmd, string.len("SYSC "))
					syscmd = "lua /www/cgi-bin/syscmd.lua \"" .. trim(cmd) .. "\" 2>/dev/null"
					output = shell_exec(syscmd)

				elseif (checkCmd(subcmd,"FTPC")) then
					-- MQT FTPC
					-- FTP commands
					url = string.sub(subcmd, string.len("FTPC "))

					for token in string.gmatch(url, "[^/]+") do
						table.insert(words, token)
					end
					filename = trim(words[#words])
					vprint("FTP download .. ")
					cmd = "curl -sfk -o /tmp/" .. filename .. " -u " .. FTPLOGIN .. " \"" .. FTPURL .. filename .. "\""
					os.execute(cmd)

					if (file_exists("/tmp/" .. filename)) then
						cmd = "tar zxf /tmp/" .. filename .. " -C / 2> /tmp/err"
						os.execute(cmd)
						if (fsize("/tmp/err")==0) then
							os.execute("echo \"" .. filename .. "\" >> /etc/patch")
							os.execute("rm /tmp/" .. filename)
							output = getOKJson(completecmd, "FTPC OK!")
							HAVETOREBOOT = true
						else
							output = getERRORJson(completecmd, "FTPC FAILED!")
						end
					else
						output = getERRORJson(completecmd, "FTPC FAILED!")
					end

				elseif (checkCmd(subcmd,"UPLD")) then

					-- MQT UPLD
					-- Upload commands
					local params = {}
					params_str = string.sub(subcmd, string.len("UPLD "))
					for token in string.gmatch(params_str, "[^%s]+") do
						table.insert(params, token)
					end
					mountpoint = trim(shell_exec("cat /proc/mounts | grep \"/mnt/sd\" | awk '{print $2}'"))

					if (trim(params[1]) == "dropbox") then
						print("Dropbox upload .. ")
						cmd = "curl -k -H \"Authorization: Bearer " .. trim(params[2]) .. "\" https://api-content.dropbox.com/1/files_put/auto/ -T " .. mountpoint .. "/" .. trim(params[3]) .. " 2> /tmp/err"

						os.execute(cmd)
						if (fsize("/tmp/err")==0) then
							output = getOKJson(completecmd)
						else
							output = getERRORJson(completecmd, "UPLD FAILED")
						end

					else
						output = getERRORJson(completecmd, "UPLD FAILED", "PARSER_ERROR")
					end

				elseif (checkCmd(subcmd,"CSVL")) then

					-- MQT CSVL
					-- CSV list command

					file_size = {}
					file_name = {}
					for fl in io.popen("ls  -l /mnt/sda1/*.csv | awk '{print $5}'"):lines() do
						table.insert(file_size, fl)
					end

					for fl in io.popen("ls  -l /mnt/sda1/*.csv | awk '{print $9}' | xargs -n 1 basename"):lines() do
						table.insert(file_name, fl)
					end

					output = "{\"INFO\":{\"RSP\":\"OK\",\"TS\":\"" .. os.date('%Y-%m-%d %H:%M:%S') .. "\"}, \"filelist\":["

					for i=1,#file_size,1 do
						output = output .. "{\"name\":\"" .. file_name[i] .. "\",\"size\":" .. file_size[i] .. "},"
					end

					output = output:sub(1, -2) .. "]}"


				else
					output = getERRORJson(completecmd, "", "PARSER_ERROR")
				end

				-- write outputJsonFile
				writeinfile(outputJsonFile, output)

			else
				-- --------------------------------
				-- stove commands
				-- print("bridge command: " .. output)
				sendmsg(completecmd, outputJsonFile)

				if (string.upper(output)=="GET ALLS") then
					-- if somebody asks for a "GET ALLS", reset logging loop timer
					CBOXPARAMS["MQTT_TS_ACTIVITY"] = getTS("sec")
				end

			end

			-- -----------------------------------------
			-- add GUID
			JOUT = readfline(outputJsonFile)

			JOUT = JOUT:gsub("({\"INFO\":{)", "{\"INFO\":{\"GUID\":\"" .. CONNID .. "\",")
			myts = "\"TS\":" .. getTS("sec") .. ","
			JOUT = JOUT:gsub("\"DATA\":{", "\"DATA\":{" .. myts)
			vprint("***** JOUT: \n" .. JOUT)
			writeinfile(outputJsonFile, JOUT)
			i, j = JOUT:find("\"DATA\":{")
			if (j==nil) then
				print ("Communication error")
			else
				--[[
				-- b64(gzip(DATA))
				writeinfile(outputJsonFile, "{" .. JOUT:sub(j+1, JOUT:len()-2) .. "}")
				writeinfile(outputJsonFile, JOUT:sub(0, j-1) .. "\"" .. encdata(outputJsonFile) .. "\"}\n")
				]]--

				-- transmit mqtt response
				vprint("transmit mqtt response:  \n" .. readfline(outputJsonFile))

			end

			--  persistent publisher
			mqttpub(CURRENT_BROKER, "persistent", outputJsonFile, true)

		end
		f:close()

		sleep(1)
	end
end
