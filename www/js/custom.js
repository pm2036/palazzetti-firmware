
var sampleTime = 10000;

var seqInterval;
var seqStepTimeout;
var seqTimeout = 5000;

var clockInterval;


$.statusString = function(status) {
		switch (status) {

			case 0:
				return 'OFF';
			case 1:
				return 'OFF TIMER';
			case 2:
				return 'TESTFIRE';
			case 3:
				return 'HEATUP';
			case 4:

				return 'FUELIGN';
			case 5:
				return 'IGNTEST';
			case 6:
				return 'BURNING';
			case 9:
				return 'COOLFLUID';
			case 10:
				return 'FIRESTOP';
			case 11:
				return 'CLEANFIRE';
			case 12:
				return 'COOL';

			case 239: // i01+i04
				return 'MFDOOR ALARM';
			case 240:
				return 'FIRE ERROR';
			case 241:
				return 'CHIMNEY ALARM';
			case 243:
				return 'GRATE ERROR';
			case 244:
				return 'NTC2 ALARM';
			case 245:
				return 'NTC3 ALARM';
			case 247:
				return 'DOOR ALARM';
			case 248:
				return 'PRESS ALARM';
			case 249:
				return 'NTC1 ALARM';
			case 250:
				return 'TC1 ALARM';
			case 252:
				return 'GAS ALARM';
			case 253:
				return 'NOPELLET ALARM';
			default:
				return status;

		}
}

$.statusStringMn = function(status) {
		switch (status) {
			case 0:
				return 'OFF';
			case 1:
				return 'HEATUP';
			case 2:
				return 'FUELIGN';
			case 3:
				return 'STABILIZATION';
			case 4:
				return 'BURNING';
			case 5:
				return 'CLEANFIRE';
			case 6:
				return 'FINAL CLEANING';
			case 7:
				return 'ECOSTOP';
			case 8:
				return 'ALARM';

			default:
				return status;

		}
}

$.fan2String = function(fan2level) {
		switch (fan2level) {
			case 0:
				return 'Auto';
			case 6:
				return 'Hi';
			case 7:
				return 'Off';
			default:
				return fan2level;
		}
}

$.userInitSelImmediate = function() {

	$(".immediate").not(".ui-slider-input").on("change", function() {
		var mycommand = $(this).attr("cmd");
		mycommand+= $(this).attr("prm")!="" ? " " + $(this).attr("prm") : "";
		mycommand+= " " + $(this).val();

		if ($(this).attr("prm")=="CPRD") {
			// caso particolare
			// CPRD [PRG] [TMP] [STARTHOURS] [STARTMIN] [STOPHOURS] [STOPMIN]

			var prog = $(this).attr("id").substr(1,1);
			var temp = $("#P"+prog+"CHRSETP").val();
			var starth = $("#P"+prog+"START").val().substr(0,2);
			var startm = $("#P"+prog+"START").val().substr(3,2);
			var stoph = $("#P"+prog+"STOP").val().substr(0,2);
			var stopm = $("#P"+prog+"STOP").val().substr(3,2);

			mycommand = "SET CPRD " + prog + " " + temp + " " + starth + " " + startm + " " + stoph + " " + stopm;
		}

		$.lowLevelReq(mycommand, true);
	});

	$(".ui-slider-input").focus(function() {
		$(this).attr("oldval", $(this).val());
	})

	$(".ui-slider-input").blur(function() {

		if ((typeof $(this).attr("oldval")==="undefined") || ($(this).attr("oldval")==$(this).val()))
			return false;

		$(this).attr("oldval", $(this).val());

		if ($(this).val()>$(this).attr("max"))
			$(this).val($(this).attr("max"));

		if ($(this).val()<$(this).attr("min"))
			$(this).val($(this).attr("min"));

		var mycommand = $(this).attr("cmd");
		mycommand+= $(this).attr("prm")!="" ? " " + $(this).attr("prm") : "";
		mycommand+= " " + $(this).val();
		$.lowLevelReq(mycommand, true);
	})

	$(".ui-slider-input").enterKey(function() {
		$(this).trigger("blur");
	});
}

$.userInit = function() {
	mainpage = "user";

	$.globalInit();

	$(".ui-input-text").css("max-width", "4em");

	$.lowLevelReq("GET ALLS", true)
		.always(function() {
			$.lowLevelReq("GET CHRD", true)
				.done(function(data) {
					$.each(data, function(key, val) {
						if (key != "INFO") {
							$.each(val, function(k, v) {
								if (k.substr(0, 1) == "D") {
									$.each(v, function(m, p) {
										var target = $("#"+k+m);
										var value;
										if (p=="OFF") {
											value = 0;
										} else {
											value = parseInt(p.substr(1,2));
										}
										target.val(value);
										target.selectmenu("refresh");
									})
								} else if (k.substr(0, 1) == "P") {
									$.each(v, function(pkey, pval) {
										var target = $("#"+k+pkey);
										switch (pkey) {
											case "START":
											case "STOP":
												$("#"+k+pkey).val(pval);
												break;
											default:
												target.val(pval);
												break;
										}

									})
								}
							});

						}
					});
				})
				.always(function() {
					if (($("#STATUS").text()=="OFF") || ($("#STATUS").text()=="OFF TIMER")) {
						$("#CMDONOFF").val("OFF").flipswitch("refresh");
					} else {
						$("#CMDONOFF").val("ON").flipswitch("refresh");
					}

					$.userInitSelImmediate();
				});
		});


}



