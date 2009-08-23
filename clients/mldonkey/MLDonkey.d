module clients.mldonkey.MLDonkey;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import tango.io.Stdout;
import Tango = tango.io.device.File;
import tango.io.model.IFile;
import tango.io.model.IConduit;
import tango.io.FilePath;
import tango.io.stream.Format;
import tango.text.Ascii;
import tango.text.Util;
import tango.text.convert.Layout;
import tango.net.device.Socket;
import tango.core.Array;
import tango.time.Clock;
static import Integer = tango.text.convert.Integer;
static import Convert = tango.util.Convert;
static import Base64 = tango.io.encode.Base64;

import api.Client;
import api.Host;
import api.Node;
import api.File;
import api.User;
import api.Meta;
import api.Setting;
import api.Search;

static import Utils = utils.Utils;
static import Selector = utils.Selector;
static import Timer = utils.Timer;
import webcore.Dictionary; //for unified settings
import webcore.Logger;

import clients.mldonkey.InBuffer;
import clients.mldonkey.OutBuffer;
import clients.mldonkey.model.MLFileInfo;
import clients.mldonkey.model.MLAddr;
import clients.mldonkey.model.MLServerInfo;
import clients.mldonkey.model.MLClientInfo;
import clients.mldonkey.model.MLClientKind;
import clients.mldonkey.model.MLClientState;
import clients.mldonkey.model.MLResult;
import clients.mldonkey.model.MLSearch;
import clients.mldonkey.model.MLSharedFile;
import clients.mldonkey.model.MLNetworkInfo;
import clients.mldonkey.model.MLSetting;
import clients.mldonkey.model.MLConsoleLine;


final class MLDonkey : Client, Settings, Metas, Files, Searches, Users
{
    uint id;
    
    Socket socket;
    
    char[] client_version;
    const uint core_protocol = 41;
    const char[] core_protocol_str = "41";
    ushort http_port = 4080; //for remote preview
    
    char[] host = "127.0.0.1";
    ushort port = 4001;
    char[] username = "admin";
    char[] password;
    
    InBuffer in_buf;
    
    Time lastChanged;
    void changed()
    {
        lastChanged = Clock.now();
    }

    ulong total_uploaded;
    ulong total_downloaded;
    ulong total_shared;
    uint total_upload_rate;
    uint total_download_rate;

    uint search_counter = 1;
    uint console_counter = 1;
    
    //send data, disconnect when cannot send data
    synchronized void send(OutBuffer msg)
    {
        try
        {
            auto sc = socket;
            if(sc) msg.send(sc);
        }
        catch(Exception e)
        {
            Logger.addError(this, "MLDonkey: {}", e.toString);
            disconnect();
            throw e;
        }
    }

    MLSharedFile[uint] shared_files;
    MLClientInfo[uint] clients;
    MLFileInfo[uint] files;
    MLServerInfo[uint] servers;
    MLNetworkInfo[uint] networks;
    MLSetting[uint] settings;
    MLSearch[uint] searches;
    MLResult[uint] results; //TODO: we do need a reliable cleanup for this temporary storage.
    
    MLConsoleLine[] console;
    
    static const uint preview_setting_id = Phrase.Preview_Directory__setting;
    
    //some little helper
    private static V get(V, K)(V[K] aa, K key)
    {
        auto ptr = (key in aa);
        return ptr ? (*ptr) : null;
    }
    
public:
    
    this(uint id)
    {
        this.id = id;
        in_buf = new InBuffer();
    }
    
    ~this()
    {
        disconnect();
    }
    
    synchronized void connect()
    {
        if(socket) return;
        
        try
        {
            socket = new Socket();
            socket.connect(new IPv4Address(host, port));
            socket.socket.blocking = false;
            
            //add setting categories
            settings[1] = new MLSettings("Donkey", this, 1);
            settings[2] = new MLSettings("BitTorrent", this, 2);
            settings[3] = new MLSettings("HTTP/FTP", this, 3);
            settings[4] = new MLSettings("HTML", this, 4);
            settings[5] = new MLSettings("Networks", this, 5);
            settings[6] = new MLSettings("Gnutella 2", this, 6);
            settings[7] = new MLSettings("Gnutella 1", this, 7);
            settings[8] = new MLSettings("FastTrack", this, 8);
            settings[9] = new MLSettings("Direct Connect", this, 9);
            settings[10] = new MLSettings("Other", this, 10);
            
            //add local setting
            settings[preview_setting_id] = new MLSetting("Preview Directory", "", Setting.Type.STRING, preview_setting_id);
            
            Selector.register(socket, &run);
            Timer.add(&requestUploaders, 0.5, 2);
            
            changed();
        }
        catch(Exception e)
        {
            disconnect();
            Logger.addError(this, "MLDonkey: {}", e.toString);
        }
    }
    
