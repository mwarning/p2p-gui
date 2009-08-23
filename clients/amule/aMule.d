module clients.amule.aMule;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/

import tango.time.Clock;
import tango.text.convert.Format;
import tango.text.Util;
import tango.text.Ascii;
static import Convert = tango.util.Convert;
static import Integer = tango.text.convert.Integer;
import tango.net.device.Socket;
import tango.io.compress.ZlibStream;
import tango.io.Stdout;
import tango.io.model.IFile;
import tango.io.model.IConduit;
import tango.io.digest.Md5;
import tango.io.device.Array;
static import Tango = tango.io.device.File;
import tango.io.FilePath;

import clients.amule.ECCodes;
import clients.amule.ECPacket;
import clients.amule.ECTag;
import clients.amule.model.AServerInfo;
import clients.amule.model.AFileInfo;
import clients.amule.model.AResultInfo;
import clients.amule.model.ASearchInfo;
import clients.amule.model.APreference;
import clients.amule.model.AClientInfo;

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
import webcore.Logger;
import webcore.Dictionary; //for unified settings
import webcore.Main;


/*
* aMule interface.
* supports EC protocol 0x200 (2.2.4) and 0x203 (2.2.5)
*/
final class aMule : Client, Files, Nodes, Searches, Settings
{
    //some little helper
    static V get(V, K)(V[K] aa, K key)
    {
        auto ptr = (key in aa);
        return ptr ? (*ptr) : null;
    }
    
    const uint id;
    char[] host = "127.0.0.1";
    ushort port = 4712;
    char[] username = "admin";
    char[] password;
    
    char[] version_str;
    
    uint upload_speed;
    uint download_speed;
    uint lastChanged;

    uint current_search_id; //aMule only allows one search at a time
    ASearchInfo[uint] searches;
    AFileInfo[uint] files;
    AServerInfo[uint] servers;
    APreference[uint] preferences;
    APreference[] categories;
    AClientInfo[uint] uploaders;
    
    Socket socket;
    Array buffer;
    
    //aMule temp directory for preview
    APreference preview_directory;
    
    ANetwork edonkey;
    ANetwork kademlia;
    
    ushort protocol_version = EC_CURRENT_PROTOCOL_VERSION; //0x203, default protocol version
    
    ECOpCodes last_op;
    
    final class ANetwork : NullNode
    {
        aMule amule;
        uint id;
        char[] name;
        Node_.State state = Node_.State.DISCONNECTED;
        uint user_count;
        uint file_count;
        
        this(aMule amule, uint id, char[] name)
        {
            this.id = id;
            this.name = name;
            this.amule = amule;
        }
        
        uint getId()
        {
            return id;
        }
        
        char[] getName()
        {
            return name;
        }
        
        Node_.State getState()
        {
            return state;
        }
        
        uint getFileCount(File_.Type type, File_.State state)
        {
            return file_count;
        }
        
        uint getUserCount()
        {
            return user_count;
        }
        
        //TODO: add kademlia/ed2k node
        Node addNode(Node_.Type type, char[] host, ushort  port, char[], char[])
        {
            return null;
        }
        
        //indicate that searches for this network are supported
        Searches getSearches()
        {
            return amule;
        }
    }
    
public:

    this(uint id)
    {
        this.id = id;
        preview_directory = new APreference(Phrase.Preview_Directory__setting, "Preview Directory", "");
        buffer = new Array(1024, 2048);
        edonkey = new ANetwork(this, 1, "Donkey");
        kademlia = new ANetwork(this, 2, "Kademlia");
    }
    
    char[] getSoftware() { return "aMule"; }
    char[] getVersion() { return version_str; }
    char[] getUsername() { return username; }
    char[] getName() { return username; }
    char[] getPassword() { return password; }
    
    char[] getProtocol()
    {
        //the other supported protocol version is 0x200
        return (protocol_version == 0x203) ? "515" : "512";
    }
    
    uint getId() { return id; }
    uint getLastChanged() { return  lastChanged; }
    char[] getHost() { return host; }
    ushort getPort() { return port; }
    char[] getLocation() { return null; }
    void setHost(char[] host) { this.host = host; }
    void setPort(ushort port) {this.port = port; }
    void setUsername(char[] user) { this.username = user; }
    void setPassword(char[] pass) { this.password = pass; }
    char[] getDescription() { return null; }
    Priority getPriority() { return Priority.NONE; }
    ushort getPing() { return 0; }
    
    uint getUploadRate() { return upload_speed; }
    uint getDownloadRate() { return download_speed; }
    ulong getUploaded() { return 0; }
    ulong getDownloaded() { return 0; }
    
    uint getAge() { return 0; }
    Node getNetwork() { return null; }
    Node_.Type getType() { return Node_.Type.CORE; }
    Node_.State getState()
    {
        return isConnected() ? Node_.State.CONNECTED : Node_.State.DISCONNECTED;
    }
    
    synchronized void connect()
    {
        if(socket) return;
        
        try
        {
            socket = new Socket();
            socket.connect(new IPv4Address(host, port));
            socket.socket.blocking = false;
            
            Selector.register(socket, &run);
            
            sendLogin();
            changed();
            
            categories ~= preview_directory;
        }
        catch(Exception e)
        {
            disconnect();
            Logger.addError(this, "aMule: {}", e.toString);
        }
    }
    
    synchronized void disconnect()
    {
        if(socket is null) return;
        
        Selector.unregister(socket);
        
        socket = null;
        buffer.clear();
        current_search_id = 0;
        
        searches = null;
        preferences = null;
        categories = null;
        uploaders = null;
        files = null;
        servers = null;
        
        edonkey.state = Node_.State.DISCONNECTED;
        kademlia.state = Node_.State.DISCONNECTED;
        
        upload_speed = 0;
        download_speed = 0;
        last_op = last_op.init;
        
        //remove all callers related to this instance
        Timer.remove(this); 
        
        changed();
    }
    
