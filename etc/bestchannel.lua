#!/usr/bin/lua

function spairs(t, order)
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys
    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

-- split iw scan by BSS
local scan
local i=1

os.execute("iw dev wlan0 scan > /tmp/wlist")
local f = assert(io.open("/tmp/wlist", "r"))
local wlist = f:read("*all")
f:close()

wlist = string.gsub(wlist, "BSS", "§BSS")

listSSID = {}
listBestChannel = {}
for bss in string.gmatch(wlist, "[^§]+") do
	ssid = string.match(bss, "SSID: ([%w%p]+)")
	if ssid ~= nil then
		signal = string.match(bss, "signal: ([%d%p]+)")
		channel = string.match(bss, "DS Parameter set: channel ([%d]+)")
		if channel ~= nil then
			listSSID[tonumber(channel)] = tonumber(signal)
		end
	end
end

-- first verify best channels 11, 6, 1


if listSSID[11] == nil then
	print(11)
	os.exit()
end
if listSSID[1] == nil then
	print(1)
	os.exit()
end

for i=2,5 do
	if listSSID[i] == nil then
		print(i)
		os.exit()
	end
end

for i=7,10 do
	if listSSID[i] == nil then
		print(i)
		os.exit()
	end
end

-- ALL CHANNELS ARE BUSY! Select the less powerful channel
for k,v in spairs(listSSID, function(t,a,b) return t[b] > t[a] end) do
    print(k)
	os.exit()
	-- print(k,v)
end

