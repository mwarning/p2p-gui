
/*
* collection of json rpc requests
*/

var get_settings_arac_rpc = function(current_client)
{
	var req = {
		"id" : "Settings_arac",
		"query" : {
			"method" : "nodes",
			"chain" : {
				"method" : "get",
				"params" : ["CORE", current_client],
				"chain" : 
				{
					"method" : "settings",
					"chain" :  {
						"method" : "getsettings",
						"chain" : ["name", "value", "type"]
					}
				}
			}
		}
	};
	return req;
};


var get_transfers_arac_rpc = function(current_client)
{
	var req = {
	"id" : "Transfers_arac",
	"query" : {
			"method" : "nodes",
			"chain" : {
				"method" : "get",
				"params" : ["CORE", current_client],
				"chain" : {
					"method" : "nodes",
					"chain" : {
						"method" : "getnodes",
						"params" : ["CLIENT", "_", "_"],
						"chain" : [
							"name", "state",
							//TODO?
							{
								"method" : "nodes",
								"retalias" : "network",
								"params" : ["NETWORK", "_", "_"],
								"chain" : ["name"]
							},
							/*nodes()network.getnodes(NETWORK,_,_)[name],*/
							"location", "uploaded", "downloaded", "software", "version", "port", "host", "age",
							//TODO?
							{
								"method" : "files",
								"retalias" : "filename",
								"params" : ["DOWNLOAD", "_", "_"],
								"chain" : ["name"]
							}
							/*files()filename.getfiles(DOWNLOAD,_,_)[name]*/
						],
					}
				}
			}
		}
	};
	return req;
}

var get_results_arac_rpc = function(current_client, current_search)
{
	var req = {
		"id" : "Results_arac",
		"query" : {
			"method" : "nodes",
			"chain" : {
				"method" : "get",
				"params" : ["CORE", current_client],
				"chain" : {
					"method" : "searches",
					"chain" : {
						"method" : "get",
						"params" : [current_search],
						"chain" : 
						{
							"method" : "getresults",
							"params" : ["_", "_"],
							"chain" : [
								"name",
								{ "method" : "filecount", "params" : ["_", "_"], "realias" : "fileallc"},
								{ "method" : "filecount", "params" : ["_", "COMPLETE"], "realias" : "filecc"},
								"size", "state", "format", "id"
							]
						}
					}
				}
			}
		}
	};
	return req;
}

var get_results_irac_rpc = function(current_client, current_search)
{
	var req = {
		"id" : "Results_irac",
		"query" : {
			"method" : "nodes",
			"chain" : {
				"method" : "get",
				"params" : ["CORE", current_client],
				"chain" : {
					"method" : "searches",
					"chain" : {
						"method" : "get",
						"params" : [current_search],
						"chain" : 
						{
							"method" : "getresults",
							"params" : ["_", 4],
							"chain" : [
								"name",
								{ "method" : "filecount", "params" : ["_", "_"], "retalias" : "fileallc"},
								{ "method" : "filecount", "params" : ["_", "COMPLETE"], "retalias" : "filecc"},
								"size", "state", "id"
							]
						}
					}
				}
			}
		}
	};
	return req;
}

var get_files_arac_rpc = function()
{
	var req = {
		"id" : "Files_arac",
		"query" : {
			"method" : "files",
			"chain" : {
				"method" : "getfiles",
				"params" : ["FILE", "_", "_"],
				"chain" : {
					"method" : "searches",
					"chain" : ["id", "name", "size", "type"]
				}
			}
		}
	};
	return req;
}


var get_files_arac_rpc = function()
{
	var req = {
		"id" : "Files_arac",
		"query" : {
			"method" : "files",
			"chain" : {
				"method" : "getfiles",
				"params" : ["FILE", "_", "_"],
				"chain" : {
					"method" : "searches",
					"chain" : ["id", "name", "size", "type"]
				}
			}
		}
	};
	return req;
}

