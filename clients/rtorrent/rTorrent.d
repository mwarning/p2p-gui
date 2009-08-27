module clients.rtorrent.rTorrent;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import tango.io.Stdout;
import tango.io.device.Array;
import tango.io.FilePath;
import Tango = tango.io.device.File;
import tango.io.model.IFile;
import tango.io.model.IConduit;
import tango.core.Array : find;
import tango.net.device.Socket;
import tango.text.convert.Layout;
static import Integer = tango.text.convert.Integer;
import tango.text.Util : jhash;
import tango.time.Clock;

static import Utils = utils.Utils;
static import Timer = utils.Timer;
import webcore.Logger;
import webcore.Dictionary;

import api.Client;
import api.Host;
import api.Node;
import api.File;
import api.User;
import api.Meta;
import api.Search;
import api.Setting;

import clients.rtorrent.rDownload;
import clients.rtorrent.rSetting;
import clients.rtorrent.rPeer;
import clients.rtorrent.rTracker;
import clients.rtorrent.XmlOutput;
import clients.rtorrent.XmlInput;

//some little helper
V get(V, K)(V[K] aa, K key)
{
    auto ptr = (key in aa);
    return ptr ? (*ptr) : null;
}

struct VariableRequest
{
    void ctor(char[] request)
    {
        this.request = request;
        pos = find(request, rTorrent.dummy_hash);
    }
    
    char[] withHash(char[] hash)
    {
        request[pos..pos+rTorrent.dummy_hash.length] = hash;
        return request;
    }
    
    char[] request;
    size_t pos; //hash position
}


final class rTorrent : Client, Files, Settings
{
private:
    
    const uint id;
    
    char[] host = "127.0.0.1";
    ushort port = 5000;
    
    char[] software = "rTorrent";
    char[] version_str;

    Array buffer;
    rDownload[uint] files;
    rSetting[uint] settings;
    
    uint lastChanged;
    bool is_connected;
    
    uint upload_rate;
    uint download_rate;
    ulong upload_total;
    ulong download_total;
    
    uint tracker_id_counter;
    static const uint bittorrent_net_id = 1;
    
    BtNetwork network;
    class BtNetwork : NullNode
    {
        rTorrent rt;
        this(rTorrent rt)
        {
            this.rt = rt;
        }
        
        uint getId() { return bittorrent_net_id; }
        char[] getName() { return "BitTorrent"; }
        Node_.State getState() { return rt.getState(); }
        ulong getUploaded() { return rt.getUploaded(); }
        ulong getDownloaded() { return rt.getDownloaded(); }
    }
    
    
    static char[] stats_update_request;
    static const char[] dummy_hash = "0000000000000000000000000000000000000000";
    
    //static VariableRequest full_peer_request;
    //static VariableRequest update_peer_request;
    
    //static char[] full_downloads_request;
    //static char[] update_downloads_request;
    
    static const uint preview_setting_id = Phrase.Preview_Directory__setting;
    
public:

    //static this replacement
    //since it would result in a cyclic dependency on runtime
    static this()
    {
        //build regular requests
        if(stats_update_request.length)
        {
            return;
        }
        
        auto msg = new Multicall();
        msg.addMethod("get_up_rate");
        msg.addMethod("get_down_rate");
        msg.addMethod("get_up_total");
        msg.addMethod("get_down_total");
        stats_update_request = msg.toString();
        
        //avoid cyclic dependency errors
        rDownload.construct();
        rPeer.construct();
        rTracker.construct();
    }
    
