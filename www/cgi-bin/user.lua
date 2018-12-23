jdata = cjson.decode(sendmsg("GET STDT"))

out = [[
<script>
	$(document).ready(function() {
		$.userInit();
	});
</script>

	<div class="ui-grid-a ui-responsive">
		<h1>User settings</h1>

		<div class="ui-body ui-body-a ui-corner-all">
			<div data-role="fieldcontain">
			   <label for="STATUS">Status</label>
			   <div id="STATUS"></div>
			</div>

			<div data-role="fieldcontain">
				<label for="CMDONOFF">Switch ON/OFF</label>
				<select class="immediate" cmd="CMD" prm="" id="CMDONOFF" name="CMDONOFF" data-role="flipswitch">
					<option value="OFF">Off</option>
					<option value="ON">On</option>
				</select>
			</div>
		</div>
		<br />

		<div class="ui-body ui-body-a ui-corner-all">
			<div data-role="fieldcontain">
			   <label for="SETP">Setpoint (°C)</label>
			   <input class="immediate" type="range" cmd="SET" prm="SETP" name="SETP" id="SETP" value="0" min="5" max="51" data-highlight="true" />
			</div>

			<div data-role="fieldcontain">
			   <label for="PWR">Power</label>
			   <input class="immediate" type="range" cmd="SET" prm="POWR" name="PWR" id="PWR" value="1" min="1" max="5" data-highlight="true" />
			</div>

			<div data-role="fieldcontain">
			   <label for="F2L">Room FAN</label>
				<select class="immediate" cmd="SET" prm="RFAN" id="F2L" name="F2L" >
					<option value="7">Off</option>
					<option value="1">1</option>
					<option value="2">2</option>
					<option value="3">3</option>
					<option value="4">4</option>
					<option value="5">5</option>
					<option value="0">Auto</option>
					<option value="6">Hi</option>
				</select>
			</div>
		</div>

		<br />


		<div class="ui-body ui-body-a ui-corner-all">
			<div data-role="fieldcontain">
				<label for="CMDTMR">ChronoTimer</label>
				<select class="immediate" cmd="SET" prm="CSST" id="CHRSTATUS" name="CHRSTATUS" data-role="flipswitch">
					<option value="0">Off</option>
					<option value="1">On</option>
				</select>
			</div>


			<table data-role="table" class="ui-responsive ui-shadow" id="">
			  <thead>
				<tr>
				  <th></th>
				  <th>Setpoint</th>
				  <th>Start</th>
				  <th>Stop</th>
				</tr>
			  </thead>
			  <tbody>
]]

local i=1

repeat

out = out .. [[

				<tr>
					<th>P]]..i..[[</th>
					<td>
						<input class="immediate clNumber" type="number" cmd="SET" prm="CPRD" name="P]]..i..[[CHRSETP" id="P]]..i..[[CHRSETP" value="5" min="5" max="51" data-highlight="true" />
					</td>
					<td>
						<input class="immediate clNumber" type="text" data-role="datebox" data-options='{"mode":"timeflipbox"}' cmd="SET" prm="CPRD" name="P]]..i..[[START" id="P]]..i..[[START">
					</td>
					<td>
						<input class="immediate clNumber" type="text" data-role="datebox" data-options='{"mode":"timeflipbox"}' cmd="SET" prm="CPRD" name="P]]..i..[[STOP" id="P]]..i..[[STOP">
					</td>
				</tr>
]]
i = i + 1
until( i > 6 )

out = out .. [[
			  </tbody>
			</table>

			<table style="margin-top: 1em;" data-role="table" class="ui-responsive ui-shadow" id="">
			  <thead>
				<tr>
				  <th></th>
				  <th>MEM1</th>
				  <th>MEM2</th>
				  <th>MEM3</th>
				</tr>
			  </thead>
			  <tbody>
			  ]]

days = {"MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"}
i=1
repeat
out = out .. [[
				<tr>
					<th>]] .. days[i] .. [[</th>]]
		c=1
		repeat
			out = out .. [[
					<td>
						<select class="immediate" cmd="SET" prm="CDAY ]] .. i .. [[ ]] .. c .. [[" id="D]]..i..[[M]]..c..[[" name="D]]..i..[[M]]..c..[[" data-native-menu="false">
							<option value="0">OFF</option>
							<option value="1">P1</option>
							<option value="2">P2</option>
							<option value="3">P3</option>
						</select>
					</td>]]
		c = c + 1
		until (c>3)
		out = out .. [[
				</tr>]]
i = i + 1
until (i>7)
out = out .. [[
			  </tbody>
			</table>

		</div>
	</div>
]]

return out