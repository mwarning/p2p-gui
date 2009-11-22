module webguis.clutch.ClutchGui;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import tango.io.Stdout;
import tango.util.Convert;
import tango.text.Util;
static import tango.io.device.File;
static import Base64 = tango.util.encode.Base64;

import api.File;
import api.User;
import api.Meta;
import api.Node;
import api.Host;
import api.Client;
import api.Setting;

static import Main = webcore.Main;
static import Utils = utils.Utils;
import webcore.Webroot;
import webcore.Session;
import webcore.Dictionary;
import webcore.Logger;
import webserver.HttpRequest;
import webserver.HttpResponse;
import utils.json.JsonParser;
import utils.json.JsonBuilder;
import utils.Storage;


/*
* Backend for the clutch gui in Transmission.
* Translates it's json rpc format to internal calls and backwards.
*/
class ClutchGui : Main.Gui
{
    alias JsonParser!().JsonString JsonString;
    alias JsonParser!().JsonObject JsonObject;
    alias JsonParser!().JsonValue JsonValue;
    
    bool try_connect = true;
    
    static JsonObject empty_json_object;
    static JsonArray empty_json_array;
    
    JsonParser!() parser;
    
    char[] clutch_dir;
    
    static this()
    {
        empty_json_object = new JsonObject();
        empty_json_array = new JsonArray();
    }
    
    this(Storage s)
    {
        this.clutch_dir = "/clutch/";
        this.parser = new JsonParser!();
        load(s);
    }
    
    char[] getGuiName()
    {
        return "Clutch";
    }
    
    void save(Storage s)
    {
    }
    
    void load(Storage s)
    {
    }
    
    private JsonObject parseQuery(char[] query)
    {
        try
        {
            return parser.parseObject(query);
        }
        catch(Exception e)
        {
            Logger.addError("ClutchGui: Parsing: " ~ e.toString);
        }
        return JsonObject.init;
    }
    
    /*
    * Get first client available in user list and try to connect if disconnected.
    */
    private Client getClient(Session session)
    {
        auto array = session.getUser.getNodes.getNodeArray(Node_.Type.CORE, Node_.State.ANYSTATE, 0);
        Client client = null;
        
        //get first connected client
        foreach(c; array)
        {
            if(c.getState() == Node_.State.CONNECTED)
            {
                client = cast(Client) c;
                break;
            }
        }
        
        if(client)
        {
            return client;
        }
        else if(array.length)
        {
            client = cast(Client) array[0];
        }
        
        //get and connect first client
        if(client && try_connect) try
        {
            try_connect = false;
            client.connect();
        }
        catch(Exception e)
        {
            Logger.addError("ClutchGui: {} : {}", client.getSoftware, e.toString);
        }
        
        return client;
    }

    bool process(HttpRequest http_req, Session session, HttpResponse http_res)
    {
        char[] uri = http_req.getUri();
    
        if(uri.length == 0 || uri == "/" || uri == clutch_dir || uri == clutch_dir[0..$-1])
        {
            //redirect
            http_res.setCode(HttpResponse.Code.FOUND);
            http_res.addHeader("Location: " ~ clutch_dir ~ "index.html");
            return true;
        }
        else if(uri == "/clutch/upload")
        {
            //torrent file upload
            Client client = getClient(session);
            if(client && client.getState == Node_.State.CONNECTED)
                addTorrents(http_req, client, http_res);
            return true;
        }
        else if(uri == "/clutch/rpc" && http_req.getHttpMethod == HttpMethod.POST && Utils.is_in(http_req.getContentType, "json"))
        {
            answerJsonRequest(http_req, session, http_res);
            return true;
        }
        else if(Utils.is_prefix(uri, clutch_dir))
        {
            Webroot.getFile(http_res, uri);
            try_connect = true; //allow another client connection try when the page is reloaded
            return true;
        }
        
        return false;
    }
    
