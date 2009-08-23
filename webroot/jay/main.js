/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

SimpleTable.prototype = new Sortable();

var url = window.location.protocol + "//" + window.location.host + "/jay/rpc";
var current_client = 0;  //current client id
var current_search = 0; //current search id

var date = new Date();

$(document).ready( function()
{
	$('#systemWorking').hide();
	attach_functions();
	
	loadTables();
	
	$('#Body').children().hide();
	$('#Downloads').show();
	
	EventLoop(); //start event loop
});

function loadTables()
{
new FileDetails();
new Footer();
new Console();

new SimpleTable("Interfaces", true, undefined,
	[
	new RootSelectCell(),
	new DataCell("id", undefined),
	new DataCell("software", undefined),
	new DataCell("version", undefined),
	new DataCell("name", undefined),
	new DataCell("protocol", undefined),
	new ConnectionCell(),
	new DataCell("downloaded", formatSize),
	new DataCell("uploaded", formatSize),
	new DataCell("downloadrate", formatSpeed),
	new DataCell("uploadrate", formatSpeed),
	new DataCell("state", undefined)
	], function(freq) {
		if(freq == 0) makeCall(get_interfaces_arac_rpc);
		else if(freq == 1) makeCall(get_interfaces_iric_rpc);
		else { return false; } return true;
	}
);

new SimpleTable("Transfers", true, undefined,
	[
	new NetworkCell(),
	new DataCell("name", cropName),
	new CountryCell(),
	new ConnectionCell(),
	new DataCell("filename", formatName),
	new DataCell("age", formatTime, false),
	new DataCell("state", undefined),
	new DataCell("uploaded", formatSize),
	new DataCell("downloaded", formatSize),
	new SoftwareCell()
	], function(freq) {
		if(freq == 0) makeCall(get_transfers_arac_rpc(current_client));
		else if(freq == 1) makeCall(get_transfers_iric_rpc(current_client));
		else { return false; } return true;
	}
);

new SimpleTable("Networks", true, undefined,
	[
	new DataCell("id", undefined),
	new DataCell("name", undefined),
	new DataCell("uploaded", formatSize),
	new DataCell("downloaded", formatSize),
	new DataCell("state", undefined)
	], function(freq) {
		if(freq == 0) makeCall(get_networks_arac_rpc(current_client));
		else { return false; } return true;
	}
);

new SimpleTable("Servers", true, undefined,
	[
	new CheckCell(),
	new DataCell("id", undefined),
	new CountryCell(),
	new DataCell("name", cropName),
	new ConnectionCell(),
	new DataCell("users", undefined),
	new DataCell("files", undefined),
	new DataCell("description", undefined),
	new DataCell("state", undefined),
	new DataCell("ping", undefined)
	], function(freq) {
		if(freq == 0) makeCall(get_servers_arac_rpc(current_client));
		else if(freq == 3) makeCall(get_servers_iric_rpc(current_client));
		else { return false; } return true;
	}
);

new SimpleTable("Searches", true, undefined,
	[
	new CheckCell(),
	new DataCell("id", undefined),
	new DataCell("name", cropFileName, true, selectSearch),
	new DataCell("resultsc", undefined),
	new DataCell("state", undefined)
	], function(freq) {
		if(freq == 0) makeCall(get_searches_arac_rpc(current_client));
		else if(freq == 2) makeCall(get_searches_iric_rpc(current_client));
		else { return false; } return true;
	}
);

var results = new SimpleTable("Results", false, undefined,
	[
	new CheckCell(),
	new DataCell("id", undefined),
	new DataCell("name", cropFileName),
	new DataCell("filecc", undefined),
	new DataCell("fileallc", undefined),
	new DataCell("size", formatSize),
	new DataCell("format", undefined),
	new DataCell("state", undefined)
	], function(freq) {
		if(tables["Searches"].isEmpty()) return true;
		if(freq == 0) makeCall(get_results_arac_rpc(current_client, current_search));
		else if(freq == 2) makeCall(get_results_irac_rpc(current_client, current_search));
		else { return false; } return true;
	}
);


new SimpleTable("Files", false, undefined,
	[
	new DataCell("name", undefined, true, function(id) { downloadFile(id); }),
	new DataCell("size", formatSize),
	new DirectoryCell()
	], function(freq) {
		if(freq == 0) makeCall(get_files_arac_rpc);
		else { return false; } return true;
	}
);

new SimpleTable("Downloads", false, undefined,
	[
	new CheckCell(),
	new DataCell("id", undefined),
	new NetworkCell(),
	new DataCell("name", formatName, true, function(id) { tables["FileDetails"].setId(id); }),
	new PercentCell(),
	new ETACell(),
	new DataCell("completed", formatSize),
	new DataCell("size", formatSize),
	new DataCell("uploaded", formatSize),
	new SourcesCell(),
	new SpeedCell()
	//new DataCell("state", undefined),
	//new DataCell("lastseen", formatTime, false),
	//new DataCell("priority", undefined)
	], function(freq) {
		if(freq == 0) makeCall(get_downloads_arac_rpc(current_client));
		else if(freq == 2) makeCall(get_downloads_iric_rpc(current_client));
		else { return false; } return true;
	}
);

new SimpleTable("Settings", true, undefined,
	[
	new DataCell("name", undefined),
	new SettingsCell()
	], function(freq) {
		if(freq == 0) makeCall(get_settings_arac_rpc);
		else { return false; } return true;
	}
);

var removeInfoRow = function(id) {
	if(id < 0) { //is local message
		tables["Infos"].removeRow(id);
	} else {
		makeCall('{"query" : {"method" : "metas", "chain" : { "method" : "del", "params" : ["LOG",' + id + ']}}}');
	}
}

new SimpleTable("Infos", true, undefined,
	[
	new DataCell("changed", formatDate),
	new DataCell("text", colorizeRowOnRating, true, removeInfoRow)
	], function(freq) {
		if(freq == 0) makeCall(get_infos_arac_rpc);
		else { return false; } return true;
	}
);

} //end of loadTableHandler()

