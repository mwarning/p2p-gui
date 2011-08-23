module clients.transmission.Transmission;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/

import tango.io.Stdout;
import Path = tango.io.Path;
import tango.io.device.Array;
static import tango.io.device.File;
import tango.io.model.IFile;
import tango.io.model.IConduit;
import tango.net.device.Socket;
import tango.text.Util;
import tango.core.Array;
import tango.time.Clock;
static import Base64 = tango.util.encode.Base64;
static import Convert = tango.util.Convert;
static import Integer = tango.text.convert.Integer;

import api.Client;
import api.Host;
import api.Node;
import api.File;
import api.Meta;
import api.User;
import api.Search;
import api.Connection;
import api.Setting;

static import Selector = utils.Selector;
static import Timer = utils.Timer;
static import Utils = utils.Utils;
static import Main = webcore.Main;
import webcore.Dictionary; //for unified settings
import webcore.Logger;

import utils.json.JsonParser;
import utils.json.JsonBuilder;

import clients.transmission.TTorrent;
import clients.transmission.TTracker;
import clients.transmission.TFile;
import clients.transmission.TPeer;
import clients.transmission.TSetting;


final class Transmission : Client, Files, Nodes, Settings
{
private:
    
    alias JsonBuilder!().JsonValue JsonValue;
    alias JsonBuilder!().JsonString JsonString;
    alias JsonBuilder!().JsonNumber JsonNumber;
    alias JsonBuilder!().JsonNull JsonNull;
    alias JsonBuilder!().JsonBool JsonBool;
    alias JsonBuilder!().JsonArray JsonArray;
    alias JsonBuilder!().JsonObject JsonObject;

    uint id;
    char[] host = "127.0.0.1";
    ushort port = 9091;

    char[] session_id; //value for request header key X-Transmission-Session-I
    char[] basic_auth;
    char[] username;
    char[] password;
    
    bool is_connected;
    TSetting preview_directory;
    
    uint upload_speed;
    uint download_speed;
    ulong downloaded;
    ulong uploaded;

    char[] client_version;

    Time lastChanged;

    void changed()
    {
        lastChanged = Clock.now();
    }
    
    TTorrent[uint] downloads;
    TSetting[uint] settings;
    
    const uint torrent_get_tag = 1;
    const uint session_stats_tag = 2;
    const uint get_settings_tag = 3;
    
    package BtNetwork network;
    static const uint bittorrent_net_id = 1;
    
    static final class BtNetwork : NullNode
    {
        Transmission tc;
        this(Transmission tc)
        {
            this.tc = tc;
        }
        
        uint getId() { return bittorrent_net_id; }
        char[] getName() { return "BitTorrent"; }
        Node_.State getState() { return tc.getState(); }
        ulong getUploaded() { return tc.getUploaded(); }
        ulong getDownloaded() { return tc.getDownloaded(); }
    }

    Array buffer;
    
public:

    this(uint id)
    {
        this.id = id;
        network = new BtNetwork(this);
        buffer = new Array(8 * 1024, 2 * 1024);
        
        preview_directory = new TSetting(Phrase.Preview_Directory__setting, "Preview Directory", null, Setting.Type.STRING);
    }
    
    uint getId() { return id; }
    
    uint getLastChanged() { return (lastChanged - Time.epoch1970).seconds; }
    char[] getHost() { return host; }
    ushort getPort() { return port; }
    char[] getLocation() { return null; }
    void setHost(char[] host) { this.host = host; }
    void setPort(ushort port) {this.port = port; }
    
    synchronized void connect()
    {
        if(is_connected) return;
        is_connected = true;

        if(username.length)
            basic_auth = Base64.encode(cast(ubyte[]) (username ~ ":" ~ password));
        
        Timer.add(&updateSlow, 0.5, 5);
        Timer.add(&updateFast, 1, 2);
        Timer.add(&statsRequest, 1, 2);
        
        //sneak in own setting
        settings[preview_directory.getId] = preview_directory;
        
        changed();
    }
    