var get_downloads_arac_rpc = function(current_client)
{
	var req = {
		"id" : "Downloads_arac",
		"query" : {
			"method" : "nodes",
			"chain" : {
				"method" : "get",
				"params" : ["CORE", current_client],
				"chain" : {
					"method" : "files",
					"chain" : {
						"method" : "getfiles",
						"params" : ["DOWNLOAD", "_", "_"],
						"chain" : [
							"id", "name", { "method" : "downloaded", "retalias" : "completed" },
							"size",
							{ "method" : "downloadrate", "retalias" : "speed" },
							{
								"method" : "nodes",
								"retalias" : "network",
								"chain" : { "method" : "getnodes", "params" : ["NETWORK", "_", "_"], "chain" : ["name"] }
							},
							"lastseen", "state", "uploaded",
							{ "method" : "nodecount", "params" : ["_", "CONNECTED"], "retalias" : "sources"},
							{ "method" : "nodecount", "params" : ["_", "DISCONNECTED"], "retalias" : "clients"},
							"priority"
						]
					}
				}
			}
		}
	};
	return req;
}

var get_downloads_iric_rpc = function(current_client)
{
	var req = {
		"id" : "Downloads_iric",
		"query" : {
			"method" : "nodes",
			"chain" : {
				"method" : "get",
				"params" : ["CORE", current_client],
				"chain" : {
					"method" : "files",
					"chain" : {
						"method" : "getfiles",
						"params" : ["DOWNLOAD", "_", 3],
						"chain" : [
							"size",
							{ "method" : "downloaded", "retalias" : "completed" },
							{ "method" : "downloadrate", "retalias" : "speed" },
							"lastseen", "state"
						]
					}
				}
			}
		}
	};
	return req;
}

var get_infos_arac_rpc = function()
{
	var req = {
		"id" : "Infos_arac",
		"query" : {
			"method" : "metas",
			"chain" : {
				"method" : "getmetas",
				"params" : ["LOG", "_", "_"],
				"chain" : ["text", "rating", "changed"]
			}
		}
	};
	return req;
}


var get_transfers_iric_rpc = function(current_client)
{
	var req = {
		"id" : "Transfers_iric",
		"query" : {
			"method" : "nodes",
			"chain" : {
				"method" : "get",
				"params" : ["CORE", current_client],
				"chain" : {
					"method" : "nodes",
					"chain" : {
						"method" : "getnodes",
						"params" : ["CLIENT", "_", 3],
						"chain" : ["state", "uploaded", "downloaded", "age"]
					}
				}
			}
		}
	};
	return req;
}

var get_servers_arac_rpc = function(current_client)
{
	var req = {
		"id" : "Servers_arac",
		"query" : {
			"method" : "nodes",
			"chain" : {
				"method" : "get",
				"params" : ["CORE", current_client],
				"chain" : {
					"method" : "nodes",
					"chain" : {
						"method" : "getnodes",
						"params" : ["SERVER", "CONNECTED", "_"],
						"chain" : [
							"id", "name", 
							{
								"method" : "nodecount",
								"params" : ["CLIENT", "_"],
								"retalias" : "users"
							},
							{
								"method" : "filecount",
								"params" : ["_", "_"],
								"retalias" : "files"
							},
							"description", "state", "host",
							"port", "location", "ping"
						]
					}
				}
			}
		}
	};
	return req;
}

var get_servers_iric_rpc = function(current_client)
{
	var req = {
		"id" : "Servers_iric",
		"query" : {
			"method" : "nodes",
			"chain" : {
				"method" : "get",
				"params" : ["CORE", current_client],
				"chain" : {
					"method" : "nodes",
					"chain" : {
						"method" : "getnodes",
						"params" : ["SERVER", "CONNECTED", 4],
						"chain" : [
							"files", "state", "ping",
							{
								"method" : "nodecount",
								"params" : ["CLIENT", "_"],
								"retalias" : "users"
							},
							{
								"method" : "filecount",
								"params" : ["_", "_"],
								"retalias" : "files"
							}
						]
					}
				}
			}
		}
	};
	return req;
}


