out = [[
<html>
<head>
	<meta charset="utf-8">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<meta name="apple-mobile-web-app-capable" content="yes">
	<meta name="apple-mobile-web-app-status-bar-style" content="black">
	<meta name="mobile-web-app-capable" content="yes">
	<?=META_THEMECOLOR?>
	<meta name="HandheldFriendly" content="True" />
	<link rel="apple-touch-icon" href="./customico/appliance.png" />

	<title>]] .. CBOXPARAMS["MAINTITLE"] .. [[</title>

	<link rel="shortcut icon" href="favicon.ico">

	<link rel="stylesheet" href="themes/labtools.min.css" />
	<link rel="stylesheet" href="themes/jquery.mobile.icons.min.css" />
	<link rel="stylesheet" href="themes/jquery.mobile.structure-1.4.5.min.css" />

	<link rel="stylesheet" href="assets/custom.css" />

	<script src="js/jquery-1.12.3.min.js"></script>
	<script src="js/jquery.mobile-1.4.5.min.js"></script>

	<link href="assets/jtsage-datebox.min.css" rel="stylesheet" type="text/css">
	<script src="js/jtsage-datebox.min.js" type="text/javascript"></script>

	<script src="js/mainlib.js"></script>
	<script src="js/custom.js"></script>

</head>
<body>
	<div data-role="popup" id="toast" class="mypopup"><p>Done</p></div>

	<div id="mainpage" data-role="page" data-theme="a">
		<div id="pnMenu" data-role="panel" data-display="overlay" data-theme="d">
		</div>

		<div id="mainheader" data-role="header" data-position="inline" data-theme="a">
			<a id="btMenu" href="#pnMenu" class="ui-alt-icon ui-btn ui-icon-bars ui-nodisc-icon ui-btn-icon-left ui-btn-icon-notext">Menu</a>
			<img src="img/logo.png" class="logo" onClick="window.location='.'">
			<h1></h1>
			<div class="ui-btn-right" data-role="controlgroup" data-type="horizontal">
				<span class="version">v]] .. CBOXPARAMS["UIVERSION"] .. [[</style>
				<span class="reading" style="display: none"><img src="img/timer.gif"></span>
			</div>
		</div>

		<div id="maincontent" data-role="content" data-theme="a">
]]

out = out .. loadcontent("/welcome.lua")

out = out .. [[

		</div>

	</div>
</body>
</html>

]]

return out