//wrapper function
function formatName(name)
{
	//var newname = name.replace(/\[.*\]/g,""); //remove brackets, sense?
	return name;
	//return l33t(newname);
}

function SettingsCell()
{
	this.sortup = false;
	this.name = "setting";
	this.create = function(id, td, values) {
		var type = values["type"];
		var value = values["value"];
		var name = values["name"];
		var elem;
		if(type == "STRING" || type == "NUMBER" || type == "PASSWORD") {
			elem = document.createElement('input');
			
			if(type == "STRING" || type == "NUMBER") elem.setAttribute("type", "text");
			else elem.setAttribute("type", "password");
			
			elem.setAttribute("value", value);
			elem.onkeypress = function(event) {
				if(!event || event.keyCode != 13) return true;
				
				makeCall(get_set_settings_rpc(current_client, id, this.value));
				makeCall(get_settings_irac_rpc(current_client, id));
			}
		} else if (type == "BOOL") {
			elem = document.createElement('input');
			elem.setAttribute("type", "checkbox");
			elem.setAttribute("value", value);
			if(value == "true") elem.setAttribute("checked", "checked");
			elem.onkeypress = function(event) {
				if(!event || event.keyCode != 13) return true;
				var request1 ={
					"id" : "Settings",
					"query" : {
						"method" : "nodes",
						"chain" : {
							"method" : "get",
							"params" : [ "CORE", current_client],
							"chain" : {
								"method" : "settings", 
								"chain" : {
									"method" : "set",
									"params" : [id, this.value]
								}
							}
						}
					}
				};
				
				var request2 ={
					"id" : "Settings_irac",
					"query" : {
						"method" : "nodes",
						"chain" : {
							"method" : "get",
							"params" : [ "CORE", current_client],
							"chain" : {
								"method" : "get",
								"params" : [id],
								"chain" : {
									"method" : "settings", 
									"chain" : {
										"method" : "getsettings",
										"params" : [2],
										"chain" : ["name", "value", "type"]
									}
								}
							}
						}
					}
				};
				makeCall(request1);
				makeCall(request2);
			}
		} else if (type == "MULTIPLE") {
			elem = document.createElement('span');
			elem.appendChild(document.createTextNode(name));
			elem.click(function() {
				
				var request ={
					"id" : "Settings_arac",
					"query" : {
						"method" : "nodes",
						"chain" : {
							"method" : "get",
							"params" : [ "CORE", current_client],
							"chain" : {
								"method" : "settings", 
								"chain" : {
									"method" : "get",
									"params" : [id],
									"chain" : {
										"method" : "settings",
										"chain" : {
											"method" : "getsettings",
											"chain" : ["name", "value", "type"]
										}
									}
								}
							}
						}
					}
				};
				
				makeCall(request);
			});
		} else {
			elem = document.createTextNode(value);
		}
		td.appendChild(elem);
	}
	this.update = function(td, values) {}
}

function CheckCell()
{
	this.sortup = true;
	this.name = "check";
	this.create = function(id, td, values) {
		var checkbox = document.createElement('input');
		checkbox.setAttribute("type", "checkbox");
		checkbox.setAttribute("value", id);
		//if(value == undefined) checkbox.setAttribute("disabled", "disabled");
		td.appendChild(checkbox);
	}
	this.update = function(td, values) { }
}

function SoftwareCell()
{
	this.sortup = true;
	this.name = "software";
	this.create = function(id, td, values) {
		td.appendChild(document.createElement('img'));
		td.appendChild(document.createTextNode("?"));
	}
	this.update = function(td, values) {
		var software = values["software"];
		var version = values["version"];
		if(software == undefined || software.length == 0) return;
		td.firstChild.setAttribute("src", "/client_img/" + software + ".gif");
		td.firstChild.setAttribute("alt", software);
		if(version == undefined) version = "";
		td.children[1].nodeValue = " " + version;
	}
}

function RootSelectCell()
{
	this.sortup = true;
	this.name = "root";
	this.create = function(id, td, values) {
		var input = document.createElement('input');
		input.setAttribute("type", "radio");
		input.setAttribute("name", "root");
		if(id == current_client) input.setAttribute("checked", "checked");
		td.appendChild(input);
		td.onclick = function() { current_client = id; };
	}
	this.update = function(td, values) {}
}

function DirectoryCell()
{
	this.sortup = true;
	this.name = "file";
	this.create = function(id, td, values) {
		td.appendChild(document.createElement('img'));
		if(values["type"] == "directory") td.click(function()
		{
			makeCall({
				"id" : "Files_arac",
				"query" : {
					"method" : "files",
					"chain" : {
						"method" : "get",
						"params" : ["CORE", id],
						"chain" : {
							"method" : "files",
							"chain" :
							{
								"method" : "getfiles",
								"params" : ["FILE", "_", "_"],
								"chain" : ["id", "name", "size", "type"]
							}
						}
					}
				}
			});
		});
		this.update(td, values);
	}
	this.update = function(td, values) {
		var type = values["type"];
		if(type == undefined) return
		td.firstChild.setAttribute("src", "/jay/images/" + type + ".png");
	}
}

function CountryCell()
{
	this.sortup = true;
	this.name = "country";
	this.create = function(id, td, values) {
		td.appendChild(document.createElement('img'));
		td.firstChild.setAttribute("alt", "N/A");
		td.firstChild.setAttribute("src", "/flag_img/--.gif");
	}
	this.update = function(td, values) {
		var location = values["location"];
		if(location == undefined) return
		td.firstChild.setAttribute("alt", location);
		td.firstChild.setAttribute("src", "/flag_img/" + location + ".gif");
	}
}