$.paramsInit = function() {
	mainpage = "params";


	$.globalInit();

	$.lowLevelReq("GET ALLS", true);


}

var passphrase = "Qtest2017";
var inputphrase = "";
$.initInfo = function() {
	$.globalInit();
	mainpage = "info";

	$("body").unbind("keypress");
	$("body").bind("keypress", function(e) {
		if ($(document.activeElement).is("input"))
			return true;
		inputphrase += e.key;
		if (passphrase.indexOf(inputphrase)==-1) {
			inputphrase = "";
			return true;
		}
		if (passphrase!=inputphrase)
			return true;

		inputphrase = "";
		$.mobileLoadingShow(true);
		$.getJSON("syscmd.lua?cmd=cboxtest")
			.done(function(data) {

				var $grid = '<div class="ui-grid-a" style="min-width: 30em;">';

				$.each(data, function(key, val) {
					var bgcolor = ";";
					switch (key) {
						case 'WIFISCAN':
							var result = 0;
							for (var i=0; i<val.length; i++) {
								if (+val[i].signal > -60) {
									result = 1;
									break;
								}
							}
							val = result;
							if (+val==1) {
								val = "OK";
							} else {
								bgcolor = "background-color: red";
								val = "ERROR";
							}
							break;
						case 'APPLCONN':
							key = "SERIALCOM";
							if (+val==1) {
								val = "OK";
							} else {
								bgcolor = "background-color: red";
								val = "ERROR";
							}
							break;
						case 'USB':
							if (+val==1) {
								val = "OK";
							} else {
								bgcolor = "background-color: red";
								val = "ERROR";
							}
							break;
						case 'INTERNETCONN':
							if (+val==1) {
								val = "OK";
							} else {
								bgcolor = "background-color: red";
								val = "ERROR";
							}
							break;
						case 'SYSTEM':
						case 'plzbridge':
						case 'sendmsg':
							break;
						default:
							return true;
							break;
					}

					$grid += '<div class="ui-block-a" style="'+bgcolor+'">' + key + '</div>';
					$grid += '<div class="ui-block-b" style="'+bgcolor+'; text-align: right">' + val + '</div>';
				})
				$grid += '</div>';

				$("#popupContent").html($grid);
				$("#popReport").popup("open");
			})
			.always(function() {
				$.mobileLoadingShow(false);
			})
	})

	$.syscmdJson('nwdata')
		.done(function(data) {
			$("#noCommIcon").hide();
			$("#menuMonitor").css("backgroundColor", "");
		});

	$("#LABEL").keypress(function(e) {

		// if enter
		if (e.which==13)
			$.lowLevelReq("SET LABL " + $.trim($(this).val()), true, true);
	})


	function updateClock() {
		var currentdate = new Date();
		var browsertime = currentdate.getFullYear() + "-"
					+ $.strPad(currentdate.getMonth()+1,2)  + "-"
					+ $.strPad(currentdate.getDate(),2) + " "
					+ $.strPad(currentdate.getHours(),2) + ":"
					+ $.strPad(currentdate.getMinutes(),2) + ":"
					+ $.strPad(currentdate.getSeconds(),2);

		$("#spBrowserTime").text(browsertime);

		var a = $("#spSystemTime").text().split(/[^0-9]/);
		var systemdate = new Date (a[0],a[1]-1,a[2],a[3],a[4],a[5] );
		// add one second
		systemdate = new Date(systemdate.getTime() + 1000);
		var systemtime = systemdate.getFullYear() + "-"
					+ $.strPad(systemdate.getMonth()+1,2)  + "-"
					+ $.strPad(systemdate.getDate(),2) + " "
					+ $.strPad(systemdate.getHours(),2) + ":"
					+ $.strPad(systemdate.getMinutes(),2) + ":"
					+ $.strPad(systemdate.getSeconds(),2);
		$("#spSystemTime").text(systemtime);

		if (mainpage!="info")
			clearTimeout(clockInterval);
	}

	clockInterval = setInterval(updateClock, 1000);

	$("#btClockSync").click(function () {
		var cmd = "setsystemclock&datetime=" + $("#spBrowserTime").text();
		$.syscmdJson(cmd)
			.always(function() {
				$.mobileLoadingShow(false);
				window.location.replace(".");
			});
	});
}
