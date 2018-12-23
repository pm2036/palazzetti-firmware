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
					<div class="ui-block-b cellRight">]] .. (jdata['DATA']['PQT']~=nil and jdata['DATA']['PQT'] or "-") .. [[</div>
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
					<div class="ui-block-b cellRight">]] .. (jdata['DATA']['IGN']~=nil and jdata['DATA']['IGN'] or "-") .. [[</div>
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
					<div class="ui-block-b cellRight">]] .. (jdata['DATA']['POWERTIME']~=nil and jdata['DATA']['POWERTIME'] or "-") .. [[</div>
					<div class="ui-block-a">Heat time</div>
					<div class="ui-block-b cellRight">]] .. (jdata['DATA']['HEATTIME']~=nil and jdata['DATA']['HEATTIME'] or "-") .. [[</div>
					<div class="ui-block-a">Service time</div>
					<div class="ui-block-b cellRight">]] .. (jdata['DATA']['SERVICETIME']~=nil and jdata['DATA']['SERVICETIME'] or "-") .. [[</div>
					<div class="ui-block-a">ON time</div>
					<div class="ui-block-b cellRight">]] .. (jdata['DATA']['ONTIME']~=nil and jdata['DATA']['ONTIME'] or "-") .. [[</div>
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
					<div class="ui-block-b cellRight">]] .. (jdata['DATA']['OVERTMPERRORS']~=nil and jdata['DATA']['OVERTMPERRORS'] or "-") .. [[</div>
					<div class="ui-block-a">Ignition Errors</div>
					<div class="ui-block-b cellRight">]] .. (jdata['DATA']['IGNERRORS']~=nil and jdata['DATA']['IGNERRORS'] or "-") .. [[</div>
				</div><!-- /grid-a -->
			</div>
		</div>

	</div>

]]

return out