function NetworkCell()
{
	this.sortup = true;
	this.name = "network";
	this.create = function(id, td, values) {
		td.appendChild(document.createElement('img'));
		td.firstChild.setAttribute("alt", "?");
		td.firstChild.setAttribute("src", "/net_img/Unknown_connected.gif");
	}
	this.update = function(td, values) {
		var nets = values["network"];
		if(nets == undefined || nets.length == 0) return;
		for(var i = 0; i < nets.length; i++) {
			td.firstChild.setAttribute("src", "/net_img/" + nets[0][i] + "_connected.gif");
			td.firstChild.setAttribute("alt", nets[0][i]);
		}
	}
}

function ETACell()
{
	this.sortup = true;
	this.name = "eta";
	this.create = function(id, td, values) {
		td.appendChild(document.createTextNode("?"));
	}
	this.update = function(td, values) {
		var size = values["size"];
		var completed = values["completed"];
		var speed = values["speed"];
		if(size == undefined || completed == undefined || speed == undefined) { value = 0; }
		else if(speed == 0) { value = 0; }
		else { value = (size - completed) / speed; }
		
		td.firstChild.nodeValue = formatTime(value);
		td.setAttribute("value", value.toFixed());
	}
}

function PercentCell()
{
	this.sortup = true;
	this.name = "percent";
	this.create = function(id, td, values) {
		td.appendChild(document.createTextNode("?"));
	}
	this.update = function(td, values) {
		var size = values["size"];
		var completed = values["completed"];
		if(size != undefined && completed != undefined) { //size can be 0 , so we have to check for undefined
			//td.firstChild.nodeValue = "?";
			if(size == 0) { value = 100; }
			else { value = completed * 100 / size; }
			td.firstChild.nodeValue = value.toFixed(1);
		}
	}
}

function ConnectionCell()
{
	this.sortup = true;
	this.name = "connection";
	this.create = function(id, td, values) { td.appendChild(document.createTextNode("?")); }
	this.update = function(td, values) {
		var host = values["host"]; var port = values["port"]; var user = values["user"];
		if(host != undefined && port != undefined) {
			if(user) td.firstChild.nodeValue = user + "@" + host + ":" + port;
			else td.firstChild.nodeValue = host + ":" + port;
		} else if(user != undefined) { td.firstChild.nodeValue = user; }
	}
}

function SourcesCell()
{
	this.sortup = false;
	this.name = "sources";
	this.create = function(id, td, values) {
		td.appendChild(document.createTextNode("?"));
	}
	this.update = function(td, values) {
		var sources = values["sources"];
		var clients = values["clients"];
		if(sources != undefined && clients != undefined) {
			td.firstChild.nodeValue = sources + " (" + clients + ")";
			td.setAttribute("value", sources);
		} //else td.firstChild.nodeValue ="?";
	}
}

function SpeedCell()
{
	this.sortup = true;
	this.name = "speed";
	this.create = function(id, td, values) {
		td.appendChild(document.createTextNode("?"));
	}
	this.update = function(td, values) {
		var speed = values["speed"];
		if(speed == undefined) return;
		td.setAttribute("value", speed);
		if(speed == 0) {
			td.className = "speed";
		} else if(speed < 5120) { // 5KB/s
			td.className = "speed slowest";
		} else  if(speed < 10240) { // 10KB/s
			td.className = "speed slow";
		} else  if(speed < 15360) { // 15KB/s
			td.className = "speed medium";
		} else if(speed < 20480) { // 20KB/s
			td.className = "speed fast";
		} else if(speed > 30960) { // 30KB/S
			td.className = "speed fastest";
		}
		td.firstChild.nodeValue = formatSpeed(speed);
	}
}

function DataCell(className, formatFunc, sort_drct, onClickFunc)
{
	this.sortup = typeof(sort_drct) != undefined ? sort_drct : true; //default value
	this.name = className;
	this.create = function(id, td, values) {
		td.appendChild(document.createTextNode("?"));
		if(onClickFunc) td.onclick = function() { onClickFunc(id); }
	}
	this.update = function(td, values) {
		var value = values[className];
		if(value == undefined) return;
		while(value instanceof Array && value.length)
			value = value[0];
		
		if(formatFunc) {
			td.setAttribute("value", value)
			value = formatFunc(value, td, values);
		}
		td.firstChild.nodeValue = value;
	}
}
/*
function InfoCell()
{
	this.sortup = true;
	this.name = "text";
	this.create = function(id, td, values) {
		td.appendChild(document.createElement('img'));
		td.firstChild.setAttribute("alt", "?");
		td.firstChild.setAttribute("src", imagePath);
		if(on_click) td.click(function() { on_click(id); });
	}
	this.update = function(td, values) {
		if(on_update == undefined) return;
		on_update(td, values);
	}
}
*/
/*
function ImageCell(className, path_prefix, path_suffix, on_click)
{
	this.sortup = true;
	this.name = className;
	this.create = function(id, td, values) {
		td.appendChild(document.createElement('img'));
		td.firstChild.setAttribute("alt", "?");
		td.firstChild.setAttribute("src", path_prefix + value + path_suffix);
		if(on_click) td.click(function() { on_click(id); });
	}
	this.update = function(td, values) {
		var value = values[className];
		if(value == undefined) return;
		td.firstChild.setAttribute("src", path_prefix + value + path_suffix);
		td.firstChild.setAttribute("alt", value);
	}
}*/

function logout()
{
	makeCall('{"query" : {"method" : "logout"}}');
	window.location.reload(true);
	return false;
}

function promptQuestion(onTrue, onFalse, lock_bg, text)
{
	$('#AskText').firstChild.nodeValue  = text;
	//apply functionality
	$('#AskTrue').click(function() {
		if(onTrue) onTrue();
		$('#Ask').hide();
		$('#LockBG').hide();
	});
	$('#AskFalse').click(function() {
		if(onFalse) onFalse();
		$('#Ask').hide();
		$('#LockBG').hide();;
	});
	//show Message
	$('#Ask').show();
	if(lock_bg) $('#LockBG').show();
}

