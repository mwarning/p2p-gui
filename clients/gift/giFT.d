module clients.gift.giFT;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import tango.io.Stdout;
import tango.io.device.Array;
import tango.text.convert.Format;
import tango.text.convert.Integer;
import tango.text.Util;
import tango.net.device.Socket;
import tango.core.Thread;
import tango.time.Clock;
import tango.text.Util;
import tango.io.model.IConduit;
static import Convert = tango.util.Convert;

static import Utils = utils.Utils;
static import GeoIP = utils.GeoIP;
static import Selector = utils.Selector;
import webcore.Logger;

import api.Client;
import api.Host;
import api.Node;
import api.File;
import api.User;
import api.Meta;
import api.Search;
import api.Setting;

import clients.gift.model.giFTFile;
import clients.gift.model.giFTSearch;
import clients.gift.model.giFTResult;
import clients.gift.model.giFTNetwork;
import clients.gift.giFTParser;

//some little helper
V get(V, K)(V[K] aa, K key)
{
    auto ptr = (key in aa);
    return ptr ? (*ptr) : null;
}

final class giFT :
    public Client, public Files
{
    const uint id;
    
    char[] host = "127.0.0.1";
    ushort port = 1213;
    
    uint lastChanged;
    bool is_connected;
    
    Socket socket;
    Array buffer;
    
    uint search_counter;
    uint network_counter;

    giFTFile[uint] files;
    giFTSearch[uint] searchInfos;
    giFTNetwork[uint] networkInfos;
    char[][char[]] options;
    
    char[] version_str;
    
public:

    this(uint id)
    {
        this.id = id;
        buffer = new Array(1024, 2 * 1024);
    }

    ~this()
    {
        disconnect();
    }

    void previewFile(File_.Type type, uint id)
    {
    }
    
    private void changed()
    {
        lastChanged = (Clock.now - Time.epoch1970).seconds;
    }
    
    uint getLastChanged()
    {
        return lastChanged;
    }
    
    synchronized void connect()
    {
        if(is_connected) return;
        
        try
        {
            socket = new Socket();
            socket.connect(new IPv4Address(host, port));
            
            is_connected = true;
            Selector.register(socket, &run);
            
            //if we don't attach first, giFt would close the connection
            send("ATTACH client(unknown) version(0.1) profile(default);");

            changed();
        }
        catch(Exception e)
        {
            Logger.addError(this, "giFT: {}", e.toString);
        }
    }

    synchronized void disconnect()
    {
        if(!is_connected) return;
        //send("DETACH;");
        is_connected = false;
        
        Selector.unregister(socket);
        socket = null;
        
        buffer.clear();
        
        files = files.init;
        searchInfos = searchInfos.init ;
        networkInfos = networkInfos.init;
        version_str = null;
        changed();
    }

    bool isConnected()
    {
        return is_connected;
    }
    
    uint getId() { return id; }
    char[] getLocation() { return GeoIP.getCountryCode(host); }
    char[] getProtocol() { return null; }
    char[] getDescription() { return null; }
    char[] getHost() { return host; }
    ushort getPort() { return port; }
    uint getAge() { return port; }
    void setHost(char[] host) { this.host = host; }
    void setPort(ushort port) { this.port = port; }
    void setUsername(char[] user) {}
    void setPassword(char[] pass) {}
    Priority getPriority() { return Priority.NONE; }
    ushort getPing() { return 0; }
    uint getUploadRate() { return 0; }
    uint getDownloadRate() { return 0; }
    
    ulong getUploaded() { return 0; }
    ulong getDownloaded() { return 0; }
    
    uint getNodeCount(Node_.Type type, Node_.State state) { return 0; }
    uint getUserCount(/*User.State state*/) { return 0; }
    
    Nodes getNodes() { return null; }
    Settings getSettings() { return null; }
    Metas getMetas() { return null; }
    Users getUsers() { return null; }

    void copyFiles(File_.Type type, uint[] sources, uint target) {}
    void moveFiles(File_.Type type, uint[] sources, uint target) {}
    void removeFiles(File_.Type type, uint[] ids) {}
    void renameFile(File_.Type type, uint id, char[] new_name) {}
    void startFiles(File_.Type type, uint[] ids) {}
    void pauseFiles(File_.Type type, uint[] ids) {}
    void stopFiles(File_.Type type, uint[] ids) {}
    void prioritiseFiles(File_.Type type, uint[] ids, Priority priority) {}
    
    void start() {}
    
    void shutdown()
    {
        send("QUIT;");
    }

    char[] getSoftware() { return "giFT"; }
    char[] getName() { return null; }
    char[] getUsername() { return null; }
    char[] getPassword() { return null; }
    char[] getVersion() { return version_str; }
    Node_.Type getType() { return Node_.Type.CORE; }
    Node_.State getState()
    {
        return is_connected ? Node_.State.CONNECTED : Node_.State.DISCONNECTED;
    }
    
    uint stats_asked;
    void getStats()
    {
        uint now = (Clock.now - Time.epoch1970).seconds;
        if(now - stats_asked < 2)
        {
            stats_asked = now;
            send("STATS;");
        }
    }
    
    void listDownloads()
    {
        send("DOWNLOADS;");
    }
    
    void getUploads()
    {
        send("UPLOADS;");
    }
    
    void actionDownload(uint id, char[] action)
    {
        char[] str = Format("TRANSFER({}) action ({});\n", id, action);
        send(str);
    }
    
    void delSource(uint id)
    {
        //char[] str = Format("DELSOURCE({}) url ({});\n", id, url);
        //send(str);
        //searchInfos.remove(id);
    }
    
    void connect(Node_.Type type, uint id) {}
    void disconnect(Node_.Type type, uint id) {}

    //Settings getSettings() { return this; }
    Searches getSearches() { return null; }
    Files getFiles() { return this; }
    
    uint getFileCount(File_.Type type, File_.State state)
    {
        if(type == File_.Type.DOWNLOAD) return files.length;
        return 0;
    }
    
    File getFile(File_.Type type, uint id)
    {
        return files.get(id);
    }
    
    File[] getFileArray(File_.Type type, File_.State state, uint age)
    {
        if(type == File_.Type.DOWNLOAD)
        {
            getStats(); //TODO: only update every .. seconds
            return Utils.filter!(File)(files, state, age);
        }
        return null;
    }
    
    uint getNodeCount(Node_.Type type)
    {
        //if(type == Node_.CLIENT) return clientInfos.length
        //if(type == Node_.SERVER) return serverInfos.length
        if(type == Node_.Type.NETWORK) return networkInfos.length;
        return 0;
    }
    
    Node getNode(Node_.Type type, uint id)
    {
        //if(type == Node_.CLIENT) return clientInfos[id];
        //if(type == Node_.SERVER)  return serverInfos[id];
        if(type == Node_.Type.NETWORK) return networkInfos.get(id); //new NullNode;
        return null;
    }
    
    Node[] getNodeArray(Node_.Type type, Node_.State state, uint age)
    {
        if(type == Node_.Type.NETWORK) return Utils.filter!(Node)(networkInfos, state, age);
        return null;
    }

    void setSetting(char[] var, char[] val)
    {
        
    }
    
    void enableNetwork(uint id) {}
    void disableNetwork(uint id) {}
    
    void pauseDownload(uint id)
    {
        char[] str = Format("TRANSFER({}) action (pause);", id);
        send(str);
    }
    
    void resumeDownload(uint id)
    {
        char[] str = Format("TRANSFER({}) action (unpause);", id);
        send(str);
    }
    
    void cancelDownload(uint id)
    {
        char[] str = Format("TRANSFER({}) action (cancel);", id);
        send(str);
    }
    
    void addLink(char[] link)
    {
        Logger.addError(this, "giFT: Not supported.");
    }
    
    /*
    * like search command, but search for sources by hash
    *
    void locateSources(char[] hash)
    {
        uint id = ++search_counter;
        std::ostringstream o;
        o << "LOCATE (" << id << ") query (" << hash << ");";
        send(o.str());
        Search search(new giFTSearch(id));
        searchInfos[id] = search;
        return id;
    }*/
    Node addNode(Node_.Type type, char[] host, ushort  port, char[], char[]) { return null; }
    void removeNode(Node_.Type type, uint id) {}
    /*
    uint startSearch(char[] keywords, File_.Media media, ulong min_size, ulong max_size)
    {
        return 0;
    }
    
    void removeSearch(uint id) {}
    void startResult(uint id) {}
    */
    void renameDownload(uint id, char[] new_name)
    {
    
    }
    
    void startSearchResult(uint search_id, uint result_id)
    {
        if(!(search_id in searchInfos)) {
            //throw new Exception("No such search. Cannot start download.");
            return;
        }
        auto search = (search_id in searchInfos);
        giFTResult result;
        if(search) result = search.getResult(result_id);
        if(result is null) return;
        //if(result == 0)  Exception("No such result. Cannot start download."); //not needed
        
        char[] str = Format
        (
            "ADDSOURCE user ({}) hash ({}) size ({}) url ({}) save ({});\n",
            result.getUser(), result.getHash(), result.getSize(),
            result.getUrl(), result.getName()
        );

        send(str);
    }

    void cancelSearch(uint id)
    {
        char[] str = Format("SEARCH({}) action (cancel);\n", id);
        send(str);
        searchInfos.remove(id);
    }

    void stopSearch(uint id)
    {
        char[] str = Format("SEARCH({}) action (stop);\n", id);
        send(str);
        //TODO: set search stopped
    }

    uint startSearch(char[] query)
    {
        if(query.length == 0) return 0; //throw Exception("Search invalid.");
        uint id = ++search_counter;
        char[] str = Format("SEARCH ({}) query ({});\n", id, query);
        //o << " META { "
        //<< "query (" << query << ")"//some keywords...
        //<<" };"
        send(str);
        searchInfos[id] = new giFTSearch(id, query);
        return id;
    }
    
    void getShares(uint id)
    {
        char[] str = Format("SHARES ({});", id);
        send(str);
    }
    
    synchronized void run()
    {
        auto sc = socket;
        if(sc is null) return;
        
        try
        {
            auto read = Utils.transfer(&sc.read, &buffer.write);
            
            if(read == 0 || read == IConduit.Eof)
            {
                throw new Exception("giFT: Connection failed.");
            }
            
            while(true)
            {
                debug(giFT) Stdout("|")(buffer.slice())("|").newline;
                
                scope msg = new giFTParser(cast(char[]) buffer.slice);
                uint ate = msg.getConsumed();
                if(ate == 0) break; //need to read more
                
                parse(msg);
                
                buffer.seek(ate, IOStream.Anchor.Current);
            }
        }
        catch(Exception e)
        {
            Logger.addError(this, "giFT: {}", e.toString);
            disconnect();
        }
    }

    //void parse(char[] str)
    void parse(giFTParser msg)
    {
        char[] cmd = msg.first_key;
        msg.print();
        
        switch(cmd)
        {
        case "ITEM":
            
            uint id = Convert.to!(uint)(msg["ITEM"]);
            auto search = (id in searchInfos);
            if(search)
            {
                (*search).addResult(msg);
            }
        //returned by "SHARES(session-id);":
        //ITEM (session-id) path (path and filename) size (filesize) mime (mime-type) hash (hash) META {name (value)};
            break;
        case "ADDSOURCE":
            uint id = Convert.to!(uint)(msg["ADDSOURCE"], 0);
            break;
        case "DELSOURCE":
            uint id = Convert.to!(uint)(msg["DELSOURCE"], 0);
            break;
        case "ADDDOWNLOAD":
            auto file = new giFTFile(msg);
            uint id = file.getId();
            if(!(id in files)) files[id] = file;
            break;
        case "CHGDOWNLOAD":
            uint id = Convert.to!(uint)(msg["CHGDOWNLOAD"], 0);
            if(id in files) files[id].update(msg);
            break;
        case "DELDOWNLOAD":
            uint id  = Convert.to!(uint)(msg["DELDOWNLOAD"], 0);
            files.remove(id);
            break;
        case "DELdir": //in use?
            uint id  = Convert.to!(uint)(msg["DELdir"], 0);
            files.remove(id);
            break;
        case "STATS":
            foreach(key, value; msg.map)
            {
                network_counter++;
                if(key == "giFT") continue;
                auto network = new giFTNetwork(network_counter, key, value);
                networkInfos[network_counter] = network;
            }
            break;
        case "ATTACH":
            //software = msg["server"]; // "giFT"
            version_str = msg["version"];
            getStats();
            break;
        }
    }
    
    synchronized void send(char[] cmd)
    {
        if(!is_connected) return; //throw Exception("giFT: Not Connected");
        debug(giFT) Stdout("Send: ")(cmd).newline;
        socket.socket.send(cmd);
    }
}
