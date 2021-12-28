#!/usr/bin/lua

local uci = require "palazzetti.uci".cursor()
local ubus = require "palazzetti.ubus".ubus
local utils = require "palazzetti.utils"
local socket = require "socket"
local cjson = require "cjson"

local network = {}

function network:net_data()

	local MYETH0="eth0.1"
	local _networkData = {}
	local _networkData_output = ""

	_networkData["LABEL"] = utils:trim(utils:readfile("/etc/appliancelabel"))
	_networkData["SYSTEM"] = utils:trim(utils:readfile("/etc/systemver"))

	if (utils:getenvparams()["OEMBRIDGE_ENABLED"] == 1) then
		_networkData["oembridge"] = utils:trim(utils:shell_exec("oembridge -v"))
	else
		_networkData["plzbridge"] = utils:trim(utils:shell_exec("plzbridge -v"))
	end
	
	_networkData["sendmsg"] = utils:trim(utils:shell_exec("sendmsg -v"))
	
	_networkData["CBTYPE"] = utils:trim(utils:shell_exec("ash /etc/myboard.sh"))
	_networkData["ICONN"] = (utils:file_exists("/tmp/isICONN") and 1 or 0)
	_networkData["GWDEVICE"] = utils:trim(utils:shell_exec("route -n | grep UG | head -n1 | awk '{print$8}'"))
	_networkData["GATEWAY"] = utils:trim(utils:shell_exec("route -n | grep UG | head -n1 | awk '{print$2}'"))
	_networkData["DNS"] = cjson.decode("[" .. utils:trim(utils:shell_exec("cat /tmp/resolv.conf | grep nameserver | awk -vORS=, '{ print \"\\\"\"$2\"\\\"\" }' | sed 's/,$/\\n/'")) .. "]")

	_networkData["MAC"] = utils:trim(utils:shell_exec("cat /sys/class/net/eth0/address | tr '[a-z]' '[A-Z]'"))
		
	_networkData["EMAC"] = utils:trim(utils:shell_exec("cat /sys/class/net/eth0/address | tr '[a-z]' '[A-Z]'"))
	_networkData["ECBL"] = utils:trim(utils:shell_exec("ash /etc/ethlink.sh -v"))
	_networkData["EPR"] = utils:trim(utils:shell_exec("uci get network.lan.proto"))
	_networkData["EBCST"] = utils:trim(utils:shell_exec("ifconfig " .. MYETH0 .. " 2>/dev/null | grep Bcast | awk '{print $3}' | cut -d':' -f2"))

	if (_networkData["EPR"] == "dhcp") then
		_networkData["EGW"]=(_networkData["ECBL"] == "up" and utils:trim(utils:shell_exec("route -n | grep " .. MYETH0 .. " | grep UG | awk '/default|0.0.0.0/ { print $2 }' | head -n 1")) or utils:trim(utils:shell_exec("uci get network.lan.gateway")))
		_networkData["EADR"]=(_networkData["ECBL"] == "up" and utils:trim(utils:shell_exec("ifconfig " .. MYETH0 .. " | grep \"inet addr\" | awk '{print $2}' | cut -d':' -f2")) or "0.0.0.0")
		_networkData["EMSK"]=(_networkData["ECBL"] == "up" and utils:trim(utils:shell_exec("ifconfig " .. MYETH0 .. " | grep \"Mask:\" | awk '{print $4}' | cut -d':' -f2")) or "0.0.0.0")
	else
		_networkData["EGW"]=utils:trim(utils:shell_exec("uci get network.lan.gateway"))
		_networkData["EADR"]=utils:trim(utils:shell_exec("uci get network.lan.ipaddr"))
		_networkData["EMSK"]=utils:trim(utils:shell_exec("uci get network.lan.netmask"))
	end

	_networkData["CLOUD_ENABLED"] = true

	_networkData["WMODE"] = utils:trim(utils:shell_exec("uci get wireless.@wifi-iface[0].mode"))
	if (self:wifi_disabled() == 1) then
		_networkData["WMODE"] = "off"
	end

	if (_networkData["WMODE"] == "off") then
		_networkData["WADR"] = ""
		_networkData["WBCST"] = ""
		_networkData["WMSK"] = ""
		_networkData["WMAC"] = ""
		_networkData["WCH"] = ""
		_networkData["WSSID"] = ""
		_networkData["WPWR"] = ""
	elseif (_networkData["WMODE"] == "sta") then

		local _currWlanStatus=ubus("network.interface.wlan", "status", {})

		if (_currWlanStatus["ipv4-address"] ~= nil) then
			_networkData["WSSID"] = utils:trim(utils:shell_exec("iw dev wlan0 link 2>&1 | grep -i ssid | cut -d':' -f2"))
		else
			_networkData["WSSID"] = utils:trim(utils:shell_exec("uci get wireless.@wifi-iface[0].ssid"))
		end

		_networkData["WADR"] = utils:trim(utils:shell_exec("ifconfig wlan0 | grep \"inet addr\" | awk '{print $2}' | cut -d':' -f2"))
		_networkData["WBCST"] = utils:trim(utils:shell_exec("ifconfig wlan0 | grep Bcast | awk '{print $3}' | cut -d':' -f2"))
		_networkData["WMSK"] = utils:trim(utils:shell_exec("ifconfig wlan0 | grep Mask | awk '{print $4}' | cut -d':' -f2"))		
		_networkData["WCH"] = utils:trim(utils:shell_exec("iw dev wlan0 info | grep channel | cut -d' ' -f2"))
		_networkData["WPWR"] = utils:trim(utils:shell_exec("iw dev wlan0 link 2>&1 | grep signal | cut -d':' -f2"))
		_networkData["WMAC"] = utils:trim(utils:shell_exec("ifconfig wlan0 | grep HWaddr | awk '{print $5}'"))
	else
		_networkData["WADR"] = utils:trim(utils:shell_exec("uci get network.wlan.ipaddr"))
		_networkData["WBCST"] = utils:trim(utils:shell_exec("ifconfig br-wlan | grep Bcast | awk '{print $3}' | cut -d':' -f2"))
		_networkData["WMSK"] = utils:trim(utils:shell_exec("uci get network.wlan.netmask"))
		_networkData["WMAC"] = utils:trim(utils:shell_exec("ifconfig br-wlan | grep HWaddr | awk '{print $5}'"))
		_networkData["WSSID"] = utils:trim(utils:shell_exec("uci get wireless.@wifi-iface[0].ssid"))
		_networkData["WCH"] = utils:trim(utils:shell_exec("uci get wireless.radio0.channel"))
		_networkData["WPWR"] = ""
	end

	_networkData["WPR"] = utils:trim(utils:shell_exec("uci get network.wlan.proto"))
	_networkData["WGW"] = utils:trim(utils:shell_exec("route -n | grep wlan0 | grep UG | awk '/default|0.0.0.0/ { print $2 }' | head -n 1"))
	_networkData["WENC"] = utils:trim(utils:shell_exec("uci get wireless.@wifi-iface[].encryption"))

	local _networkData_output = {}

	for k,v in utils:spairs(_networkData) do
		table.insert(_networkData_output, "\"" .. k .. "\"" .. ":" .. cjson.encode(v))
	end

	utils:writeinfile("/tmp/netdata.txt", table.concat(_networkData_output, ","))

	return _networkData