    synchronized void disconnect()
    {
        if(!is_connected) return;
        is_connected = false;
        session_id = null;
        basic_auth = null;
        
        buffer.clear();
        
        upload_speed = 0;
        download_speed = 0;
        downloads = null;
        settings = null;
        downloaded = 0;
        uploaded = 0;
        client_version = null;
        
        //remove all callers related to this instance
        Timer.remove(this); 
        
        changed();
    }
    
    char[] getSoftware() { return "Transmission"; }
    char[] getVersion() { return client_version; }
    char[] getName() { return null; }
    char[] getUsername() { return username; }
    char[] getPassword() { return password; }
    char[] getProtocol() { return "json-rpc"; }
    
    void setUsername(char[] username)
    {
        this.username = username;
    }
    
    void setPassword(char[] password)
    {
        this.password = password;
    }
    
    void addLink(char[] link)
    {
        if(link.length < 200 * 1024)
        {
            addTorrent(link);
        }
        else
        {
            Logger.addError(this, "Transmission: File too big.");
        }
    }
    
    void shutdown() {}
    
    uint getFileCount(File_.Type type, File_.State state)
    {
        return downloads.length;
    }
    
    uint getNodeCount(Node_.Type type, Node_.State state)
    {
        if(type == Node_.Type.NETWORK)
        {
            return 1;
        }
    }
    
    uint getUserCount(/*User.State state*/) { return 0; }
    
    Searches getSearches() { return null; }
    Nodes getNodes() { return this; }
    Files getFiles() { return this; }
    
    Settings getSettings()
    {
        if(!is_connected) return null;
        getJsonSettings();
        return this;
    }
    
    Metas getMetas() { return null; }
    Users getUsers() { return null; }
    
    char[] getDescription() { return null; }
    ushort getPing() { return 0; }
    uint getAge() { return 0; }
    Priority getPriority() { return Priority.NONE; }
    
    uint getUploadRate() { return upload_speed; }
    uint getDownloadRate() { return download_speed; }
    ulong getUploaded() { return uploaded; }
    ulong getDownloaded(){ return downloaded; }
    
    
    Node_.Type getType() { return Node_.Type.CORE; }
    Node_.State getState()
    {
        return is_connected ? Node_.State.CONNECTED : Node_.State.DISCONNECTED;
    }

//from Nodes:
    
    Node addNode(Node_.Type type, char[] host, ushort  port, char[] user, char[] password) { return null; }
    void removeNode(Node_.Type type, uint id) {}

    void connect(Node_.Type type, uint id) {}
    void disconnect(Node_.Type type, uint id) {}
    
    Node getNode(Node_.Type type, uint id)
    {
        if(type == Node_.Type.NETWORK && is_connected && id == network.getId)
        {
            return network;
        }
        return null;
    }
    
    Node[] getNodeArray(Node_.Type type, Node_.State state, uint age) 
    {
        if(type == Node_.Type.NETWORK && is_connected)
        {
            return Utils.filter!(Node)([network], state, age);
        }
        else if(type == Node_.Type.CLIENT || type == Node_.Type.SERVER)
        {
            Node[] all = [];
            foreach(download; downloads)
            {
                all ~= download.getNodeArray(type, state, age);
            }
            return all;
        }
        return null;
    }
    
//from Files
    
    File getFile(File_.Type type, uint id)
    {
        if(type == File_.Type.DOWNLOAD)
        {
            auto ptr = (id in downloads);
            if(ptr) return *ptr;
        }
        return null;
    }
    
    File[] getFileArray(File_.Type type, File_.State state, uint age)
    {
        if(type != File_.Type.DOWNLOAD) return null;
        return Utils.filter!(File)(downloads, state, age);
    }

    void previewFile(File_.Type type, uint id) {}