    synchronized void disconnect()
    {
        if(socket is null) return;
        
        Timer.remove(this);

        Selector.unregister(socket);
        socket = null;
        
        in_buf.reset();
        
        total_uploaded = 0;
        total_downloaded = 0;
        total_shared = 0;
        total_upload_rate = 0;
        total_download_rate = 0;

        search_counter = 1;
        console_counter = 1;
        
        console = console.init;
        settings = settings.init;
        shared_files = shared_files.init;
        files = files.init;
        clients = clients.init;
        servers = servers.init;
        networks = networks.init;
        results = results.init;
        searches = searches.init;
        
        changed();
    }

    void setPreviewDirectory(char[] directory)
    {
        if(directory.length == 0)
        {
            if(auto setting = (preview_setting_id in settings))
            {
                setting.value = null;
            }
            return;
        }
        
        if(directory[$-1] != FileConst.PathSeparatorChar)
        {
            directory ~= FileConst.PathSeparatorChar;
        }
        
        auto path = new FilePath(directory);
        if(!path.exists || !path.isFolder)
        {
            Logger.addWarning(this, "MLDonkey: Directory '{}' does not exist!", directory);
            return;
        }
        
        if(auto setting = (preview_setting_id in settings))
        {
            setting.value = directory;
        }
    }
    
    uint getId() { return id; }
    uint getLastChanged() { return (lastChanged - Time.epoch1970).seconds; }
    char[] getHost() { return host; }
    ushort getPort() { return port; }
    char[] getLocation() { return null; }
    char[] getSoftware() { return "MLDonkey"; }
    char[] getVersion() { return client_version; }
    char[] getUsername() { return username; }
    char[] getName() { return username; }
    char[] getPassword() { return password; }
    char[] getDescription() { return null; }
    char[] getProtocol() { return core_protocol_str; }
    uint getAge() { return 0; }
    void startResult(uint id) {}

    Node addNode(Node_.Type type, char[] host, ushort  port, char[] user, char[] pass)
    {
        //implemented in MLNetworkInfo
        return null; 
    }
    
    void removeNode(Node_.Type type, uint  id) {}
    Priority getPriority() { return Priority.NONE; }
    ushort getPing() { return 0; }
    
    Node_.Type getType() { return Node_.Type.CORE; }
    Node_.State getState()
    {
        return socket ? Node_.State.CONNECTED : Node_.State.DISCONNECTED;
    }
    
    void shutdown()
    {
        auto o = new OutBuffer;
        o.write16(3);
        send(o);
    }
    
    void setHost(char[] host) { this.host = host; }
    void setPort(ushort port) { this.port = port; }
    void setUsername(char[] user) { this.username = user; }
    void setPassword(char[] password) { this.password = password; }
    
    void sendConsole(char[] line)
    {
        auto o = new OutBuffer;
        o.write16(29);
        o.writeString(line);
        send(o);
    }
    
    /*
    * Get preview for files.
    */
    void previewFile(File_.Type type, uint id)
    {
        if(socket is null) return;
        
        auto file = (id in files);
        
        if(file is null)
        {
            Logger.addWarning(this, "MLDonkey: File id {} not found!", id);
            return;
        }
        
        if(file.getPartFiles().length != 0)
        {
            Logger.addWarning(this, "MLDonkey: File id {} points to a directory!", id);
            return;
        }
        
        auto setting = (preview_setting_id in settings);
        if(setting && setting.value.length)
        {
            previewFromDisk(file.getNetworkId, toUpper(file.getHash), file.getName);
        }
        else
        {
            //Only for a file without subfiles (or only a single subfile)!
            previewFromNet(file.getId, file.getName, file.getSize);
        }
    }
    
    /*
    * Get a preview of files by using
    * MLDonkey's webservers and
    * forwarding the data.
    */
    void previewFromNet(uint file_id, char[] file_name, ulong size, ulong offset = 0, bool part_file = false)
    {
        if(size == 0) return;
        
        auto socket = new Socket();
        scope(failure)
        {
            socket.shutdown();
            socket.close();
        }
        
        char[256] buffer;
        size_t pos;
        void append(char[] s) { buffer[pos..pos+s.length] = s; }
        void appendNum(uint n) { Integer.toString(n, buffer[pos..$]); }
        
        append("GET /preview_download?q=");
        appendNum(file_id);
        append(" HTTP/1.1\r\n");
        append("User-Agent: ");
        append(Host.main_name);
        append("\r\n");
        append("Connection: keep-alive\r\n"); //try close?
        append("Accept-Encoding: chunked\r\n"); //remove?
        append("Authorization: Basic ");
        append( Base64.encode(cast(ubyte[]) (username ~ ":" ~ password)) );
        append("\r\n");
        if(part_file)
        {
            append("Range: bytes=");
            appendNum(offset);
            append("-");
            appendNum(offset + size  - 1);
            append("\r\n");
        }
        append("\r\n");
        
        socket.connect(new IPv4Address(host, http_port));
        socket.write(buffer[0..pos]);

        //reader header only
        char[] header = Utils.readUntil(socket, "\r\n\r\n", 512);

        //token found?
        if(header.length == 512)
            return;
        
        //extract file size from header to validate response
        static ulong extractSizeFromHeader(char[] header)
        {
            char[] token = "Content-Length: ";
            uint begin = header.find(token) + token.length;
            if(begin > header.length) return 0;
            uint end = begin + find(header[begin..$], "\r\n");
            if(end > header.length) return 0;
            return Convert.to!(ulong)(header[begin..end], 0);
        }
        
        ulong size_from_header = extractSizeFromHeader(header);
        if(size_from_header != size)
        {
            Logger.addError(this, "MLdonkey: Unexpected size from client!");
            socket.shutdown();
            socket.close();
            return;
        }
        
        Host.saveFile(socket, file_name, size);
    }
    
