local sendmsg = require "palazzetti.sendmsg"
jdata = cjson.decode(sendmsg:execute{command="GET STDT"})

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

	</div>
]]

return out