    private void answerJsonRequest(HttpRequest http_req, Session session, HttpResponse http_res)
    {
        char[] result = "success";
        Client client = getClient(session);
        
        if(client is null)
        {
            result = "No client available.";
        }
        
        char[] query = http_req.getBody();
        auto rpc_req = parseQuery(query);

        if(rpc_req is null)
        {
            debug
            {
                Logger.addWarning("ClutchGui: Received message is not JSON:\n {}", query);
            }
            return;
        }
        
        char[] method = rpc_req["method"].toString;
        auto args = cast(JsonObject) rpc_req["arguments"].ptr;
        uint tag = rpc_req["tag"].toInteger;
        auto res_args = empty_json_object;
        
        if(client && client.getState == Node_.State.CONNECTED)
            try switch(method)
        {
            case "torrent-get":
                res_args = handleTorrentGet(args, client);
                break;
            case "torrent-start":
                res_args = handleStartTorrent(args, client);
                break;
            case "torrent-stop":
                res_args = handleStopTorrent(args, client);
                break;
            case "torrent-remove":
                res_args = handleRemoveTorrent(args, client);
                break;
            case "torrent-add":
                res_args = handleTorrentAdd(args, client);
                break;
            case "session-get":
                res_args = handleSessionGet(args, client);
                break;
            case "session-set":
                res_args = handleSessionSet(args, client);
                break;
            default:
                Logger.addWarning("ClutchGui: Unknown method call '{}'.", method);
                result = "Method '" ~ method ~ "' is not implemented.";
        }
        catch(Exception e)
        {
            result = e.toString();
            Logger.addWarning("ClutchGui: Exception: {}", result);
        }
        
        //special handling for torrent-get default return
        if(res_args is empty_json_object && method == "torrent-get")
        {
            res_args = new JsonObject();
            res_args["torrents"] = empty_json_array;
        }
        
        //build response
        auto res = new JsonObject();
        
        res["result"] = result;
        res["arguments"] = res_args;
        
        if(tag)
            res["tag"] = tag;
        
        http_res.setContentType("text/x-json");
        
        //write response
        auto o = http_res.getWriter();
        res.print((char[] s){ o(s); });
    }
    
    /*
    * Get settings.
    */
    private JsonObject handleSessionGet(JsonObject in_args, Client client)
    {
        auto settings = client.getSettings();
        
        if(settings is null)
            return empty_json_object;
        
        auto args = new JsonObject();
        
        foreach(setting; settings.getSettingArray)
        {
            char[] name = setting.getName();
            char[] value = setting.getValue();
            Setting.Type type = setting.getType();
            
            switch(type)
            {
                case Setting.Type.STRING:
                    args[name] = new JsonString(value);
                    break;
                case Setting.Type.NUMBER:
                    args[name] = new JsonNumber(value);
                    break;
                case Setting.Type.BOOL:
                    args[name] = new JsonBool(value);
                    break;
                default:
                    debug
                    {
                        Logger.addWarning("ClutchGui: Unexpected setting type fpr '{}'.", name);
                    }
            }
        }
        
        return args;
    }
    
    /*
    * Save settings
    */
    private JsonObject handleSessionSet(JsonObject in_args, Client client)
    {
        auto settings = client.getSettings();
        
        if(settings is null)
            return empty_json_object;

        uint getId(char[] name)
        {
            switch(name)
            {
                //map to unified id
                //enables limited settings when backend is not Transmission
                case "download-dir":
                    return Phrase.download_dir__setting;
                case "peer-limit":
                    return Phrase.peer_limit__setting;
                case "peer-port":
                    return Phrase.port__setting;
                case "port-forwarding-enabled":
                    return Phrase.port_forwarding_enabled__setting;
                case "speed-limit-down":
                    return Phrase.speed_limit_down__setting;
                case "speed-limit-up":
                    return Phrase.speed_limit_up__setting;
                default:
                    foreach(setting; settings.getSettingArray)
                    {
                        if(setting.getName == name)
                            return setting.getId();
                    }
                    /*
                    //Transmission specific
                    if(client.getSoftware == "Transmission")
                    {
                        uint id = jhash(name);
                        if(id <= Phrase.max)
                            id += Phrase.max;
                        return id;
                    }
                    */
                    debug {
                        Logger.addWarning("ClutchGui: No setting id found for '{}'.", name);
                    }
                    return 0;
            }
        }
        
        Setting.Type getType(JsonValue value)
        {
            switch(value.type)
            {
                case JsonType.String: return Setting.Type.STRING;
                case JsonType.Number: return Setting.Type.NUMBER;
                case JsonType.Bool: return Setting.Type.BOOL;
                default: return Setting.Type.UNKNOWN;
            }
        }
        
        char[] toString(JsonValue value)
        {
            if(auto n = value.toJsonNumber)
                return n.toString();
            if(auto n = value.toJsonString)
                return n.toString();
            if(auto n = value.toJsonBool)
                return n.toString();
            return null;
        }
        
        foreach(char[] name, JsonValue value; in_args)
        {
            auto id = getId(name);
            auto type = getType(value);
            auto setting = settings.getSetting(id);
            
            if(setting is null)
            {
                debug
                {
                    Logger.addWarning("ClutchGui: Setting not found '{}'.", name);
                }
                continue;
            }
            
            if(setting.getType == type)
            {
                settings.setSetting(id, toString(value));
            }
            else debug
            {
                Logger.addWarning("ClutchGui: Unknown setting type for '{}'.", name);
            }
        }
        
        return empty_json_object;
    }
    
