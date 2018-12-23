cli=false
if (arg~=nil) then
	-- cli mode
	cli=true
	dofile "/etc/main.lib.lua"
	cjson = require "cjson"
	qstring = parseurl(arg[1])
end

function getOutput()

	-- 26/01/2018 - Support "command" to retrofit compatibility with Cloud Architecture (Mobile App purpose)
	if (qstring==nil) then return getERRORJson("nil qstring") end
	qstring.cmd = (qstring.cmd==nil and qstring.command or qstring.cmd):lower()

	exec("echo \"" .. cjson.encode(qstring) .. "\" >> /tmp/log_lua.txt")

	if (qstring.cmd==nil) then
		return getERRORJson("nil cmd")
	end

	-- -------------------------------
	-- nwdata
	if (qstring.cmd=="nwdata") then
		jdata = cjson.decode(sendmsg("GET STAT"))
		if (jdata.INFO.RSP ~= "OK") then
			-- got timeout or error!
			jdata["DATA"] = cjson.decode("{" .. shell_exec("ash /etc/nwdata.sh") .. "}")
			jdata["DATA"]["APLCONN"] = 0;
		else
			jdata = cjson.decode(sendmsg("GET STDT"))
			jdata['DATA']['APLCONN'] = 1;
		end
		return (cjson.encode(jdata))

	-- -------------------------------
	-- setwifi
	elseif (qstring.cmd=="applywifi") then

		if file_exists("/tmp/apply_netconfig.sh") then
			exec("ash /tmp/apply_netconfig.sh &")
			return getOKJson(qstring.cmd, "Network configuration are going to apply.")
		else
			return getERRORJson(qstring.cmd, "Network configuration apply failed.")
		end

	-- -------------------------------
	-- setwifi
	elseif (qstring.cmd=="setwifi") then

			if (empty(qstring.WMODE)) then return getERRORJson("empty WMODE") end

			if (qstring.WMODE=='default') then
				os.execute("ash /etc/setwifi.sh default")
				return getOKJson(qstring.cmd)

			elseif (qstring.WMODE=='off') then
				shell_exec("ash /etc/setwifi.sh off")
				return getOKJson(qstring.cmd)
			end

			if (empty(qstring.WSSID)) then return getERRORJson(qstring.cmd,"empty WSSID") end


			-- set wifi
			if (not empty(qstring.WIFI_KEY)) then
				qstring.WIFI_KEY = qstring.WIFI_KEY:gsub('($)', '\\$')
			end

			if (qstring.WMODE=='ap') then
				exec("ash /etc/setwifi.sh ap \"" .. qstring.WSSID .. "\" " .. qstring.WENC .. " " .. qstring.WCH .. " \"" .. qstring.WIFI_KEY .. "\"")
				return getOKJson(qstring.cmd, "wifi ap ok")
			elseif (qstring.WMODE=='teststa' or qstring.WMODE=='sta') then

				if (empty(qstring.WPR)) then return getERRORJson(qstring.cmd,"empty WPR") end

				if (empty(qstring.WIFI_KEY)) then
					qstring.WIFI_KEY = '-'
				end

				local apply_background = (qstring.WMODE=='teststa' and "sleep 2 && " or "")

				if (qstring.WPR=='dhcp') then
					exec(apply_background .. "ash /etc/setwifi.sh " .. qstring.WMODE .. " \"" .. qstring.WSSID .. "\" " .. qstring.WENC .. " \"" .. qstring.WIFI_KEY .. "\" " .. qstring.WPR .. (apply_background:len() > 1 and " &" or ""))
					return getOKJson(qstring.cmd, "wifi dhcp ok")
				elseif (qstring.WPR=='static') then
					exec(apply_background .. "ash /etc/setwifi.sh " .. qstring.WMODE .. " \"" .. qstring.WSSID .. "\" " .. qstring.WENC .. " \"" .. qstring.WIFI_KEY .. "\" " .. qstring.WPR .. " " .. qstring.WADR .. " " .. qstring.WMSK .. " " .. qstring.WGW .. (apply_background:len() > 1 and " &" or ""))
					return getOKJson(qstring.cmd, "wifi static ok")
				else
					return getERRORJson(qstring.cmd,"unrecognized WPR")
				end
			else
				return getERRORJson(qstring.cmd,"unrecognized WMODE")
			end

	-- -------------------------------
	-- wifiscan
	elseif (qstring.cmd=="wifiscan") then

			-- parse wifi list devices
			wliststr = shell_exec("iwinfo wlan0 scan");
			wliststr = wliststr:gsub("%\n\n", "#")
			result = {}

			local jsonout = {}
			jsonout["SUCCESS"] = true

			jsonout["INFO"] = {}
			jsonout["INFO"]["CMD"] = cmd
			jsonout["INFO"]["TS"] = getTS()
			jsonout["INFO"]["RSP"] = "OK"

			local i=1

			for block in wliststr:gmatch("[^#]+") do
				ssid=block:match('%b""')

				-- Hidden Network doesn't have a SSID
				if (ssid~=nil) then

					ssid=ssid:sub(2, ssid:len()-1)

					channel = block:match('Channel: (%d+)')
					signal = block:match('Signal: (-%d+)')
					enc = block:match('Encryption: (%w+)')

					if (enc=="WPA") then
						enc = "psk"
					elseif (enc=="WPA2") then
						enc = "psk2"
					elseif (enc=="WEP") then
						enc = "wep"
					else
						enc = "none"
					end

					result[i] = {}
					result[i]["essid"] = ssid
					result[i]["channel"] = channel
					result[i]["signal"] = signal
					result[i]["enc_type"] = enc

					i = i + 1
				end
			end

			jsonout["DATA"] = {}
			jsonout["DATA"]["WLIST"] = result

			return (cjson.encode(jsonout))

	-- -------------------------------
	-- seteth
	elseif (qstring.cmd=="seteth") then
			if (empty(qstring.EPR)) then return getERRORJson(qstring.cmd,"empty EPR") end

			if (qstring.EPR=="dhcp") then
				exec("ash /etc/seteth.sh dhcp")
				return getOKJson(qstring.cmd, "seteth dhcp ok")

			elseif (qstring.EPR=="static") then
				if (empty(qstring.EMSK)) then return getERRORJson(qstring.cmd,"empty EMSK") end
				if (empty(qstring.EADR)) then return getERRORJson(qstring.cmd,"empty EADR") end
				if (empty(qstring.EGW)) then return getERRORJson(qstring.cmd,"empty EGW") end

				exec("ash /etc/seteth.sh static " .. qstring.EMSK .. " " .. qstring.EADR .. " " .. qstring.EGW)
				return getOKJson(qstring.cmd, "seteth static ok")
			else
				return getERRORJson(qstring.cmd,"unrecognized EPR")
			end


	-- -------------------------------
	-- startlogger
	elseif (qstring.cmd=="startlogger") then
		DEFAULT_LOGGERSPLITSEC = 604800 -- 1 week
		exec("lua /etc/syslogger.lua &")
		exec("echo \"" .. getTS("sec") .. "\" > /tmp/loggerTS")

		if (readfile('/tmp/loggersplitsec')=="") then
			writeinfile("/tmp/loggersplitsec", DEFAULT_LOGGERSPLITSEC)
		end

		return getOKJson(qstring.cmd, "startlogger ok")

	-- -------------------------------
	-- stoplogger
	elseif (qstring.cmd=="stoplogger") then

		exec("kill `ps | grep [/etc/log]ger | awk '{print $1}' | head -n1`")
		exec("rm /tmp/seqcurrent")
		return getOKJson(qstring.cmd, "stoplogger ok")

	-- -------------------------------
	-- logger
	elseif (qstring.cmd=="logger") then

			local out = cjson.decode(sendmsg("GET ALLS"))
			local ts = getTS("sec")
			local row = getTS() .. ";"
			local title = "timestamp;"
			for k,v in pairs(out.DATA) do
				title = title .. k .. ";"
				row = row .. v .. ";"
			end

			-- check if is splitperiod
			loggersplitsec = readfile("/tmp/loggersplitsec")
			if (loggersplitsec:len()>0) then
				loggersplitsec = tonumber(loggersplitsec)
				local timeFirst = tonumber(readfile("/tmp/loggerTS"))
				local diff = (ts-timeFirst)

				if (diff > loggersplitsec) then
					-- stop logger
					exec("kill `ps | grep [/etc/log]ger | awk '{print $1}' | head -n1`")
					-- start logger
					os.execute("lua /etc/syslogger.lua >/dev/null 2>/dev/null &")
					writeinfile("/tmp/loggerTS", ts)
				end
			end

			return row
	-- -------------------------------
	-- loggerhead
	elseif (qstring.cmd=="loggerhead") then
			local out = cjson.decode(sendmsg("GET ALLS"))
			local ts = getTS("sec")
			local row = getTS() .. ";"
			local title = "timestamp;"

			--[[
			local fields={}
			if (file_exists("/www/fields.csv")) then
				-- Open file for read
				local fh, local err = io.open("/www/fields.csv", "r")

				-- line by line
				while true do
					line = fh:read()
					if line == nil then break end
					fields
				end
			end
			--]]

			if (out.DATA==nil) then return "" end

			for k,v in pairs(out.DATA) do
				title = title .. k .. ";"
				row = row .. v .. ";"
			end

			-- check if is splitperiod
			loggersplitsec = readfile("/tmp/loggersplitsec")
			if (loggersplitsec:len()>0) then
				loggersplitsec = tonumber(loggersplitsec)
				local timeFirst = tonumber(readfile("/tmp/loggerTS"))
				local diff = (ts-timeFirst)

				if (diff > loggersplitsec) then
					-- stop logger
					exec("kill `ps | grep [/etc/log]ger | awk '{print $1}' | head -n1`")
					-- start logger
					os.execute("lua /etc/syslogger.lua >/dev/null 2>/dev/null &")
					writeinfile("/tmp/loggerTS", ts)
				end
			end

			return title
	-- -------------------------------
	-- setloggersplit
	elseif (qstring.cmd=="setloggersplit") then
		if (empty(qstring.splitperiod)) then return getERRORJson(qstring.cmd,"empty splitsec") end
		-- splitperiod comes in days. have to save in seconds
		writeinfile("/tmp/loggersplitsec", qstring.splitperiod*86400)

		return getOKJson(qstring.cmd, "setloggersplit ok")

	-- -------------------------------
	-- eventlogger
	elseif (qstring.cmd=="eventlogger") then

		local tmpfile = os.tmpname()
		os.execute("logread -e SYSLOG > " .. tmpfile)

		jdata = {}
		jdata["TS"] = getTS("sec")
		jdata["LOGITEMS"] = {}

		for line in io.lines(tmpfile) do
			i, j = line:find(" user.notice SYSLOG: ")
			ts = line:sub(1, i-1)
			ts = trim(shell_exec("date -D \"" .. ts .. "\" +%s"))
			line = line:sub(j+1)
			i, j = line:find(" ")
			logtype = line:sub(1,i-1)
			msg = line:sub(j+1)
			jnewlog = {}
			jnewlog["LOGTS"] = ts
			jnewlog["LOGTYPE"] = logtype
			jnewlog["LOGMSG"] = msg
			table.insert(jdata["LOGITEMS"], jnewlog)

		end
		os.execute("rm " .. tmpfile)

		jdata = encstring(cjson.encode(jdata))
		-- Restarting log services will truncate logs circual buffer
		os.execute("/etc/init.d/log restart")

		return cjson.encode(getStandardJson("eventlogger", {LOGS=jdata}))

	-- -------------------------------
	-- delcsvfile
	elseif (qstring.cmd=="delcsvfile") then
		if (empty(qstring.csvfile)) then return getERRORJson(qstring.cmd,"empty csvfile") end

		exec("rm /mnt/sda1/"..qstring.csvfile)
		return getOKJson(qstring.cmd, "delcsvfile ok")

	-- -------------------------------
	-- dwlcsv
	elseif (qstring.cmd=="dwlcsv") then

		if (empty(qstring.csvfile)) then return getERRORJson(qstring.cmd,"empty csvfile") end

		-- download csv file
		myfile = "/mnt/sda1/"..qstring.csvfile
		if (not file_exists(myfile)) then return getERRORJson(qstring.cmd,"csvfile not exists") end
		local output = readfile(myfile)

		out = "Content-Description: File Transfer\r\n"
		out = out .. "Content-Disposition: attachment;filename=\""..qstring.csvfile.."\"\r\n"
		out = out .. "Expires: 0\r\n"
		out = out .. "Cache-Control: must-revalidate\r\n"
		out = out .. "Pragma: public\r\n"
		out = out .. "Content-Length: " .. output:len() .. "\r\n"
		out = out .. "Content-Type: application/octet-stream\r\n\r\n"
		out = out .. output

		return out

	-- -------------------------------
	-- gettimer
	elseif (qstring.cmd=="gettimer") then
		local jsonout = {}
			jsonout["SUCCESS"] = true

			jsonout["INFO"] = {}
			jsonout["INFO"]["CMD"] = cmd
			jsonout["INFO"]["TS"] = getTS("sec")
			jsonout["INFO"]["RSP"] = "OK"

			jsonout["DATA"] = {}
			jsonout["DATA"]["TIMER"] = encstring(cjson.encode(cjson.decode(readfile("/tmp/timer.json"))))

			return (cjson.encode(jsonout))
	-- -------------------------------
	-- settimer
	elseif (qstring.cmd=="settimer") then
		-- if (empty(qstring.data)) then return getERRORJson(qstring.cmd,"empty data") end
		if (empty(qstring.path)) then return getERRORJson(qstring.cmd,"empty path location") end
		if (file_exists(qstring.path) == false) then return getERRORJson(qstring.cmd,"writing stage file doesn't exists") end

		local jstatic = cjson.decode(readfile("/tmp/staticdata.json"))
		local jtimer = cjson.decode(decstring(readfile(qstring.path)))

		-- Update Timer Appliance Identifier
		jtimer["applid"] = ((jstatic~=nil and jstatic["DATA"]~=nil and jstatic["DATA"]["SPLMIN"]~=nil) and (jstatic["DATA"]["SPLMIN"] .. "_" .. jstatic["DATA"]["SPLMAX"]) or "")
		-- Try writing to Timer RAM file
		writeinfile("/tmp/timer.json", cjson.encode(jtimer))

		-- Cleanup file
		exec("rm -f /tmp/*settimer")

		-- If writing not succeded
		if (fsize("/tmp/timer.json") <= 0) then
			-- Restore previous situation
			exec("cp /etc/timer.json /tmp/timer.json")
			return getERRORJson(qstring.cmd,"Timer format is not valid. Please, try again.")
		end

		if (jstatic~=nil and jstatic["DATA"]~=nil and jstatic["DATA"]["ICONN"]~=nil) then
			-- Internet Connection not available
			if(jstatic["DATA"]["ICONN"] == 0) and (jtimer["last_edit"]~=nil) and (jtimer["last_edit"]~="") then 
				-- Set date as last edit date and transfer time to appliance
				shell_exec("date -s '" .. jtimer["last_edit"]:gsub("T", " ") .. "'")
				sendmsg("SET TIME")
			end
		end

		-- Store timer succesfully
		exec("cp /tmp/timer.json /etc/timer.json")

		-- *************** TO DO ***************
		-- Se manca connessione ad internet utilizzo il campo last-modified del jsontimer
		-- per forzare la data ed ora di sistema e della stufa
		-- Al reboot sarà attiva la procedura di sync dell'orologio tra stufa e cbox senza NTP



		return getOKJson(qstring.cmd, "settimer OK")

	-- -------------------------------
	-- update
	elseif (qstring.cmd=="getparams") then

		return (cjson.encode(cjson.decode(readfile("/etc/cboxparams.json"))))

	-- -------------------------------
	-- update
	elseif (qstring.cmd=="update") then

		if (qstring["FILE"]["filesize"]==0) then return getERRORJson(qstring.cmd,"filesize 0") end

		writeinfile("/tmp/key", trim(readfile("/etc/key")).." " .. qstring["FILE"]["filename"])

		--exec("openssl aes-256-cbc -d -in "..qstring["FILE"]["tmpfile"].." -out "..qstring["FILE"]["tmpfile"]..".dec -pass file:/tmp/key > /tmp/lualog")
		cmd="openssl aes-256-cbc -d -in "..qstring["FILE"]["tmpfile"].." -pass file:/tmp/key"
		local f = io.popen(cmd)
		chunk=f:read(1024)
		exec("rm "..qstring["FILE"]["tmpfile"])
		qstring["FILE"]["tmpfile"] = qstring["FILE"]["tmpfile"]..".dec"
		fdec = io.open(qstring["FILE"]["tmpfile"], "a")
		fdec:write(chunk)
		while true do
			chunk=f:read(1024)
			if (chunk == nil) then break end
			fdec:write(chunk)
		end
		f:close()
		fdec:close()

		if (shell_exec("sysupgrade -T "..qstring["FILE"]["tmpfile"]) == "") then
			-- AGGIORNAMENTO SYSTEM
			exec("/etc/init.d/plzwatchdog stop")
			exec("sysupgrade -n "..qstring["FILE"]["tmpfile"].."& ")
			--exec("rm "..qstring["FILE"]["tmpfile"])
			return getOKJson(qstring.cmd, "update system OK")
		end

		if (shell_exec("tar xzf "..qstring["FILE"]["tmpfile"].." -O > /dev/null") == "") then

			-- AGGIORNAMENTO PATCH
			exec("tar zxf "..qstring["FILE"]["tmpfile"].." -C / ")
			exec("rm "..qstring["FILE"]["tmpfile"])
			exec("echo \"".. getTS() .. "\t"..qstring["FILE"]["filename"].."\" >> /etc/patch")

			return getOKJson(qstring.cmd, "update patch OK")
		end

		exec("rm "..qstring["FILE"]["tmpfile"])

		return getERRORJson(qstring.cmd,"invalid file error")
	else

		return getERRORJson(qstring.cmd,"unrecognized cmd")

	end
	return getOKJson(qstring.cmd, "syscmd OK")
end

if (cli==true) then
	io.write(getOutput())
else
	return getOutput()
end