    /*
    * Set local setting preview_directory to access files for preview
    */
    void setPreviewDirectory(char[] directory)
    {
        if(directory.length == 0)
        {
            preview_directory.value = null;
            return;
        }
        
        if(directory[$-1] != FileConst.PathSeparatorChar)
        {
            directory ~= FileConst.PathSeparatorChar;
        }
        
        auto path = new FilePath(directory);
        if(!path.exists || !path.isFolder)
        {
            Logger.addWarning(this, "aMule: Directory '{}' does not exist!", directory);
            return;
        }
        
        preview_directory.value = directory;
    }
    
    bool isConnected() { return (socket !is null); }
    
    void connect(Node_.Type type, uint id)
    {
        if(type == Node_.Type.SERVER)
        {
            if(auto server = (id in servers))
            {
                connectServer(server.getIp, server.getPort);
            }
        }
    }
    
    void disconnect(Node_.Type type, uint id)
    {
        if(type == Node_.Type.SERVER)
        {
            if(auto server = (id in servers))
            {
                disconnectServer(server.getIp, server.getPort);
            }
        }
    }
    
    void removeNode(Node_.Type type, uint id)
    {
        if(type == Node_.Type.SERVER)
        {
            if(auto server = (id in servers))
            {
                removeServer(server.getIp, server.getPort);
            }
        }
    }
    
    void shutdown()
    {
        auto packet = new ECPacket(ECOpCodes.EC_OP_SHUTDOWN);
        send(packet);
    }
    
    void previewFile(File_.Type type, uint id)
    {
        if(type != File_.Type.DOWNLOAD) return;
        
        auto file = (id in files);
        if(file is null)
        {
            Logger.addWarning(this, "aMule: File id {} not found!", id);
            return;
        }
        
        auto part_id = file.getPartId();
        if(part_id == 0)
        {
            return;
        }
        
        if(preview_directory.value.length == 0)
        {
            Logger.addInfo(this, "aMule: Please set preview directory first.");
            return;
        }
        
        auto path = new FilePath (
            preview_directory.value ~ Format("{0:d3}", part_id) ~ ".part"
        );
        
        if(!path.exists)
        {
            Logger.addError(this, "aMule: Can't find file for preview '{}'!", path.toString);
            return;
        }
        
        if(path.isFolder)
        {
            Logger.addError(this, "aMule: Can only preview files, found folder '{}'!", path.toString);
            return;
        }
        
        auto fc = new Tango.File(path.toString);
        Host.saveFile (
            fc, file.getName, path.fileSize
        );
    }
    
    Nodes getNodes()
    {
        //block access to persistent network objects
        return isConnected() ? this : null;
    }
    
    Searches getSearches() { return this; }
    Files getFiles() { return this; }
    Users getUsers() { return null; }
    Settings getSettings() { return this; }
    Metas getMetas() { return null; }
    
    uint getUserCount()
    {
        return 0;
    }
    
    uint getNodeCount(Node_.Type type, Node_.State state)
    {
        if(type == Node_.Type.SERVER)
        {
            return servers.length;
        }
        else if(type == Node_.Type.NETWORK) 
        {
            if(state == Node_.State.ANYSTATE)
            {
                return 2;
            }
            uint i;
            if(edonkey.getState == state) i++;
            if(kademlia.getState == state) i++;
            return i;
        }
        return 0;
    }
    
    uint getFileCount(File_.Type type, File_.State state)
    {
        if(type == File_.Type.DOWNLOAD) return files.length;
        return 0;
    }

    File getFile(File_.Type type, uint id)
    {
        if(type == File_.Type.DOWNLOAD)
        {
            return files.get(id);
        }
        return null;
    }
    
    File[] getFileArray(File_.Type type, File_.State state, uint age)
    {
        if(type != File_.Type.DOWNLOAD)
            return null;
        
        return Utils.filter!(File)(files, state, age);
    }
    
    Node getNode(Node_.Type type, uint id)
    {
        if(type == Node_.Type.SERVER) return get(servers, id);
        if(type == Node_.Type.CLIENT) return get(uploaders, id);
        if(type == Node_.Type.NETWORK && isConnected())
        {
            if(id == edonkey.getId) return edonkey;
            if(id == kademlia.getId) return kademlia;
        }
        return null;
    }
    
    Node[] getNodeArray(Node_.Type type, Node_.State state, uint age)
    {
        if(type == Node_.Type.SERVER) return Utils.filter!(Node)(servers, state, age);
        if(type == Node_.Type.CLIENT) return Utils.filter!(Node)(uploaders, state, age);
        if(type == Node_.Type.NETWORK && isConnected())
        {
            return Utils.filter!(Node)( [edonkey, kademlia] , state, age);
        }
        return null;
    }
    
    Node addNode(Node_.Type type, char[] host, ushort port, char[] username, char[] password)
    {
        if(type == Node_.Type.SERVER)
        {
            addServer(host, host, Convert.to!(char[])(port));
            //return ?
        }
        return null;
    }