var get_searches_arac_rpc = function(current_client)
{
	var req = {
		"id" : "Searches_arac",
		"query" : {
			"method" : "nodes",
			"chain" : {
				"method" : "get",
				"params" : ["CORE", current_client],
				"chain" : {
					"method" : "searches",
					"chain" : {
						"method" : "getsearches",
						"chain" : ["id", "name", { "method" : "resultcount", "params" : ["_"], "realias" : "resultsc"}, "state"]
					}
				}
			}
		}
	};
	return req;
}


var get_searches_iric_rpc = function(current_client)
{
	var req = {
		"id" : "Searches_iric",
		"query" : {
			"method" : "nodes",
			"chain" : {
				"method" : "get",
				"params" : ["CORE", current_client],
				"chain" : {
					"method" : "searches",
					"chain" : {
						"method" : "getsearches",
						"chain" : [{ "method" : "resultcount", "params" : ["_"], "realias" : "resultsc"}, "state"]
					}
				}
			}
		}
	};
	return req;
}


var get_interfaces_arac_rpc = 
{
"id" : "Interfaces_arac",
"query":  {
		"method" : "nodes",
		"chain" : {
			"method" : "getnodes",
			"params" : ["CORE", "_", "_"],
			"chain" : [ "id", "software", "version", "host", "port", "state", "name", "uploaded", "downloaded", "uploadrate", "downloadrate", "protocol" ]
		}
	}
};

var get_interfaces_iric_rpc = 
{
"id" : "Interfaces_iric",
"query":  {
		"method" : "nodes",
		"chain" : {
			"method" : "getnodes",
			"params" : ["CORE", "_", 3],
			"chain" : [ "uploaded", "downloaded", "uploadrate", "downloadrate", "state" ]
		}
	}
};

var get_networks_arac_rpc = function(current_client)
{
	return {
		"id" : "Networks_arac",
		"query":  {
			"method" : "nodes",
			"chain" : {
				"method" : "get",
				"params" : ["CORE", current_client],
				"chain" : {
					"method" : "nodes",
					"chain" : {
						"method" : "getnodes",
						"params" : ["NETWORK", "_", "_"],
						"chain" : ["id", "name", "state", "uploaded", "downloaded"],
					}
				}
			}
		}
	};
}

var get_set_settings_rpc = function(current_client, id, value)
{
	return {
		"id" : "Settings",
		"query" : {
			"method" : "nodes",
			"chain" : 
			{
				"method" : "get",
				"params" : ["CORE", current_client],
				"chain" : {
					"method" : "settings",
					"chain" : {
						"method" : "set",
						"params" : [id, value]
					}
				}
			}
		
		}
	};
}


var get_settings_irac_rpc = function(current_client, id)
{
	return {
		"id" : "Settings_irac",
		"query" : {
			"method" : "nodes",
			"chain" : 
			{
				"method" : "get",
				"params" : ["CORE", current_client],
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
}

var get_download_action_rpc = function(current_client, action, ids)
{
	return {
		"request" :
		{
			"method" : "nodes",
			"chain" : {
				"method" : "get",
				"params" : ["CORE", current_client],
				"chain" : {
					"method" : "files",
					"chain" : {
						"method" : action,
						"params" : ["DOWNLOAD", ids]
					}
				}
			}
		}
	};
}

var get_search_action_rpc = function(current_client, action, ids)
{
	return {
		"query" : {
			"method" : "nodes",
			"chain" : {
				"method" : "get",
				"params" : ["CORE", current_client],
				"chain" : {
					"method" : "searches",
					"chain" : {
						"method" : action,
						"params" : [ids]
					}
				}
			}
		}
	};
}

var get_client_action_rpc = function(action, id)
{
	var req = {
		"query" : {
			"method" : "nodes",
			"chain" : {
				"method" : action,
				"params" : ["CORE", id]
			}
		}
	};
	return req;
}