function getAllSelected(name) {
	var rows = tables[name].rows;
	var ids = new Array();
	for(var id in rows) {
		id = parseInt(id);
		if(rows[id].firstChild.firstChild.checked) {
		
			ids.push(id);
		}
	}
	return ids;
}

var colorizeRowOnRating = function(value, tag, values)
{
	var rating = values["rating"];
	if(rating == undefined) return;
	if(rating <= 50) { //info
		tag.className = "info";
	} else if(rating <= 100) { //status
		tag.className = "status";
	} else if(rating <= 150) { //warning
		tag.className = "warning";
	} else { //error
		tag.className = "error";
	}
	return value;
}

//get file from hdd
function downloadFile(id) {
	var func = function() {
		makeCall({
			"request" :
			{
				"method" : "files",
				"chain" : {
					"method" : "download",
					"params" : ["FILE", id]
				}
			}
		});
		
		$('#trigger_request').src = "/jay?download="; //value doesn't matter
	}
	promptQuestion(func, undefined, true, "Download File Now?");
}

function resumeDownload() {
	if(ids.length) makeCall(get_download_action_rpc(current_client, "start", ids));
	return false;
}

function pauseDownload() {
	var ids = getAllSelected("Downloads");
	if(ids.length) makeCall(get_download_action_rpc(current_client, "pause", ids));
	return false;
}

function removeDownload() {
	var ids = getAllSelected("Downloads");
	var func = function() {
		makeCall(get_download_action_rpc(current_client, "remove", ids));
	}
	promptQuestion(func, undefined, true, "Remove Selected Downloads?");
	return false;
}

function prioritiseDownload(tag) {
	var ids = getAllSelected("Downloads");
	var priority = tag.options[tag.selectedIndex].value;
	var request = {
		"request" :
		{
			"method" : "nodes",
			"chain" : {
				"method" : "get",
				"params" : ["CORE", current_client],
				"chain" : {
					"method" : "files",
					"chain" : {
						"method" : "prioritise",
						"params" : ["DOWNLOAD", ids, priority]
					}
				}
			}
		}
	};
	
	if(ids.length) makeCall(request);
	return false;
}

function downloadLink()
{
	var link = $('#link-field');
	if(link && link.length)
		makeCall('{"query" : { "method" : "start_link", "params" : [' + current_client + ', "' +  link + '"]}}');
	return false;
}

function selectSearch(id)
{
	current_search = id;
	var results = tables["Results"];
	results.clearTable();
	results.requestUpdate(0);
}

function attach_functions()
{
	$('#Navigation > div').click(function() {
		var name = $(this).attr("name");
		if(name == "Logout")
		{
			logout();
			return;
		}
		
		$('#Body').children().hide();
		tables[name].requestUpdate(0);
		$('#' + name).show();
		//update all visible tablest
		//obj.requestUpdate(0);
	});

	$('#hideFileDetails').click(function() { $('#FileDetails').hide(); });
	
	$('#search-start').click(function() {
		var query = $('#search-query').val();
		var media = $('#search-media').val(); 
		var min_size = $('#search-min-size').val();
		var max_size = $('#search-max-size').val();
		var max_results = $('#search-max-results').val();
		
		if(query == "") return false;
		if(media.length) query = query + " MEDIA " + media;
		if(min_size > 0) query = query + " MINSIZE " + (min_size * 1024 * 1024);
		if(max_size > 0) query = query + " MAXSIZE " + (max_size * 1024 * 1024);
		if(max_results > 0) query = query + " MAXRESULTS " + max_results;
		
		tables["Results"].clearTable();
		
		makeCall({
			"query" : {
				"method" : "nodes",
				"chain" : {
					"method" : "get",
					"params" : ["CORE", current_client],
					"chain" : {
						"method" : "searches",
						"chain" : {
							"method" : "add",
							"params" : [query]
						}
					}
				}
			}
		});
		
		tables["Searches"].requestUpdate(0);
		return false;
	});

	$('#search-forget').click(function() {
		var ids = getAllSelected("Searches");
		if(ids.length == 0) return false;
		
		makeCall(get_search_action_rpc(current_client, "remove", ids));
		
		tables["Results"].clearTable();
		tables["Searches"].requestUpdate(0);
		return false;
	});
	
	$('#search-stop').click(function() {
		var ids = getAllSelected("Searches");
		if(ids.length == 0) return false;
	
		makeCall(get_search_action_rpc(current_client, "stop", ids));
		
		tables["Searches"].requestUpdate(1);
		return false;
	});
	
	$('#result-start').click(function() {
		var ids = getAllSelected("Results");
		
		if(ids.length != 0) makeCall({
			"query" : {
				"method" : "nodes",
				"chain" : {
					"method" : "get",
					"params" : ["CORE", current_client],
					"chain" : {
						"method" : "searches",
						"chain" : {
							"method" : "startresults",
							"params" : [current_search, ids]
						}
					}
				}
			}
		});
		
		tables["Results"].requestUpdate(1);
		return false;
	});
	
	//trigger submit when enter key pressed
 	$('#console-command').keypress(function(event) {
		var cmd = $('#console-command').val();
		if (cmd.length && event && event.keyCode == 13) {
			makeCall({
				"query" : {
					"method" : "nodes",
					"chain" : {
						"method" : "get",
						"params" : ["CORE", current_client],
						"chain" : {
							"method" : "metas",
							"chain" : {
								"method" : "add",
								"params" : ["CONSOLE", cmd]
							}
						}
					}
				}
			});
			tables["Console"].requestUpdate(0);
		} else return true;
	});
	
	$('#add-server').click(function() {
		var host = $('#server-host');
		var port = $('#server-port');
		if(host != "" && port != "") makeCall({
			"query" : {
				"method" : "nodes",
				"chain" : {
					"method" : "get",
					"params" : ["CORE", current_client],
					"chain" : {
						"method" : "nodes",
						"chain" : {
							"method" : "add",
							"params" : ["SERVER", host, port]
						}
					}
				}
			}
		});
		return false;
	});
	
	$('#client-connect').click(function() {
		var ids = getAllSelected("Interfaces");
		if(ids.length == 0) return false;
		for(var i = 0; i < ids.length; i++) makeCall(get_client_action_rpc("connect", ids[i]));
		return false;
	});
	
	$('#client-disconnect').click(function() {
		var ids = getAllSelected("Interfaces");
		if(ids.length == 0) return false;
		for(var i = 0; i < ids.length; i++) makeCall(get_client_action_rpc("disconnect", ids[i]));
		return false;
	});
	
	$('#client-remove').click(function() {
		var ids = getAllSelected("Interfaces");
		if(ids.length == 0) return false;
		for(var i = 0; i < ids.length; i++) makeCall(get_client_action_rpc("remove", ids[i]));
		tables["Interfaces"].requestUpdate(0);
		return false;
	});
	
	$('#client-add').click(function() {
		var type = $('#client-type').val();
		var host = $('#client-host').val();
		var port = $('#client-port').val();
		var user = $('#client-user').val();
		var pass = $('#client-pass').val();
		
		makeCall({
			"query" : {
				"method" : "nodes",
				"chain" : {
					"method" : "add",
					"params" : [ type, host, port, user, pass]
				}
			}
		});
		
		tables["Interfaces"].requestUpdate(0);
		return false;
	});
}