    /*
    * Get a preview of the file by copy
    * from MLDonkey's temp directory.
    * More efficient for as forwarding.
    */
    void previewFromDisk(uint network_id, char[] file_path, char[] file_name)
    {
        auto network = (network_id in networks);
        
        if(network is null)
        {
            Logger.addError(this, "MLDonkey: Network id {} not found!", network_id);
            return;
        }
        
        auto setting = (preview_setting_id in settings);
        
        if(setting is null)
            return;
        
        if(setting.value.length == 0)
        {
            Logger.addInfo(this, "MLDonkey: Please set preview directory first.");
            return;
        }
        
        char[] base_path = setting.value;
        char[] network_name = network.getName();
        switch(network_name)
        {
            case "Donkey":
                base_path ~= "urn_ed2k_" ~ file_path;
                break;
            case "BitTorrent":
                base_path ~= "BT-" ~ file_path;
                break;
            default:
                base_path ~= network_name ~ "-" ~ file_path;
        }
        
        auto path = new FilePath(base_path);
        
        if(!path.exists)
        {
            Logger.addWarning(this, "MLDonkey: Can't find file for preview '{}'.", base_path);
            return;
        }
        
        if(path.isFolder)
        {
            Logger.addWarning(this, "MLDonkey: Can only preview files, found folder '{}'.", base_path);
            return;
        }
        
        auto file = new Tango.File(path.toString);
        
        Host.saveFile(file, path.file, path.fileSize);
    }
    
    void addMeta(Meta_.Type type, char[] value, int rating)
    {
        if(type == Meta_.Type.CONSOLE)
            sendConsole(value);
    }
    
    void removeMeta(Meta_.Type type, uint id)
    {
    }
    
    Search addSearch(char[] query_string)
    {
        auto o = new OutBuffer;
        void sendQuery(Query query)
        {
            o.write8(query.type);
            
            switch(query.type)
            {
            case Query.Type.AND:
            case Query.Type.OR:
                o.write16(query.childs.length);
                foreach(q; query.childs)
                {
                    sendQuery(q);
                }
                break;
            case Query.Type.ANDNOT:
                if(query.childs.length < 2) break;
                sendQuery(query.childs[0]);
                sendQuery(query.childs[1]);
                break;
            default:
                o.writeString(query.comment);
                o.writeString(query.value);
            }
        }
        
        if(searches.length == 1)
            results = results.init; //remove obsolete results
        
        uint search_id = search_counter++;
        
        auto search = new MLSearch(search_id, query_string);
        searches[search_id] = search;
        
        o.write16(42);
        o.write32(search_id);
        
        //does search contain any pattern?
        if(search.childs.length == 0)
        {
            return null;
        }
        
        //MLDonkey doesn't accept a list with one item
        else if(search.childs.length == 1)
        {
            sendQuery(search.childs[0]);
        }
        else
        {
            sendQuery(search);
        }

        o.write32(search.max_results); //maximal number of results, not used?
        o.write8(1);    //0=local (ancient, doesn't work), 1=remote, 2=subscription (experimental server feature, probably not working)
        o.write32(search.network_id);

        send(o);
        return search;
    }
    
    Search[] getSearchArray()
    {
        return Utils.convert!(Search)(searches);
    }

    uint getUploadRate() { return total_upload_rate; }
    uint getDownloadRate() { return total_download_rate; }
    
    ulong getUploaded() { return total_uploaded; }
    ulong getDownloaded() { return total_downloaded; }
    
    //MLD doesn't react on this command...
    void stopSearch(uint searchID)
    {
        auto search = (searchID in searches);
        if(!search || !search.active) return;
        search.stop();
        auto o = new OutBuffer;
        o.write16(53);
        o.write32(searchID);
        o.write8(0);
        send(o);
    }

