var deferredFunc = [];

var tblConnection = ["Not Connected", "Connected"];

var wlist, wlistmapping;
var mainInterval;

var mainpage = "";
var spinningCalls = 0;

var toastInterval;
var toastTimeout = 3000;

var cboxparams = {}

$.fn.enterKey = function (fnc) {
    return this.each(function () {
        $(this).keypress(function (ev) {
            var keycode = (ev.keyCode ? ev.keyCode : ev.which);
            if (keycode == '13') {
                fnc.call(this, ev);
            }
        })
    })
}

function pad8(input) {
    var BASE = "00000000";
    return input ? BASE.substr(0, 8 - Math.ceil(input / 10)) + input : BASE;
}

monitorLoop = function() {
	$.lowLevelReq("GET ALLS");
}

$.mobileLoadingShow = function(isShow) {

	if (isShow) {
		$("body").addClass('ui-disabled');
		$.mobile.loading("show");
		spinningCalls++;
	}
	else {

		// hide
		if (--spinningCalls==0) {
			$.mobile.loading("hide");
			$("body").removeClass('ui-disabled');
		}
	}
}


$.syscmdJson = function(cmd) {
		$.mobileLoadingShow(true);
		var result = $.getJSON('syscmd.lua?cmd='+cmd)
		.done(function(data) {
			if (cmd=="wifiscan") {

				// save wlist data
				wlist = ((data["DATA"]||{})["WLIST"]||[]);
				wlistmapping = {}

				// refresh essid list
				$('#WIFI_WLIST').empty();

				$('#WIFI_WLIST').append($("<li></li>")).append($("<a></a>").attr("value", 0));

				$.each(wlist, function(keydata, valdata) {
					//val = keydata + " [ch" + valdata['channel'] + " " + valdata['signal'] + "dBm]";

					wlistmapping["" + valdata["essid"]] = valdata

					$('#WIFI_WLIST').append($("<li></li>")
						.attr("value", valdata["essid"])
						.append($("<a>" + valdata["essid"] + "</a>")
							.append($("<span>ch" + valdata['channel'] + " " + valdata['signal'] + "dBm</span>")
								.addClass("ui-li-count"))
						)
					);
				});
				$('#WIFI_WLIST').listview("refresh");

				$(".wifilistview li").on("click", function() {

					$('#WSSID').val(wlistmapping[$(this).attr("value")]['essid']);
					$('#WENC').val(wlistmapping[$(this).attr("value")]['enc_type']);
					$('#WENC').selectmenu("refresh");
					$('#WCH').val(wlistmapping[$(this).attr("value")]['channel']);
					$('#WCH').selectmenu("refresh");
				});

				return true;
			}

			$.each(data, function(i, item) {
				if (i.toUpperCase()=="INFO")
					return true;
				if (i.toUpperCase()!="DATA")
					return true;
				$.each(item, function(idx, val) {
					//console.log(idx + " " + val);
					var target = $("#" + idx + ", ." + idx);
					target.each(function() {
						if ($(this).is("span, div, h1, h2")) {
							if ($(this).is("[hashtable]"))
								$(this).text(eval($(this).attr("hashtable"))[val]);
							else
								$(this).text(val);
						} else {
							$(this).val(val);
							if ($(this).is("select"))
								$(this).selectmenu("refresh");
						}
					});
				})
			});
		})
		.error(function(data) {
			//alert("syscmdJson error");
			a=1;
		})

		.always(function() {
			switch (mainpage) {
				case "wifi":
					if (cmd!="wifiscan")
						$.initWMode($("#WMODE").val());
					break;
				case "eth":
					$.initEthProto($('#EPR').val());
					break;
			}

			$.mobileLoadingShow(false);
		});

		return result;
}

$.strPad = function(i,l,s) {
	var o = i.toString();
	if (!s) { s = '0'; }
	while (o.length < l) {
		o = s + o;
	}
	return o;
}

