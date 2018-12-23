#!/usr/bin/lua

dofile "/etc/main.lib.lua"

local LED_GREEN_ON
local LED_GREEN_OFF
local LED_RED_ON
local LED_RED_OFF

MYBOARD = trim(shell_exec("ash /etc/myboard.sh"))
if (MYBOARD == "miniembplug" or MYBOARD == "omni-plug") then
	LED_GREEN_ON="swconfig dev rt305x port 4 set led 4 && swconfig dev rt305x set apply"
	LED_GREEN_OFF="swconfig dev rt305x port 4 set led 12 && swconfig dev rt305x set apply"

	LED_RED_ON="echo 0 > /sys/class/leds/rt2800soc-phy0\:\:radio/brightness"
	LED_RED_OFF="echo 1 > /sys/class/leds/rt2800soc-phy0\:\:radio/brightness"

else
	LED_GREEN_ON="echo 1 > /sys/class/leds/miniembwifi\:green\:wlan/brightness"
	LED_GREEN_OFF="echo 0 > /sys/class/leds/miniembwifi\:green\:wlan/brightness"

	LED_RED_ON=""
	LED_RED_OFF=""
end

local short_delay=0.4
local med_delay=2
local long_delay=10

local ledspid="/tmp/ledspid"

-- ------------------------------------------------
-- reset all previous tasks

res=readfline("/proc/self/stat")
i, j = string.find(res, " ", 1)
pid = trim(string.sub(res, 1, i))

-- print("pid " .. pid)

f = io.popen("ps | grep [leds].lua  | awk '{print $1}'")
while true do
	line = f:read()
	if line == nil then break end
	if trim(line) ~= pid then
		-- print("kill " .. line)
		os.execute("kill -9 " .. trim(line))
	end
end
f:close()


-- ------------------------------------------------

os.execute(LED_GREEN_OFF)
os.execute(LED_RED_OFF)

if arg[1]=="red" then
	color_on=LED_RED_ON
	color_off=LED_RED_OFF
	negcolor_on=LED_GREEN_ON
	negcolor_off=LED_GREEN_OFF
elseif arg[1]=="green" then
	color_on=LED_GREEN_ON
	color_off=LED_GREEN_OFF
	negcolor_on=LED_RED_ON
	negcolor_off=LED_RED_OFF
elseif arg[1]=="on" then
	os.execute(LED_GREEN_ON)
	os.execute(LED_RED_ON)
end

if arg[2]=="off" then
	os.execute(color_off)
end

if arg[2]=="on" then
	os.execute(color_on)
end


if arg[2]=="blink+" then
	while 1 do
		os.execute(color_on)
		sleep(short_delay)
		os.execute(color_off)
		sleep(med_delay)
	end
end

if arg[2]=="blink2+" then
	while 1 do
		os.execute(color_on)
		sleep(short_delay)
		os.execute(color_off)
		sleep(short_delay)
		os.execute(color_on)
		sleep(short_delay)
		os.execute(color_off)
		sleep(med_delay)
	end
end

if arg[2]=="blink-" then
	while 1 do
		os.execute(color_off)
		sleep(short_delay)
		os.execute(color_on)
		sleep(long_delay)
	end
end

if arg[2]=="blink2-" then
	while 1 do
		os.execute(color_off)
		sleep(short_delay)
		os.execute(color_on)
		sleep(short_delay)
		os.execute(color_off)
		sleep(short_delay)
		os.execute(color_on)
		sleep(long_delay)
	end
end

if arg[2]=="blink-+" then
	while 1 do
		os.execute(color_off)
		sleep(short_delay)
		os.execute(color_on)
		sleep(short_delay)
		os.execute(color_off)
		sleep(short_delay)
		os.execute(negcolor_on)
		sleep(short_delay)
		os.execute(negcolor_off)
		sleep(short_delay)
		os.execute(color_on)
		sleep(long_delay)
	end
end

if arg[2]=="blink-2+" then
	while 1 do
		os.execute(color_off)
		sleep(short_delay)
		os.execute(color_on)
		sleep(short_delay)
		os.execute(color_off)
		sleep(short_delay)
		os.execute(negcolor_on)
		sleep(short_delay)
		os.execute(negcolor_off)
		sleep(short_delay)
		os.execute(negcolor_on)
		sleep(short_delay)
		os.execute(negcolor_off)
		sleep(short_delay)
		os.execute(color_on)
		sleep(long_delay)
	end
end

if arg[2]=="blink2-+" then
	while 1 do

		os.execute(color_off)
		sleep(short_delay)
		os.execute(color_on)
		sleep(short_delay)
		os.execute(color_off)
		sleep(short_delay)
		os.execute(color_on)
		sleep(short_delay)
		os.execute(color_off)
		sleep(short_delay)
		os.execute(negcolor_on)
		sleep(short_delay)
		os.execute(negcolor_off)
		sleep(short_delay)
		os.execute(color_on)
		sleep(long_delay)
	end
end