//TODO?: speedup, make invisible during redisplay
function removeChilds(e) {
	e = e.get(0);
	if(e == undefined)
		return;
	/*
	if(e.get(0).children() == undefined)
	{
		//TODO: what elements to we get here
		return;
	}
	var i = e.children().length;
	while(i--) e.remove(e.firstChild);
	*/
	while (e.hasChildNodes()) {
		e.removeChild(e.firstChild);
	}
}

function getChildPosition(node) {
	var i = 0;
	var j = 0;
	var childs = node.parent().children();
	while(childs[i] != node) {
		if(childs[i].nodeType == 1) j++;
		i++;
	}
	return j;
}

function getParentId(elem) {
	if(elem == document)
		alert("root reached");
	
	var id = elem.parent().attr("id");
	if(id) { return id; } else { return getParentId(elem.parent()); }
	/*
	while(elem.get(0) != document)
	{
		elem = elem.parent().get(0);
		var id = elem.attr("id");
		if(id) return id;
	}
	return undefined;
	*/
}

function isVisible(elem) {
	while(elem.get(0) != document)
	{
		var display = elem.css('display');
		if(display && display == 'none')
			return false;
		
		elem = elem.parent();
	}
	return true;
}

/*
//make item visble and hide all neighbours
var visibleItems = new Array();
function visible(elem)
{
	if(elem == undefined) return;
	var pid = getParentId(elem);
	
	var selected = visibleItems[pid];
	if(selected) {
		selected.hide();
	} else {
		elem.parent().children().hide();
	}
	elem.show();
	visibleItems[pid] = elem;
}*/

var selectedItems = new Array();
function select(elem) //allow toggle
{
	var pid = getParentId(elem);
	var selected = selectedItems[pid];
	
	if(selected) { //if we have a selected recorded for that id, just unselect it
		selected.removeClass("selected");
		//selected.className = selected.className.replace(/selected/, "");
	} else { //if we don't have anything selected/recorded yet, unselect all at first
		elem.parent().children().removeClass("selected");
		/*
		var childs = elem.parent().children();
		for(var i = 0; i < childs.length; i++) {
			if(childs[i].nodeType != 1) continue;
			childs[i].className = childs[i].className.replace(/selected/, "");
		}*/
	}
	//elem.className += " selected";
	elem.addClass("selected");
	
	selectedItems[pid] = elem;
}

function makeCall(request)
{
	if(request == undefined)
		return;
	
	if(typeof request == 'object')
		request = $.toJSON(request);
		
	if(typeof request != 'string')
		return; //alert("oh " + typeof request);
	
	$.ajax({
		url: url,
		type: 'POST',
		data : request,
		dataType: 'json',
		timeout: 1000,
		beforeSend : function(){
			$('#systemWorking').show(); //css('display', 'block');
		},
		error: function(){
			$('#systemWorking').hide(); //css('display', 'none');
			addDebugMsg("Error: No response from server!");
		},
		success: function(json){
			$('#systemWorking').hide();//css('display', 'none');
			
			var id = json.id;
			var obj = json.result;
			
			if(id == undefined || obj == undefined)
				return;
			
			var name;
			var type;
			var pos = id.lastIndexOf('_');
			if(pos == -1) {
				type = "";
				name = id;
			} else {
				type = id.substring(pos + 1);
				name = id.substring(0, pos);
			}
			
			var handler = tables[name];
			
			if(handler != undefined) {
				handler.update(obj, type);
			}
		}
	});
};

function Footer() {
	tables["Footer"] = this;
	makeCall({
		"id" : "Footer",
		"query" : {
			"method" : "metas",
			"chain" : ["main_name", "main_version", "main_weblink"]
		}
	});
	
	this.update = function(elems, type) {
		$('#main-version').text(elems['main_version']);
		$('#main-name').text(elems['main_name']);
		$('#main-weblink').attr("href", elems['main_weblink']);
	}
	this.requestUpdate = function(level) { return true; }
	this.isEmpty = function() { return false; }
	this.isVisible = function() { return false; }
}