$.loadmaincontent = function(href) {
		clearTimeout(mainInterval);
		$.mobileLoadingShow(true);
		$.ajax({
			url: href,
			cache: false
		})
			.done(function(data) {
				if (href=="logger.lua")
					$.menuInit();
				$('#maincontent').html(data);

			})
			.error(function(data) {
				$.openToast(data.responseText);
			})
			.always(function() {

				$("#pnMenu").css('height', $(window).height()-$("#mainheader").height()-4);
				$("#pnMenu").panel("close");

				$.mobileLoadingShow(false);
			});
}

$(document).on("pagecreate", "#mainpage", function() {

	$.getJSON( "syscmd.lua?cmd=getparams", function(data) {
		cboxparams = data;
	})

    $(document).on("swipeleft swiperight", "#mainpage", function(e) {
        if ($(".ui-page-active").jqmData("panel") !== "open") {
            if (e.type === "swiperight") {
                $("#pnMenu").panel("open");
            }
        }
    });
});

$(document).on("pageinit", function() {

	$(window).resize(function() {
		$("#pnMenu").css('height', $(window).height()-$("#mainheader").height()-4);
	});

	$.menuInit();

});


$.recursiveCmd = function(cmdlist, doneFunction) {
	if (cmdlist.length) {
		$.lowLevelReq(cmdlist.shift(), true)
			.always(function() {
				if (cmdlist.length==0)
					doneFunction();
				$.recursiveCmd(cmdlist, doneFunction);
			});
	}
}

function closeToast() {
	$("#toast").popup("close");
	clearTimeout(toastInterval);
}
$.openToast = function(msg) {
	toastInterval = setInterval("closeToast()", toastTimeout);
	$("#toast").html(msg);
	$("#toast").popup().popup("open");
}

$.openInfo = function(msg) {
	$("#info #infocontent").html(msg);
	$("#info").popup().popup("open");
}


$.globalInit = function() {

	clearTimeout(mainInterval);

	var initSliderVal;

	$("#mainpage").trigger('create');

	$(".clHex").keypress(function(e) {
		var validchar = /[\dABCDEFabcdef]/;

		// if canc
		if (e.which==0)
			return true;

		// if backspace
		if (e.which==8)
			return true;

		var patt = new RegExp(validchar);
		if (patt.test(String.fromCharCode(e.which)))
			return true;
		return false;
	});

	$(".clNumber, .clParam").click(function () {
	   $(this).select();
	});

	$(".immediate .clNumber").change(function(e) {
		var target = $(this);
		if ((target.val().length > 3) || (parseFloat(target.val()) > target.attr("max")) || (parseFloat(target.val()) < target.attr("min"))) {
			$.openToast("Value out of range");

			if ($(this).attr("oldval")!="") {
				$(this).val($(this).attr("oldval"));
			}
			return false;
		}
		var mycommand = target.attr("cmd") + " " + target.attr("prm") + " " + target.val();
		$.lowLevelReq(mycommand, true, true)
			.always(function() {
				target.blur();
			});
	});

	$(".clLimit").change(function(e) {
		var target = $(this);
		var idx = target.attr("id").substr(4, target.attr("id").length);
		var idname = target.attr("id").substr(0, 4);

			switch (idname) {
				case "LMIN":
					$("#P"+idx).attr("min", parseInt(target.val()));
					break;
				case "LMAX":
					$("#P"+idx).attr("max", parseInt(target.val()));
					break;
			}

			$("#P"+idx).textinput("refresh");
			var mycommand = target.attr("cmd") + " " + target.attr("prm") + " " + target.val();
			$.lowLevelReq(mycommand, true, true)
				.always(function() {
					target.blur();
				});
	});

	$(".ipformat").keypress(function(e) {

		var mystr = $(this).val();
		// if canc
		if (e.which==0)
			return true;

		// if backspace
		if (e.which==8)
			return true;

		// 46 is '.'
		if ((e.which != 46) && ((e.which < 48) || (e.which > 57)))
			return false;

		if ((e.which == 46) && (mystr.split('.').length==4))
			return false;

		if (mystr.length==15)
			return false;

		if ((mystr.split('.').length==4) && (mystr.substring(mystr.lastIndexOf(".")+1, mystr.length).length==3))
			return false;
	});

	$("input.immediate").bind("slidestop", function(event, ui) {
		var mycommand = $(this).attr("cmd") + " " + $(this).attr("prm") + " " + $(this).val();

		if (typeof $(this).attr("syscmd") !== "undefined") {

		} else {
			$.lowLevelReq(mycommand, true);
		}
	});

	$("input.setval").bind("slidestop", function(event, ui) {
		if (confirm("Are you sure to apply value?"))
			$.lowLevelReq("set parm " + $(this).attr("par") + " " + $(this).val()*100, true);
		else {
			$(this).val(initSliderVal);
			$(this).slider("refresh");
			return false;
		}
	});

	$("input.setval").bind("slidestart", function(event, ui) {
		initSliderVal = $(this).val();
	});

}