end

function network:wifi_disabled()
	return (uci:get("wireless", "radio0", "disabled") == "1" and true or false)
end

function network:wifi_status(ip)

	-- Initial delay for OS operations
	socket.sleep(5)

	local _currWlanAddress=nil
	local _currWlanStatus=nil
	local _attempts=10
	
	-- Wait max 20 seconds to acquire lease from DHCP
	while (_attempts > 0) do
		_currWlanStatus = ubus("network.interface.wlan", "status", {})
		if (_currWlanStatus["ipv4-address"] ~= nil) then
			_currWlanAddress = _currWlanStatus["ipv4-address"][1]["address"]
			break
			-- break
		else
			socket.sleep(2)
		end
		_attempts=_attempts-1
	end

	-- Check if given IP is equal to current interface address
	if ((utils:empty(ip) ~= true) and (ip == _currWlanAddress)) then
		return true
	-- Check if interface address IP is valid
	elseif (_currWlanAddress ~= nil) then
		return true
	end

	return false
end

function network:wifi_default(isBackground)
	-- Add default connectivity host check for Android
	utils:shell_exec("grep -qF -- \"192.168.10.1	connectivitycheck.gstatic.com\" \"/etc/hosts\" || echo \"192.168.10.1	connectivitycheck.gstatic.com\" >> \"/etc/hosts\"")

	uci:load("wireless")
	uci:load("network")
	uci:load("dhcp")

	-- Restore Radio if previously disabled
	if self:wifi_disabled()==true then
		uci:set("wireless", "radio0", "disabled", "0")
		-- uci:save("wireless")
	end

	-- Set Wireless Radio Interface Parameters
	uci:delete("wireless", "radio0", "ht_capab")
	uci:set_first("wireless", "radio0", "wifi-device")
	
	uci:set("wireless", "radio0", "type", "mac80211")
	uci:set("wireless", "radio0", "hwmode", "11ng")
	uci:set("wireless", "radio0", "path", "10180000.wmac")
	uci:set("wireless", "radio0", "channel", utils:trim(utils:shell_exec("lua /etc/bestchannel.lua")))

	uci:set_list("wireless", "radio0", "ht_capab", {
		"GF", "SHORT-GI-20", "SHORT-GI-40", "RX-STBC1"
	})

	uci:set("wireless", "radio0", "htmode", "HT20")
	uci:set("wireless", "radio0", "disabled", "0")

	-- Set Wireless Configuration Parameters
	uci:delete_all("wireless", "wifi-iface", nil)
	uci:section("wireless", "wifi-iface", nil, {
		encryption	= "psk2",
		mode		= "ap",
		network		= "wlan",
		device		= "radio0",
		ssid		= utils:getenvparams()["DEFAULT_WIFI_AP_SSID"] .. utils:getmacaddress_shortversion(),
		key			= utils:getenvparams()["DEFAULT_WIFI_AP_KEY"]
	})

	-- Set Network Configuration Parameters
	uci:set("network", "wlan", "proto", "static")
	uci:set("network", "wlan", "netmask", "255.255.255.0")
	uci:set("network", "wlan", "ipaddr", "192.168.10.1")
	uci:set("network", "wlan", "ifname", "wlan0")
	uci:set("network", "wlan", "type", "bridge")
	uci:delete("network", "wlan", "gateway")

	-- Enable dhcp server
	-- uci:set_first("dhcp", "ignore", "0")
	uci:tset("dhcp", "wlan", {
		ignore	= "0"
	})
	-- Enable dns server
	uci:set_first("dhcp", "dnsmasq", "port", "53")

	-- Store changes commited by UCI
	uci:commit("wireless")
	uci:commit("network")
	uci:commit("dhcp")
	uci:apply()

	-- Enforce DOWN and UP of Network Interface
	utils:shell_exec("sleep 3 && wifi down && wifi up &")

	-- Enforce Internet Check
	utils:checkInternet()

	if (isBackground == true) then
		return true
	end

	return self:wifi_status("192.168.10.1")
