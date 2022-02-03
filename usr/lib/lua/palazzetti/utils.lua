#!/usr/bin/lua

local cjson = require "cjson"
local socket = require "socket"

local utils = {}

-- gettmpfile
-- writeinfile
-- exec
-- shell_exec
-- trim

function utils:bitand(a, b)
    local result = 0
    local bitval = 1
    while a > 0 and b > 0 do
      if a % 2 == 1 and b % 2 == 1 then -- test the rightmost bits
          result = result + bitval      -- set the current bit
      end
      bitval = bitval * 2 -- shift left
      a = math.floor(a/2) -- shift right
      b = math.floor(b/2)
    end
    return result
end

function utils:b64enc(data)
	local _token = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

    return ((data:gsub('.', function(x)
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return _token:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

function utils:b64dec(data)
	local _token = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

    data = string.gsub(data, '[^'.._token..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(_token:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

function utils:encstring(str)
	local tmpfile = os.tmpname()
	self:writeinfile(tmpfile, str)
	local output = self:b64enc(self:shell_exec("gzip -c " .. tmpfile))
	os.execute("rm ".. tmpfile)
	return output
end

function utils:decstring(str)
	local tmpfile = os.tmpname()
	writeinfile(tmpfile, self:b64dec(str))
	local output = self:shell_exec("gzip -cd " .. tmpfile)
	os.execute("rm ".. tmpfile)
	return output
end

function utils:file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

function utils:fage(filepath)
	if (self:file_exists(filepath) == false) then
		return -1
	end

	return tonumber(self:shell_exec("echo -n $(($(date +%s) - $(date +%s -r \"" .. filepath .. "\")))"))
end

function utils:fsize (filepath)
	local f = io.open(filepath,"r")
	if f==nil then return -1 end
	local size = f:seek("end")    -- get file size
	f:seek("set", current)        -- restore position
	f:close()
	return size
end

function utils:lpad (s, l, c)
	local res = string.rep(c or ' ', l - #s) .. s
	return res
end

function utils:rpad (s, l, c)
	local res = s .. string.rep(c or ' ', l - #s)
	return res
end

function utils:syslogger(logtype, msg)
	if (msg==nil) then msg="---" end
	if (logtype==nil) then logtype="" end
	os.execute("logger -t SYSLOG " .. logtype .. " \"" .. msg .. "\"")
end

function utils:shell_escape(args)
	local ret = {}
	for _,a in pairs(args) do
		s = tostring(a)
		if s:match("[^A-Za-z0-9_/:=-]") then
			s = "'"..s:gsub("'", "'\\''").."'"
		end
		table.insert(ret,s)
	end
	return table.concat(ret, " ")
end

function utils:init_serial(dev, baudrate)
	local output = nil
	local f = io.popen("stty -F " .. dev .. " " .. baudrate .. "")
	output=f:read("*a")
	f:close()

	return output
end

function utils:empty(val)
	if val == nil then return true end
	if val == "" then return true end
	if val == 0 then return true end
	return false
end

function utils:writeinfile (filepath, buffer)
	local f = io.open(filepath, "w")
	f:write(buffer)
	f:close()
end

function utils:readfile(filepath)
	local f = io.open(filepath, "rb")
	if (self:empty(f)) then return "" end

	local content = f:read("*all")
	f:close()
	return content
end

function utils:shell_exec(cmd)
	local output = nil
	local f = io.popen(cmd)
	output=f:read("*a")
	f:close()

	return output
end

function utils:trim(s)
  -- from PiL2 20.4
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function utils:getTS(tsformat)
	if (tsformat=="sec") then
		return os.time()
	end
	return os.date('%Y-%m-%d %H:%M:%S')
end

function utils:getERRORJson(cmd, msg, errorstr)
	if msg==nil then msg = "" end
	if errorstr==nil then errorstr = "ERROR" end
	local jsonout = {}
	jsonout["SUCCESS"] = false
	jsonout["INFO"] = {}
	jsonout["INFO"]["CMD"] = cmd
	jsonout["INFO"]["TS"] = self:getTS("sec")
	jsonout["INFO"]["RSP"] = errorstr
	jsonout["INFO"]["MSG"] = msg
	jsonout["DATA"] = {}
	jsonout["DATA"]["NODATA"] = true
	return cjson.encode(jsonout)
end

function utils:getOKJson(cmd, msg)
	if msg==nil then msg = "" end
	local jsonout = {}
	jsonout["SUCCESS"] = true
	jsonout["INFO"] = {}
	jsonout["INFO"]["CMD"] = cmd
	jsonout["INFO"]["TS"] = self:getTS("sec")
	jsonout["INFO"]["RSP"] = "OK"
	jsonout["INFO"]["MSG"] = msg
	jsonout["DATA"] = {}
	jsonout["DATA"]["NODATA"] = true
	return cjson.encode(jsonout)
end

function utils:getStandardJson(cmd, jdata, msg)
	if msg==nil then msg = "" end
	if jdata==nil then jdata = {} end
	local jsonout = {}
	jsonout["SUCCESS"] = true
	jsonout["INFO"] = {}
	jsonout["INFO"]["CMD"] = cmd
	jsonout["INFO"]["TS"] = self:getTS("sec")
	jsonout["INFO"]["RSP"] = "OK"
	jsonout["INFO"]["MSG"] = msg
	jsonout["DATA"] = jdata
	return jsonout
end

function utils:sleep(sec)
    socket.select(nil, nil, sec)
end

function utils:mutex(code, lockdir, retries)
	local out = os.execute("mkdir " .. lockdir .. " >/dev/null 2>&1")
	if retries==nil then retries=10 end
	while (tonumber(out)>0) and retries > 0 do
		out = os.execute("mkdir " .. lockdir .. " >/dev/null 2>&1")
		-- print("Collision!")
		retries = retries - 1
		self:sleep(0.1)
	end

	code()

	os.execute("rmdir " .. lockdir)
	return true
end

function utils:checkInternet(cmd, host)

	if (host==nil) then
		host = "http://clients3.google.com/generate_204"
	end

	-- check only from cache
	if (cmd == "cache") then
		return ((self:file_exists("/tmp/isICONN")) and true or false)
	end

	local pingAttempt = self:trim(self:shell_exec("curl -q --head " .. host .. " 2>/dev/null"))
	-- vprint("Attempt real ping internet..");
	-- if shell_exec("wget -q --spider -T 2 http://www.google.com/test 2>/dev/null; if [ $? -eq 0 ]; then echo -n '1'; else echo -n '0'; fi") == "1" then
	if (pingAttempt ~= nil and pingAttempt:len() > 0) then
		self:mutex(function() if self:file_exists("/tmp/staticdata.json") then self:exec("sed -i -e 's/\"ICONN\":0/\"ICONN\":1/g' /tmp/staticdata.json") end end, "/tmp/lockjstatic")
		os.execute("touch -f /tmp/isICONN")
		return true
	end

	self:mutex(function() if self:file_exists("/tmp/staticdata.json") then self:exec("sed -i -e 's/\"ICONN\":1/\"ICONN\":0/g' /tmp/staticdata.json") end end, "/tmp/lockjstatic")
	os.execute("rm -f /tmp/isICONN")
	return false
end

function utils:getenvparams()
	local _envparams = cjson.decode(utils:readfile("/etc/cboxparams.json"))

	if (self:file_exists("/tmp/isUARTBridge")) then
		local _bleloop_device = self:trim(utils:readfile("/tmp/isUARTBridge") or "")
		_envparams["BLELOOP_DEVICE"] = ((_bleloop_device ~= nil and _bleloop_device:len() > 0) and _bleloop_device or _envparams["BLELOOP_DEVICE"])
	end

	return _envparams
end

function utils:gettmpfile(suffix)
	if suffix==nil then suffix="" end
	local tmpfile = os.tmpname()
	os.execute("rm " .. tmpfile)
	return tmpfile .. "_" .. suffix
end

function utils:exec(cli)
	os.execute(cli .. " > /dev/null")
end

function utils:uniqueid(bytes)
	local rand = fs.readfile("/dev/urandom", bytes)
	return rand
end

function utils:getmacaddress_shortversion()
	return self:trim(self:shell_exec("cat /etc/macaddr | sed 's/://g' | tail -c 6"))
end

function utils:spairs(t, order)
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

return utils