    synchronized Search addSearch(char[] query)
    {
        if(!isConnected)
        {
            Logger.addInfo(this, "aMule: Not connected");
            return null;
        }
        
        enum EC_SEARCH_TYPE : ubyte
        {
            EC_SEARCH_LOCAL, //ed2k server search only
            EC_SEARCH_GLOBAL, //only available when connected to ed2k server
            EC_SEARCH_KAD, //Kademlia search only
            EC_SEARCH_WEB //search on some website..; not used here
        };
        
        char[] keywords;
        ulong min_size;
        ulong max_size;
        uint min_avail;
        uint max_results;
        char[] file_type;
        char[] extension;
        EC_SEARCH_TYPE search_type;
        
        void addSubQuery(Search_.BoolType type, char[] query_string)
        {
            Logger.addInfo(this, "aMule: Subqueries are not supported!");
        }
        
        void addKey(Search_.ValueType value_type, char[] value)
        {
            switch(value_type)
            {
            case Search_.ValueType.KEYWORD:
                keywords ~= " " ~ value;
                break;
            case Search_.ValueType.MAXSIZE:
                max_size = Convert.to!(ulong)(value, 0);
                break;
            case Search_.ValueType.MINSIZE:
                min_size = Convert.to!(ulong)(value, 0);
                break;
            case Search_.ValueType.MINAVAIL:
                min_avail = Convert.to!(uint)(value, 0);
                break;
            case Search_.ValueType.MEDIA:
                auto media_type = Utils.fromString!(Search_.MediaType)(value);
                switch(media_type)
                {
                    case Search_.MediaType.AUDIO:
                        file_type = "Audio";
                        break;
                    case Search_.MediaType.COPY:
                        file_type = "CD-Images";
                        break;
                    case Search_.MediaType.IMAGE:
                        file_type = "Image";
                        break;
                    case Search_.MediaType.PROGRAM:
                        file_type = "Software";
                        break;
                    case Search_.MediaType.DOCUMENT:
                        file_type = "Document";
                        break;
                    case Search_.MediaType.VIDEO:
                        file_type = "Video";
                        break;
                    default:
                        Logger.addInfo(this, "aMule: Query type '{}' not supported!", value);
                }
                break;
            case Search_.ValueType.MAXRESULTS:
                max_results = Convert.to!(uint)(value, 0);
                break;
            case Search_.ValueType.NETWORKID:
                auto id = Convert.to!(uint)(value, 0);
            
                if(edonkey.getId() == id)
                {
                    search_type = EC_SEARCH_TYPE.EC_SEARCH_GLOBAL; //EC_SEARCH_LOCAL?
                }
                else if(kademlia.getId() == id)
                {
                    search_type = EC_SEARCH_TYPE.EC_SEARCH_KAD;
                }
                break;
            default:
                Logger.addInfo(this, "aMule: Query type '{}' not supported.", Utils.toString(value_type));
            }
        }
        
        Utils.parseQuery(query, &addKey, &addSubQuery);
        
        if(!keywords.length)
            return null;
        
        auto packet = new ECPacket(ECOpCodes.EC_OP_SEARCH_START);
        
        auto type_tag = new ECTag(ECTagNames.EC_TAG_SEARCH_TYPE, cast(ubyte) search_type);
        type_tag.addTag(ECTagNames.EC_TAG_SEARCH_NAME, keywords);
        type_tag.addTag(ECTagNames.EC_TAG_SEARCH_FILE_TYPE, file_type); //? make optional
        packet.addTag(type_tag);
        
        if(extension.length)
            packet.addTag(ECTagNames.EC_TAG_SEARCH_EXTENSION, extension);
        
        if(min_avail)
            packet.addTag(ECTagNames.EC_TAG_SEARCH_AVAILABILITY, min_avail);
        
        if(min_size)
            packet.addTag(ECTagNames.EC_TAG_SEARCH_MIN_SIZE, min_size);
        
        if(max_size)
            packet.addTag(ECTagNames.EC_TAG_SEARCH_MAX_SIZE, max_size);
        
        if(current_search_id)
            stopSearch(current_search_id);
        
        send(packet);
        
        static uint search_id_counter = 0;
        uint id = ++search_id_counter;
        
        auto search = new ASearchInfo(id, keywords, this, max_results);
        searches[id] = search;
        current_search_id = id;
        
        //ask for new results every 3 seconds
        Timer.add(&askForResults, 2, 3);
        
        return search;
    }
    
    //ask every three seconds
    private void askForResults()
    {
        auto search = (current_search_id in searches);
        if(search is null || search.active == false)
        {
            Timer.remove(&askForResults, true);
            return;
        }
        
        if(search.results.length)
        {
            static ubyte[] data = [
            0x00, 0x00, 0x00, 0x22,
            0x00, 0x00, 0x00, 0x06,
            0x28, //EC_OP_SEARCH_RESULTS
            0x01, //tag count
                0x08, //EC_TAG_DETAIL_LEVEL
                0x02, //EC_TAGTYPE_UINT8
                0x01, //data length
                0x04 //EC_DETAIL_INC_UPDATE
            ];
            send(data);
            
        }
        else
        {
            static ubyte[] data = [
            0x00, 0x00, 0x00, 0x22,
            0x00, 0x00, 0x00, 0x06,
            0x28, //EC_OP_SEARCH_RESULTS
            0x01, //tag count
                0x08, //EC_TAG_DETAIL_LEVEL
                0x02, //EC_TAGTYPE_UINT8
                0x01, //data length
                0x02 //EC_DETAIL_FULL
            ];
            send(data);
        }
    }
    
    void stopSearch(uint id)
    {
        if(auto search = (id in searches))
        {
            if(id == current_search_id && search.active)
            {
                static ubyte[] data = [
                0x00, 0x00, 0x00, 0x22,
                0x00, 0x00, 0x00, 0x02,
                0x27, //EC_OP_SEARCH_STOP
                0x00
                ];
                send(data);
            }
            
            search.stop();
        }
    }
    
    void startSearchResults(uint search_id, uint[] result_ids) 
    {
        auto search = (search_id in searches);
        if(search is null)
            return;
        
        //we can start the search result if it is the current search
        if(search_id == current_search_id)
        {
            ubyte category;
            
            foreach(id; result_ids)
            {
                ubyte[] hash = search.getResultHashById(id);
                
                auto packet = new ECPacket(ECOpCodes.EC_OP_DOWNLOAD_SEARCH_RESULT);
                auto tag = new ECTag(ECTagNames.EC_TAG_PARTFILE, hash); //or EC_TAG_KNOWNFILE
                tag.addTag(ECTagNames.EC_TAG_PARTFILE_CAT, category);
                packet.addTag(tag);
                
                send(packet);
            }
        }
        else
        {
            //workaound to start result from old search
            foreach(id; result_ids)
            {
                if(auto result = search.getResultById(id))
                {
                    addLink (
                        Format("ed2k://|file|{}|{}|{}|", result.getName, result.getSize, result.getHash)
                    );
                }
            }
        }
    }
    