function FileDetails() {
	tables["FileDetails"] = this;
	this.update = function(elems, type) {
		var node = $('#FileDetailsComments').getElementsByTagName("ul")[0];
		var comments = elems['comments'];
		removeChilds(node);
		$('#FileDetailsComments').hide();
		for(var id in comments) {
			var elem = comments[id];
			var li = document.createElement('li');
			li.appendChild(document.createTextNode("(" + elem["rating"] + "): " + elem["comment"]));
			var source = elem["source"];
			if(source != undefined) {
				var location = source["location"];
				if(location != undefined) {
					var img = document.createElement('img');
					img.setAttribute("alt", location);
					img.setAttribute("src", "/flag_img/" + location + ".gif");
					li.appendChild(img);
				}
			}
			node.appendChild(li);
			$('#FileDetailsComments').css('display', '');
		}
		
		$('#FileDetailsId').firstChild.nodeValue = elems['id'];
		$('#FileDetailsName').firstChild.nodeValue = elems['name'];
		$('#FileDetailsSize').firstChild.nodeValue = formatSize(elems['size']);
		this.set('FileDetailsFormat', elems['format']);
		this.set('FileDetailsRequests', elems['requests']);
		$('#FileDetailsCompleted').firstChild.nodeValue = formatSize(elems['completed']);
		$('#FileDetailsUploaded').firstChild.nodeValue = formatSize(elems['uploaded']);
		this.set('FileDetailsPriority', elems['priority']);
		$('#FileDetailsLastSeen').firstChild.nodeValue = formatTime(elems['lastseen']);
		this.set('FileDetailsState', elems['state']);
		this.set('FileDetailsHash', elems['hash']);
		this.set('FileDetailsSubfileCount', elems['subfilec']);
		this.set('FileDetailsChunkCount', elems['chunkc']);
		$('#FileDetails').css('display', 'block'); //make visible
	}
	
	//when no value -> invisible, else set value, make visible
	this.set = function(name, value) {
		var elem = $(name);
		if(value == undefined || value == "" || value == "0") {
			elem.hide();
		} else {
			elem.getElementsByTagName("span")[0].firstChild.nodeValue = value;
			elem.css('display', '');
		}
	}
	//set what file  details should be displayed
	this.setId = function(id) {
		if(isNaN(id) || this.currentId == id) {
			$('#FileDetails').hide();
			this.currentId = 0;
		} else {
			makeCall({
				"id" : "FileDetails",
				"query" : {
					"method" : "nodes",
					"chain" : 
					{
						"method" : "get",
						"params" : ["CORE", current_client],
						"chain" : {
							"method" : "files",
							"chain" : {
								"method" : "get",
								"params" : ["DOWNLOAD", id],
								"chain" : [
									"id", "name", "size", "priority", "format", { "method" : "downloaded", "retalias" : "completed"},
									"uploaded", "requests", "lastseen", "state", "hash", 
									{ "method" : "files", "retalias" : "subfilec", "chain" : { "method" : "filecount", "params" : ["SUBFILE", "_"]}},
									{ "method" : "files", "retalias" : "chunkc", "chain" : { "method" : "filecount", "params" : ["CHUNK", "_"]}},
									{
										"method" : "meta",
										"chain" : {
											"method" : "getmetas",
											"params" : ["COMMENT", "_", "_"],
											"chain" : ["text", "rating", { "method" : "source", "chain" : ["location", "name"]}]
										}
									}
								]
							}
						}
					}
				}
			});
			
			//"nodes()FileDetails.get(CORE," + current_client + ").files.get(DOWNLOAD," + id + "){id,name,size,priority,format,downloaded()completed,uploaded,requests,lastseen,state,hash,files()subfilec.filecount(SUBFILE,_),files()chunkc.filecount(CHUNK,_),metas.getmetas(COMMENT,_,_){text,rating,source{location,name}}}");
			this.currentId = id;
		}
	}
	this.requestUpdate = function(level) { return true; }
	this.isEmpty = function() { return false; }
	this.isVisible = function() { return false; }
}

function Console() {
	tables["Console"] = this;
	
	this.update = function(elems, type) {
		var out = $('#console-output');
		removeChilds(out);
		for(var id in elems)
		{
			var entry = elems[id];
			var text = entry["text"];
			out.appendChild(document.createTextNode(text));
			out.appendChild(document.createElement('br'));
		}
	}
	
	this.requestUpdate = function(level) {
		if(level == 0) makeCall({
			"id" : "Console",
			"query" : {
				"method" : "nodes",
				"chain" : {
					"method" : "get",
					"params" : ["CORE", current_client],
					"chain" : {
						"method" : "metas",
						"chain" : {
							"method" : "getmetas",
							"params" : ["CONSOLE", "_", "_"],
							"chain" : ["text"]
						}
					}
				}
			}
		});
		return true;
	}
	this.isVisible = function() { return isVisible($('#Console')); }
	this.isEmpty = function() { return false; }
}

//insert debug messages into the Infos table,
//limited to 4 debug messages at a time
var debug_counter = 0;
function addDebugMsg(text) {
	if(debug_counter < -4) debug_counter = 0;
	debug_counter--; //negative numbers doesn't interfer with client ids
	var msg = {};
	var date = new Date();
	msg[debug_counter] = {"text" : text, "changed" : (date.getTime() / 1000), "rating" : 0};
	tables["Infos"].update(msg, "irac");
}

//tables is source for all objects that react on incoming data from server side
var tables = new Object();
var counter = 1;
function EventLoop() {
	for(var name in tables) {
		var obj = tables[name];
		//($('#Console').css('display') != 'none')
		if(!obj.isVisible()) continue; //don't update invisible tables
		if(obj.isEmpty()) continue; //don't update empty tables (full updates by obj.requestUpdate(0))
		if(counter%8 == 0 && obj.requestUpdate(4)) {} // 16 sec. interval
		else if(counter%4 == 0 && obj.requestUpdate(3)) {} // 8 sec. interval
		else if(counter%2 == 0 && obj.requestUpdate(2)) {} // 4 sec. interval
		else obj.requestUpdate(1) // 2 sec. interval
	}
	counter++;
	if(counter%1000 == 0) counter = 0; //reset counter
	setTimeout("EventLoop()", 2000);
}

function updateFooter(elems)
{
	$('#software').firstChild.nodeValue = elems["software"];
	var version = elems["version"];
	if(version == "") version = "?";
	$('#version').firstChild.nodeValue = version;
}