    void removeFiles(File_.Type type, uint[] ids)
    {
        deleteTorrents(ids);
    }
    
    void copyFiles(File_.Type type, uint[] source, uint target) {}
    void moveFiles(File_.Type taddype, uint[] source, uint target) {}
    
    void renameFile(File_.Type type, uint id, char[] new_name)
    {
        Logger.addWarning(this, "Transmission: Renaming not supported.");
    }
        
    //for download resume and search result start
    void startFiles(File_.Type type, uint[] ids)
    {
        startTorrents(ids);
    }
    
    void pauseFiles(File_.Type type, uint[] ids)
    {
        stopTorrents(ids);
    }
    
    void stopFiles(File_.Type type, uint[] ids)
    {
        stopTorrents(ids);
    }
    
    /*
    * Set priority for files.
    */
    void prioritiseFiles(File_.Type type, uint[] ids, Priority priority)
    {
        //missing files indexes match all
        static const uint[] all;
        
        switch(priority)
        {
            case Priority.VERY_LOW:
            case Priority.LOW:
                torrentSet(ids, "priority-low", all);
                break;
            case Priority.NONE:
            case Priority.AUTO:
            case Priority.NORMAL:
                torrentSet(ids, "priority-normal", all);
                break;
            case Priority.HIGH:
            case Priority.VERY_HIGH:
                torrentSet(ids, "priority-high", all);
                break;
        }
    }

    void setPreviewDirectory(char[] path)
    {
        auto setting = preview_directory;
        if(setting is null) return;
        
        if(path.length == 0)
        {
            setting.value = null;
            return;
        }
        
        if(path[$-1] != FileConst.PathSeparatorChar)
        {
            path ~= FileConst.PathSeparatorChar;
        }
        
        if(!Path.exists(path))
        {
            Logger.addWarning(this, "Transmission: Directory '{}' does not exist.", path);
            return;
        }
        
        setting.value = path;
    }
    
    Setting getSetting(uint id)
    {
        if(!is_connected)
            return null;
        
        if(settings.length <= 1)
            getJsonSettings();
        
        auto ptr = (id in settings);
        return ptr ? *ptr : null;
    }
    
    void setSetting(uint id, char[] value)
    {
        //sneak in own setting
        if(id == preview_directory.getId)
        {
            return setPreviewDirectory(value);
        }
        
        auto setting = cast(TSetting) getSetting(id);
        if(setting) sessionSet(setting, value);
    }
    
    uint getSettingCount()
    {
        return is_connected ? settings.length : 0;
    }
    
    Setting[] getSettingArray()
    {
        return is_connected ? Utils.convert!(Setting)(settings) : null;
    }
    
    void previewFile(char[] name)
    {
        char[] path;
        
        if(preview_directory.value.length)
        {
            path = preview_directory.value;
        }
        else
        {
            auto id = getSettingId("download-dir");
            auto setting = getSetting(id);
            
            if(setting is null || setting.getValue().length == 0)
            {
                Logger.addWarning(this, "Transmission: The preview directory nor download-dir is set for file preview.");
                return;
            }
            else
            {
                path = setting.getValue();
            }
        }
        
        Utils.appendSlash(path);
        
        path ~= name;
        
        if(!Path.exists(path))
        {
            Logger.addWarning(this, "Transmission: Can't find file '{}' for preview.", path);
            return;
        }
        
        if(Path.isFolder(path))
        {
            Logger.addWarning(this, "Transmission: Can only preview files, found folder '{}'.", path);
            return;
        }
        
        auto fc = new tango.io.device.File.File(path);
        Host.saveFile(fc, name, Path.fileSize(path));
    }
    
    private void getJsonSettings()
    {
        assert(get_settings_tag == 3);
        send(`{ "method" : "session-get", "tag": 3 }`);
    }
    
