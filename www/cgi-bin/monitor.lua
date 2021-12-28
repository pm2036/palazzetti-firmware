local sendmsg = require "palazzetti.sendmsg"
json = cjson.decode(sendmsg:execute{command="GET STDT"})
jdata = json["DATA"]


out = [[
<script>
	$(document).ready(function() {
		$("#mainpage").trigger('create');
		$.monitorInit();
	});
</script>

	<div class="ui-grid-a ui-responsive">
		<h1>Appliance Monitor</h1>

		<div class="ui-corner-all custom-corners" style="font-size: 0.8em; margin-bottom: 1em;">
			<div class="ui-bar ui-bar-a">
				<h3>Appliance data</h3>
			</div>
			<div class="ui-body ui-body-a">
				<div class="ui-grid-a" data-mini="true">
					<div class="ui-block-a">Stove</div>
					<div class="ui-block-b">]] .. jdata['LABEL'] .. [[ <strong>mod]] .. jdata['MOD'] .. [[</strong> ver]] .. jdata['VER'] .. [[ ]] .. jdata['FWDATE'] .. [[</div>
					<div class="ui-block-a">Serial number</div>
					<div class="ui-block-b">]] .. jdata['SN'] .. [[</div>
					<div class="ui-block-a">Pellet type</div>
					<div class="ui-block-b">]] .. (jdata['PELLETTYPE']~=nil and jdata['PELLETTYPE'] or "-") .. [[</div>
					<div class="ui-block-a">Configuration</div>
					<div class="ui-block-b">]] .. (jdata['CONFIG']~=nil and jdata['CONFIG'] or "-") .. [[</div>
					<div class="ui-block-a">Nominal power</div>
					<div class="ui-block-b">]] .. jdata['NOMINALPWR'] .. [[kW</div>
					<div class="ui-block-a">Stove type</div>
					<div class="ui-block-b">]] .. getStoveTypeStr(jdata['STOVETYPE']) .. [[</div>
					<div class="ui-block-a">Fluid type</div>
					<div class="ui-block-b">]] .. getFluidStr(jdata['FLUID']) .. [[</div>
					<div class="ui-block-a">RoomFAN type</div>
					<div class="ui-block-b">]] .. getFAN2TypeStr(jdata['FAN2TYPE']) .. [[</div>

				</div><!-- /grid-a -->
			</div>
		</div>


		<div class="ui-block-a" style="margin-bottom: 1em;">
			<div class="ui-grid-a mygrid">
				<div class="ui-block-a"><div class="ui-bar ui-bar-a"><h3>Status</h3></div></div>
				<div class="ui-block-b"><div class="ui-bar ui-bar-b"><span id="STATUS">&nbsp;</span></div></div>]]
				if ((jdata['MOD']>500) and (jdata['MOD']<600)) then
					out = out .. [[
				<div class="ui-block-a"><div class="ui-bar ui-bar-a"><h3>MultiFire Status</h3></div></div>
				<div class="ui-block-b"><div class="ui-bar ui-bar-b"><span id="MFSTATUS">&nbsp;</span></div></div>]]
				end
out = out .. [[
			</div>
		</div>

		<div class="ui-block-b" style="margin-bottom: 1em;">
			<div class="ui-grid-a">
				<div class="ui-grid-solo">
					<div class="ui-grid-a ui-responsive">
						<div class="ui-block-a divleds" id="IN">
							<div class="ledcontainer">i01<div class="led led-off" id="IN1"></div></div>
							<div class="ledcontainer">i02<div class="led led-off" id="IN2"></div></div>]]
							if (jdata['MBTYPE']==0) then
								out = out .. [[
							<div class="ledcontainer">i03<div class="led led-off" id="IN3"></div></div>
							<div class="ledcontainer">i04<div class="led led-off" id="IN4"></div></div>]]
							end
out = out .. [[
						</div>

						<div class="ui-block-b divleds" id="OUT">
							<div class="ledcontainer">o01<div class="led led-off" id="OUT1"></div></div>
							<div class="ledcontainer">o02<div class="led led-off" id="OUT2"></div></div>
							<div class="ledcontainer">o03<div class="led led-off" id="OUT3"></div></div>
							<div class="ledcontainer">o04<div class="led led-off" id="OUT4"></div></div>]]
							if (jdata['MBTYPE']==0) then
								out = out .. [[
							<div class="ledcontainer">o05<div class="led led-off" id="OUT5"></div></div>
							<div class="ledcontainer">o06<div class="led led-off" id="OUT6"></div></div>
							<div class="ledcontainer">o07<div class="led led-off" id="OUT7"></div></div>]]
							end