    void removeSearch(uint searchID)
    {
        MLSearch search = searches.get(searchID);
        if(!search) return;
        
        search.stop();
        search.removeResults(search.results.keys);
        searches.remove(searchID);
        
        auto o = new OutBuffer;
        o.write16(53);
        o.write32(searchID);
        o.write8(1);
        send(o);
    }

    void prioritiseDownload(uint id, byte priority)
    {
        auto o = new OutBuffer;
        o.write16(51);
        o.write32(id);
        o.write32(cast(uint) priority);
        send(o);
    }

    void enableNetwork(uint networkID)
    {
        auto o = new OutBuffer;
        o.write16(40);
        o.write32(networkID);
        o.write8(1);
        send(o);
    }

    void disableNetwork(uint networkID)
    {
        auto o = new OutBuffer;
        o.write16(40);
        o.write32(networkID);
        o.write8(0);
        send(o);
    }
    
    void pauseDownload(uint id)
    {
        auto o = new OutBuffer;
        o.write16(23);
        o.write32(id);
        o.write8(0);
        send(o);
    }

    void resumeDownload(uint id)
    {
        auto o = new OutBuffer;
        o.write16(23);
        o.write32(id);
        o.write8(1);
        send(o);
    }

    void renameDownload(uint id, char[] new_name)
    {
        auto file = (id in files);
        if(file is null) return;
        
        auto o = new OutBuffer;
        o.write16(13); //not 56
        o.write32(id);
        o.writeString(new_name);
        send(o);
        
        //GetFileInfo
        o.reset();
        o.write16(37);
        o.write32(id);
        send(o);
    }

    void cancelDownload(uint id)
    {
        auto o = new OutBuffer;
        o.write16(11);
        o.write32(id);
        send(o);
    }

    void addServer(uint networkID, uint ip, ushort port)
    {
        auto o = new OutBuffer;
        o.write16(54);
        o.write32(ip);
        o.write32(port);
        send(o);
    }

    void sendMessageToClient(uint clientID, char[] message)
    {
        auto o = new OutBuffer;
        o.write16(43);
        o.write32(clientID);
        o.writeString(message);
        send(o);
    }

    void connectServer(uint serverID)
    {
        auto o = new OutBuffer;
        o.write16(21);
        o.write32(serverID);
        send(o);
    }

    void disconnectServer(uint serverID)
    {
        auto o = new OutBuffer;
        o.write16(22);
        o.write32(serverID);
        send(o);
    }

    void connectClient(uint clientID)
    {
        auto o = new OutBuffer;
        o.write16(61);
        o.write32(clientID);
        send(o);
    }

    void disconnectClient(uint clientID)
    {
        auto o = new OutBuffer;
        o.write16(62);
        o.write32(clientID);
        send(o);
    }

    void setSetting(uint id, char[] value)
    {
        auto setting = (id in settings);
        
        if(setting is null)
            return;
        
        if(setting.getId == preview_setting_id)
            return setPreviewDirectory(value);
        
        //don't use global ids and settings we have sneaked in
        if(setting.getId < Phrase.max)
            return;
        
        //setting.update(value);
        auto o = new OutBuffer;
        o.write16(28);
        char[] name = setting.getName();
        o.writeString(name);
        o.writeString(value);
        send(o);
    }
    
    /*
    * Generate an unique id for a setting name.
    * Some setting names get a global id assigned.
    */
    private static uint chooseSettingId(char[] name)
    {
        //get a id based on a name hash
        uint id = jhash(name);
        
        //avoid collisions with unified setting ids and settings we have sneaked in (ids 1-11)
        if(id <= Phrase.max)
            id += Phrase.max;
        
        return id;
    }
    
    private void addSetting(char[] name, char[] value)
    {
        //store port for further connections (for preview)
        if(name == "http_port")
        {
            http_port = Convert.to!(ushort)(value, http_port);
        }
        
        uint id = chooseSettingId(name);
        
        //update when setting already stored
        if(auto setting = (id in settings))
        {
            setting.update(value);
            return;
        }
        
        bool is_prefix(char[] prefix)
        {
            if(prefix.length >= name.length) return false;
            return (name[0..prefix.length] == prefix);
        }
        
        uint category_id;
        if(is_prefix("ED2K")) category_id = 1;
        else if(is_prefix("BT")) category_id = 2;
        else if(is_prefix("FTP")) category_id = 3;
        else if(is_prefix("html")) category_id = 4;
        else if(is_prefix("enable")) category_id = 5;
        else if(is_prefix("G2")) category_id = 6;
        else if(is_prefix("GNUT")) category_id = 7;
        else if(is_prefix("FT")) category_id = 8;
        else if(is_prefix("DC")) category_id = 9;
        else category_id = 10; //misc
        
        auto type = Setting.Type.STRING;
        if(value == "true" || value == "false")
        {
            type = Setting.Type.BOOL;
        }
        
        settings[id] = new MLSetting(name, value, type, id);
        
        if(category_id)
        {
            auto category = cast(MLSettings) settings.get(category_id);
            assert(category, "(E) MLDonkey: Category id " ~ Utils.toString(category_id) ~" not found!");
            category.addSettingId(id);
        }
    }
    
