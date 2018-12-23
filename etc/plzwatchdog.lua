#!/usr/bin/lua

os.execute("cp /etc/cboxparams.json /tmp/cboxparams.json")
os.execute("cp /etc/timer.json /tmp/timer.json")

dofile "/etc/main.lib.lua"
dofile "/etc/param.lib.lua"
cjson = require "cjson"

local MYETH0="eth0"
local WLAN0_MODE=""
local WLAN0_ISDISABLE=""
local CURRENT_WMODE=""
local CURRENT_WSTATUS=""
local POWERLOW=""
local INTERNETOK=""
local FIRSTINTERNETCHECK=false
local STDTINFOMD5=nil
local NOTIFYSTANDARDINFO=false
local PID
local IMGFILE
local WIFILINK=0

local MYBOARD=trim(shell_exec("ash /etc/myboard.sh"))
if MYBOARD=="miniembplug" or MYBOARD=="omni-plug" then
	MYETH0="eth0.1"
end
print(MYBOARD)

-- verify if this is first boot
local FIRSTBOOT=0
local COUNT=15
if file_exists("/etc/macaddr")==false or fsize("/etc/macaddr")==0 then
	FIRSTBOOT=1
end

if FIRSTBOOT==1 then
	os.execute("wifi up && ifdown lan && ifup lan")
	os.execute("/etc/init.d/fstab restart")
end

local mac
while (file_exists("/etc/macaddr") == false or fsize("/etc/macaddr")==0) and COUNT>0 do
	os.execute("cat /sys/class/net/" .. MYETH0 .. "/address | tr '[a-z]' '[A-Z]' > /etc/macaddr")
	FIRSTBOOT = 1
	COUNT = COUNT - 1
	syslogger(DEBUG, "Trying to set macaddr count=" .. COUNT)
	sleep(1)
end

if FIRSTBOOT==1 then
	syslogger(DEBUG, "FIRSTBOOT. Set default network..")
	if (CBOXPARAMS["SSL"]==1) then
		os.execute("openssl req -newkey rsa:2048 -nodes -keyout /etc/uhttpd.key -x509 -days 365 -out /etc/uhttpd.crt -subj \"/C=IT/ST=Pordenone/L=Pordenone/O=Dis/CN=www.domain.it\"")
		os.execute("uci set uhttpd.main.redirect_https=1 && uci commit uhttpd && /etc/init.d/uhttpd restart")
	else
		os.execute("rm /etc/uhttpd.*")
		os.execute("uci set uhttpd.main.redirect_https=0 && uci commit uhttpd && /etc/init.d/uhttpd restart")
	end
	os.execute("ash /etc/setwifi.sh default")
	os.execute("cat /etc/macaddr > /etc/appliancelabel")
	os.execute("echo 0 > /sys/bus/usb/devices/usb1/authorized && echo 1 > /sys/bus/usb/devices/usb1/authorized")
end

if FIRSTBOOT==1 then
	syslogger(DEBUG, "FIRSTBOOT. Restore previous configurations..")
	if file_exists("/etc/upgrade_config.sh")==true then
		os.execute("chmod +x /etc/upgrade_config.sh")
		os.execute("ash /etc/upgrade_config.sh")
		os.execute("rm -f /etc/upgrade_config.sh")

		-- If label is still empty
		-- It couldn't be recovered
		if ((file_exists("/etc/appliancelabel") ~= true) or (fsize("/etc/appliancelabel") <= 0)) then
			os.execute("cat /etc/macaddr > /etc/appliancelabel")
		end

		os.execute("lua /etc/leds.lua off")
		os.execute("reboot")
	end
end

os.execute("lua /etc/leds.lua off")