    void removeSearchResults(uint search_id, uint[] result_ids)
    {
        if(auto search = (search_id in searches))
        {
            search.removeResults(result_ids);
        }
    }
    
    void removeSearch(uint id)
    {
        if(auto search = (id in searches))
        {
            stopSearch(search.getId);
            searches.remove(id);
        }
    }
    
    Search getSearch(uint id)
    {
        return searches.get(id);
    }
    
    Search[] getSearchArray()
    {
        return Utils.convert!(Search)(searches);
    }
    
    void removeFiles(File_.Type type, uint[] ids)
    {
        foreach(id; ids)
        {
            auto file = (id in files);
            if(file is null) continue;
            
            auto packet = new ECPacket(ECOpCodes.EC_OP_PARTFILE_DELETE);
            packet.addTag(ECTagNames.EC_TAG_PARTFILE, file.getRawHash);
            
            send(packet);
        }
    }
    
    void copyFiles(File_.Type type, uint[] sources, uint target) {}
    void moveFiles(File_.Type type, uint[] sources, uint target) {}
    void renameFile(File_.Type type, uint id, char[] new_name)
    {
        if(new_name.length == 0)
            return;
        
        if(type != File_.Type.DOWNLOAD)
            return;
        
        if(auto file = (id in files))
        {
            auto packet = new ECPacket(ECOpCodes.EC_OP_RENAME_FILE);
            packet.addTag(ECTagNames.EC_TAG_KNOWNFILE, file.getRawHash);
            packet.addTag(ECTagNames.EC_TAG_PARTFILE_NAME, new_name);
            
            send(packet);
        }
    }
    
    void startFiles(File_.Type type, uint[] ids)
    {
        foreach(id; ids)
        {
            if(auto file = (id in files))
            {
                auto packet = new ECPacket(ECOpCodes.EC_OP_PARTFILE_RESUME);
                packet.addTag(ECTagNames.EC_TAG_PARTFILE, file.getRawHash);
                
                send(packet);
                
                file.markActive();
            }
        }
    }
    
    void pauseFiles(File_.Type type, uint[] ids)
    {
        foreach(id; ids)
        {
            if(auto file = (id in files))
            {
                auto packet = new ECPacket(ECOpCodes.EC_OP_PARTFILE_PAUSE);
                packet.addTag(ECTagNames.EC_TAG_PARTFILE, file.getRawHash);
                
                send(packet);
            }
        }
    }
    
    void stopFiles(File_.Type type, uint[] ids) {}
    void prioritiseFiles(File_.Type type, uint[] ids, Priority p)
    {
        ubyte priority;
        switch(p)
        {
            case Priority.LOW: priority = PR.LOW; break;
            case Priority.NORMAL: priority = PR.NORMAL; break;
            case Priority.HIGH: priority = PR.HIGH; break;
            case Priority.VERY_HIGH: priority = PR.VERYHIGH; break;
            case Priority.VERY_LOW: priority = PR.VERYLOW; break;
            case Priority.AUTO: priority = PR.AUTO; break;
            //case Priority.: priority = PR.POWERSHARE; break;
        }
        
        foreach(id; ids)
        {
            if(auto file = (id in files))
            {
                auto packet = new ECPacket(ECOpCodes.EC_OP_PARTFILE_PRIO_SET);
                auto tag = new ECTag(ECTagNames.EC_TAG_PARTFILE, file.getRawHash);
                tag.addTag(ECTagNames.EC_TAG_PARTFILE_PRIO, priority);
                packet.addTag(tag);
                send(packet);
            }
        }
    }

    /*
    void getStatsCollection()
    {
        ushort size;
        ushort nGraphScale = 1;
        double LastTimeStamp; //need to be set globally
        
        auto packet = new ECPacket(ECOpCodes.EC_OP_GET_STATSGRAPHS);
        packet.addTag(ECTagNames.EC_TAG_STATSGRAPH_WIDTH, size);
        packet.AddTag(ECTagNames.EC_TAG_STATSGRAPH_SCALE, nGraphScale);
        if(LastTimeStamp > 0.0)
        {
            request.AddTag(ECTagNames.EC_TAG_STATSGRAPH_LAST, LastTimeStamp);
        }
        
        send(packet);
    }*/
    
    Setting getSetting(uint id)
    {
        auto pref = (id in preferences);
        return pref ? *pref : null;
    }
    
    void setSetting(uint id, char[] value_str)
    {
        //bypass for local setting
        if(id == Phrase.Preview_Directory__setting)
        {
            setPreviewDirectory(value_str);
            return;
        }
        
        auto pref = (id in preferences);
        if(pref is null)
            return;
        
        auto packet = new ECPacket(ECOpCodes.EC_OP_SET_PREFERENCES);
        auto category_tag = new ECTag(pref.category_code);
        switch(pref.type)
        {
        case ECTagTypes.EC_TAGTYPE_UINT8:
            ubyte value = Convert.to!(ubyte)(value_str);
            category_tag.addTag(pref.category_code, value);
            break;
        case ECTagTypes.EC_TAGTYPE_UINT16:
            ushort value = Convert.to!(ushort)(value_str);
            category_tag.addTag(pref.category_code, value);
            break;
        case ECTagTypes.EC_TAGTYPE_UINT32:
            uint value = Convert.to!(uint)(value_str);
            category_tag.addTag(pref.category_code, value);
            break;
        case ECTagTypes.EC_TAGTYPE_UINT64:
            ulong value = Convert.to!(ulong)(value_str);
            category_tag.addTag(pref.category_code, value);
            break;
        case ECTagTypes.EC_TAGTYPE_STRING:
            category_tag.addTag(pref.category_code, value_str);
            break;
        //TODO: implement
        case ECTagTypes.EC_TAGTYPE_DOUBLE:
            //double value = Convert.to!(double)(value_str);
            //category_tag.addTag(pref.category_code, value);
            return;
        case ECTagTypes.EC_TAGTYPE_IPV4:
            return;
        case ECTagTypes.EC_TAGTYPE_HASH16:
            if(value_str.length != 32)
                return;
            //convert hex string to ubyte[]
            //category_tag.addTag(pref.category_code, value_str);
            break;
        default:
            return;
        }
        
        packet.addTag(category_tag);
        
        send(packet);
    }
    