$.menuInit = function() {

	$.get("menu.lua")
		.done(function(data) {
			$("#pnMenu").html(data);
			$("#lvMenu").listview().listview("refresh");
		})
		.always(function() {
			$(document).on("click", "a.menulink", function () {
				var myhref = $(this).attr("href").substring(1, $(this).attr("href").length) + ".lua";
				$.loadmaincontent(myhref);
			});
		});

}

$.initWMode = function(val) {

	switch (val) {
		case 'default':
		case 'off':
			$("#WIFI_BASIC_DATA").hide();
			$('#WLAN0_SELECT_STDATA').hide();
			$('#WPR').val('dhcp').selectmenu("refresh");
			$('#WPR').selectmenu('disable');
			break;
		case 'sta':
			$("#WIFI_SCANLIST_DATA").show();
			$("#WIFI_BASIC_DATA").show();
			$("#WIFI_SCAN").trigger("click");

			$('#WLAN0_SELECT_STDATA').show();

			$('#WPR').selectmenu('enable');
			if ($('#WPR').val()=='static') {
				//show static ip
				$('#WLAN0_STATIC_DATA').show();
			} else {
				$('#WLAN0_STATIC_DATA').hide();
			}

			break;
		case 'ap':
			$("#WIFI_BASIC_DATA").show();
			$('#WLAN0_SELECT_STDATA').show();
			$("#WIFI_SCANLIST_DATA").hide();
			$('#WLAN0_STATIC_DATA').hide();
			$('#WPR').val('dhcp').selectmenu("refresh");
			$('#WPR').selectmenu('disable');
			break;
	}
}