end

function network:wifi_ap(arg)
	-- Check method required parameters
	if (utils:empty(arg.ssid)) then 
		return false
	end

	uci:load("wireless")
	uci:load("network")
	uci:load("dhcp")

	-- Restore Radio if previously disabled
	if self:wifi_disabled()==true then
		uci:set("wireless", "radio0", "disabled", "0")
		-- uci:save("wireless")
	end
	
	-- Set Wireless Radio Interface Parameters
	uci:delete("wireless", "radio0", "ht_capab")
	uci:set_first("wireless", "radio0", "wifi-device")
	
	uci:set("wireless", "radio0", "type", "mac80211")
	uci:set("wireless", "radio0", "hwmode", "11ng")
	uci:set("wireless", "radio0", "path", "10180000.wmac")
	uci:set("wireless", "radio0", "channel", (arg.channel or "11")) -- lua /etc/bestchannel.lua

	uci:set_list("wireless", "radio0", "ht_capab", {
		"GF", "SHORT-GI-20", "SHORT-GI-40", "RX-STBC1"
	})

	uci:set("wireless", "radio0", "htmode", "HT20")
	uci:set("wireless", "radio0", "disabled", "0")

	-- Set Wireless Configuration Parameters
	uci:delete_all("wireless", "wifi-iface", nil)
	uci:section("wireless", "wifi-iface", nil, {
		mode		= "ap",
		network		= "wlan",
		device		= "radio0",
		ssid		= (arg.ssid or utils:getenvparams()["DEFAULT_WIFI_AP_SSID"] .. utils:getmacaddress_shortversion()),
		encryption	= (arg.encryption or ""),
		key			= (arg.key or "")
	})

	-- Set Network Configuration Parameters
	uci:set("network", "wlan", "proto", "static")
	uci:set("network", "wlan", "netmask", "255.255.255.0")
	uci:set("network", "wlan", "ipaddr", "192.168.10.1")
	uci:set("network", "wlan", "ifname", "wlan0")
	uci:set("network", "wlan", "type", "bridge")
	uci:delete("network", "wlan", "gateway")

	-- Enable dhcp server
	-- uci:set_first("dhcp", "ignore", "0")
	uci:tset("dhcp", "wlan", {
		ignore	= "0"
	})
	-- Enable dns server
	uci:set_first("dhcp", "dnsmasq", "port", "53")

	-- Store changes commited by UCI
	uci:commit("wireless")
	uci:commit("network")
	uci:commit("dhcp")
	uci:apply()

	-- Enforce DOWN and UP of Network Interface
	utils:shell_exec("sleep 3 && wifi down && wifi up &")

	-- Enforce Internet Check
	utils:checkInternet()

	return self:wifi_status("192.168.10.1")
