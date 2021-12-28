#!/usr/bin/lua

local utils = require "palazzetti.utils"
local socket = require "socket"

utils:init_serial(utils:getenvparams()["BLELOOP_DEVICE"], 115200)
-- Second parameter used as local flag instead of Baud Rate (setup by previous line)
utils:init_serial(utils:getenvparams()["BLELOOP_DEVICE"], "-echo")
-- Transform new line to carridge return + new line
utils:init_serial(utils:getenvparams()["BLELOOP_DEVICE"], "-onlcr")

local rserial = io.open(utils:getenvparams()["BLELOOP_DEVICE"], "r+")

assert(rserial, "Not a valid Serial Device! Make sure to be connected to USB Device")

local FILE_PATH = arg[1]

local _updateBinarySize = utils:fsize(FILE_PATH)
local _updateBinaryPacketNumber = math.ceil(_updateBinarySize / 1024)

rserial:write("<")
rserial:flush()
-- rserial:write("OTASTART" .. _updateBinaryPacketNumber .. "\r\n")

socket.sleep(5)

local _updateBinary = io.open(FILE_PATH, "r")
local _fbuffer = nil

repeat
	_fbuffer = _updateBinary:read(1024)

	print((_fbuffer ~= nil) and ("OTAPACKET" .. _fbuffer) or "OTAUPDATE")
	print(_updateBinaryPacketNumber)

	-- rserial:write(((_fbuffer ~= nil) and ("OTAPACKET" .. _fbuffer) or "OTAUPDATE") .. "\r\n")
	rserial:write((_fbuffer ~= nil and _fbuffer or ""))
	rserial:flush()

	_updateBinaryPacketNumber = _updateBinaryPacketNumber - 1
	socket.sleep(0.5)
until (_fbuffer == nil)

_updateBinary:close()
_updateBinary = nil