    uint getSettingCount() { return preferences.length; }
    
    Setting[] getSettingArray()
    {
        return Utils.convert!(Setting)(categories);
    }

    void addLink(char[] ed2k_link)
    {
        if(ed2k_link.length < 512 && Utils.is_prefix(ed2k_link, "ed2k://|file|"))
        {
            ubyte category = 0;
            auto packet = new ECPacket(ECOpCodes.EC_OP_ADD_LINK);
            auto tag = new ECTag(ECTagNames.EC_TAG_STRING, ed2k_link);
            tag.addTag(ECTagNames.EC_TAG_PARTFILE_CAT, category);
            packet.addTag(tag);
            send(packet);
        }
        else
        {
            Logger.addWarning(this, "aMule: Only ed2k links are supported.");
        }
        /*
        else if(Utils.is_prefix(ed2k_link, "ed2k://|server|"))
        {
            //TODO
        }
        */
    }
        
    void connectServer(uint ip, ushort port)
    {
        auto packet = new ECPacket(ECOpCodes.EC_OP_SERVER_CONNECT);
        packet.addTag(new ECTag(ECTagNames.EC_TAG_SERVER, ip, port));
        send(packet);
    }
    
    void disconnectServer(uint ip, ushort port)
    {
        auto packet = new ECPacket(ECOpCodes.EC_OP_SERVER_DISCONNECT);
        packet.addTag(new ECTag(ECTagNames.EC_TAG_SERVER, ip, port));
        send(packet);
    }
    
    void removeServer(uint ip, ushort port)
    {
        auto packet = new ECPacket(ECOpCodes.EC_OP_SERVER_REMOVE);
        packet.addTag(new ECTag(ECTagNames.EC_TAG_SERVER, ip, port));
        send(packet);
    }
    
    void addServer(char[] name, char[] addr, char[] port)
    {
        auto packet = new ECPacket(ECOpCodes.EC_OP_SERVER_ADD);
        
        auto tag = new ECTag(ECTagNames.EC_TAG_SERVER, addr ~ ":" ~ port);
        tag.addTag(ECTagNames.EC_TAG_SERVER_ADDRESS, addr ~ ":" ~ port);
        tag.addTag(ECTagNames.EC_TAG_SERVER_NAME, name);
        
        packet.addTag(tag);
        
        send(packet);
    }
    
    /*
    //set priority for shared files
    void setSharePriority(PR priority)
    {
        auto packet = new ECPacket(ECOpCodes.EC_OP_SHARED_SET_PRIO);
        
        auto tag = new ECTag(ECTagNames.EC_TAG_KNOWNFILE, shared.getRawHash);
        tag.addTag(ECTagNames.EC_TAG_PARTFILE_PRIO, cast(ubyte) priority);
        
        packet.addTag(tag);
        
        send(packet);
    }*/
    
private:

    synchronized void send(ubyte[] packet)
    {
        auto s = this.socket;
        try
        {
            if(s) s.socket.send(packet);
        }
        catch(Exception e)
        {
            Logger.addError(this, "aMule: {}", e.toString);
            disconnect();
            throw e;
        }
    }
    
    void send(ECPacket packet)
    {
        last_op = packet.getOpCode();
        
        ubyte[] buffer;
        packet.write(buffer);
        send(buffer);
    }
    
    void changed()
    {
        lastChanged = (Clock.now - Time.epoch1970).seconds;
    }

    void sendLogin()
    {
        auto packet = new ECPacket(ECOpCodes.EC_OP_AUTH_REQ);
        packet.addTag(ECTagNames.EC_TAG_CLIENT_NAME, Host.main_name);
        packet.addTag(ECTagNames.EC_TAG_CLIENT_VERSION, Host.main_version);
        
        if(protocol_version == EC_CURRENT_PROTOCOL_VERSION) //aMule >2.2.5
        {
            packet.addTag(ECTagNames.EC_TAG_PROTOCOL_VERSION, cast(ulong) 0x203);
        }
        else //0x200 aMule 2.2.4 and 2.2.5
        {
            ubyte[] md5_pass = Utils.md5_bin(password);
            packet.addTag(ECTagNames.EC_TAG_PROTOCOL_VERSION, cast(ulong) 0x200); 
            packet.addTag(ECTagNames.EC_TAG_PASSWD_HASH, md5_pass);
        }
        
        send(packet);
    }
    
    //amulegui sends this after auth and auth_ok comes back from amuled
    void getPreferences()
    {
        static ubyte[] data = [
        0x00, 0x00, 0x00, 0x22,
        0x00, 0x00, 0x00, 0x0d,
        0x3f, //EC_OP_GET_PREFERENCES
        0x02, //tag count

        0x08, //EC_TAG_DETAIL_LEVEL
        0x02, //EC_TAGTYPE_UINT8
        0x01, 0x03,

        0xe2, 0x80, 0x80, //EC_TAG_SELECT_PREFS
        0x03, //EC_TAGTYPE_UINT16
        0x02, 0x19, 0xff]; //anded EcPrefs values
        /*
        EC_PREFS_GENERAL |
        EC_PREFS_CONNECTIONS |
        EC_PREFS_MESSAGEFILTER |
        EC_PREFS_ONLINESIG |
        EC_PREFS_SERVERS |
        EC_PREFS_FILES |
        EC_PREFS_SRCDROP |
        EC_PREFS_SECURITY |
        EC_PREFS_CORETWEAKS |
        EC_PREFS_REMOTECONTROLS |
        EC_PREFS_CATEGORIES;
        */
        
        send(data);
    }
    