    //request static data for torrents
    private void updateSlow()
    {
        assert(torrent_get_tag == 1);
        
        send(`{"method":"torrent-get","tag":1,"arguments":{ "fields":[`
            `"id","addedDate", "announceURL", "comment", "creator", "dateCreated", "hashString", "id", "isPrivate", "name", "totalSize", "files"] }}`
        );
    }
    
    //request dynamic data for torrents
    private void updateFast()
    {
        assert(torrent_get_tag == 1);
        
        send(`{"method":"torrent-get","tag":1,"arguments":{"fields":[` //"ids":"recently-active", //not supported by older versions
            `"id","downloadedEver", "error", "errorString", `
            `"haveUnchecked", "haveValid", "leechers", "leftUntilDone", "peersConnected",`
            `"peersGettingFromUs", "peersSendingToUs", "rateDownload", "rateUpload",`
            `"recheckProgress", "seeders", "sizeWhenDone", "status", "swarmSpeed",`
            `"uploadedEver", "uploadRatio", "seedRatioLimit", "seedRatioMode", "downloadDir", "fileStats"] }}`
        );
    }
    
    void deleteTorrents(uint[] ids)
    {
        actionRequest("torrent-remove", ids);
    }
    
    void verifyTorrents(uint[] ids)
    {
        actionRequest("torrent-verify", ids);
    }

    void startTorrents(uint[] ids)
    {
        actionRequest("torrent-start", ids);
    }
    
    void stopTorrents(uint[] ids)
    {
        actionRequest("torrent-stop", ids);
    }
    
    private void actionRequest(char[] method, uint[] ids)
    {
        if(ids.length == 0) return;
        
        auto args = new JsonObject();
        args["ids"] = ids;
        
        auto packet = new JsonObject();
        packet["method"] = method;
        packet["arguments"] = args;
        
        send(packet);
    }

    private void statsRequest()
    {
        assert(session_stats_tag == 2);
        send(`{"method":"session-stats","tag": 2}`);
    }

    void setPeerLimit(uint[] ids, uint max_peers)
    {
        torrentSet(ids, "peer-limit", max_peers);
    }
    
    void setFilesWanted(uint[] ids, uint[] subfiles_wanted)
    {
        torrentSet(ids, "files-wanted", subfiles_wanted);
    }
    
    void setFilesUnwanted(uint[] ids, uint[] subfiles_unwanted)
    {
        torrentSet(ids, "files-unwanted", subfiles_unwanted);
    }
    
    void setSpeedLimitDown(uint[] ids, uint speed_limit_down)
    {
        torrentSet(ids, "speed-limit-down", speed_limit_down);
    }
    
    void setSpeedLimitDownEnabled(uint[] ids, bool enable)
    {
        torrentSet(ids, "speed-limit-down-enabled", enable);
    }
    
    void setSpeedLimitUp(uint[] ids, uint speed_limit_up)
    {
        torrentSet(ids, "speed-limit-up", speed_limit_up);
    }
    
    void setSpeedLimitUpEnabled(uint[] ids, bool enable)
    {
        torrentSet(ids, "speed-limit-up-enabled", enable);
    }
    
    private void torrentSet(T)(uint[] ids, char[] arg_name, T arg_value)
    {
        if(ids.length == 0)
            return;
        
        auto args = new JsonObject();
        auto packet = new JsonObject();
        
        args[arg_name] = arg_value;
        args["ids"] = ids;
        
        packet["method"] = "torrent-set";
        packet["arguments"] = args;
        
        send(packet);
    }
    
    private void sessionSet(TSetting setting, char[] new_value)
    {
        if(setting is null || new_value.length > 160 || setting.getValue == new_value)
        {
            return;
        }
        
        auto args = new JsonObject();
        
        switch(setting.type)
        {
        case Setting.Type.BOOL:
            args[setting.name] = Convert.to!(bool)(new_value);
            break;
        case Setting.Type.NUMBER:
            args[setting.name] = Convert.to!(double)(new_value);
            break;
        case Setting.Type.STRING:
            args[setting.name] = new_value;
            break;
        }
        
        auto packet = new JsonObject();
        packet["method"] = "session-set";
        packet["arguments"] = args;
        
        send(packet);
    }
    
