jdata = cjson.decode(sendmsg("GET CNTR"))
out = [[
<script>
	$(document).ready(function() {
		$.globalInit();
	});
</script>

	<div class="ui-grid-a ui-responsive">
		<h1>Counters</h1>

		<div class="ui-corner-all custom-corners" style="font-size: 0.8em; margin-bottom: 1em;">
			<div class="ui-bar ui-bar-a">
				<h3>Quantity of Pellet</h3>
			</div>
			<div class="ui-body ui-body-a">
				<div class="ui-grid-a" data-mini="true">
					<div class="ui-block-a">Quantity of Pellet [kg]</div>
					<div class="ui-block-b cellRight">]] .. jdata['DATA']['PQT'] .. [[</div>
				</div><!-- /grid-a -->
			</div>
		</div>

		<div class="ui-corner-all custom-corners" style="font-size: 0.8em; margin-bottom: 1em;">
			<div class="ui-bar ui-bar-a">
				<h3>Counters</h3>
			</div>
			<div class="ui-body ui-body-a">
				<div class="ui-grid-a" data-mini="true">
					<div class="ui-block-a">Number of ignitions</div>
					<div class="ui-block-b cellRight">]] .. jdata['DATA']['IGN'] .. [[</div>
				</div><!-- /grid-a -->
			</div>
		</div>

		<div class="ui-corner-all custom-corners" style="font-size: 0.8em; margin-bottom: 1em;">
			<div class="ui-bar ui-bar-a">
				<h3>Timers [hh:mm]</h3>
			</div>
			<div class="ui-body ui-body-a">
				<div class="ui-grid-a" data-mini="true">
					<div class="ui-block-a">Power time</div>
					<div class="ui-block-b cellRight">]] .. jdata['DATA']['POWERTIME'] .. [[</div>
					<div class="ui-block-a">Heat time</div>
					<div class="ui-block-b cellRight">]] .. jdata['DATA']['HEATTIME'] .. [[</div>
					<div class="ui-block-a">Service time</div>
					<div class="ui-block-b cellRight">]] .. jdata['DATA']['SERVICETIME'] .. [[</div>
					<div class="ui-block-a">ON time</div>
					<div class="ui-block-b cellRight">]] .. jdata['DATA']['ONTIME'] .. [[</div>
				</div><!-- /grid-a -->
			</div>
		</div>

		<div class="ui-corner-all custom-corners" style="font-size: 0.8em; margin-bottom: 1em;">
			<div class="ui-bar ui-bar-a">
				<h3>Error Counters</h3>
			</div>
			<div class="ui-body ui-body-a">
				<div class="ui-grid-a" data-mini="true">
					<div class="ui-block-a">Overtemperature Errors</div>
					<div class="ui-block-b cellRight">]] .. jdata['DATA']['OVERTMPERRORS'] .. [[</div>
					<div class="ui-block-a">Ignition Errors</div>
					<div class="ui-block-b cellRight">]] .. jdata['DATA']['IGNERRORS'] .. [[</div>
				</div><!-- /grid-a -->
			</div>
		</div>

	</div>

]]

return out