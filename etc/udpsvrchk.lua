#!/usr/bin/lua
local socket = require("socket")
local utils = require "palazzetti.utils"

local CBOXPARAMS = utils:getenvparams()

local udp = socket.udp()
local port = 54549

assert(udp:setpeername('127.0.0.1', port))
assert(udp:setoption('reuseport',true))
assert(udp:setoption('reuseaddr',true))
assert(udp:settimeout(3))

udp:send(CBOXPARAMS["BRANDPREFIX"] .. "bridge?")

data = udp:receive()
if data then
    print("OK")
else
    print("KO")
end