    private uint[] getAllDownloadIds(Client client)
    {
        if(client is null) return null;
        
        auto files_obj = client.getFiles();
        if(files_obj is null) return null;
        
        auto files = files_obj.getFileArray(File_.Type.DOWNLOAD, File_.State.ANYSTATE, 0);
        
        uint[] ids;
        foreach(file; files)
        {
            ids ~= file.getId();
        }
        return ids;
    }
    
    private JsonObject handleStopTorrent(JsonObject in_args, Client client)
    {
        auto ids = JsonBuilder!().fromJson!(uint[])( in_args["ids"] );
        
        if(ids.length == 0)
        {
            ids = getAllDownloadIds(client);
        }
        
        auto files = client.getFiles();
        if(files) files.stopFiles(File_.Type.DOWNLOAD, ids);
        
        return empty_json_object;
    }
    
    private JsonObject handleStartTorrent(JsonObject in_args, Client client)
    {
        auto ids = JsonBuilder!().fromJson!(uint[])( in_args["ids"] );
        
        if(ids.length == 0)
        {
            ids = getAllDownloadIds(client);
        }
        
        auto files = client.getFiles();
        if(files)
            files.startFiles(File_.Type.DOWNLOAD, ids);
        
        return empty_json_object;
    }
    
    private JsonObject handleRemoveTorrent(JsonObject in_args, Client client)
    {
        auto files = client.getFiles();
        
        if(files is null)
            return empty_json_object;
        
        //bool delete_local_data = in_args["delete-local-data"].toBool;
        auto ids = in_args["ids"].to!(uint[]);
        
        if(ids.length == 0)
            ids = getAllDownloadIds(client);
        
        if(ids.length)
            files.removeFiles(File_.Type.DOWNLOAD, ids);
        
        return empty_json_object;
    }
    
