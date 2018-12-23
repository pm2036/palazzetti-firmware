out = [[
<script>
	$(document).ready(function() {
		$.updateInit();
	});
</script>

<h1>Update</h1>

<form class="myform" action="syscmd.lua?cmd=update" method="post" enctype="multipart/form-data">
	<label for="file">CBOX <strong>update file</strong></label>
	<input type="file" name="patchfile" id="patchfile" value="">
	<input type="submit" value="Send" name="submit">
</form>

]]

return out