    uint getSearchCount(File_.State state) { return searches.length; }
    Search getSearch(uint id) { return searches.get(id); }
    
    uint getFileCount(File_.Type type, File_.State state)
    {
        if(type == File_.Type.DOWNLOAD) return files.length;
        if(type == File_.Type.FILE) return shared_files.length;
        return 0;
    }
    
    File getFile(File_.Type type, uint id)
    {
        if(type == File_.Type.DOWNLOAD) return files.get(id);
        if(type == File_.Type.FILE) return shared_files.get(id);
        return null;
    }
    
    File[] getFileArray(File_.Type type, File_.State state, uint age)
    {
        if(type == File_.Type.DOWNLOAD) return Utils.filter!(File)(files, state, age);
        if(type == File_.Type.FILE) return Utils.filter!(File)(shared_files, state, age);
        return null;
    }
    
    void connect(Node_.Type type, uint id)
    {
        if(type == Node_.Type.NETWORK) return enableNetwork(id);
        if(type == Node_.Type.SERVER) return connectServer(id);
        if(type == Node_.Type.CLIENT) return connectClient(id);
    }
    
    void disconnect(Node_.Type type, uint id)
    {
        if(type == Node_.Type.NETWORK) return disableNetwork(id);
        if(type == Node_.Type.SERVER) return disconnectServer(id);
        if(type == Node_.Type.CLIENT) return disconnectClient(id);
    }
    
    void copyFiles(File_.Type type, uint[] sources, uint target) {}
    void moveFiles(File_.Type type, uint[] sources, uint target) {}
    
    void renameFile(File_.Type type, uint id, char[] new_name)
    {
        if(type != File_.Type.DOWNLOAD) return;
        renameDownload(id, new_name);
    }
    
    void startFiles(File_.Type type, uint[] ids)
    {
        if(type != File_.Type.DOWNLOAD) return;
        foreach(id; ids) resumeDownload(id);
    }
    
    void pauseFiles(File_.Type type, uint[] ids)
    {
        if(type != File_.Type.DOWNLOAD) return;
        foreach(id; ids) pauseDownload(id);
    }
    
    void stopFiles(File_.Type type, uint[] ids)
    {
        pauseFiles(type, ids);
    }
    
    void prioritiseFiles(File_.Type type, uint[] ids, Priority priority)
    {
        if(type != File_.Type.DOWNLOAD) return;
        byte p = 0;
        switch(priority)
        {
            case Priority.VERY_LOW: p = -20; break;
            case Priority.LOW: p = -10; break;
            case Priority.HIGH: p = 10; break;
            case Priority.VERY_HIGH: p = 20; break;
            default:
        }
        
        foreach(id; ids) prioritiseDownload(id, p);
    }
    
    uint getSharedFileByName(char[] file_name)
    {
        foreach(file; shared_files)
        {
            if(file.getName == file_name)
            {
                return file.getId();
            }
        }
        return 0;
    }
    
    uint getNodeCount(Node_.Type type, Node_.State state)
    {
        if(type == Node_.Type.CLIENT) return clients.length;
        if(type == Node_.Type.SERVER) return servers.length;
        if(type == Node_.Type.NETWORK) return networks.length;
        return 0;
    }
    
    Node getNode(Node_.Type type, uint id)
    {
        if(type == Node_.Type.CLIENT) return get(clients, id);
        if(type == Node_.Type.SERVER) return get(servers, id);
        if(type == Node_.Type.NETWORK) return get(networks, id);
        return null;
    }
    
    Node[] getNodeArray(Node_.Type type, Node_.State state, uint age)
    {
        if(type == Node_.Type.CLIENT) return Utils.filter!(Node)(clients, state, age);
        if(type == Node_.Type.SERVER) return Utils.filter!(Node)(servers, state, age);
        if(type == Node_.Type.NETWORK) return Utils.filter!(Node)(networks, state, age);
        return null;
    }
    
    Meta[] getMetaArray(Meta_.Type type, Meta_.State state, uint age)
    {
        if(type == Meta_.Type.CONSOLE) return Utils.filter!(Meta)(console, state, age);
        return null;
    }
    
    uint getMetaCount(Meta_.Type type, Meta_.State state)
    {
        if(type != Meta_.Type.CONSOLE) return 0;
        return console.length;
    }
    
