isMassStorage = not file_exists("/mnt/sda1/USB_NOT_MOUNTED")

if (not isMassStorage) then
	out = "<h1>Logger</h1> Not valid USB flash drive"
	return out
end

if fsize("/tmp/loggersplitsec")<=0 then
	os.execute("echo 86400 > /tmp/loggersplitsec")
end


out = [[
<script>
	$(document).ready(function() {
		$.loggerInit();
	});
</script>

			<div class="ui-grid-a ui-responsive">

				<div class="ui-block-a">
					<h1>Logger</h1>
					<select id="loggerswitch" name="loggerswitch" data-role="flipswitch">
]]
						pid = tonumber(shell_exec("ps | grep [/etc/syslog]ger.lua | awk '{print $1}' | wc -l"))
						if pid>0 then
out = out .. [[
				        <option value="0">Off</option>
				        <option value="1" selected>On</option>
]]
						else
out = out .. [[
				        <option value="0" selected>Off</option>
				        <option value="1" >On</option>
]]

						end


out = out .. [[

				    

				    </select>
				</div>

				<div class="ui-block-b">

				</div>

			</div>
]]

		splitperiod = tonumber(readfile("/tmp/loggersplitsec"))/86400
		if splitperiod<1 then
			splitperiod = 1
		end

out = out .. [[
			<div data-role="fieldcontain">
			   <label for="SPLITPERIOD">Split Period (days)</label>
			   <input type="range" name="SPLITPERIOD" id="SPLITPERIOD" value="]] .. splitperiod .. [[" min="1" max="31" data-highlight="true" />
			</div>

			<div class="ui-field-contain">
				<ul id="csvlistview" class="ulalternate" data-role="listview" data-count-theme="b" data-inset="true">
]]
	str=shell_exec("ls -lteh /mnt/sda1/*.csv  | awk '{ print $11 \";\" $5 \";\" $6 \" \" $7 \" \" $8 \" \" $9 \" \" $10}'")
	ln=str:split("\n")
	res = {}
	for i=1,#ln do
		t=ln[i]:split(";")
		res[i] = {}
		res[i]["filename"]=t[1]
		res[i]["size"]=t[2]
		res[i]["fdate"]=t[3]
	end

	for i=1,#res do
		filename = GetFileName(res[i]["filename"])
		size = res[i]["size"]
		fdate = res[i]["fdate"]

		out = out .. [[

			<li>
				<a href="syscmd.lua?cmd=dwlcsv&csvfile=]] .. filename .. [[" rel="external">
					<div class="ui-grid-a" data-type="horizontal">
						<div class="ui-block-a" style="width: 3em"><button csvfile="]] .. filename .. [[" class="delFile" data-role="button" data-icon="delete" data-iconpos="notext" style="float: left">Delete</button></div>
						<div class="ui-block-b clCsvFile"><span class="">]] .. filename .. [[</span></div>
						<div class="ui-block-c clCsvFile"><span class="">]] .. size .. [[ - ]] .. fdate .. [[</span></div>
					</div>
				</a>
			</li>
		]]

	end

out = out .. [[
				</ul>
			</div>
]]

return out