-- -------------------------------------------
-- -------------- Main loop ------------------
-- -------------------------------------------
while 1 do
	if CBOXPARAMS["OEMBRIDGE_ENABLED"]==1 then
		PID=shell_exec("pidof oembridge")
		if PID=="" then
			print("Restart oembridge!")
			os.execute("killall sendmsg &")
			os.execute("oembridge &")
		end
	else
		PID=shell_exec("pidof plzbridge")
		if PID=="" then
			print("Restart plzbridge!")
			os.execute("killall sendmsg &")
			os.execute("plzbridge &")
		end
	end

	PID=trim(shell_exec("ps | grep [udp]svr.lua"))
	if PID=="" then
		print("Restart udpsvr!")
		os.execute("lua /etc/udpsvr.lua &")
	end

	if CBOXPARAMS["MQTT_ENABLED"]==1 then

		PID=shell_exec("ps | grep [mqtt].lua")
		if PID=="" then
			print("Restart MQTT")
			os.execute("lua /etc/mqtt.lua &")
		end

		if CBOXPARAMS["MQTT_APIPING_ENABLED"]==1 then
			PID=shell_exec("ps | grep [mqtt_]apiping.lua")
			if PID=="" then
				print("Restart MQTT_APIPING")
				os.execute("lua /etc/mqtt_apiping.lua &")
			end
		end

	end

	if CBOXPARAMS["ALIVELOOP_ENABLED"]==1 then
		PID=trim(shell_exec("ps | grep [alive]loop.lua"))
		if PID=="" then
			print("Restart ALIVELOOP")
			sleep(5)
			os.execute("lua /etc/aliveloop.lua &")
		end
	end

	PID=shell_exec("pidof uhttpd")
	if PID=="" then
			print("Restart uhttpd")
			os.execute("/etc/init.d/uhttpd restart")
	end


	if MYBOARD=="miniembplug" or MYBOARD=="omni-plug" then
		ETHLINK=trim(shell_exec("swconfig dev switch0 port 4 get link | cut -d' ' -f2 | cut -d':' -f2"))
	else
		ETHLINK=trim(shell_exec("swconfig dev switch0 port 3 get link | cut -d' ' -f2 | cut -d':' -f2"))
	end
	STATUS=trim(shell_exec("ifstatus lan | grep '\"up\":' | cut -d':' -f2 | cut -d',' -f1"))
	if ETHLINK=="down" and STATUS=="true" then
		os.execute("ifdown lan")
		os.execute("/etc/init.d/network reload")
		FIRSTINTERNETCHECK = false
		os.execute("kill -9 `ps | grep [mqtt].lua | awk '{print $1}'`")
	end

	if ETHLINK=="up" and STATUS=="false" then
		os.execute("ifup lan")
		os.execute("/etc/init.d/network reload")
		FIRSTINTERNETCHECK = false
		os.execute("kill -9 `ps | grep [mqtt].lua | awk '{print $1}'`")
	end

	if trim(shell_exec("uci get wireless.radio0.disabled"))=="0" and trim(shell_exec("uci get wireless.@wifi-iface[0].mode"))~="ap" then
		-- STA mode
		if trim(shell_exec("ifconfig wlan0 | grep \"inet addr\""))=="" then
			-- restart wifi
			syslogger(DEBUG, "restart wifi")
			os.execute("wifi up")
			FIRSTINTERNETCHECK = false
		elseif trim(shell_exec("uci get network.wlan.proto"))=="dhcp" and WIFILINK==1 then
			-- wifi interface has valid IP
			-- ping wifi gateway
			local _wifigateway = trim(shell_exec("route -n | grep UG | grep wlan0 | awk '{print $2}'"))
			if _wifigateway ~= nil or _wifigateway ~= "" then
				if tonumber(shell_exec("ping -c 2 -q -w 2 " .. _wifigateway .. " | grep \"100%\" >/dev/null; if [ $? -eq 0 ]; then echo -n \"0\"; else echo -n \"1\"; fi")) == 0 then
					syslogger("DEBUG", "NO_PING_WIFIGATEWAY restart wifi")
					os.execute("wifi up")
				end
			end
		end
	end



	-- check if there is image file to flash
	IMGFILE=trim(shell_exec("find /tmp -name pl*.enc | head -1"))
	if IMGFILE ~= "" then
		-- flash new image file!
		os.execute("ash /etc/sysdec.sh \"" .. IMGFILE .. " \"`basename " .. IMGFILE .. "`\" &")
		os.exit()
	end

	if ((file_exists("/tmp/staticdata.json")==true) and (fsize("/tmp/staticdata.json") > 0)) then

		-- When Internet connection is available and cloud required to be notified
		-- Send the Standard informations via MQTT channel
		if ((FIRSTINTERNETCHECK==true) and (NOTIFYSTANDARDINFO == true)) then
			print("...Transmit STDT to cloud")
			NOTIFYSTANDARDINFO = false

			local appliance_connected = cjson.decode(readfile("/tmp/staticdata.json"))["DATA"]["APLCONN"]
			tmpfile = os.tmpname()
			writeinfile(tmpfile, readfile("/tmp/staticdata.json"))
			pcall(mqttpub, CBOXPARAMS["MQTT_BROKER"][1], "", tmpfile, true)
			os.execute("rm -f " .. tmpfile)

			local result, jdata = pcall(cjson.decode, readfile("/tmp/appliance_params.json"))
			if (appliance_connected==1) and (result == true) then
				print("...Transmit PARAMETERS to cloud")

				local jout = getStandardJson("GET APAR", jdata)

				tmpfile = os.tmpname()
				writeinfile(tmpfile, cjson.encode(jout))
				pcall(mqttpub, CBOXPARAMS["MQTT_BROKER"][1], "", tmpfile, true)
				os.execute("rm -f " .. tmpfile)
			end
		end

		-- Check if internet connection is now available
		if (FIRSTINTERNETCHECK == false) then
			vprint("Have to Check Internet connection")
			FIRSTINTERNETCHECK = checkInternet()
			NOTIFYSTANDARDINFO = ((FIRSTINTERNETCHECK == true) and true or false)
		end

		-- Other situations that have to be notified to the cloud
		if (NOTIFYSTANDARDINFO==false and FIRSTINTERNETCHECK==true) then
			-- 1. Asset connect / disconnect
			local static_data_flag, static_data = pcall(cjson.decode, readfile("/tmp/staticdata.json"))
			if ((static_data_flag == true) and (static_data["DATA"] ~= nil)) then

				-- Prevent WPWR to be used as a comparison value
				static_data["DATA"]["WPWR"] = "0"
				-- Consider only DATA and not INFO
				writeinfile("/tmp/staticdata_md5.json", cjson.encode(static_data["DATA"]))

				-- Check if board has changed connection status
				STDTINFOMD5UPD = trim(shell_exec("md5sum /tmp/staticdata_md5.json | cut -d' ' -f1"))
				if (STDTINFOMD5~=STDTINFOMD5UPD) then
					vprint("Asset Data Changed")
					vprint(STDTINFOMD5UPD)
					-- Notify the standard informations only when there is a change on board connection
					NOTIFYSTANDARDINFO = ((STDTINFOMD5 ~= nil) and true or false)
					STDTINFOMD5 = STDTINFOMD5UPD
				end

				-- Cleanup unusued file
				shell_exec("rm -f /tmp/staticdata_md5.json")
			end
		end
	end

		-- check wireless status and set leds
		CURRENT_WMODE=trim(shell_exec("uci get wireless.@wifi-iface[0].mode"))
		CURRENT_WSTATUS=trim(shell_exec("uci get wireless.radio0.disabled"))

		if WLAN0_MODE~=CURRENT_WMODE or WLAN0_ISDISABLE~=CURRENT_WSTATUS then
			WLAN0_MODE=trim(shell_exec("uci get wireless.@wifi-iface[0].mode"))
			WLAN0_ISDISABLE=trim(shell_exec("uci get wireless.radio0.disabled"))
			if WLAN0_ISDISABLE=="1" then
				WLAN0_MODE="off"
			end

			if WLAN0_MODE=="ap" then
				os.execute("lua /etc/leds.lua green blink+ &")
			elseif WLAN0_MODE=="sta" then
				if trim(shell_exec("iw dev wlan0 link"))=="Not connected." then WIFILINK=0 else WIFILINK=1 end
				if WIFILINK==0 then
					INTERNETOK=""
					POWERLOW=""
				else
					INTERNETOK=checkInternet()
					SIGNALSTRENGTH=tonumber(shell_exec("iw dev wlan0 link | grep signal | cut -d ':' -f 2  | awk '{print $1}'"))
					if SIGNALSTRENGTH~=nil and SIGNALSTRENGTH < -80 then POWERLOW="1" else POWERLOW="0" end
				end

				if WIFILINK==0 then
					-- *** collegamento col router KO ***
					os.execute("lua /etc/leds.lua red blink+ &")
				else
					-- *** collegamento col router OK ***
					if INTERNETOK==false then
						if POWERLOW=="1" then
							-- no internet e potenza scarsa
							os.execute("lua /etc/leds.lua green blink-2+ &")
						else
							-- no internet e potenza ok
							os.execute("lua /etc/leds.lua green blink-+ &")
						end
					else
						if POWERLOW=="1" then
							-- ok internet e potenza scarsa
							os.execute("lua /etc/leds.lua green blink2-+ &")
						else
							-- ok internet e potenza ok
							os.execute("lua /etc/leds.lua green blink2- &")
						end
					end
				end
			end
		else
			if WLAN0_MODE=="sta" then

				if trim(shell_exec("iw dev wlan0 link"))=="Not connected." then WIFILINK=0 else WIFILINK=1 end

				if WIFILINK==1 then
					local _currentPower = tonumber(shell_exec("iw dev wlan0 link | grep signal | cut -d ':' -f 2  | awk '{print $1}'"))
					if _currentPower==nil then _currentPower=-100 end
					if _currentPower < -80 then CURRENT_POWERLOW="1" else CURRENT_POWERLOW="0" end
					CURRENT_INTERNETOK=checkInternet()
				else
					CURRENT_POWERLOW=""
					CURRENT_INTERNETOK=""
				end

				if POWERLOW~=CURRENT_POWERLOW or INTERNETOK~=CURRENT_INTERNETOK then

					if WIFILINK==0 then
						INTERNETOK=""
						POWERLOW=""
					else
						INTERNETOK=checkInternet()
						if tonumber(shell_exec("iw dev wlan0 link | grep signal | cut -d ':' -f 2  | awk '{print $1}'")) < -80 then POWERLOW="1" else POWERLOW="0" end
					end

					if WIFILINK==0 then
						os.execute("lua /etc/leds.lua red blink+ &")
					else
						if INTERNETOK==false then
							if POWERLOW=="1" then
								os.execute("lua /etc/leds.lua green blink-+ &")
							else
								os.execute("lua /etc/leds.lua green blink-+ &")
							end
						else
							if POWERLOW=="1" then
								os.execute("lua /etc/leds.lua green blink2-+ &")
							else
								os.execute("lua /etc/leds.lua green blink2- &")
							end
						end
					end
				end
			end
		end
	-- ---------------------------------------------

sleep(20)
end
-- main loop