    void addTorrent(void[] torrent_file, char[] download_dir = null, bool paused = false, int peer_limit = 0)
    {
        auto args = new JsonObject();
    
        if(download_dir)
            args["download-dir"] = download_dir;
        
        if(paused)
            args["paused"] = 1;
        
        if(peer_limit)
            args["peer-limit"] = peer_limit;
        
        args["metainfo"] = Base64.encode(cast(ubyte[]) torrent_file);
        
        auto packet = new JsonObject();
        
        packet["method"] = "torrent-add";
        packet["arguments"] = args;
        packet["tag"] = "torrent-add";
        
        send(packet);
    }
    
    private synchronized void send(JsonObject query)
    {
        buffer.clear();
        query.print((char[] s) { buffer.append(s); }, false);
        send(cast(char[]) buffer.slice.dup);
    }

    private synchronized void send(char[] query)
    {
        buffer.clear();
        buffer.append("POST /transmission/rpc HTTP/1.1\r\n");
        buffer.append("User-Agent: " ~ Host.main_name ~ "\r\n");
        buffer.append("Content-Type: application/json; charset=UTF-8\r\n");
        
        if(session_id.length)
            buffer.append("X-Transmission-Session-Id: " ~ session_id ~ "\r\n");
        
        if(basic_auth.length)
            buffer.append("Authorization: Basic " ~ basic_auth ~  "\r\n");
        
        buffer.append("Content-Length: " ~ Integer.toString(query.length) ~ "\r\n\r\n");
        buffer.append(query);

        debug(Transmission)
            Stdout("(D) Transmission request:\n")(req).newline;
        
        char[] packet_header;
        char[] packet_body;
        
        try
        {
            debug(Transmission)
            {
                Stdout("Transmission: Out:\n")(cast(char[]) buffer.slice).newline;
            }
            
            scope socket = new Socket();
            socket.connect(new IPv4Address(host, port));
            
            socket.write(buffer.slice);
            
            buffer.clear();
            
            auto read = Utils.transfer(&socket.read, &buffer.write);
            if(read == 0 || read == IConduit.Eof)
            {
                throw new Exception("Transmission: Connection failed.");
            }
            
            socket.shutdown();
            socket.close();
            
            char[] in_msg = cast(char[]) buffer.slice();
            debug(Transmission)
                Stdout("Transmission: In:\n")(in_msg).newline;
            
            auto header_end = 4 + find(in_msg, "\r\n\r\n");
            if(header_end < in_msg.length)
            {
                packet_header = in_msg[0..header_end];
                packet_body = in_msg[header_end..$];
                
                handlePacketBody(packet_body);
            }
            else
            {
                Logger.addWarning(this, "Transmission: No payload found.");
            }
        }
        catch(Exception e)
        {
            /*
            *    If we receive a 409 http error code,
            *    then we haven't set the  X-Transmission-Session-Id header yet.
            */
            if(Utils.is_prefix(packet_header, "HTTP/1.1 409") && session_id.length == 0)
            {
                //extract the value of a given key
                static char[] getHeaderValue(char[] header, char[] key)
                {
                    auto beg = key.length + find(header, key);
                    if(beg >= header.length)
                        return null;
                    auto end = beg + find(header[beg..$], "\r\n");
                    if(end >= header.length)
                        return null;
                    return header[beg..end].dup;
                }
                
                session_id = getHeaderValue(packet_header, "X-Transmission-Session-Id: ");
        
                if(session_id.length != 0)
                {
                    //resend message
                    return send(query);
                }
                Logger.addError(this, "Transmission: Could not get X-Transmission-Session-Id.");
            }
            
            Logger.addError(this, "Transmission: {}", e.toString);
            disconnect(); //clears buffer, too
        }
    }
    
