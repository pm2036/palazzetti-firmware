out = [[

	<ul id="lvMenu" data-role="listview">
		<li><a id="menu_info" class="menulink" data-rel="close" href="#info">General Info</a></li>
		<li data-role="list-divider">Network settings</li>
		<li><a data-rel="close" class="menulink" href="#wifi">Wifi</a></li>
		<li><a data-rel="close" class="menulink" href="#eth">Ethernet</a></li>
		<li data-role="list-divider">Appliance</li>
		<li><a id="menuMonitor" data-rel="close" class="menulink" href="#monitor">Monitor  <span id="noCommIcon" class="ui-btn-icon-notext ui-icon-alert" style="display: none" /><span class="reading ui-li-count" style="display: none"><img src="img/timer.gif"></span></a></li>
		<li><a data-rel="close" class="menulink" href="#user">User settings</a></li>
		<li><a data-rel="close" class="menulink" href="#counters">Counters</a></li>
]]
	pid = tonumber(shell_exec("ps | grep [/etc/syslog]ger.lua | awk '{print $1}' | wc -l"))
	out = out .. [[ <li><a data-rel="close" class="menulink" href="#logger">Logger ]]  if (pid>0) then out = out .. [[<span class="ui-li-count">running</span>]] end out = out .. [[</a></li>]]

out = out .. [[
		<li data-role="list-divider">Service</li>
		<li><a data-rel="close" class="menulink" href="#update">Update</a></li>

	</ul>
]]

return out
