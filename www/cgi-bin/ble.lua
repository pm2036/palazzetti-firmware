out = [[

<script>
	$(document).ready(function() {
		$.initBle();
	});
</script>

			<form autocomplete="off" method="post" action="syscmd.lua?cmd=setbledev" name="frmSETble" id="frmSETble" autocomplete="off">
			<div class="ui-grid-a ui-responsive">
				<div class="ui-block-a">
					<h1>Bluetooth Settings</h1>
				</div>
			</div>

			<div id="BLE_BASIC_DATA" class="ui-field-contain" style="padding-left: 1em;">

				<ul data-role="listview" data-inset="true" class="ulalternate blelistview" data-count-theme="b" id="BLE_LIST"></ul>

				<div class="ui-field-contain ble_data_entry" id="BLE_SETUP_DATA" style="display: none">
					<div class="ui-field-contain">
						<label for="MAC">MAC</label>
						<input maxlength="64" type="text" name="MAC" id="BMAC" class="bledata" value="" readonly="true" />
					</div>
					<div class="ui-field-contain">
						<label for="BLOCATION">Location</label>
						<select name="LOCATION" id="BLOCATION" data-native-menu="false" >
							<option value="-1">-</option>
							<option value="36">MAIN</option>
							<option value="37">LEFT</option>
							<option value="38">RIGHT</option>
						</select>
					</div>
				</div>

			</div> <!-- BLE_BASIC_DATA -->

			<div class="ble_data_entry" style="display: none">
				<input id="btBleApply" type="submit" value="Apply" />
				<input id="btBleDelete" type="submit" value="Delete" formaction="syscmd.lua?cmd=delbledev" />
			</div>
			</form>
]]

return out