    void removeFiles(File_.Type type, uint[] ids)
    {
        if(type != File_.Type.DOWNLOAD) return;
        foreach(id; ids) cancelDownload(id);
    }
    
    /*
    * Connect comments with already known nodes
    * - not used yet, may be used by source of file commnent
    */
    Node getNodeBy(char[] name, char[] host)
    {
        foreach(node; clients)
        {
            if(node.getName == name && node.getHost == host)
            {
                return node;
            }
        }
        return null;
    }
    
    Setting getSetting(uint id)
    {
        auto setting = (id in settings);
        return setting ? (*setting) : null;
    }
    
    uint getSettingCount()
    {
        return settings.length;
    }
    
    Setting[] getSettingArray()
    {
        Setting[] categories;
        for(uint id; id < 12; id++)
        {
            auto setting = (id in settings);
            if(setting) categories ~= *setting;
        }
        return categories;
    }

    Searches getSearches() { return this; }
    Nodes getNodes() { return this; }
    Files getFiles() { return this; }
    Settings getSettings() { return this; }
    Metas getMetas() { return this; }
    Users getUsers() { return this; }
    
    void removeSearchResults(uint search_id, uint[] result_ids)
    {
        auto search = (search_id in searches);
        if(search) search.removeResults(result_ids);
    }
    
    /*
    * searchID is ignored here, because all resultIDs are considered unique
    */
    void startSearchResults(uint search_id, uint[] result_ids)
    {
        auto o = new OutBuffer;
        foreach(id; result_ids)
        {
            o.write16(50);
            o.write16(0);     // result_names (empty list), purpose?
            o.write32(id);
            o.write8(0);    //0 = Try, 1 = Force Download
            send(o);
            o.reset;
        }
    }

    /*
    * http://mldonkey.sourceforge.net/MultiUser
    */
    //TODO: most stuff needs to be done via telnet
    uint addUser(User_.Type type, char[] name)
    {
        if(type == User_.Type.USER)
        {
        //useradd <user> <passwd> [<mail>] : 
        //sendConsole("useradd \"" ~ name ~ "\" \"\"");
        //if want to add users to another user
        //we have to change the user to a group
        //that also may disables the user account, since it's a group...
        //sendConsole("groupadd \"" ~ name ~ "\" \"\"");
        }
        else if(type == User_.Type.GROUP)
        {
            
        }
        return 0;
    }
    void renameUser(uint id, char[] new_name) {}
    void removeUser(uint id)
    {
        //TODO: get username by id
        //sendConsole("userdel \"" ~ name ~ "\"");
    }
    void setUserPassword(uint id, char[] password)
    {
        //if not admin, use passwd
        char[] name;
        sendConsole("useradd \"" ~ name ~ "\" \"" ~ password ~ "\"");
    }
    
    uint getUserCount(/*User.State state*/) { return 0; }
    User getUser(uint id) { return null; }
    User[] getUserArray() { return null; }
    
    void downloadLink(char[] url)
    {
        auto o = new OutBuffer;
        o.write16(8);
        o.writeString(url);
        send(o);
    }

    void addLink(char[] link)
    {
        if(link.length < 512)
        {
            downloadLink(link);
        }
        else if(link.length < 200 * 1024)
        {
            downloadTorrent(link);
        }
        else
        {
            Logger.addError(this, "MLDonkey: File too big.");
        }
    }
    
    /*
    * Send a Torrent file as string.
    */
    void downloadTorrent(void[] data)
    {
        //get BitTorrent network id
        uint net_id;
        foreach(net; networks)
        {
            if(net.getName == "BitTorrent")
            {
                net_id =  net.getId();
                break;
            }
        }
        if(net_id == 0) return;
        
        auto o = new OutBuffer;
        o.write16(63);
        o.write32(net_id); //network id
        o.write16(0xffff); //indicates 32bit length field following
        o.write32(data.length + 2);
        o.write16(0); //some flag?
        o.writeArray(cast(char[]) data);
        send(o);
    }

    void fileRemoveSource(uint fileID, uint clientID)
    {
        auto o = new OutBuffer;
        o.write16(50);
        o.write32(fileID);
        o.write32(clientID);
        send(o);
    }

    private void addConsoleString(char[] text)
    {
        char[][] lines = split(text, "\n");
        foreach(line; lines)
        {
            if(line.length > 120) line = line[0..120]; //crop line
            uint id = console_counter++;
            console ~= new MLConsoleLine(line, id);
        }
        
        if(console.length > 60)
        {
            console = console[$-60..$];
        }
    }
    
    /*
    * Request list of uploading client (opcode 55)
    */
    private void requestUploaders()
    {
        auto o = new OutBuffer;
        o.write16(57);
        send(o);
    }
    