    private JsonObject handleTorrentGet(JsonObject in_args, Client client)
    {
        auto fields = JsonBuilder!().fromJson!(char[][])( in_args["fields"] );
        //auto ids = in_args["ids"].to!(uint[]); //not supported yet
        
        auto torrents = new JsonArray();
        
        File[] files = null;
        if(auto obj = client.getFiles)
            files = obj.getFileArray(File_.Type.DOWNLOAD, File_.State.ANYSTATE, 0);
        
        foreach(file; files)
        {
            auto obj = new JsonObject();
            
            File[] sub_files;
            if(auto obj = file.getFiles)
            {
                sub_files = obj.getFileArray(File_.Type.SUBFILE, File_.State.ANYSTATE, 0);
            }
            else
            {
                sub_files = [file];
            }
            
            foreach(field; fields)
            {
                switch(field)
                {
                case "addedDate":
                    obj[field] = 0;
                    break;
                case "announceURL":
                    char[] url = "http://unknown";
                    auto nodes = file.getNodes();
                    if(nodes)
                    {
                        auto servers = nodes.getNodeArray(Node_.Type.SERVER, Node_.State.ANYSTATE, 0);
                        if(servers.length)
                        {
                            url = servers[0].getName();
                        }
                    }
                    obj[field] = url;
                    break;
                case "comment":
                    obj[field] = "";
                    break;
                case "creator":
                    obj[field] = "";
                    break;
                case "dateCreated":
                    obj[field] = 0; //seconds since 1970
                    break;
                case "downloadedEver":
                    obj[field] = file.getDownloaded();
                    break;
                case "error":
                    obj[field] = 0;
                    break;
                case "errorString":
                    obj[field] = "";
                    break;
                case "eta":
                    auto downloaded = file.getDownloaded();
                    auto size = file.getSize();
                    auto rate = file.getDownloadRate();
                    obj[field] = rate ? ((size - downloaded) / rate) : -1;
                    break;
                case "hashString":
                    obj[field] = file.getHash();
                    break;
                case "haveUnchecked":
                    obj[field] = 0;
                    break;
                case "haveValid":
                    obj[field] = file.getDownloaded();
                    break;
                case "id":
                    obj[field] = file.getId();
                    break;
                case "isPrivate":
                    obj[field] = false;
                    break;
                case "leechers":
                    if(auto nodes = file.getNodes)
                    {
                        obj[field] = nodes.getNodeCount(Node_.Type.CLIENT , Node_.State.CONNECTED);
                    }
                    break;
                case "leftUntilDone":
                    obj[field] = file.getSize() - file.getDownloaded();
                    break;
                case "name":
                    obj[field] = file.getName();
                    break;
                case "peersGettingFromUs":
                    obj[field] = 0;
                    break;
                case "peersKnown":
                    if(auto nodes = file.getNodes)
                    {
                        obj[field] = nodes.getNodeCount(Node_.Type.CLIENT , Node_.State.ANYSTATE);
                    }
                    break;
                case "peersConnected":
                case "peersSendingToUs":
                    if(auto nodes = file.getNodes)
                    {
                        obj[field] = nodes.getNodeCount(Node_.Type.CLIENT , Node_.State.CONNECTED);;
                    }
                    break;
                case "priorities":
                    auto priorities = new JsonArray();
                    foreach(sub_file; sub_files)
                    {
                        switch(sub_file.getPriority)
                        {
                            case Priority.NONE:
                            case Priority.AUTO:
                                priorities ~= 0;
                                break;
                            case Priority.VERY_LOW:
                            case Priority.LOW:
                                priorities ~= -1;
                                break;
                            case Priority.NORMAL:
                                priorities ~= 0;
                                break;
                            case Priority.HIGH:
                            case Priority.VERY_HIGH:
                                priorities ~= 1;
                                break;
                        }
                    }
                    obj[field] = priorities;
                    break;
                case "rateDownload":
                    obj[field] = file.getDownloadRate();
                    break;
                case "rateUpload":
                    obj[field] = file.getUploadRate();
                    break;
                case "seeders":
                    if(auto nodes = file.getNodes)
                    {
                        obj[field] = nodes.getNodeCount(Node_.Type.CLIENT , Node_.State.CONNECTED);
                    }
                    break;
                case "sizeWhenDone":
                    obj[field] = file.getSize();
                    break;
                case "status":
                    uint state;
                    switch(file.getState)
                    {
                    case File_.State.ACTIVE:
                        state = 4; //Torrent._StatusDownloading
                        break;
                    case File_.State.PAUSED:
                    case File_.State.STOPPED:
                        state = 16; //Torrent._StatusPaused
                        break;
                    case File_.State.PROCESS:
                        state = 2; //Torrent._StatusChecking
                        break;
                    case File_.State.COMPLETE:
                        state = 8; //Torrent._StatusSeeding
                        break;
                    default:
                        state = 4;    
                    }
                    //Torrent._StatusWaitingToCheck  = 1;
                    obj[field] = state;
                    break;
                case "swarmSpeed":
                    obj[field] = file.getUploadRate();
                    break;
                case "totalSize":
                    obj[field] = file.getSize();
                    break;
                case "uploadedEver":
                    obj["uploadedEver"] = file.getUploaded();
                    break;
                case "files":
                    auto files_array = new JsonArray();
                    foreach(sub_file; sub_files)
                    {
                        auto file_object = new JsonObject();
                        file_object["bytesCompleted"] = sub_file.getDownloaded();
                        file_object["length"] = sub_file.getSize();
                        file_object["name"] = sub_file.getName();
                        files_array ~= file_object;
                    }
                    obj["files"] = files_array;
                    break;
                case "wanted":
                    auto wanted = new JsonArray();
                    foreach(sub_file; sub_files)
                    {
                        wanted ~= 0; //TODO
                    }
                    obj[field] = wanted;
                    break;
                case "recheckProgress":
                    obj[field] = 0.0; //TODO
                    break;
                case "uploadRatio":
                    obj[field] = 0.0; //TODO
                    break;
                case "seedRatioLimit":
                    obj[field] = 0.0; //TODO
                    break;
                case "seedRatioMode":
                    //TR_RATIOLIMIT_GLOBAL    = 0, /* follow the global settings */
                    //TR_RATIOLIMIT_SINGLE    = 1, /* override the global settings, seeding until a certain ratio */
                    //TR_RATIOLIMIT_UNLIMITED = 2  /* override the global settings, seeding regardless of ratio */
                    obj[field] = 0; //TODO
                    break;
                case "downloadDir":
                    obj[field] = ""; //TODO
                    break;
                case "fileStats":
                    auto array = new JsonArray();
                    foreach(sub_file; sub_files)
                    {
                        auto object = new JsonObject();
                        object["bytesCompleted"] = sub_file.getDownloaded();
                        switch(sub_file.getState())
                        {
                            case File_.State.PAUSED:
                            case File_.State.STOPPED:
                                object["wanted"] = false;
                                break;
                            default:
                                object["wanted"] = true;
                        }
                        
                        switch(sub_file.getPriority())
                        {
                            case Priority.VERY_LOW:
                            case Priority.LOW:
                                object["priority"] = -1;
                                break;
                            case Priority.NORMAL:
                            case Priority.NONE:
                            case Priority.AUTO:
                                object["priority"] = 0;
                                break;
                            case Priority.HIGH:
                            case Priority.VERY_HIGH:
                                object["priority"] = 1;
                                break;
                        }
                        
                        array ~= object;
                    }
                    obj[field] = array;
                    break;
                default:
                    debug
                    {
                        Logger.addWarning("ClutchGui: Unknown torrent field requested: {}", field);
                    }
                }
            }
            
            torrents ~= obj;
        }
        
        auto res_args = new JsonObject();
        res_args["torrents"] = torrents;
        
        return res_args;
    }
    
