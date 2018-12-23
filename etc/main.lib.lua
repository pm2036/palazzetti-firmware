#!/usr/bin/lua
require "socket"

dofile "/etc/custom.lib.lua"

function file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

function fsize (filepath)
	local f = io.open(filepath,"r")
	if f==nil then return -1 end
	local size = f:seek("end")    -- get file size
	f:seek("set", current)        -- restore position
	f:close()
	return size
end

function GetFileExtension(url)
  return url:match("^.+(%..+)$")
end

function GetFileName(url)
  return url:match("^.+/(.+)$")
end

function GetBasename(filename)
	return filename:match("^(.+)%.%w+$")
end

function empty(val)
	if val == nil then return true end
	if val == "" then return true end
	if val == 0 then return true end
	return false
end

function loadcontent(file)
	local ext = GetFileExtension(file)

	if (ext==".lua") then
		file = "/www/cgi-bin"..file
	else
		file = "/www"..file
	end
	--os.execute("echo ".. file .. " > " .. gettmpfile("dbglua"))
	if (not file_exists(file)) then
		return "File not found"
	end

	local content = readfile(file)

	if (ext==".lua") then
		code = loadstring(content)
		if code==nil then return "" end
		return code()
	end
	return content

end

function writeinfile (filepath, buffer)
	local f = io.open(filepath, "w")
	f:write(buffer)
	f:close()
end

function readfile(filepath)
	local f = io.open(filepath, "rb")
	if (empty(f)) then return "" end

	local content = f:read("*all")
	f:close()
	return content
end

function shell_exec(cmd)
	local output = nil
	local f = io.popen(cmd)
	output=f:read("*a")
	f:close()

	return output
end

function readfline (filepath)
	local f = io.open(filepath)
	OUT = f:read("*l")
	f:close()
	return OUT
end


function sleep(sec)
    socket.select(nil, nil, sec)
end

function encdata(myjsonfile)
	return b64enc(shell_exec("gzip -c " .. myjsonfile))
end

function encstring(str)
	local tmpfile = os.tmpname()
	writeinfile(tmpfile, str)
	local output = b64enc(shell_exec("gzip -c " .. tmpfile))
	os.execute("rm ".. tmpfile)
	return output
end

function decdata(myjsonfile)
	writeinfile(myjsonfile, b64dec(readfile(myjsonfile)))
	return shell_exec("gzip -cd " .. myjsonfile)
end

function decstring(str)
	local tmpfile = os.tmpname()
	writeinfile(tmpfile, b64dec(str))
	local output = shell_exec("gzip -cd " .. tmpfile)
	os.execute("rm ".. tmpfile)
	return output
end

local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

-- b64encoding
function b64enc(data)
    return ((data:gsub('.', function(x)
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

-- b64decoding
function b64dec(data)
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

function syslogger(logtype, msg)
	if (msg==nil) then msg="---" end
	if (logtype==nil) then logtype="" end
	os.execute("logger -t SYSLOG " .. logtype .. " \"" .. msg .. "\"")
end

function trim(s)
  -- from PiL2 20.4
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function string:split(sep)
   local sep, fields = sep or ":", {}
   local pattern = string.format("([^%s]+)", sep)
   self:gsub(pattern, function(c) fields[#fields+1] = c end)
   return fields
end

function mutex(code, lockdir, retries)
	local out = os.execute("mkdir " .. lockdir .. " >/dev/null 2>&1")
	if retries==nil then retries=10 end
	while (tonumber(out)>0) and retries > 0 do
		out = os.execute("mkdir " .. lockdir .. " >/dev/null 2>&1")
		-- print("Collision!")
		retries = retries - 1
		sleep(0.1)
	end

	code()

	os.execute("rmdir " .. lockdir)
	return true
end

function getTS(tsformat)
	if (tsformat=="sec") then
		return os.time()
	end
	return os.date('%Y-%m-%d %H:%M:%S')
end

function getMinutes()
	return tonumber(os.date('%H'))*60 + tonumber(os.date('%M'))
end

function checkInternet()
	if shell_exec("wget -q --spider -T 2 http://google.com 2>/dev/null; if [ $? -eq 0 ]; then echo -n '1'; else echo -n '0'; fi") == "1" then
		mutex(function() if file_exists("/tmp/staticdata.json") then exec("sed -i -e 's/\"ICONN\":0/\"ICONN\":1/g' /tmp/staticdata.json") end end, "/tmp/lockjstatic")
		return true
	end
	mutex(function() if file_exists("/tmp/staticdata.json") then exec("sed -i -e 's/\"ICONN\":1/\"ICONN\":0/g' /tmp/staticdata.json") end end, "/tmp/lockjstatic")
	return false
end



function getERRORJson(cmd, msg, errorstr)
	if msg==nil then msg = "" end
	if errorstr==nil then errorstr = "ERROR" end
	local jsonout = {}
	jsonout["SUCCESS"] = false
	jsonout["INFO"] = {}
	jsonout["INFO"]["CMD"] = cmd
	jsonout["INFO"]["TS"] = getTS("sec")
	jsonout["INFO"]["RSP"] = errorstr
	jsonout["INFO"]["MSG"] = msg
	jsonout["DATA"] = {}
	jsonout["DATA"]["NODATA"] = true
	return cjson.encode(jsonout)
end

function getOKJson(cmd, msg)
	if msg==nil then msg = "" end
	local jsonout = {}
	jsonout["SUCCESS"] = true
	jsonout["INFO"] = {}
	jsonout["INFO"]["CMD"] = cmd
	jsonout["INFO"]["TS"] = getTS("sec")
	jsonout["INFO"]["RSP"] = "OK"
	jsonout["INFO"]["MSG"] = msg
	jsonout["DATA"] = {}
	jsonout["DATA"]["NODATA"] = true
	return cjson.encode(jsonout)
end

function getStandardJson(cmd, jdata, msg)
	if msg==nil then msg = "" end
	if jdata==nil then jdata = {} end
	local jsonout = {}
	jsonout["SUCCESS"] = true
	jsonout["INFO"] = {}
	jsonout["INFO"]["CMD"] = cmd
	jsonout["INFO"]["TS"] = getTS("sec")
	jsonout["INFO"]["RSP"] = "OK"
	jsonout["INFO"]["MSG"] = msg
	jsonout["DATA"] = jdata
	return jsonout
end

function urldecode(s)
	local s = s:gsub('+', ' ')
	   :gsub('%%(%x%x)', function(h)
						   return string.char(tonumber(h, 16))
						 end)
	return s
end

function parseurl(s)
	local ans = {}
	if s==nil then return ans end
	for k,v in s:gmatch('([^&=?]-)=([^&=?]+)' ) do
		ans[k] = urldecode(v)
	end
	return ans
end

function gettmpfile(suffix)
	if suffix==nil then suffix="" end
	local tmpfile = os.tmpname()
	os.execute("rm " .. tmpfile)
	return tmpfile .. "_" .. suffix
end

function exec(cli)
	os.execute(cli .. " > /dev/null")
end

function sendmsg(cmd, dest)
	if (dest == nil) then dest=""
	else
		dest = " > " .. dest
	end
	return trim(shell_exec("lua /www/cgi-bin/sendmsg.lua \"" .. cmd .. "\" " .. dest))
end