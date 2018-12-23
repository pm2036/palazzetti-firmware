out = [[

<script>
	$(document).ready(function() {
		$.initWifi();
	});
</script>

			<form autocomplete="off" method="post" action="syscmd.lua?cmd=setwifi" name="frmSETwifi" id="frmSETwifi" autocomplete="off">
			<div class="ui-grid-a ui-responsive">

				<div class="ui-block-a">
					<h1>Wifi Settings</h1>
				</div>

				<div class="ui-block-b">
					<h4>WIFI Data</h4>
					<div class="ui-grid-a" >
						<div class="ui-block-a">Address</div>
						<div class="ui-block-b WADR"></div>
						<div class="ui-block-a">Broadcast</div>
						<div class="ui-block-b WBCST"></div>
						<div class="ui-block-a">Netmask</div>
						<div class="ui-block-b WMSK"></div>
						<div class="ui-block-a">MAC</div>
						<div class="ui-block-b WMAC"></div>
						<div class="ui-block-a">Proto</div>
						<div class="ui-block-b WPR"></div>
						<div class="ui-block-a">Gateway</div>
						<div class="ui-block-b WGW"></div>
						<div class="ui-block-a">Mode</div>
						<div class="ui-block-b WMODE"></div>
						<div class="ui-block-a">Channel</div>
						<div class="ui-block-b WCH"></div>
						<div class="ui-block-a">SSID</div>
						<div class="ui-block-b WSSID"></div>
						<div class="ui-block-a">Encryption</div>
						<div class="ui-block-b WENC"></div>
						<div class="ui-block-a">Power</div>
						<div class="ui-block-b WPWR"></div>

					</div>
				</div>

			</div>

			<div class="ui-field-contain">
				<label for="WMODE">Wireless mode</label>
				<select name="WMODE" id="WMODE" data-native-menu="false" >
					<option value="ap">Access Point</option>
					<option value="default">DEFAULT</option>
]]

if (CBOXPARAMS["WIFIAP_ONLY"]==0) then

out = out .. [[
					<option value="sta">Client</option>
					<option value="off">OFF</option>
]]
end

out = out .. [[

				</select>
			</div>

			<div id="WIFI_BASIC_DATA" class="ui-field-contain" style="padding-left: 1em; display: none">

				<div class="ui-field-contain" id="WIFI_SCANLIST_DATA" style="display: none">

					<fieldset data-role="controlgroup" data-type="horizontal">
						<legend>Detected networks</legend>
						<a id="WIFI_SCAN" class="syscmd" cmd="wifiscan" href="#" data-inline="true" data-role="button" data-icon="recycle" data-mini="true">Scan</a>
					</fieldset>
					<fieldset data-mini="true">
						<ul id="WIFI_WLIST" class="ulalternate wifilistview" data-role="listview" data-count-theme="b" data-inset="true"></ul>
					</fieldset>

				</div>

				<div class="ui-field-contain">
					<label for="WSSID">SSID</label>
					<input maxlength="32" type="text" name="WSSID" id="WSSID" class="wifidata" value=""  />
				</div>
				<div class="ui-field-contain">
					<label for="WENC">Encryption</label>
					<select name="WENC" id="WENC" data-native-menu="false" >
						<option value="none" >none</option>
						<option value="wep">WEP</option>
						<option value="psk">WPA PSK</option>
						<option value="psk2">WPA2 PSK</option>
					</select>
				</div>
				<div class="ui-field-contain">
					<label for="WIFI_KEY">Password</label>
					<input maxlength="32" type="text" name="WIFI_KEY" id="WIFI_KEY" class="wifidata" value=""  />
				</div>
				<div class="ui-field-contain">
					<label for="WCH">Channel</label>

					<select name="WCH" id="WCH" >
]]

							for i=1,13 do
								out = out .. "<option value=\"" .. i .. "\">" .. i .. "</option>\n"
							end
out = out .. [[
					</select>
				</div>

				<div id="WLAN0_SELECT_STDATA">

					<div class="ui-field-contain">
						<label for="WPR">Proto</label>
						<select name="WPR" id="WPR" data-native-menu="false" >
							<option value="dhcp">Automatic (DHCP)</option>
							<option value="static">Static</option>
						</select>
					</div>

					<div id="WLAN0_STATIC_DATA" style="padding-left: 1em;">

						<div class="ui-field-contain">
							<label for="WADR">IP</label>
							<input maxlength="15" type="text" name="WADR" id="WADR" class="ipformat" value=""  />
						</div>

						<div class="ui-field-contain">
							<label for="WMSK">Netmask</label>
							<input maxlength="15" type="text" name="WMSK" id="WMSK" class="ipformat" value=""  />
						</div>

						<div class="ui-field-contain">
							<label for="WGW">Gateway</label>
							<input maxlength="15" type="text" name="WGW" id="WGW" class="ipformat" value=""  />
						</div>

					</div>
				</div>

			</div> <!-- WIFI_BASIC_DATA -->

			<input id="btWifiApply" type="submit" value="Apply" />
			</form>
]]

return out