out = [[

<script>
	$(document).ready(function() {
		$.initEth();
	});
</script>

			<form autocomplete="off" method="post" action="syscmd.lua?cmd=seteth" name="frmSETeth" id="frmSETeth" autocomplete="off">
			<div class="ui-grid-a ui-responsive">

				<div class="ui-block-a">
					<h1> Ethernet Settings</h1>
				</div>

				<div class="ui-block-b">
					<h4>Ethernet Data</h4>
					<div class="ui-grid-a" >
						<div class="ui-block-a">Address</div>
						<div class="ui-block-b EADR"></div>
						<div class="ui-block-a">Broadcast</div>
						<div class="ui-block-b EBCST"></div>
						<div class="ui-block-a">Netmask</div>
						<div class="ui-block-b EMSK"></div>
						<div class="ui-block-a">MAC</div>
						<div class="ui-block-b EMAC"></div>
						<div class="ui-block-a">Proto</div>
						<div class="ui-block-b EPR"></div>
						<div class="ui-block-a">Gateway</div>
						<div class="ui-block-b EGW"></div>
						<div class="ui-block-a">Cable</div>
						<div class="ui-block-b ECBL"></div>

					</div>
				</div>

			</div>

			<div class="ui-field-contain">
				<label for="EPR" class="select">Ethernet mode</label>
				<select data-native-menu="false" id="EPR" name="EPR">
					<option value="dhcp">Automatic (DHCP)</option>
					<option value="static">Static</option>
				</select>
			</div>
			<div id="ETH0_STATIC_DATA" style="display: none">
				<div class="ui-field-contain">
					<label for="EADR" class="select">Address</label>
					<input type="text" class="ipformat" name="EADR" id="EADR" value="" placeholder="" />
				</div>
				<div class="ui-field-contain">
					<label for="EMSK" class="select">Netmask</label>
					<input type="text" class="ipformat" name="EMSK" id="EMSK" value="" placeholder="" />
				</div>
				<div class="ui-field-contain">
					<label for="EGW" class="select">Gateway</label>
					<input type="text" class="ipformat" name="EGW" id="EGW" value="" placeholder="" />
				</div>
			</div>

			<input id="btEthApply" type="submit" value="Apply" />
]]

return out