end

function network:wifi_off(arg)
	uci:load("wireless")
	uci:set("wireless", "radio0", "disabled", "1")
	uci:commit("wireless")
	uci:apply()

	-- Enforce Internet Check
	utils:checkInternet()

	return true
end

function network:wifi_sta(arg)
	-- Check method required parameters
	if (utils:empty(arg.ssid)) then 
		return false
	end

	uci:load("wireless")
	uci:load("network")
	uci:load("dhcp")

	uci:set("wireless", "radio0", "disabled", "0")
	uci:set("wireless", "radio0", "channel", "auto")

	-- Disable dhcp server
	-- uci:set_first("dhcp", "ignore", "1")
	uci:tset("dhcp", "wlan", {
		ignore	= "1"
	})
	-- Disable dns server
	uci:set_first("dhcp", "dnsmasq", "port", "0")

	-- Set Wireless Configuration Parameters
	uci:delete_all("wireless", "wifi-iface", nil)
	uci:section("wireless", "wifi-iface", nil, {
		mode		= "sta",
		network		= "wlan",
		device		= "radio0",
		ssid		= (arg.ssid or utils:getenvparams()["DEFAULT_WIFI_AP_SSID"] .. utils:getmacaddress_shortversion()),
		encryption	= (arg.encryption or ""),
		key			= (arg.key or "")
	})

	-- Set Network Configuration Parameters
	uci:set("network", "wlan", "hostname", utils:getenvparams()["DEFAULT_WIFI_AP_SSID"] .. utils:getmacaddress_shortversion())
	uci:set("network", "wlan", "proto", (arg.protocol=="static" and "static" or "dhcp"))

	if (arg.protocol == "static") then
		uci:set("network", "wlan", "ipaddr", arg.ipaddr)
		uci:set("network", "wlan", "netmask", arg.netmask)
		uci:set("network", "wlan", "gateway", arg.gateway)
	else
		-- DHCP also per default
		uci:delete("network", "wlan", "netmask")
		uci:delete("network", "wlan", "ipaddr")
		uci:delete("network", "wlan", "gateway")
	end

	-- remove bridge between wan
	uci:delete("network", "wlan", "type")

	-- Store changes commited by UCI
	uci:commit("wireless")
	uci:commit("network")
	uci:commit("dhcp")
	uci:apply()

	local _operationSucceded = self:wifi_status()

	if (_operationSucceded == true) then
		-- Enforce Internet Check
		utils:checkInternet()
		return true
	else
		-- Rollback to Access Point in case of Failure
		self:wifi_default()
		return false
	end