function SimpleTable(name, preserve_order, modify_tr, colObjects, updaterFunc)
{
	tables[name] = this; //register table for global access
	this.tbody = $("#" + name + "_tbody");
	this.modify_tr = modify_tr; //modify rows on change
	this.cols = colObjects; //create and update td cells
	this.rows = new Object();
	this.updater = updaterFunc;
	this.enableStripes = $(name + '_thead') ? true : false; //set stripes when table header present
	removeChilds(this.tbody); //prepare tbody, in case of text/white space inside tbody
	//make table sortable
	
	$('#' + name + '_thead th').click( function() {
		tables[name].sortBy(this);
		select($(this));
	});
	/*.each( function(el) {
		el.click(function() {
			tables[name].sortBy(this);
			select($(this));
		});
	});*/
	
	this.clearTable = function() {
		for(var id in this.rows) {
			//there are some essential elements since JS doesn't have AAs,
			//also ids < 1 are manually inserted
			if(isNaN(id) || id < 0) continue;
			var row = this.rows[id];
			this.tbody.remove(row);
			delete this.rows[id];
		}
	}
	this.clearTable();
	
	/*
	* accepted elems json format is {1 : {name : "a", ...}, 2 : { name : "b", ...}, {}}
	* expected message types are:
	* "arac" (all rows / all columns)
	* "aric" (all rows / incomplete columns)
	* "iric" (incomplete rows / all columns)
	* "irac" (incomplete rows /  incomplete columns)
	*/
	this.update = function(elems, type)
	{
		var new_data = true;
		var new_rows = false;
		var all_rows = (type.substr(0, 2) == "ar");
		var all_cols = (type.substr(2, 2) == "ac");
		
		//addDebugMsg("Update " + name); //some debug message
		
		if(elems == undefined)
		{
			this.clearTable();
			this.setEmptyLine();
			return;
		}
		
		if(all_rows && all_cols)
			this.clearTable();
		
		for(var id in elems)
		{
			id = parseInt(id);
			
			var row = this.rows[id];
			var data = elems[id];
			
			if(row == undefined) {
				if(all_cols) { //add new row
					row = this.buildRow(id, data);
					this.tbody.append(row);
					this.rows[id] = row;
					new_rows = true;
				}
			} else { //update row
				var tds = row.children();
				for(var k = 0; k < this.cols.length; k++) {
					this.cols[k].update(tds[k], data);
				}
			}
			
			if(all_rows) row.setAttribute("x", true);
			new_data = true;
		}
		
		if(this.modify_tr != undefined)
			this.modify_tr(row, data);
		
		//remove all rows that were not mentioned in elems
		if(all_rows && new_data) {
			for(var id in this.rows) {
				//we also iterate over special hidden attributes, that's why we check for id
				if(isNaN(id) || id < 0) continue;
				var row = this.rows[id];
				if(row.getAttribute("x") == undefined) {
					this.tbody.remove(row);
					delete this.rows[id];
					new_rows = true;
				} else { row.removeAttribute("x");}
			}
		}
		
		if(new_data) {
			if(preserve_order) {
				this.sort();
				if(this.enableStripes) setTableStripes(this.tbody.rows);
			} else if(new_rows && this.enableStripes) setTableStripes(this.tbody.rows);
		}
		
		this.setEmptyLine();
	}
	
	//display an empty line when no items in list
	this.setEmptyLine = function()
	{
		var empty_line = $('#' + name + '_empty');
		if(this.isEmpty()) {
			if(empty_line) empty_line.show(); //css('display', '');
		} else {
			if(empty_line) empty_line.hide(); //css('display', 'none');
		}
	}
	
	this.buildRow = function(id, attributes) {
		var tr = document.createElement('tr');
		for(var i = 0; i < this.cols.length; i++) {
			var td = document.createElement('td');
			td.className = this.cols[i].name;
			this.cols[i].create(id, td, attributes);
			this.cols[i].update(td, attributes);
			tr.appendChild(td);
		}
		return tr;
	}
	
	//in case we need to remove elements manually, because they were inserted manually
	this.removeRow = function(id) {
		this.tbody.remove(this.rows[id]);
		delete this.rows[id];
	}
	
	this.requestUpdate = function(level) {
		return this.updater(level);
	}
	
	this.isEmpty = function() { return (this.tbody.length == 0); }
	this.isVisible = function() { return isVisible($("#" + name + "_tbody")); } //access the div
}

