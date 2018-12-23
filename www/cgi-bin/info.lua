out = [[

<script>
	$(document).ready(function() {
		$.initInfo();
	});
</script>
<h1>General Info</h1>

	<div class="ui-grid-a ui-responsive">
		<div class="ui-block-a">
			<div class="ui-grid-a" >
				<div class="ui-block-a" style="text-align: center"><img src="customico/appliance.png" /></div>
				<div class="ui-block-b"><h2 id="APLCONN" hashtable="tblConnection"></h2></div>
			</div>
		</div>

		<div class="ui-block-b">
			<h4>Appliance Data</h4>
			<div class="ui-grid-a">
				<div class="ui-block-a">MBType</div>
				<div class="ui-block-b"><span id="MBTYPE"></span></div>
				<div class="ui-block-a">MOD</div>
				<div class="ui-block-b"><span id="MOD"></span></div>
				<div class="ui-block-a">VER</div>
				<div class="ui-block-b"><span id="VER"></span></div>
				<div class="ui-block-a">FWDATE</div>
				<div class="ui-block-b"><span id="FWDATE"></span></div>
			</div>
			<div class="ui-field-contain">
				<label for="LABEL">Label</label>
				<input type="text" name="LABEL" id="LABEL" value="" data-mini="true" placeholder="]] .. readfile("/etc/appliancelabel") .. [["/>
			</div>
		</div>
	</div>
	<br />

	<div class="ui-grid-a ui-responsive">
		<div class="ui-block-a">
			<div class="ui-grid-a" >
				<div class="ui-block-a" style="text-align: center"><img src="customico/cloud.png" /></div>
				<div class="ui-block-b"><h2 id="ICONN" hashtable="tblConnection"></h2></div>
			</div>
		</div>
		<div class="ui-block-b">
			<h4>Routing Data</h4>
			<div class="ui-grid-a" >
				<div class="ui-block-a">Gateway</div>
				<div class="ui-block-b"><span id="GATEWAY"></span></div>
				<div class="ui-block-a">Device</div>
				<div class="ui-block-b"><span id="GWDEVICE"></span></div>
				<div class="ui-block-a">WiFi Address</div>
				<div class="ui-block-b"><span id="WADR"></span></div>
				<div class="ui-block-a">Ethernet Address</div>
				<div class="ui-block-b"><span id="EADR"></span></div>
			</div>
		</div>
	</div>
	<br />

	<div class="ui-grid-a ui-responsive">
		<div class="ui-block-a">
			<div class="ui-grid-a" >
				<div class="ui-block-a" style="text-align: center"><img src="customico/system.png" /></div>
				<div class="ui-block-b"><h2>Running</h2></div>
			</div>
		</div>
		<div class="ui-block-b">
			<h4>CBOX Data</h4>
			<div class="ui-grid-a" >
				<div class="ui-block-a">ID</div>
				<div class="ui-block-b"><span>]] .. readfile("/etc/macaddr") .. [[</span></div>
				<div class="ui-block-a">Type</div>
				<div class="ui-block-b"><span id="CBTYPE"></span></div>
				<div class="ui-block-a">System</div>
				<div class="ui-block-b"><span id="SYSTEM"></span></div>
				<div class="ui-block-a">plzbridge</div>
				<div class="ui-block-b"><span id="PLZBRIDGE"></span></div>
				<div class="ui-block-a">sendmsg</div>
				<div class="ui-block-b"><span id="SENDMSG"></span></div>
				<div class="ui-block-a">USB</div>
				<div class="ui-block-b">]]
	if file_exists("/mnt/sda1/USB_NOT_MOUNTED") then
		out = out .. 'USB NOT MOUNTED'
	else
		out = out .. 'USB MOUNTED'
	end

out = out .. [[
				</div>

				<div class="ui-block-a">Browser Clock</div>
				<div class="ui-block-b"><span id="spBrowserTime"></span></div>

				<div class="ui-block-a"><p style="vertical-align: middle;">System Clock</p></div>
				<div class="ui-block-b"><span id="spSystemTime">]] .. getTS() .. [[</span> <a id="btClockSync" href="#" data-role="button" data-icon="arrow-r" data-mini="true" data-inline="true">Sync</a></div>

]]

				if (file_exists("/etc/patch") and (fsize("/etc/patch")>0)) then
					out = out .. [[
					<div class="ui-block-a">Applied patches</div>
					<div class="ui-block-b ui-mini">]] .. readfile("/etc/patch") .. [[</div>
					]]
				end

out = out .. [[
			</div>
		</div>
	</div>

]]

return out