    this(uint id)
    {
        this.id = id;
        network = new BtNetwork(this);
        buffer = new Array(1024, 1024);
        
        settings[preview_setting_id] = new rSetting(preview_setting_id, "Preview Directory", "", Setting.Type.STRING);
        
        //will be prefixed by "get_" or "set_"
        struct Rec { char[] name; Setting.Type type; }
        static const Rec[] all_settings =
        [
        {"bind", Setting.Type.STRING}, {"check_hash", Setting.Type.STRING},
        {"connection_leech", Setting.Type.STRING}, {"connection_seed", Setting.Type.STRING},
        {"dht_port", Setting.Type.STRING}, {"directory", Setting.Type.STRING},
        {"download_rate", Setting.Type.STRING}, {"handshake_log", Setting.Type.STRING},
        {"hash_interval", Setting.Type.STRING}, {"hash_max_tries", Setting.Type.STRING},
        {"hash_read_ahead", Setting.Type.STRING}, {"http_cacert", Setting.Type.STRING},
        {"http_capath", Setting.Type.STRING}, {"http_proxy", Setting.Type.STRING},
        {"ip", Setting.Type.STRING}, {"key_layout", Setting.Type.STRING},
        {"max_downloads_div", Setting.Type.STRING}, {"max_downloads_global", Setting.Type.STRING},
        {"max_file_size", Setting.Type.STRING}, {"max_memory_usage", Setting.Type.STRING},
        {"max_open_files", Setting.Type.STRING}, {"max_open_http", Setting.Type.STRING},
        {"max_open_sockets", Setting.Type.STRING}, {"max_peers", Setting.Type.STRING},
        {"max_peers_seed", Setting.Type.STRING}, {"max_uploads", Setting.Type.STRING},
        {"max_uploads_div", Setting.Type.STRING}, {"max_uploads_global", Setting.Type.STRING},
        {"min_peers", Setting.Type.STRING}, {"min_peers_seed", Setting.Type.STRING},
        {"name", Setting.Type.STRING}, {"peer_exchange", Setting.Type.STRING},
        {"port_open", Setting.Type.STRING}, {"port_random", Setting.Type.STRING},
        {"port_range", Setting.Type.STRING}, {"preload_min_size", Setting.Type.STRING},
        {"preload_required_rate", Setting.Type.STRING}, {"preload_type", Setting.Type.STRING},
        {"proxy_address", Setting.Type.STRING}, {"receive_buffer_size", Setting.Type.STRING},
        {"safe_sync", Setting.Type.STRING}, {"scgi_dont_route", Setting.Type.STRING},
        {"send_buffer_size", Setting.Type.STRING}, {"session", Setting.Type.STRING},
        {"session_lock", Setting.Type.STRING}, {"session_on_completion", Setting.Type.STRING},
        {"split_file_size", Setting.Type.STRING}, {"split_suffix", Setting.Type.STRING},
        {"timeout_safe_sync", Setting.Type.STRING}, {"timeout_sync", Setting.Type.STRING},
        {"tracker_dump", Setting.Type.STRING}, {"tracker_numwant", Setting.Type.STRING},
        {"upload_rate", Setting.Type.STRING}, {"use_udp_trackers", Setting.Type.STRING}
        ];
        
        foreach(info; all_settings)
        {
            auto sid = chooseSettingId(info.name);
            settings[sid] = new rSetting(sid, info.name, "", info.type);
        }
    }

    ~this()
    {
        disconnect();
    }
    
    void previewFile(File_.Type type, uint id)
    {
        if(type != File_.Type.DOWNLOAD)
        {
            return;
        }
        
        if(auto file = (id in files))
        {
            previewFile(file.getName);
        }
        else
        {
            Logger.addWarning(this, "rTorrent: File id {} not found!", id);
        }    
    }
    
    void previewFile(char[] file_name, char[] prefix = null)
    {
        auto setting = (preview_setting_id in settings);
        if(setting is null)
        {
            return;
        }
        
        if(setting.getValue.length == 0)
        {
            Logger.addInfo(this, "rTorrent: Please set preview directory first.");
            return;
        }
        
        FilePath path = new FilePath(setting.getValue);
        if(prefix.length)
        {
            path.append(prefix);
        }
        
        path.append(file_name);
        
        if(!path.exists)
        {
            Logger.addWarning(this, "rTorrent: Can't find file for preview '{}'.", path.toString);
            return;
        }
        
        if(path.isFolder)
        {
            Logger.addWarning(this, "rTorrent: Can only preview files, found folder '{}'.", path.toString);
            return;
        }
        
        auto fc = new Tango.File(path.toString);
        Host.saveFile(fc, file_name, path.fileSize);
    }
    
    private void changed()
    {
        lastChanged = (Clock.now - Time.epoch1970).seconds;
    }
    
    uint getLastChanged()
    {
        return lastChanged;
    }
    
    private void setVersion()
    {
        auto msg = new XmlOutput("system.client_version");
        auto res = send(msg);
        if(res) version_str = res.getString();
    }
    
