local _ubus = require "ubus"
local _ubus_connection = nil

local rawget, rawset, unpack, select = rawget, rawset, unpack, select
local tostring, type, assert, error = tostring, type, assert, error

module "palazzetti.ubus"

local ubus_codes = {
	"INVALID_COMMAND",
	"INVALID_ARGUMENT",
	"METHOD_NOT_FOUND",
	"NOT_FOUND",
	"NO_DATA",
	"PERMISSION_DENIED",
	"TIMEOUT",
	"NOT_SUPPORTED",
	"UNKNOWN_ERROR",
	"CONNECTION_FAILED"
}

local function ubus_return(...)
	if select('#', ...) == 2 then
		local rv, err = select(1, ...), select(2, ...)
		if rv == nil and type(err) == "number" then
			return nil, err, ubus_codes[err]
		end
	end

	return ...
end

function ubus(object, method, data, path, timeout)
	if not _ubus_connection then
		_ubus_connection = _ubus.connect(path, timeout)
		assert(_ubus_connection, "Unable to establish ubus connection")
	end

	if object and method then
		if type(data) ~= "table" then
			data = { }
		end
		return ubus_return(_ubus_connection:call(object, method, data))
	elseif object then
		return _ubus_connection:signatures(object)
	else
		return _ubus_connection:objects()
	end
end