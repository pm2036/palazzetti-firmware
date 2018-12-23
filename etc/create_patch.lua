#!/usr/bin/lua

dofile "/etc/main.lib.lua"
dofile "/etc/param.lib.lua"

local filepatch = "/tmp/" .. CBOXPARAMS["PATCH_FILEPATTERN"] .. os.date("%Y%m%d") .. ".tar.gz"
local cmd = "tar czf " .. filepatch .. " "

for i,v in ipairs(arg) do
	cmd  = cmd .. tostring(v) .. " "
end

-- print(cmd)
os.execute(cmd)
print(filepatch .. " create succesfully!")
os.execute("scp " .. filepatch .. " enrico@172.16.1.180:~/PATCHES")