dofile "/etc/main.lib.lua"
cjson = require "cjson"
http = require("socket.http")

local output
mytmpfile = ""

CBOXPR_FILE = "/etc/cboxparams.json"
CBOXPR_TMPFILE = "/tmp/cboxparams.json"
if (not file_exists(CBOXPR_TMPFILE)) then
	os.execute("cp " .. CBOXPR_FILE .. " " .. CBOXPR_TMPFILE)
end

if (CBOXPARAMS == nil) then
	local f = io.open(CBOXPR_TMPFILE)
	jsondata = f:read("*a")
	f:close()
	CBOXPARAMS = cjson.decode(jsondata)
	if (CBOXPARAMS["MQTT_VERBOSE"]==1) then print("read cboxparams.json OK") end
end


function handle_request(env)

	function sendContentType(output)
		local ext = GetFileExtension(env.PATH_INFO)
		if (ext==".css") then
			uhttpd.send("Content-Type: text/css;\r\n\r\n")
		elseif (ext==".js") then
			uhttpd.send("Content-Type: application/javascript;\r\n\r\n")
		elseif (ext==".gif") then
			uhttpd.send("Content-Type: image/gif;\r\n\r\n")
		elseif (ext==".png") then
			uhttpd.send("Content-Type: image/png;\r\n\r\n")
		elseif (ext==".jpg") then
			uhttpd.send("Content-Type: image/jpeg;\r\n\r\n")
		elseif (ext==".bmp") then
			uhttpd.send("Content-Type: image/bmp;\r\n\r\n")
		elseif (ext==".ico") then
			uhttpd.send("Content-Type: image/x-icon;\r\n\r\n")
		else
			local ok, jout = pcall(cjson.decode, output)
			if (ok==true) then
				uhttpd.send("Content-Type: application/json; charset=ISO-8859-1\r\n\r\n")
			else
				uhttpd.send("Content-Type: text/html; charset=utf-8\r\n\r\n")
			end
		end
		return
	end

	uhttpd.send("Status: 200 OK\r\n")

--[[


	uhttpd.send("Content-Type: text/html; charset=utf-8\r\n\r\n")
	body=io.read("*all")
	uhttpd.send(body)
	os.exit()

	uhttpd.send("Content-Type: text/html; charset=utf-8\r\n\r\n")
	--uhttpd.send("Content-Type: application/json\r\n\r\n")
	uhttpd.send(cjson.encode(env))

	local f = io.open("/tmp/body", "w")
	f:write(io.read("*all"))
	f:close()

	os.exit()
]]


	if (env.REQUEST_METHOD=="POST") then
		local body = io.read("*all")

		if not string.match(body, "Content%-Disposition:") then
			qstring = parseurl(env.QUERY_STRING.."&"..body)

			-- Parameters may come from application/x-www-form-urlencoded or application/json
			-- In the first case parsing is not necessary because previous body read succeed
			if (env.headers["content-type"]:gmatch("(application/json)")() ~= nil) then

				-- Compatibility with Web Interface
				-- Which give command through Querystring
				-- And Parameters via POST 
				local _command = (qstring.cmd==nil and qstring.command or qstring.cmd)

				qstring = cjson.decode(body)

				-- If command is present on querystring, it take precedence
				if (_command ~= nil) then
					qstring["cmd"] = _command
				end
			end

		elseif (env.headers["content-type"]:gmatch("(multipart/form%-data)")() ~= nil) then
			-- file upload

			local tmpfile = os.tmpname()
			local f = io.open(tmpfile, "a")
			local chunk = io.read(512)
			head=chunk:gmatch("[-]+%w+")()

			name, filename = chunk:match("Content%-Disposition: form%-data; name=\"([%w%p]+)\"; filename=\"([%w%p%s]+)\"")

			i,j,mimetype = chunk:find("Content%-Type: ([%w]+/[%w%p]+)[\r][\n][\r][\n]")

			chunk = chunk:sub(j+1, chunk:len())
			f:write(chunk)

			while true do
				chunk = io.read(512)
				if (chunk == nil) then break end
				i,j,tail = chunk:find("[\r][\n]"..head)
				if i ~= nil then
					chunk = chunk:sub(1, i-1)
				end
				f:write(chunk)
			end
			f:close()

			qstring = parseurl(env.QUERY_STRING)
			qstring["FILE"] = {}
			qstring["FILE"]["mimetype"] = mimetype

			qstring["FILE"]["filename"] = filename
			qstring["FILE"]["tmpfile"] = tmpfile

			qstring["FILE"]["size"] = fsize(qstring["FILE"]["tmpfile"])

		else
			qstring = parseurl(env.QUERY_STRING.."&"..body)
		end

	else
		qstring = parseurl(env.QUERY_STRING)
	end

	if (env.PATH_INFO == nil) or (env.PATH_INFO == "/") then
		env.PATH_INFO = "/main.lua"
	end

	--os.execute("echo ".. env.PATH_INFO .. " > " .. gettmpfile("dbglua"))
	--os.execute("echo ".. env.PATH_INFO .. " >> /tmp/dbglua_temp")

	output = loadcontent(env.PATH_INFO)

	if output:gmatch("Content%-Type: %w+/%w+")() ~= nil then
		uhttpd.send(output)
	else
		sendContentType(output)
		uhttpd.send(output)
	end

--[[
	-- qstring vuoto
	if next(qstring) ~= nil then

		uhttpd.send("Status: 200 OK\r\n")
		uhttpd.send("Content-Type: application/json\r\n\r\n")
		uhttpd.send(cjson.encode(env))
]]



end