    void connect()
    {
        if(is_connected) return;
        is_connected = true;

        Timer.add(&updateStats, 0.5, 2);
        setVersion();
        //updateAllSettings();  //off until rTorrent won't crash
        
        changed();
    }
    
    void disconnect()
    {
        if(!is_connected) return;
        is_connected = false;
        
        version_str = null;
        files = null;
        upload_rate = 0;
        download_rate = 0;
        upload_total = 0;
        download_total = 0;
        tracker_id_counter = 0;
        
        Timer.remove(this);
        
        changed();
    }

    bool isConnected()
    {
        return is_connected;
    }
    
    //generate an unique id for a setting name
    private static uint chooseSettingId(char[] name)
    {
        uint id = jhash(name);
        
        //avoid collisions with unified setting ids
        if(id <= Phrase.max)
            id += Phrase.max;
        
        return id;
    }

    private Time settings_last_changed;
    private void updateAllSettings()
    {
        //prevent function to be executed too frequently (<4sec)
        auto now = Clock.now();
        if((now - settings_last_changed) < TimeSpan.fromSeconds(4))
        {
            return;
        }
        settings_last_changed = now;
        
        foreach(setting; settings)
        {
            if(setting.getId() == preview_setting_id)
                continue;
            
            scope msg = new XmlOutput("get_" ~ setting.getName());
            
            
            if(auto res = send(msg.toString))
            {
                //TODO: extract value from response
                setting.setValue("");
            }
            else
            {
                Logger.addError(this, "rTorrent: Cannot load setting '{}'", setting.getName());
                return;
            }
        }
    }

    private void updateStats()
    {
        if(auto res = send(stats_update_request))
        {
            upload_rate = res.getUInt();
            download_rate = res.getUInt();
            upload_total = res.getULong();
            download_total = res.getULong();
            
            changed();
        }
    }
    
    private void setPreviewDirectory(char[] directory)
    {
        auto setting = (preview_setting_id in settings);
        if(setting is null)
        {
            return;
        }
        
        if(directory[$-1] != FileConst.PathSeparatorChar)
        {
            directory ~= FileConst.PathSeparatorChar;
        }
        
        auto path = new FilePath(directory);
        if(!path.exists || !path.isFolder)
        {
            Logger.addWarning(this, "rTorrent: Directory '{}' does not exist.", directory);
            return;
        }
        
        setting.setValue(directory);
    }
    
    uint getId() { return id; }
    char[] getLocation() { return null; }
    char[] getProtocol() { return "xml-rpc"; }
    char[] getDescription() { return ""; }
    char[] getHost() { return host; }
    ushort getPort() { return port; }
    uint getAge() { return port; }
    void setHost(char[] host) { this.host = host; }
    void setPort(ushort port) { this.port = port; }
    void setUsername(char[] user) { }
    void setPassword(char[] pass) { }
    Priority getPriority() { return Priority.NONE; }
    ushort getPing() { return 0; }
    uint getUploadRate() { return upload_rate; }
    uint getDownloadRate() { return download_rate; }
    
    ulong getUploaded()
    {
        ulong tmp;
        foreach(file; files)
        {
            tmp += file.getUploaded();
        }
        return tmp;
    }
    
    ulong getDownloaded()
    {
        ulong tmp;
        foreach(file; files)
        {
            tmp += file.getDownloaded();
        }
        return tmp;
    }
    
    private Time all_files_last_changed;
    private void updateAllDownloads()
    {
        //only allow updated every 2 seconds
        auto now = Clock.now();
        if((now - all_files_last_changed) < TimeSpan.fromSeconds(2))
        {
            return;
        }
        all_files_last_changed = now;
        
        rDownload[uint] files;
        
        auto res = send(rDownload.full_update_request);
        
        if(res) while(!res.allConsumed())
        {
            char[] hash = res.peekStringSlice();
            if(hash.length != 40)
            {
                Logger.addError(this, "rTorrent: Got wrong XML element.");
                return;
            }
            
            uint id = jhash(hash);
            files[id] = new rDownload(id, res, this);
        }
        
        this.files = files;
    }
    
    private Time all_trackers_last_changed;
    private void updateAllTrackers()
    {
        updateAllDownloads();
        
        //only allow updated every 2 seconds
        auto now = Clock.now();
        if((now - all_trackers_last_changed) < TimeSpan.fromSeconds(2))
        {
            return;
        }
        all_trackers_last_changed = now;
        
        foreach(file; files)
        {
            char[] hash = file.getHash();
            char[] req = rTracker.full_request.withHash(hash);
            auto res = send(req);
            if(res) file.updateTracker(res);
        }
    }
    