out = out .. [[
						</div>
					</div>
				</div>
			</div>
		</div>

		<div class="ui-block-a">
			<div class="ui-grid-a mygrid">

				<div class="ui-block-a"><div class="ui-bar ui-bar-a"><h3>Exhaust</h3></div></div>
				<div class="ui-block-b"><div class="ui-bar ui-bar-b"><span id="T3">&nbsp;</span>°C</div></div>

				<div class="ui-block-a"><div class="ui-bar ui-bar-a"><h3>T01</h3></div></div>
				<div class="ui-block-b"><div class="ui-bar ui-bar-b"><span id="T1">&nbsp;</span>°C</div></div>

				<div class="ui-block-a"><div class="ui-bar ui-bar-a"><h3>T02</h3></div></div>
				<div class="ui-block-b"><div class="ui-bar ui-bar-b"><span id="T2">&nbsp;</span>°C</div></div>

				<div class="ui-block-a"><div class="ui-bar ui-bar-a"><h3>T05</h3></div></div>
				<div class="ui-block-b"><div class="ui-bar ui-bar-b"><span id="T5">&nbsp;</span>°C</div></div>

				<div class="ui-block-a"><div class="ui-bar ui-bar-a"><h3>T04</h3></div></div>
				<div class="ui-block-b"><div class="ui-bar ui-bar-b"><span id="T4">&nbsp;</span>°C</div></div>

			</div>
			<br />
			<div class="ui-grid-a mygrid">

				<div class="ui-block-a"><div class="ui-bar ui-bar-a"><h3>Setpoint</h3></div></div>
				<div class="ui-block-b"><div class="ui-bar ui-bar-b"><span id="SETP">&nbsp;</span>°C</div></div>

				<div class="ui-block-a"><div class="ui-bar ui-bar-a"><h3>Power set</h3></div></div>
				<div class="ui-block-b"><div class="ui-bar ui-bar-b"><span id="PWR">&nbsp;</span></div></div>

				<div class="ui-block-a"><div class="ui-bar ui-bar-a"><h3>Feeder</h3></div></div>
				<div class="ui-block-b"><div class="ui-bar ui-bar-b"><span id="FDR">&nbsp;</span>s</div></div>


			</div>
		</div>

		<div class="ui-block-b" >
			<div class="ui-grid-a mygrid">]]

				if (jdata['MBTYPE']==0) then
					out = out .. [[
				<div class="ui-block-a"><div class="ui-bar ui-bar-a"><h3>Delta Pressure</h3></div></div>
				<div class="ui-block-b"><div class="ui-bar ui-bar-b"><span id="DP">&nbsp;</span></div></div>

				<div class="ui-block-a"><div class="ui-bar ui-bar-a"><h3>Target Pressure</h3></div></div>
				<div class="ui-block-b"><div class="ui-bar ui-bar-b"><span id="DPT">&nbsp;</span></div></div>]]
				end
out = out .. [[
				<div class="ui-block-a"><div class="ui-bar ui-bar-a"><h3>ExhFAN RPM</h3></div></div>
				<div class="ui-block-b"><div class="ui-bar ui-bar-b"><span id="F1RPM">&nbsp;</span></div></div>]]

				if (jdata['MBTYPE']==0) then
					out = out .. [[
				<div class="ui-block-a"><div class="ui-bar ui-bar-a"><h3>ExhFAN V</h3></div></div>
				<div class="ui-block-b"><div class="ui-bar ui-bar-b"><span id="F1V">&nbsp;</span></div></div>]]
				end

out = out .. [[
				<div class="ui-block-a"><div class="ui-bar ui-bar-a"><h3>RoomFAN Level</h3></div></div>
				<div class="ui-block-b"><div class="ui-bar ui-bar-b"><span id="F2L">&nbsp;</span></div></div>

				<div class="ui-block-a"><div class="ui-bar ui-bar-a"><h3>RoomFAN V</h3></div></div>
				<div class="ui-block-b"><div class="ui-bar ui-bar-b"><span id="F2V">&nbsp;</span></div></div>
			</div>

		</div>
	</div>

]]

return out