    /*
    * Download a torrent by url or torrent data.
    */
    private JsonObject handleTorrentAdd(JsonObject in_args, Client client)
    {
        char[] download_dir = in_args["download-dir"].toString;
        char[] filename = in_args["filename"].toString;
        char[] metainfo = in_args["metainfo"].toString;
        bool paused = in_args["paused"].toBool;
        uint peer_limit = in_args["peer-limit"].toInteger;
        
        if(metainfo.length)
        {
            auto data = Base64.decode(metainfo);
            client.addLink(cast(char[]) data);
        }
        else if(filename.length)
        {
            client.addLink(filename);
        }
        else
        {
            throw new Exception("ClutchGui: Metainfo or filename expected.");
        }
        
        /*
        if(id)
        {
            auto res = new JsonObject();
            res["id"] = id;
            //res["name"] = 
            //res["hashString"] = 
        }*/
        return empty_json_object;
    }
    
    //get uploaded torrent
    private void addTorrents(HttpRequest req, Client client, HttpResponse res)
    {
        res.setContentType("text/xml");
        
        char[][] file_names = req.getFiles();
        char[] status_string = "success";
        if(file_names.length == 0)
        {
            status_string = "No files were send.";
        }
        else if(client is null)
        {
            status_string = "No client available.";
        }
        else try
        {
            auto paused = (req.getParameter("paused") == "true"); //TODO
            
            foreach(file_name; file_names)
            {
                if(Utils.is_suffix(file_name, ".torrent"))
                {
                    auto content = tango.io.device.File.File.get(file_name);
                    client.addLink(cast(char[]) content);
                }
            }
        }
        catch(Exception e)
        {
            status_string = e.toString();
        }
        
        //Transmission sends XML as answer
        auto o = res.getWriter();
        o("<result>")(status_string)("</result>\r\n");
    }
}