    void getServerList()
    {
        static ubyte[] data = [
        0x00, 0x00, 0x00, 0x22,
        0x00, 0x00, 0x00, 0x02,
        0x2c, //EC_OP_GET_SERVER_LIST
        0x00
        ];
        send(data);
    }
    
    void getSharedFiles()
    {
        static ubyte[] data = [
        0x00, 0x00, 0x00, 0x22,
        0x00, 0x00, 0x00, 0x06,
        0x10, //EC_OP_GET_SHARED_FILES
        0x01, //tag count
        0x08, //EC_TAG_DETAIL_LEVEL
        0x02, //EC_TAGTYPE_UINT8
        0x01, 0x04
        ];
        send(data);
    }
    
    void getStats()
    {
        static ubyte[] state_req = [
        0x00, 0x00, 0x00, 0x22,
        0x00, 0x00, 0x00, 0x02,
        0x0a, //EC_OP_STAT_REQ
        0x00
        ];
        
        send(state_req);
        
        static ubyte[] conn_state_req = [
        0x00, 0x00, 0x00, 0x22,
        0x00, 0x00, 0x00, 0x02,
        0x0b, //EC_OP_GET_CONNSTATE
        0x00
        ];
        
        send(conn_state_req);
    }
    
    void getDownloadQueue()
    {
        static ubyte[] data = [
        0x00, 0x00, 0x00, 0x22,
        0x00, 0x00, 0x00, 0x06,
        0x0d, //EC_OP_GET_DLOAD_QUEUE
        0x01,
        0x08, //EC_TAG_DETAIL_LEVEL
        0x02, 0x01, 0x04
        ];
        
        send(data);
    }
    
    void getUploadQueue()
    {
        static ubyte[] data = [
        0x00, 0x00, 0x00, 0x22,
        0x00, 0x00, 0x00, 0x06,
        0x0e, //EC_OP_GET_ULOAD_QUEUE
        0x01,
        0x08, //EC_TAG_DETAIL_LEVEL
        0x02, 0x01, 0x03
        ];
        send(data);
    }
    
    //get download comments and alternative file names
    public void getDownloadQueueDetail()
    {
        static ubyte[] data = [
        0x00, 0x00, 0x00, 0x22,
        0x00, 0x00, 0x00, 0x06,
        0x4c, //EC_OP_GET_DLOAD_QUEUE_DETAIL
        0x01,
        0x08, //EC_TAG_DETAIL_LEVEL
        0x02, 0x01, 0x03
        ];
        send(data);
    }
    
    /*
    //even more details, but selective?
    void getDownloadQueueDetail()
    {
        auto packet = new ECPacket(ECOpCodes.EC_OP_GET_DLOAD_QUEUE_DETAIL);
        foreach(file; files)
        {
            packet.addTag(ECTagNames.EC_TAG_PARTFILE, file.getRawHash);
        }
        send(packet);
    }*/
    
    /*
    * Create a server id based on ip and port
    * because aMule doesn't offer such id (it uses hash strings)
    */
    private uint getServerId(uint ip, ushort port)
    {
        return ip + port;
    }
    
    private synchronized void run()
    {
        auto sc = this.socket;
        if(sc is null) return;
        
        try
        {
            auto read = Utils.transfer(&sc.read, &buffer.write);
            
            if(read == IConduit.Eof)
                return;
            
            if(read == 0)
            {
                Logger.addError(this, "aMule: Connection failed!");
                disconnect();
                return;
            }
            else if(read > 16 * 1024 * 1024)
            {
                Logger.addError(this, "aMule: Broken packet!");
                disconnect();
                return;
            }
            
            while(true)
            {
                void[] data = buffer.slice();
                
                //message header complete?
                if(data.length < 8)
                {
                    buffer.clear();
                    break;
                }
                
                uint flags = *cast(uint*) &data.ptr[0];
                flags = Utils.swapBytes(flags);
                
                uint msg_size = *cast(uint*) &data.ptr[4];
                msg_size = Utils.swapBytes(msg_size);
                
                if(msg_size > 16 * 1024 * 1024)
                {
                    Logger.addError(this, "aMule: Broken packet!");
                    disconnect();
                    return;
                }
                
                //message body complete?
                if(data.length < 8 + msg_size)
                {
                    break;
                }
                
                ubyte[] packet = cast(ubyte[]) data[0..8 + msg_size];
                
                handle(flags, packet);
                buffer.seek(packet.length, IOStream.Anchor.Current);
            }
        }
        catch(Exception e)
        {
            Logger.addError(this, "aMule: {}", e.toString);
            disconnect();
        }
    }
    