    private Time all_peers_last_changed;
    private void updateAllPeers()
    {
        updateAllDownloads();
        
        //only allow updated every 2 seconds
        auto now = Clock.now();
        if((now - all_peers_last_changed) < TimeSpan.fromSeconds(2))
        {
            return;
        }
        all_peers_last_changed = now;
        
        foreach(file; files)
        {
            char[] hash = file.getHash();
            char[] req = rPeer.full_request.withHash(hash);
            auto res = send(req);
            if(res)
            {
                file.updateAllPeers(res);
            }
        }
    }

    uint getUserCount(/*User.State state*/) { return 0; }
    
    Nodes getNodes() { return this; }
    Settings getSettings() { return this; }
    Metas getMetas() { return null; }
    Users getUsers() { return null; }
    Searches getSearches() { return null; }
    Files getFiles() { return this; }

    void copyFiles(File_.Type type, uint[] sources, uint target) {}
    void moveFiles(File_.Type type, uint[] sources, uint target) {}
    
    private void sendFileCommand(uint[] ids, char[] cmd)
    {
        foreach(id; ids)
        {
            auto file = (id in files);
            if(file is null) continue;
            
            auto msg = new XmlOutput(cmd);
            msg.addArg(file.getHash);
            send(msg);
        }
    }
    
    void removeFiles(File_.Type type, uint[] ids)
    {
        if(type != File_.Type.DOWNLOAD) return;
        sendFileCommand(ids, "d.erase");
    }
    void renameFile(File_.Type type, uint id, char[] new_name) {}
    void startFiles(File_.Type type, uint[] ids)
    {
        if(type != File_.Type.DOWNLOAD) return;
        sendFileCommand(ids, "d.start");
    }
    
    void pauseFiles(File_.Type type, uint[] ids)
    {
        if(type != File_.Type.DOWNLOAD) return;
        sendFileCommand(ids, "d.stop");
    }
    
    void stopFiles(File_.Type type, uint[] ids)
    {
        if(type != File_.Type.DOWNLOAD) return;
        sendFileCommand(ids, "d.close");
    }
    
    void prioritiseFiles(File_.Type type, uint[] ids, Priority p)
    {
        int priority;
        switch(p)
        {
            case Priority.NONE:
            case Priority.AUTO:
            case Priority.VERY_LOW:
            case Priority.LOW:
            case Priority.NORMAL:
                priority = 1;
                break;
            case Priority.HIGH:
            case Priority.VERY_HIGH:
                priority = 2;
                break;
        }
        
        foreach(id; ids)
        {
            if(auto file = (id in files))
            {
                auto msg = new XmlOutput("f.set_priority");
                msg.addArg(file.getHash);
                msg.addArg(0);
                msg.addArg(priority);//priority
                send(msg);
            }
        }
    }
    
    void start() {}
    void shutdown() {}

    char[] getSoftware() { return software; }
    char[] getName() { return null; }
    char[] getUsername() { return null; }
    char[] getPassword() { return null; }
    char[] getVersion() { return version_str; }
    Node_.Type getType() { return Node_.Type.CORE; }
    Node_.State getState()
    {
        return is_connected ? Node_.State.CONNECTED : Node_.State.DISCONNECTED;
    }

    void connect(Node_.Type type, uint id) {}
    void disconnect(Node_.Type type, uint id) {}
    
    uint getFileCount(File_.Type type, File_.State state)
    {
        if(type == File_.Type.DOWNLOAD) return files.length;
        return 0;
    }
    
    File getFile(File_.Type type, uint id)
    {
        if(type == File_.Type.DOWNLOAD) return get(files, id);
        return null;
    }

    File[] getFileArray(File_.Type type, File_.State state, uint age)
    {
        if(type != File_.Type.DOWNLOAD || !is_connected)
        {
            return null;
        }
        
        updateAllDownloads();
        
        return Utils.filter!(File)(files, state, age);
    }
    
    uint getNodeCount(Node_.Type type, Node_.State state)
    {
        if(type == Node_.Type.NETWORK)
        {
            return cast(uint) is_connected;
        }
        return 0;
    }
    