end

function network:eth_status(ip)

	-- Initial delay for OS operations
	socket.sleep(5)

	local _currLanAddress=nil
	local _currLanStatus=nil
	local _attempts=10
	
	-- Wait max 20 seconds to acquire lease from DHCP
	while (_attempts > 0) do
		_currLanStatus = ubus("network.interface.lan", "status", {})
		if (_currLanStatus["ipv4-address"] ~= nil) then
			_currLanAddress = _currLanStatus["ipv4-address"][1]["address"]
			break
			-- break
		else
			socket.sleep(2)
		end
		_attempts=_attempts-1
	end

	-- Check if given IP is equal to current interface address
	if ((utils:empty(ip) ~= true) and (ip == _currLanAddress)) then
		return true
	-- Check if interface address IP is valid
	elseif (_currLanAddress ~= nil) then
		return true
	end

	return false
end

function network:eth_default(isBackground)
	local MYETH0="eth0.1"

	uci:load("network")
	uci:load("dhcp")

	uci:set("network", "lan", "hostname", utils:getenvparams()["DEFAULT_WIFI_AP_SSID"] .. utils:getmacaddress_shortversion())
	uci:set("network", "lan", "ifname", MYETH0)
	
	uci:set("network", "lan", "ipaddr", "192.168.0.177")
	uci:set("network", "lan", "netmask", "255.255.255.0")
	uci:set("network", "lan", "gateway", "192.168.0.116")
	uci:set("network", "lan", "proto", "static")

	uci:delete("network", "lan", "dns")
	uci:delete("network", "lan", "ip6assign")

	-- Store changes commited by UCI
	uci:commit("network")
	uci:commit("dhcp")
	uci:apply()

	utils:shell_exec("ifdown lan")
	utils:shell_exec("ifup lan")
	utils:shell_exec("wifi up radio0")

	if (isBackground == true) then
		return true
	end

	return self:eth_status("192.168.0.177")
end

function network:eth_link(arg)
	local MYETH0="eth0.1"

	-- Check method required parameters
	if (utils:empty(arg.protocol)) then 
		return false
	end

	-- Dnable dhcp server
	-- uci:set_first("dhcp", "ignore", "1")

	uci:load("network")
	uci:load("dhcp")

	uci:set("network", "lan", "hostname", utils:getenvparams()["DEFAULT_WIFI_AP_SSID"] .. utils:getmacaddress_shortversion())
	uci:set("network", "lan", "ifname", MYETH0)

	if (arg.protocol == "static") then
		if (utils:empty(arg.ipaddr)) then return false end
		if (utils:empty(arg.netmask)) then return false end
		if (utils:empty(arg.protocol)) then return false end

		uci:set("network", "lan", "ipaddr", arg.ipaddr)
		uci:set("network", "lan", "netmask", arg.netmask)
		uci:set("network", "lan", "gateway", arg.gateway)

		uci:set("network", "lan", "dns", "")
	else
		-- DHCP also per default
		uci:delete("network", "lan", "netmask")
		uci:delete("network", "lan", "ipaddr")
		uci:delete("network", "lan", "dns")
		uci:delete("network", "lan", "ip6assign")

		uci:set("network", "lan", "gateway", "0.0.0.0")
	end
	
	uci:set("network", "lan", "proto", (arg.protocol=="static" and "static" or "dhcp"))

	-- Store changes commited by UCI
	uci:commit("network")
	uci:commit("dhcp")
	uci:apply()

	utils:shell_exec("ifdown lan")
	utils:shell_exec("ifup lan")
	utils:shell_exec("wifi up radio0")

	if (arg.protocol == "static") then
		utils:shell_exec("route add default gw " .. arg.gateway)
	end

	return self:eth_status((arg.protocol=="static" and arg.ipaddr or nil))
end

function network:eth_static(arg)
	arg.protocol="static"
	return self:eth_link(arg)
end

function network:eth_dhcp()
	return self:eth_link{protocol="dhcp"}
end

return network