    private void handle(uint flags, ubyte[] full_packet)
    {
        ubyte[] packet = full_packet[8..$];
        bool utf8_encoded;
        //TODO: move into ECPacket.d and make hexdump with position on crash
    
        //omit extensions when present, we don't use them
        if(flags & ECFlags.EC_FLAG_ACCEPTS)
        {
            packet = packet[4..$];
        }
        
        if(flags & ECFlags.EC_FLAG_HAS_ID)
        {
            debug(aMule)
                Logger.addDebug("aMule: EC_FLAG_HAS_ID is set");
        }
        
        if(flags & ECFlags.EC_FLAG_ZLIB)
        {
            debug(aMule)
                Logger.addDebug("aMule: EC_FLAG_ZLIB tag set");
            
            auto stream = new Array(packet);
            auto decomp = new ZlibInput(stream);
            
            auto buffer = new ubyte[64 * 1024];
            uint read = decomp.read(buffer);
            
            if(read >= buffer.length)
            {
                disconnect();
                Logger.addError(this, "aMule: Decompressed message exceeds buffer.");
                return;
            }
            packet = buffer[0 .. read];
            
            utf8_encoded = false;
        }
        else if(flags & ECFlags.EC_FLAG_UTF8_NUMBERS)
        {
            utf8_encoded = true;
        }
    
        auto ecpacket = new ECPacket();
        ecpacket.read(packet, utf8_encoded);
        
        ECOpCodes op_code = ecpacket.getOpCode();

        switch(op_code)
        {
        case ECOpCodes.EC_OP_NOOP:
            break;
        
        case ECOpCodes.EC_OP_STATS:
            parseStats(ecpacket);
            break;
        
        case ECOpCodes.EC_OP_DLOAD_QUEUE:
            uint[] ids;
            foreach(tag; ecpacket.getTags)
            {
                assert(tag.getCode == ECTagNames.EC_TAG_PARTFILE);
                
                ubyte[] hash = tag.getRawValue();
                assert(hash.length == 16);
                uint id = jhash(hash);
                if(auto file = (id in files))
                {
                    file.update(tag);
                }
                else
                {
                    files[id] = new AFileInfo(id, hash, tag, this);
                }
                ids ~= id;
            }
            
            foreach(id; Utils.diff(files.keys, ids))
            {
                files.remove(id);
            }
            break;
            
        case ECOpCodes.EC_OP_SEARCH_RESULTS:
            auto search = (current_search_id in searches);
            if(search is null)
                break;
            
            foreach(tag; ecpacket.getTags)
            {
                assert(tag.getCode == ECTagNames.EC_TAG_SEARCHFILE);
                search.addResult(tag);
            }
            break;
            
        case ECOpCodes.EC_OP_ULOAD_QUEUE:
            uint[] ids;
            foreach(tag; ecpacket.getTags)
            {
                assert(tag.getCode == ECTagNames.EC_TAG_CLIENT);
                
                uint id = tag.get32(); //is client IP
                ids ~= id;
                if(auto client = (id in uploaders))
                {
                    client.update(tag);
                }
                else
                {
                    uploaders[id] = new AClientInfo(id, tag, this);
                }
            }
            
            foreach(id; Utils.diff(uploaders.keys, ids))
            {
                uploaders.remove(id);
            }
            break;
            
        case ECOpCodes.EC_OP_FAILED:
            auto tags = ecpacket.getTags();
            if(tags.length && tags[0].getCode == ECTagNames.EC_TAG_STRING)
            {
                char[] msg = tags[0].getString();
                if(Utils.is_prefix(msg, "Search in progress"))
                {
                    //ignore stupid status message
                    break;
                }
                Logger.addError(this, "aMule: Request failed with the following error: {}", msg);
            }
            else
            {
                Logger.addError(this, "aMule: Request failed with an unknown error.");
            }
            break;
            
        case ECOpCodes.EC_OP_SET_PREFERENCES:
            parsePreferences(ecpacket);
            break;
        
        case ECOpCodes.EC_OP_SERVER_LIST:
            uint[] ids;
            foreach(tag; ecpacket.getTags)
            {
                assert(tag.getCode() == ECTagNames.EC_TAG_SERVER);
                
                uint id = getServerId(tag.getIp, tag.getPort);
                ids ~= id;
                if(auto server = (id in servers))
                {
                    server.update(tag);
                }
                else
                {
                    servers[id] = new AServerInfo(id, tag);
                }
            }
            
            foreach(id; Utils.diff(servers.keys, ids))
            {
                servers.remove(id);
            }
            break;
            
        case ECOpCodes.EC_OP_AUTH_FAIL:
            auto tags = ecpacket.getTags();
        
            char[] error_string;
            char[] amule_version;
        
            if(tags.length > 0)
                error_string = tags[0].getString;
            
            if(tags.length > 1)
                amule_version = tags[1].getString;

            //check if we have to use an older protocol version
            if(Utils.is_prefix(error_string, "Invalid protocol version") && protocol_version == 0x203)
            {
                debug(aMule)
                    Logger.addDebug(amule_version ~ " detected, retry with older protocol");
                
                //retry with older protocol version used by 2.2.4 and 2.2.5
                protocol_version = 0x200;
                sendLogin();
            }
            else
            {
                disconnect();
                throw new Exception(error_string);
            }
            break;
            
        case ECOpCodes.EC_OP_AUTH_OK:
            if(protocol_version == 0x203 && last_op != ECOpCodes.EC_OP_AUTH_PASSWD)
            {
                throw new Exception("aMule: Connection error.");
            }
            
            auto tag = ecpacket.getTagByName(ECTagNames.EC_TAG_SERVER_VERSION);
            if(tag)
            {
                version_str = tag.getString();
            }
            
            Timer.remove(this);
            
            getPreferences();
            
            Timer.add(&getDownloadQueue, 0.5, 1); //update download list every second
            Timer.add(&getUploadQueue, 0.5, 1); //update upload list every two seconds
            Timer.add(&getStats, 0.5, 2); //request stats every 2 seconds
            getServerList();
            
            Timer.add(&getDownloadQueueDetail, 2, 60); //update comments and alternative file names
            
            break;
            
        case ECOpCodes.EC_OP_MISC_DATA:
                //EC-protocol 0x203
                auto tag = ecpacket.getTagByName(ECTagNames.EC_TAG_CONNSTATE);
                if(tag)
                    parseConnectStat(tag);
            break;
        case ECOpCodes.EC_OP_STRINGS:
            auto tag = ecpacket.getTagByName(ECTagNames.EC_TAG_STRING);
            if(tag && tag.getString.length)
            {
                Logger.addWarning(this, "aMule: {}", tag.getString);
            }
            break;
            
        case ECOpCodes.EC_OP_AUTH_SALT: //only used for 0x203 and higher
            auto tag = ecpacket.getTagByName(ECTagNames.EC_TAG_PASSWD_SALT);
        
            if(tag is null || last_op != ECOpCodes.EC_OP_AUTH_REQ)
            {
                Logger.addError("aMule : External Connection: Bad reply, handshake failed. Connection closed.");
                disconnect();
                break;
            }
        
            auto salt_number = tag.get64;
            char[] password_md5 = Utils.md5_hex(password);
            
            char[] salt_string = toUpper(Utils.toHexString(salt_number));
            char[] salt_md5 = Utils.md5_hex(salt_string);
            
            ubyte[] connection_password = Utils.md5_bin(password_md5 ~ salt_md5);
            
            auto answer = new ECPacket(ECOpCodes.EC_OP_AUTH_PASSWD);
            answer.addTag(ECTagNames.EC_TAG_PASSWD_HASH, connection_password);
            send(answer);
            break;
        /*
        case ECOpCodes.EC_TAG_PREFS_STATISTICS:
            double LastTimeStamp;
            auto timeTag = ecpacket.getTagByName(EC_TAG_STATSGRAPH_LAST);
            if(tmp)
            {
                LastTimeStamp = tmp.getDouble();
            }
            
            auto dataTag = ecpacket.getTagByName(ECTagNames.EC_TAG_STATSGRAPH_DATA);
            uint[] data = cast(uint[]) dataTag.getRawValue();
        
            for (auto i = 0; i < data.length; i += 4)
            {
                m_down_speed ~= (ENDIAN_NTOHL(data[i+0]));
                m_up_speed ~= (ENDIAN_NTOHL(data[i+1]));
                m_conn_number ~= ENDIAN_NTOHL(data[i+2]));
                m_kad_count ~= (ENDIAN_NTOHL(data[i+3]));
            }    
        */
        default:
            debug(aMule)
                Logger.addDebug("aMule: Unknown op code {}", cast(uint) op_code);
            break;
        }
    }
    
