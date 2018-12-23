#!/usr/bin/lua

dofile "/etc/main.lib.lua"

-- check if logger process is already running
local PROCESSES=shell_exec("ps | grep [/etc/syslog]ger.lua | awk '{print $1}' | wc -l")

if (tonumber(PROCESSES)> 1) then
	print("logger already running. terminated!")
	os.exit()
end

dofile "/etc/param.lib.lua"

local SSL=CBOXPARAMS["SSL"]
local SAMPLETIME=CBOXPARAMS["LOGGER_SAMPLETIME"]
CBOXPARAMS = nil
collectgarbage()

HTTP="http"
if (SSL==1) then
	HTTP="https"
end

local FIRSTROW=0
local TS=trim(shell_exec("date +%Y%m%d%H%M%S"))
local MAC=trim(shell_exec("cat /etc/macaddr | tr -d :"))

os.execute("logger -t DEBUG logger started!")

local MNT=trim(shell_exec("ash /etc/getmountpoint.sh"))

if arg[1]==nil then
	FILENAME=MNT.."/"..MAC.."_"..TS..".csv"
else
	FILENAME=MNT.."/"..arg[1]..MAC.."_"..TS..".csv"
end
print(FILENAME)

-- create timestamp for splitting
writeinfile("/tmp/loggerTS", getTS("sec"))

if fsize("/tmp/loggersplitsec")<=0 then
	-- one day in seconds
	writeinfile("/tmp/loggersplitsec", "86400")
end

while 1 do

	MNT=trim(shell_exec("ash /etc/getmountpoint.sh"))
	if MNT=="" then
		os.execute("logger -t DEBUG logger terminated!")
		os.exit()
	end

	if file_exists(FILENAME) then
		OUTPUT=shell_exec("curl -sk " .. HTTP .. "://localhost/cgi-bin/syscmd.lua?cmd=logger")
		os.execute("echo \"" ..OUTPUT .. "\" | tail -n1 >> " .. FILENAME)
	else
		-- first start
		OUTPUT=shell_exec("curl -sk " .. HTTP .. "://localhost/cgi-bin/syscmd.lua?cmd=loggerhead")
		os.execute("echo \"" ..OUTPUT .. "\" | tail -n1 > " .. FILENAME)
		OUTPUT=shell_exec("curl -sk " .. HTTP .. "://localhost/cgi-bin/syscmd.lua?cmd=logger")
		os.execute("echo \"" ..OUTPUT .. "\" | tail -n1 >> " .. FILENAME)
	end

	socket.sleep(SAMPLETIME)
end