function Sortable()
{
	this.column = 0;
	this.sortup;
	this.sortorders = new Array();
	
	var sort_stable = true;
	
	this.sortBy = function(th)
	{
		var new_column = getChildPosition(th);
		var sortup = this.cols[new_column].sortup;
		if(this.column == new_column) this.sortup = !sortup;
		else this.sortup = sortup;
		this.cols[new_column].sortup = this.sortup;
		this.column = new_column;
		this.sort();
	}
	
	//sort table rows
	this.sort = function()
	{
		var tbody = this.tbody; //get from SimpleTable
		if(tbody.children().length < 2) return; //nothing to sort
		
		var column = this.column;
		var cmp; var access;
		
		//probe first row to decide what and how to compare
		var td = tbody.children()[0].childNodes[column];
		if(td == undefined)
			return alert("Error: Column " + column + " does not exist!");

		var cmp_wrapper = function(row1, row2) { return cmp( access(row1), access(row2) ); }
		
		//set accessor function
		var value;
		//probe for comparable value
		if((value = td.nodeValue) != undefined) {
			access = function(row) { return row.childNodes[column].nodeValue; }
		}  else if((value = td.getAttribute("value")) != undefined) {
			access = function(row) { return row.childNodes[column].getAttribute("value"); }
		} else if((value = td.firstChild.nodeValue) != undefined) {
			access = function(row) { return row.childNodes[column].firstChild.nodeValue; }
		} else if((value = td.firstChild.checked) != undefined) {
			access = function(row) { return row.childNodes[column].firstChild.checked; }
		} else if((value = td.firstChild.getAttribute("alt")) != undefined) {
			access = function(row) { return row.childNodes[column].firstChild.getAttribute("alt") ; }
		} else {
			alert("Error: Don't know how to sort!");
			return;
		}
		
		//set compare function
		if(isNaN(value)) {
			if(!this.sortup) cmp = function(a, b) { return (a <= b)? 0 : 1; } //sort_lexic_up
			else cmp = function(a, b) { return (a <= b)? 1 : 0; } //sort_lexic_down
		} else {
			if(this.sortup) cmp = function(a, b) { return (parseFloat(a) <= parseFloat(b))? 0 : 1; } //sort_numeric_up
			else cmp = function(a, b) { return (parseFloat(a) <= parseFloat(b))? 1 : 0; } //sort_numeric_down
		}
		
		var rows = tbody.get(0).childNodes;
		
		if(sort_stable) { bubbleSort(rows, cmp_wrapper); } //stable sort
		else { rows.sort(cmp_wrapper); } //unstable sort, faster

		$(rows).each(function(row) {
			//insertRow(row);
			tbody.append(row);
		});
		
		if(this.enableStripes) setTableStripes(tbody.rows);
	}
	
	//stable and O(n) when table is sorted
	function bubbleSort(array, cmp)
	{
		var dummy;
		var length = array.length;
		for (var i = 0; i < (length - 1); i++) {
			for (var j = i + 1; j < length; j++) {
				if (cmp(array[j], array[i])) {
					dummy = array[i];
					array[i] = array[j];
					array[j] = dummy;
				}
			}
		}
	}
}

function setTableStripes(rows) {
	if(rows == undefined) return;
	var toggle = false;
	for(var i = 0; i < rows.length; i++) {
		if(toggle) {
			//rows[i].setAttribute("class", "even"); //disabled to avoid interference with className property beeing set
			rows[i].style.backgroundColor = "#edf3fe";
			toggle = false;
		} else {
			//rows[i].setAttribute("class", "odd");
			rows[i].style.backgroundColor = "#ffffff";
			toggle = true;
		}
	};
}

//currently, first td must contain checkbox
function allBoxes(elem, value)
{
	var tbody = $('#' + elem.parent().getAttribute("name"));
	var rows = tbody.children();
	
	for(var i = 0; i < rows.length; ++i)
	{
		rows[i].firstChild.firstChild.checked = value;
	}
}

function invertBoxes(elem)
{
	var tbody = $('#' + elem.parent().getAttribute("name"));
	var rows = tbody.children();
	
	for(var i = 0; i < rows.length; ++i)
	{
		var child = rows[i].firstChild.firstChild;
		child.checked = !child.checked;
	}
}

function rangeBoxes(elem)
{
	var tbody = $('#' + elem.parent().getAttribute("name"));
	var rows = tbody.children();
	var inrange = false;
	
	for(var i = 0; i < rows.length; ++i)
	{
		var node = rows[i].firstChild.firstChild;
		if(node.checked) {
			inrange = !inrange;
		} else if(inrange == true) {
			if(!node.checked) { node.checked = true; }
			else { inrange = true }
		}
	}
}

function formatSize(bytes)
{
	if (bytes < 1024) {
		return bytes + "  b ";
	} else if (bytes < 1024*1024) {
		return (bytes/ 1024.0).toFixed(0)  + " kB";
	} else if (bytes < 1024*1024*1024) {
		return (bytes/1024.0/1024.0).toFixed(1)  + " MB";
	} else {
		return (bytes/1024.0/1024.0/1024.0).toFixed(2) + " GB";
	} 
}

function formatSpeed(bytes)
{
	if(bytes == 0) {
		return "-";
	} else if (bytes < 1024) {
		return bytes + "  b/s";
	} else if (bytes < 1024*1024) {
		return (bytes/ 1024.0).toFixed(1)  + " kB/s";
	} else {
		return (bytes/1024.0/1024.0).toFixed(1)  + " MB/s";
	}
}

function formatTime(seconds)
{
	seconds = parseInt(seconds); //prevent some hangs
	if(seconds == 0) return "\u221E"; //infinity
	if(seconds < 60) return seconds.toFixed() + "s";
	var minutes = seconds / 60;
	seconds %= 60;
	if(minutes < 60) return minutes.toFixed() + "m";// + seconds.toFixed() + "s";
	var hours = minutes / 60;
	minutes %= 60;
	if(hours < 24) return hours.toFixed() + "h" + minutes.toFixed() + "m";
	var days = hours / 24;
	hours %= 24;
	if(days < 365) return days.toFixed() + "d" +  hours.toFixed() + "h";
	return "\u221E"; //infinity
}

//format date to dd/mm/yy hh:mm
function formatDate(seconds)
{
	date.setTime(seconds * 1000);
	//return date.toUTCString();
	return date.getDate() + "/" + date.getMonth() + "/" + (date.getYear() - 100) + "  " + date.getHours() + ":" + date.getMinutes() + ":" + date.getSeconds();
}

//convert string to l33t =)
var l33t_table = { "a" : "4", "c" : "<", "e" : "3", "g" : "9", "i" : "1", "o" : "0", "s" : "5", "t" : "7", "z" : "2", "A" : "/-\\","K" : "|<", "H" : "|-|", "W" : "\\/\\/" };
function l33t(str)
{
	var ret = "";
	for(var i = 0; i < str.length; i++)
	{
		var c = l33t_table[str[i]];
		if(c == undefined) ret += str[i];
		else ret += c;
	}
	return ret;
}

//crop and preserve file extension
function cropFileName(name)
{
	var len = 80;
	if(name.length < len) { return name; }
	var first = name.substr(0, len - 4);
	var last = name.substr(-4);
	return first + "*" + last;
}

function cropName(name)
{
	var len = 30;
	if(name.length < len) return name;
	else return name.substr(0, len) + "*";
}