    Node getNode(Node_.Type type, uint id)
    {
        if(type == Node_.Type.NETWORK && id == network.getId && is_connected)
        {
            return network;
        }
        return null;
    }
    
    Node[] getNodeArray(Node_.Type type, Node_.State state, uint age)
    {
        if(!is_connected) return null;
        
        if(type == Node_.Type.NETWORK)
        {
            return Utils.filter!(Node)([network], state, age);
        }
        else if(type == Node_.Type.CLIENT)
        {
            updateAllPeers();
            
            rPeer[] peers;
            foreach(file; files)
            {
                peers ~= file.getPeers();
            }
            return Utils.filter!(Node)(peers, state, age);
        }
        else if(type == Node_.Type.SERVER)
        {
            updateAllTrackers();
            
            Node[] trackers;
            foreach(file; files)
            {
                trackers ~= file.getTracker();
            }
            return trackers;
        }
        return null;
    }

    void enableNetwork(uint id) {}
    void disableNetwork(uint id) {}
    
    void addLink(char[] link)
    {
        if(link.length > 512)
            return;
        
        //set_directory string /data/
        if(Utils.is_prefix(link, "http://") || Utils.is_prefix(link, "www"))
        {
            Logger.addWarning(this, "rTorrent: Cannot load web links.");
            return;
        }
        
        auto msg = new XmlOutput("load", link);
        auto res = send(msg);
        if(res)
        {
            Logger.addInfo(this, "rTorrent: Torrent started.");
        }
    }
    
    Node addNode(Node_.Type type, char[] host, ushort  port, char[], char[]) { return null; }
    void removeNode(Node_.Type type, uint id) {}

    void renameDownload(uint id, char[] new_name)
    {
    }
    
    rSetting getrSetting(uint id)
    {
        if(!is_connected)
            return null;
        
        auto ptr = (id in settings);
        return ptr ? *ptr : null;
    }
    
    Setting getSetting(uint id)
    {
        return getrSetting(id);
    }
    
    /*
    * Note: rTorrent doesn't seem to set the value.
    */
    void setSetting(uint id, char[] value)
    {
        if(id == 1)
        {
            setPreviewDirectory(value);
            return;
        }
        
        auto setting = getrSetting(id);
        if(setting && value != setting.getValue)
        {
            auto msg = new XmlOutput("set_" ~ setting.getName, value);
            auto res = send(msg);
            if(res) //response ok
            {
                setting.setValue(value);
            }
        }
    }
    
    uint getSettingCount()
    {
        return is_connected ? settings.length : 0;
    }
    
    Setting[] getSettingArray()
    {
        return is_connected ? Utils.convert!(Setting)(settings) : null;
    }
    
    XmlInput send(Multicall req)
    {
        return send( req.toString() );
    }
    
    XmlInput send(XmlOutput req)
    {
        char[] request = req.toString();
        return send(request);
    }
    
    synchronized XmlInput send(char[] msg)
    {
        if(!is_connected)
        {
            return null;
        }
        
        if(msg.length == 0)
        {
            Logger.addError(this, "rTorrent: Message to send is empty.");
            return null;
        }
        
        buffer.clear();    
        size_t read = 0;
        auto sc = new Socket();
        
        try
        {
            sc.connect(new IPv4Address(host, port));
            sc.socket.send(msg);
            sc.flush();
            
            read = Utils.transfer(&sc.read, &buffer.write);
        }
        catch(Exception e)
        {
            disconnect();
            Logger.addError(this, "rTorrent: {}", e.toString);
            return null;
        }
        
        sc.shutdown();
        sc.close();
        
        if(read == 0 || read == IConduit.Eof)
        {
            disconnect();
            Logger.addError(this, "rTorrent: Connection failed.");
            return null;
        }
        
        char[] res = cast(char[]) buffer.slice();
        auto pos = find(res, "<methodResponse>");
        res = res[pos..$];
        
        //check first 32 chars for fault tag presence
        if(res.length > 32 && 32 != find(res[0..32], "<fault>"))
        {
            char[] fault_code = getValue(res, "<i4>");
            char[] fault_string = getValue(res, "<string>");
            Logger.addWarning(this, "rTorrent: Fault Received: {}", fault_string);
            return null;
        }
        
        return new XmlInput(res);
    }
}