    private void handlePacketBody(char[] packet_body)
    {
        auto pa = new JsonParser!();
        auto packet = pa.parseObject(packet_body);
        
        auto data = packet["arguments"].toJsonObject();
        char[] result = packet["result"].toString();
        uint tag = packet["tag"].toInteger();
        
        
        if(result != "success")
        {
            Logger.addError(this, "Transmission: Received error: {}", result);
            return;
        }

        if(data is null)
        {
            Logger.addError(this, "Transmission: No payload received for tag {}.", tag);
            return;
        }
        
        switch(tag)
        {
            case 0:
                break;
            case torrent_get_tag:
                auto array = data["torrents"].toJsonArray();
                if(array) handleTorrents(array);
                break;
            case session_stats_tag:
                handleStats(data);
                break;
            case get_settings_tag:
                handleSettings(data);
                break;
            default:
                Logger.addWarning(this, "Transmission: Unknown tag {}.", tag);
        }
    }
    
    private void handleTorrents(JsonArray array)
    {
        uint[] ids;
        foreach(JsonValue file_value; array)
        {
            auto file = file_value.toJsonObject();
            if(file is null) continue;
            
            uint id = file["id"].toInteger();
            if(id == 0) continue;
            
            if(auto download = (id in downloads))
            {
                download.update(file);
            }
            else
            {
                downloads[id] = new TTorrent(file, this);
            }
            ids ~= id;
        }
        
        foreach(id; Utils.diff(downloads.keys, ids))
        {
            downloads.remove(id);
        }
    }
    
    private void handleStats(JsonObject obj)
    {
        foreach(char[] key, JsonValue value; obj)
        {
            switch(key)
            {
            case "activeTorrentCount":
                //active_torrent_count = value.toInteger();
                break;
            case "downloadSpeed":
                download_speed = value.toInteger();
                break;
            case "pausedTorrentCount":
                //paused_torrent_count = value.toInteger();
                break;
            case "torrentCount":
                //torrent_count = value.toInteger();
                break;
            case "uploadSpeed":
                upload_speed = value.toInteger();
                break;
            case "cumulative-stats":
                auto object = value.toJsonObject();
                if(object is null) break;
                uploaded = object["uploadedBytes"].toInteger;
                downloaded = object["downloadedBytes"].toInteger;
                //object["filesAdded"].toInteger;
                //object["sessionCount"].toInteger;
                //object["secondsActive"].toInteger;
                break;
            case "current-stats":
                auto object = value.toJsonObject();
                if(object is null) break;
                //object["uploadedBytes"].toInteger;
                //object["downloadedBytes"].toInteger;
                //object["filesAdded"].toInteger;
                //object["sessionCount"].toInteger;
                auto age = object["secondsActive"].toInteger;
                break;
            default:
                debug(Transmission)
                {
                    Logger.addWarning(tc, "Transmission: Unhandled value for '{}'.", key);
                }
            }
        }
    }
    
    private static uint getSettingId(char[] name)
    {
        //map to unified id
        switch(name)
        {
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
                uint id = jhash(name);
                if(id <= Phrase.max)
                {
                    id+= Phrase.max;
                }
                return id;
        }
    }
    
    private void handleSettings(JsonObject object)
    {
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
        
        foreach(char[] name, JsonValue value; object)
        {
            if(name == "version")
            {
                client_version = toString(value);
            }
        
            auto id = getSettingId(name);
            auto type = getType(value);
            char[] string = toString(value);
            
            if(auto setting = (id in settings))
            {
                if(setting.getType == type && setting.value != string)
                {
                    setting.value = string;
                }
            }
            else if(type != Setting.Type.UNKNOWN)
            {
                settings[id] = new TSetting(id, name, string, type);
            }
        }
    }
}