    /*
    * Request client info (opcode 15)
    */
    private void requestClientInfo(uint[] ids)
    {
        foreach(id; ids)
        {
            auto o = new OutBuffer;
            o.write16(36);
            o.write32(id);
            send(o);
        }
    }
    
    private synchronized void run()
    {
        auto sc = this.socket;
        if(sc is null) return;
        
        try
        {
        auto read = in_buf.receive(sc);
        
        if(read == IConduit.Eof)
            return;
            
        if(read == 0)
        {
            Logger.addWarning(this, "MLDonkey: Connection failed.");
            disconnect();
            return;
        }
        
        while(in_buf.nextPacket)
        {
            //uint size = getSize();
            auto opCode = in_buf.read16();
            
            debug(MLDonkey)
                Logger.addDebug("MLDonkey: OpCode: {}", opCode);
            
            switch(opCode)
            {
            //LOGIN
            case 0:
                auto o = new OutBuffer;
            
                in_buf.read32(); //max protocol version accepted by core
                in_buf.read32(); //maxFromCore
                in_buf.read32(); //maxToCore
            
                // (06:00:00:00:) 00:00:28:00:00:00 GuiProtocol Message
                o.write16(0);
                o.write32(core_protocol);
                send(o);
                o.reset();
                
                // (04:00:00:00:) 82:00:00:00:00:00 Password (empty), login (empty)
                o.write16(52);
                o.writeString(password);
                o.writeString(username);
                send(o);
                o.reset();
            
                //interested in sources
                o.write16(64);
                o.write8(1);
                send(o);
                o.reset();
                
                //get version
                o.write16(65);
                send(o);
                break;
            
            //OPTIONS_INFO
            case 1:
                ushort len = in_buf.read16();
                for(auto i = 0; i < len; i++)
                {
                    char[] name = in_buf.readString();
                    char[] value = in_buf.readString();
                    addSetting(name, value);
                }
                break;
            
            //DEFINE_SEARCHES
            case 3: break; //not used
            
            //SEARCH_RESULT
            case 4:
                auto id = in_buf.read32();
                if(auto result = (id in results))
                {
                    result.update(in_buf);
                }
                else
                {
                    results[id] = new MLResult(id, in_buf);
                }
                break;
            
            //SEARCHES_MAPPING
            case 5:
                uint search_id = in_buf.read32();
                uint result_id = in_buf.read32();
            
                auto search = (search_id in searches);
                auto result = (result_id in results);
                if(search && result)
                {
                    search.addSearchResult(*result, this);
                    results.remove(result_id);
                }
                else debug(MLDonkey)
                {
                    Logger.addWarning(this, "MLdonkey: Unknown search/result pair: search: {} result: {}", search_id, result_id);
                }
                break;
            
            //??
            case 6:
                break;
            
            //FILE_UPDATE_AVAILABILITY //used?
            case 9:
                uint file_id = in_buf.read32();
                uint client_id = in_buf.read32();
                char[] chunk_str = in_buf.readString();
                if(auto client = (client_id in clients))
                {
                    client.updateAvailability(file_id, chunk_str);
                }
                break;
            
            //FILE_ADD_SOURCE
            case 10:
                auto id = in_buf.read32();
                auto file = (id in files);
                if(file) file.addClientId(in_buf.read32);
                break;
            
            //SERVER_UPDATE
            case 13:
                auto id = in_buf.read32();
                auto server = (id in servers);
                if(server) server.readMLClientState(in_buf);
                break;
            
            //CLIENT_INFO
            case 15:
                auto id = in_buf.read32();
                if(auto client = (id in clients))
                {
                    client.update(in_buf);
                    auto state = client.getState();
                    if( state == Node_.State.REMOVED 
                        || state == Node_.State.DISCONNECTED
                        //|| client.shared_file_id == 0
                    )
                    {
                        clients.remove(id);
                    }
                    break;
                }
                else
                {
                    auto client = new MLClientInfo(id, this, in_buf);
                    auto state = client.getState();
                    
                    if( state != Node_.State.REMOVED && state != Node_.State.DISCONNECTED
                        && (client.getDownloaded || client.getUploaded)
                    )
                    {
                        clients[id] = client;
                    }
                }
                break;
            
            //CLIENT_UPDATE
            case 16:
                auto id = in_buf.read32();
                auto client = (id in clients);
                if(client)
                {
                    client.readMLClientState(in_buf);
                    auto state = client.getState();
                    if(state == Node_.State.REMOVED || state == Node_.State.DISCONNECTED)
                    {
                        clients.remove(id);
                    }
                }
                break;
            
            //CONSOLE
            case 19:
                char[] lines = in_buf.readString();
                addConsoleString(lines);
                break;
            
            //NETWORK_INFO
            case 20:
                auto id = in_buf.read32(); //id>0
                if(auto network = (id in networks))
                {
                    network.update(in_buf);
                }
                else
                {
                    networks[id] = new MLNetworkInfo(id, in_buf, this);
                }
                
                break;
            
            //SERVER_INFO
            case 14: break; //old protocol version??
            case 26:
                auto id = in_buf.read32();
                if(auto server = (id in servers))
                {
                    server.update(in_buf);
                }
                else
                {
                    servers[id] = new MLServerInfo(id, in_buf, this);
                }
                break;
            
            //CONNECTED_SERVERS
            case 28: 
                ushort count = in_buf.read16();
                for(ushort i = 0; i < count; i++)
                {
                    auto id = in_buf.read32();
                    if(auto server = (id in servers))
                    {
                        server.update(in_buf);
                    }
                    else
                    {
                        servers[id] = new MLServerInfo(id, in_buf, this);
                    }
                }
                break;
            
            //ROOM_INFO
            case 31: break;
            
            //SHARED_FILE_INFO
            case 33: break; //for old protocol versions, but is still being send..
            
            //SHARED_FILE_UNSHARED
            case 35:
                auto id = in_buf.read32();
                shared_files.remove(id);
                break;
            
            //ADD_SECTION_OPTION
            case 36:
            case 38: break;
            
            //FILE_DOWNLOAD_UPDATE
            case 46:
                auto id = in_buf.read32();
                auto file = (id in files);
                if(file) file.updateDownload(in_buf);
                break;
            
            //BAD_PASSWORD
            case 47:
                disconnect();
                Logger.addWarning(this, "MLdonkey: Wrong Password!");
                break;
        
            //SHARED_FILES
            case 48:
                //all shared files, already downloading + completed, id is not transfer id
                auto id = in_buf.read32();
            
                //shared is, a new file | a transferred file | a file from incoming
                if(auto shared_file = (id in shared_files))
                {
                    shared_file.update(in_buf);
                    //update download file object
                    if(uint file_id = shared_file.download_id)
                    {
                        auto file = (file_id in files);
                        if(file) file.updateSharedInfo(*shared_file);
                    }
                }
                else
                {
                    auto shared_file = new MLSharedFile(id, in_buf);
                    shared_files[id] = shared_file;
                    
                    //check if shared file corresponds download file object
                    foreach(file; files)
                    {
                        if(file.getSize() == shared_file.size
                            && file.getName() == shared_file.name)
                        {
                            file.updateSharedInfo(shared_file);
                            shared_file.download_id = file.getId();
                            break;
                        }
                    }
                }
                break;
            
            //CLIENT_STATS
            case 49:
                total_uploaded = in_buf.read64();
                total_downloaded = in_buf.read64();
                total_shared = in_buf.read64();
                in_buf.read32(); //num_shared_files
                total_upload_rate = in_buf.read32();
                total_download_rate = in_buf.read32();
                total_upload_rate += in_buf.read32(); // UDP
                total_download_rate += in_buf.read32(); // UDP
                in_buf.read32(); //num_current_downloads
                in_buf.read32(); //num_finished_downloads
                //list of uint/uint pairs, network id -> num_connected_servers
                changed();
                break;
                
            //FILE_REMOVE_SOURCE
            case 50:
                auto id = in_buf.read32();
                auto file = (id in files);
                if(file) file.removeClient(in_buf.read32);
                break;
            
            //CLEAN_TABLES
            case 51:
                //keep only these items
                uint[] client_ids = in_buf.read32s();
                uint[] server_ids = in_buf.read32s();
            
                foreach(uint id; client_ids) clients.remove(id);
                foreach(uint id; server_ids) servers.remove(id);
                break;
            
            //FILE_INFO
            case 52:
                auto id = in_buf.read32();
                if(auto file = (id in files))
                {
                    file.update(in_buf);
                    auto state = file.getState();
                    if(state == File_.State.CANCELED
                        || state == File_.State.SHARED) //completed downloads turn into shared after commit
                    {
                        files.remove(id);
                    }
                }
                else
                {
                    auto file = new MLFileInfo(id, this, in_buf);
                    auto state = file.getState();
                    if(state != File_.State.CANCELED
                        && state != File_.State.SHARED)
                    {
                        files[id] = file;
                    }
                }
                break;
            
            //UPLOADERS
            case 55:
                //response to requestUploaders (opcode 57)
                uint[] uploading_client_ids = in_buf.read32s();
                requestClientInfo(uploading_client_ids);
                break;
            
            //VERSION
            case 58:
                client_version = in_buf.readString();
                break;
            
            default:
                //sometimes received/need to handle: 6 7 22 25 8
                Logger.addInfo(this, "MLDonkey: Unhandled opCode: {}", opCode);
            }
        
        } } catch(Exception e)
        {
            Logger.addError(this, "MLDonkey: {}", e.toString);
            in_buf.hexDump();
            disconnect();
        }
    }
}
