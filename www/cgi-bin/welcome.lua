cbtype = shell_exec("ash /etc/myboard.sh")

out = [[

<h1>Welcome</h1>

	<a class="menulink ui-btn ui-shadow" href="#wifi" >Set WiFi</a>
	<a class="menulink ui-btn ui-shadow" hrhref="#eth">Set Ethernet</a>
	<br/>
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
				<div class="ui-block-a">LABEL</div>
				<div class="ui-block-b"><span>]] .. readfile("/etc/appliancelabel") .. [[</span></div>
				<div class="ui-block-a">Type</div>
				<div class="ui-block-b"><span id="CBTYPE">]] .. trim(shell_exec("ash /etc/myboard.sh")) .. [[</span></div>
				<div class="ui-block-a">System</div>
				<div class="ui-block-b"><span id="SYSTEM">]] .. readfile("/etc/systemver") .. [[</span></div>
				<div class="ui-block-a">USB</div>
				<div class="ui-block-b">]]
	if file_exists("/mnt/sda1/USB_NOT_MOUNTED") then
		out = out .. 'USB NOT MOUNTED'
	else
		out = out .. 'USB MOUNTED'
	end

out = out .. [[
				</div>

]]

return out