    //parse EC_OP_SET_PREFERENCES
    void parsePreferences(ECPacket packet)
    {
        ECTag[] tags = packet.getTags();
        //every tag is a category with preferences as sub tags
        foreach(ECTag tag; tags)
        {
            auto tag_code = tag.getCode();
            //we drop the detail level tag
            if(tag_code < ECTagNames.EC_TAG_PREFS_CATEGORIES)
            {
                continue;
            }
            
            assert(tag_code != Phrase.Preview_Directory__setting, "Conflicting global id and amule preference id.");
            
            APreferences category;
            if(auto tmp = (tag_code in preferences))
            {
                category = cast(APreferences) *tmp;
                if(category is null) return;
            }
            else
            {
                category = new APreferences(tag_code);
                preferences[category.getId] = category;
                categories ~= category;
            }
            
            foreach(ECTag tag_; tag.getTags)
            {
                auto pref = new APreference(tag_code, tag_);
                preferences[pref.getId] = pref;
                category.add(pref);
            }
        }
    }
    
    //parse EC_OP_STATS
    void parseStats(ECPacket packet)
    {
        foreach(ECTag tag; packet.getTags)
        {
            ECTagNames tag_code = tag.getCode();
        
            switch(tag_code)
            {
            case ECTagNames.EC_TAG_CONNSTATE:
                //EC-protocol 0x200
                parseConnectStat(tag);
                break;
            case ECTagNames.EC_TAG_STATS_UL_SPEED:
                upload_speed = tag.get32();
                break;
            case ECTagNames.EC_TAG_STATS_DL_SPEED:
                download_speed = tag.get32();
                break;
            case ECTagNames.EC_TAG_STATS_UP_OVERHEAD:
            case ECTagNames.EC_TAG_STATS_DOWN_OVERHEAD:
            case ECTagNames.EC_TAG_STATS_UL_SPEED_LIMIT:
            case ECTagNames.EC_TAG_STATS_DL_SPEED_LIMIT:
            case ECTagNames.EC_TAG_STATS_TOTAL_SRC_COUNT:
            case ECTagNames.EC_TAG_STATS_BANNED_COUNT:
            case ECTagNames.EC_TAG_STATS_UL_QUEUE_LEN:
                break;
            case ECTagNames.EC_TAG_STATS_ED2K_USERS:
                edonkey.user_count = tag.get32();
                break;
            case ECTagNames.EC_TAG_STATS_KAD_USERS:
                kademlia.user_count = tag.get32();
                break;
            case ECTagNames.EC_TAG_STATS_ED2K_FILES:
                edonkey.file_count = tag.get32();
                break;
            case ECTagNames.EC_TAG_STATS_KAD_FILES:
                kademlia.file_count = tag.get32();
                break;
            default:
                debug(aMule)
                    Logger.addWarning(this, "aMule: parseStats: unhandled tag code: {}", tag_code);
            }
        }
        
        changed();
    }
    
    //parse EC_TAG_CONNSTATE
    void parseConnectStat(ECTag tag)
    {
        ubyte val = tag.get8();
        
        //ed2k status
        if(val & 0x01) {
            edonkey.state = Node_.State.CONNECTED;
        } else if(val & 0x02) {
            edonkey.state = Node_.State.CONNECTING;
        } else {
            edonkey.state = Node_.State.DISCONNECTED;
        }
        
        //kademlia status
        if(val & 0x04) {
            kademlia.state = Node_.State.DISCONNECTED;
        } else if(val & 0x08) {
            kademlia.state = Node_.State.CONNECTED; //firewalled, TODO: keep information
        } else if(val & 0x10) {
            kademlia.state = Node_.State.CONNECTED;
        }
        
        foreach(tag_; tag.getTags)
        {
            switch(tag_.getCode())
            {
            case ECTagNames.EC_TAG_SERVER:
                uint server_id = tag_.getIp() + tag_.getPort();
                if(auto server = (server_id in servers))
                {
                    server.update(tag_);
                    server.setState(edonkey.state);
                }
                else
                {
                    auto server = new AServerInfo(server_id, tag_);
                    server.setState(edonkey.state);
                    servers[server_id] = server;
                }
                break;
            case ECTagNames.EC_TAG_ED2K_ID:
            case ECTagNames.EC_TAG_CLIENT_ID:
            default:
            }
        }
    }
}