$.initWifi = function() {

	mainpage = "wifi";
	$.globalInit();

	$.syscmdJson('nwdata');

	$("#frmSETwifi").submit(function() {

		var validip = true;

		if ($('#WLAN0_STATIC_DATA').is(':visible')) {
			$("#WLAN0_STATIC_DATA .ipformat").each(function() {
				var value = $(this).val();
				var split = value.split('.');
				var error = false;
				if (split.length == 4) {
					for (var i=0; i<split.length; i++) {
						var s = split[i];
						if (s.length==0 || isNaN(s) || s<0 || s>255) {
							error = true;
							break;
						}
					}
					if (!error) {
						$(this).removeClass("red");
						return true;
					}
				}

				$(this).addClass("red");
				alert('Not valid IP address!\nPlease type valid IP address to proceed.');
				validip = false;
				return false;

			});

			if (!validip)
				return false;
		}

		if (($('#WIFI_KEY').val().length<8) && ($('#WENC').val()!='none') && ($('#WMODE').val()!='off') && ($('#WMODE').val()!='default')){
			alert('Wifi password too short!');
			return false;
		}

		if ((($('#WSSID').val().length<1) ||($('#WSSID').val().length>32)) && ($('#WMODE').val()!='off') && ($('#WMODE').val()!='default')) {
			alert('Not valid SSID!');
			return false;
		}

		if (!confirm("Note: you could lose connection to this page.\n\nProceed?"))
			return false;

		var postData = $(this).serializeArray();
		var formURL = $(this).attr("action");
		$.mobileLoadingShow(true);
		$.ajax({
			url : formURL,
			type: "POST",
			data : postData,
			dataType: 'json'
		})
		.done(function(data, textStatus, jqXHR) {
			$('#maincontent').load(mainpage+".lua");
		})
		.error(function(jqXHR, textStatus, errorThrown) {
			alert("Network error. Please try to reload");
		})
		.always(function() {
			$.mobileLoadingShow(false);
		});

		return false;
	});

	$(".wifidata").keypress(function(e) {
		var validchar = /[\w\s\x24\x40\x5E\x60\x2C\x7C\x25\x3B\x2E\x7E\x28\x29/\x5C{}\x3A\x3F\x5B\x5D\x3D\x2D+_#!]/;
		// if canc
		if (e.which==0)
			return true;
		// if backspace
		if (e.which==8)
			return true;


		// $@^`
		//,|%;.~()/\{}:?[]=-+_#!
		var patt = new RegExp(validchar);
		if (patt.test(String.fromCharCode(e.which)))
			return true;
		return false;
	});

	$("#WMODE").change(function() {
		$.initWMode($("#WMODE").val());
	 });

	$('#WPR').change(function() {
		if ($(this).val() == 'static') {
			$('#WLAN0_STATIC_DATA').show();
		} else {
			$('#WLAN0_STATIC_DATA').hide();
		}
	});

	$("#WIFI_SCAN").click(function(e) {
		$.syscmdJson('wifiscan');
	});
}

$.initEthProto = function(val) {
	if (val == 'static') {
		$('#ETH0_STATIC_DATA').show();
	} else {
		$('#ETH0_STATIC_DATA').hide();
	}
}

$.initEth = function() {
	mainpage = "eth";

	$.globalInit();
	$.syscmdJson('nwdata');

	$('#EPR').change(function() {
		$.initEthProto($(this).val());
	});


	$('#frmSETeth').submit(function() {
		// validate IPs
		var validip = true;

		if ($('#ETH0_STATIC_DATA').is(':visible')) {
			$("#ETH0_STATIC_DATA .ip").each(function() {
				var value = $(this).val();
				var split = value.split('.');
				var error = false;
				if (split.length == 4) {
					for (var i=0; i<split.length; i++) {
						var s = split[i];
						if (s.length==0 || isNaN(s) || s<0 || s>255) {
							error = true;
							break;
						}
					}
					if (!error) {
						$(this).removeClass("red");
						return true;
					}
				}

				$(this).addClass("red");
				alert('Not valid IP address!\nPlease type valid IP address to proceed.');
				validip = false;
				return false;

			});

			if (!validip)
				return false;
		}



		if (!confirm("Note: you could loose connection on this page.\n\nProceed?"))
			return false;

		var postData = $(this).serializeArray();
		var formURL = $(this).attr("action");
		$.mobileLoadingShow(true);
		$.ajax({
			url : formURL,
			type: "POST",
			data : postData,
			dataType: 'json'
		})
		.done(function(data, textStatus, jqXHR) {
			$('#maincontent').load(mainpage+".lua");
		})
		.error(function(jqXHR, textStatus, errorThrown) {
			alert("frmSETeth error");
		})
		.always(function() {
			$.mobileLoadingShow(false);
		});

		return false;
	});


};

$.init3g = function() {
	mainpage = "3g";

	$.globalInit();


	$('#frmSET3g').submit(function() {

		var postData = $(this).serializeArray();
		var formURL = $(this).attr("action");

		$.mobileLoadingShow(true);
		$.ajax({
			url : formURL,
			type: "POST",
			data : postData,
			dataType: 'json'
		})
		.done(function(data, textStatus, jqXHR) {
			$('#maincontent').load(mainpage+".lua");
		})
		.error(function(jqXHR, textStatus, errorThrown) {
			alert("frmSET3g error");
		})
		.always(function() {
			$.mobileLoadingShow(false);
		});

		return false;
	});


}

$.updateInit = function() {

	mainpage = "update";

	$.globalInit();
	$(".myform").submit(function(e) {
		var regex = new RegExp('^' + cboxparams["SYSTEM_FILEPATTERN"] + '_\\d+.\\d+.\\d+.enc$');
		var regex2 = new RegExp('^' + cboxparams["PATCH_FILEPATTERN"] + '_\\d+.enc$');
		if (!((regex.test($("#patchfile").val().split(/[\\\/]/).pop())==true) ||
			(regex2.test($("#patchfile").val().split(/[\\\/]/).pop())==true))){
			alert("Wrong filename");
			return false;
		}

		if (!confirm("Are you sure to apply update?\n\nNote: system will be rebooted."))
			return false;

		$.mobileLoadingShow(true);

		$.ajax({
		  url: $(this).attr('action'),
		  type: 'POST',
		  data: new FormData( this ),
		  processData: false,
		  timeout: 120000,
		  contentType: false
		})
		.error(function(jqXHR, textStatus, errorThrown) {
			if ((jqXHR.statusText=="timeout") || (jqXHR.statusText=="Internal Server Error")) {
				$.openToast("Error uploading file");
			} else {
				$("#toast").html("<p>System is resetting and rebooting..</p><p>!!! DON'T REMOVE POWER DURING UPDATE !!!</p>");
				$("#toast").popup().popup("open");
			}
		})
		.done(function(data) {
			if (data.INFO.RSP != "OK") {
				$.openToast("File format ERROR!");
			} else {
				$("#toast").html("<p>System is resetting and rebooting..</p><p>!!! DON'T REMOVE POWER DURING UPDATE !!!</p>");
				$("#toast").popup().popup("open");
			}
 		})
		.always(function(data) {
			$.mobileLoadingShow(false);
			$.loadmaincontent("info.lua");
		});

		e.preventDefault();

	});
}


$.initLogin = function() {
	mainpage = "login";

	$.globalInit();

	$("#PASSWORD").keypress(function(e) {

		// if enter
		if (e.which==13)
			$("#btLogin").trigger("click");
	})

	$("#btLogin").click(function() {
		$.mobileLoadingShow(true);
		postData = {cmd: 'setpasswd', passwd: $("#PASSWORD").val()}
		$.ajax({
			url : 'syscmd.lua',
			type: "POST",
			data : postData,
			dataType: 'json'
		})
			.always(function() {
				$.mobileLoadingShow(false);
				window.location.replace(".");
			});
	});
	$("#btLogout").click(function() {
		$.mobileLoadingShow(true);
		postData = {cmd: 'setpasswd', passwd: ''}
		$.ajax({
			url : 'syscmd.lua',
			type: "POST",
			data : postData,
			dataType: 'json'
		})
			.always(function() {
				$.mobileLoadingShow(false);
				window.location.replace(".");
			});
	});
}

$.loggerInit = function() {
	mainpage = "logger";

	$.globalInit();

	$(".delFile").bind( "click", function(e) {
		e.stopImmediatePropagation();
		if (confirm("Are you sure to delete the CSV file?")) {
			$.get('syscmd.lua', { cmd: 'delcsvfile', csvfile: $(this).attr('csvfile') })
				.done(function() {
					$.openToast("Done");
				})
				.always(function() {
					$.loadmaincontent("logger.lua");
				});
		}
		return false;
	});

	$("#SPLITPERIOD").bind("slidestop", function(e) {
		e.stopImmediatePropagation();
		if (confirm("Are you sure to change split period?")) {
			$.get('syscmd.lua', { cmd: 'setloggersplit', splitperiod: $(this).val() })
				.done(function() {
					$.openToast("Done");
				})
				.always(function() {
					$.loadmaincontent("logger.lua");
				});
		}
		return false;
	});

	$("#loggerswitch").change(function() {
		if (!confirm("Are you sure to change status of logger?"))
			return false;

		$("body").addClass('ui-disabled');
		$.mobile.loading("show");

		if (parseInt($(this).val())) {
			$.get('syscmd.lua', { cmd: 'startlogger' })
				.done(function() {
					$(this).val("1");
				})
				.error(function() {
					$(this).val("0");
				})
				.always(function() {
					$.menuInit();
					$.loadmaincontent("logger.lua");
				});
		} else {
			$.get('syscmd.lua', { cmd: 'stoplogger' })
				.done(function() {
					$(this).val("0");
				})
				.error(function() {
					$(this).val("1");
				})
				.always(function() {
					$.menuInit();
					$.loadmaincontent("logger.lua");
				});
		}
	});

}


$.lowLevelReq = function(cmd, isSpinningWheel, isDoneMsg) {
	if (typeof isSpinningWheel == undefined)
		isSpinningWheel = false;

	if (typeof isDoneMsg == undefined)
		isDoneMsg = false;

	if (isSpinningWheel) {
		$.mobileLoadingShow(true);
	}

	if (mainpage=="monitor")
		$(".reading").show();

	// clear timeout to avoid over requestes
	clearTimeout(mainInterval);

	result = $.ajax({
		cache: false,
		url: 'sendmsg.lua?cmd='+cmd,
		dataType: 'json',
		timeout: 15000 //15 second timeout
		})
		.error (function(jqXHR, textStatus, errorThrown) {
			if(textStatus==="timeout") {
				$("#noCommIcon").show();
				$("#menuMonitor").css("backgroundColor", "yellow");
			}
		})
		.done(function(data) {
			$.each(data, function(keydata, valdata) {
				if (keydata=='INFO') {
					if (valdata['RSP']!='OK') {
						$("#noCommIcon").show();
						$("#menuMonitor").css("backgroundColor", "red");
						//$("#menuMonitor").addClass("clAlert");
					} else {
						$("#noCommIcon").hide();
						$("#menuMonitor").css("backgroundColor", "");
					}

					return true; // continue
				}
				if (keydata!='DATA')
					return true;
				var mbtype = parseInt(valdata.MBTYPE);
				$.each(valdata, function(key, val) {
					var target = $('#'+key);
					switch (key) {
						case "STATUS":
							if (typeof $.statusString !== 'undefined')
								val = $.statusString(val);
							break;
					}
					if (target.is("span")) {
						if (target.hasClass("clSwitch")) {
							target.text(val==1?'ON':'OFF');
							if (val!=1) {
								target.parent("div").addClass("clSwitchOFF");
							} else {
								target.parent("div").removeClass("clSwitchOFF");
							}
						} else if (target.hasClass("clIO")) {
							target.text(val);
							if (!val) {
								target.addClass("clSwitchOff");
							} else {
								target.removeClass("clSwitchOff");
							}
						}
						else {
							target.text(val);
						}
					} else if (target.is("div") && target.hasClass("divleds")){
						var binval = val.toString(2);
						while (binval.length < 8)
							binval = "0" + binval;
						binval = binval.split("").reverse();
						$.each(binval, function(k, v) {
							k++;
							var target = $("#"+key + k)
							if (+v==0) {
								target.removeClass("led-green");
								target.addClass("led-red");
							} else {
								target.addClass("led-green");
								target.removeClass("led-red");
							}

						})
					} else if (target.length) {
						if (target.attr("data-role")=="flipswitch") {
							target.val(val).flipswitch("refresh");
						} else if (target.attr("data-type")=="range") {
							target.val(val).slider("refresh");
						} else if (target.is("select")) {
							target.val(val).selectmenu("refresh");
						} else if (target.is("div")) {
							target.text(val);
						}
					}

				});
			});

		})
		.always(function(data) {
			$(".reading").hide();
			if (isSpinningWheel) {
				if (--spinningCalls==0) {

					// deferredFunc

					while (deferredFunc.length>0) {
						deferredFunc[0]();
						deferredFunc.splice(0,1);
					}

					$.mobile.loading("hide");
					$("body").removeClass('ui-disabled');
					if (isDoneMsg) {
						$.openToast("Done");
					}
				}
			}
			if (mainpage=="monitor")
				mainInterval = setInterval("monitorLoop()", sampleTime);
		});

		return result;
}

$.monitorInit = function() {
	mainpage = "monitor";

	clearTimeout(mainInterval);
	$.globalInit();
	$.lowLevelReq("GET ALLS");

}