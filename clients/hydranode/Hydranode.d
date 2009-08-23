module clients.hydranode.Hydranode;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

static import Utils = utils.Utils;
static import Scheduler = core.Scheduler;

import api.Node;
import api.File;
import api.User;
import api.Meta;
import api.Search;
import api.Setting;

import clients.hydranode.opcodes;
import clients.hydranode.model.HNDownload;
import clients.hydranode.model.HNSearch;
import clients.hydranode.model.HNResult;
import clients.hydranode.model.HNNetwork;
import clients.hydranode.model.HNModule;
//import clients.hydranode.model.HNObject;
import clients.hydranode.model.HNSharedFile;

import tango.io.Stdout;
import tango.io.FileConduit;
import tango.text.Util;
import tango.net.device.Socket;
import tango.net.InternetAddress;
import tango.core.Thread;


void putVal(T)(inout ubyte[] data, T val)
{
    uint pos = data.length;
    static if(is(T == char[]))
    {
        data.length = pos + val.length;
        for(uint i; i < val.length; i++)
        {
            data[pos] = cast(ubyte) val[i];
            pos++;
        }
    }
    else
    {
        data.length = pos + T.sizeof;
        *cast(T*) &data.ptr[pos] = val;
    }
}

T getVal(T)(inout ubyte[] data, uint len = 0)
{
    uint pos = data.length;
    T tmp = *cast(T*) &data.ptr[0];
    return tmp;
}

alias getVal!(char[]) getString;
alias getVal!(ubyte) getUByte;
alias getVal!(ushort) getUShort;
alias getVal!(uint)    getUInt;
alias getVal!(ulong) getULong;

void putTag(T)(inout ubyte[] buf, OP,T val)
{
    putVal!(ubyte)(buf, code);
    static if(is(T == char[]))
    {
        putVal!(ushort)(buf, val.length);
        putVal!(T)(buf, val);
    }
    else
    {
        putVal!(ushort)(buf, T.size);
        putVal!(T)(buf, val);
    }
}

class Hydranode : Client //, Downloads, Searches, Settings
{
    const uint id;
    char[] host = "127.0.0.1";
    ushort port = 9990;
    
    bool is_connected;
    
public:
    
    this()
    {
        id = api.Client.getUniqueId();
    }

    synchronized void connect()
    {
        if(is_connected) return;
        
        socket = new Socket();
        socket.connect (new InternetAddress(host, port));
        
        is_connected = true;
        Scheduler.register(socket, &run);
        
        getDownloads();
        monitorDownloads(750);
        getSettingsList();
        monitorSettings();
        
        //thread.start();
    }

    synchronized void disconnect()
    {
        if(!is_connected) return;

        is_connected = false;
        
        Scheduler.unregister(socket);
        socket = null;
        
        files = files.init;
        searches = searches.init;
        results = results.init;
    }
    
    bool isConnected()
    {
        return is_connected;
    }
    
    void shutdown()
    {
        ubyte[] tmp;
        putVal!(ubyte)(tmp, 0x00);
        putVal!(uint)(tmp, 0x01);
        putVal!(ubyte)(tmp, 0x01); // shutdown command
        sendData(tmp);
    }
    
    char[] getDescription() { return "Note: Not working!"; }
    
    void setHost(char[] host) {}
    void setPort(ushort port) {}
    void setUser(char[] user) {}
    void setPass(char[] pass) {}
    byte getPriority() { return 0; } 
    ushort getPing() { return 0; }
    Node_.State getState()
    {
        return is_connected ? Node_.State.CONNECTED : Node_.State.DISCONNECTED;
    }
    Node_.Type getType() { return Node_.Type.CORE; }
    
    char[] getHost() { return host; }
    ushort getPort() { return port; }
    
    uint getUploadRate() { return 0; }
    uint getDownloadRate() { return 0; }
    
    ulong getUploaded() { return 0; }
    ulong getDownloaded() { return 0; }
    
    uint getId() { return id; }
    char[] getName() { return getSoftware(); }
    char[] getSoftware() { return "Hydranode"; }
    char[] getVersion() { return ""; }

    void addLink(char[] link) {}
    
    void stopSearch(uint id) {}
    void cancelSearch(uint id)
    {
        //TODO: send message
        searches.remove(id);
    }
    
    void pauseDownload(uint id) { sendRequest(OpCodes.OC_PAUSE, id, SubSystems.SUB_DOWNLOAD); }
    void stopDownload(uint id) { sendRequest(OpCodes.OC_STOP, id, SubSystems.SUB_DOWNLOAD); }
    void resumeDownload(uint id) { sendRequest(OpCodes.OC_RESUME, id, SubSystems.SUB_DOWNLOAD); }
    void cancelDownload(uint id) { sendRequest(OpCodes.OC_CANCEL, id, SubSystems.SUB_DOWNLOAD); }
    void getDownloadNames(uint id) { sendRequest(OpCodes.OC_NAMES, id, SubSystems.SUB_DOWNLOAD); }
    void getDownloadComments(uint id) { sendRequest(OpCodes.OC_COMMENTS, id, SubSystems.SUB_DOWNLOAD); }
    void getDownloadLinks(uint id) { sendRequest(OpCodes.OC_NAMES, id, SubSystems.SUB_DOWNLOAD); }
    
    void renameName(uint id, char[] newName)
    {
        ubyte[] tmp;
        putVal!(ubyte)(tmp, OpCodes.OC_SETNAME);
        putVal!(uint)(tmp, id);
        putVal!(ushort)(tmp, newName.length);
        putVal(tmp, newName);
        sendPacket(tmp, SubSystems.SUB_DOWNLOAD);
    }
    
    void setDownloadDest(uint id, char[] newDest)
    {
        ubyte[] tmp;
        putVal!(ubyte)(tmp, OpCodes.OC_SETDEST);
        putVal!(uint)(tmp, id);
        putVal!(ushort)(tmp, newDest.length);
        putVal(tmp, newDest);
        sendPacket(tmp, SubSystems.SUB_DOWNLOAD);
    }
    void getSharedFilesList()
    {
        ubyte[] tmp;
        putVal!(ubyte)(tmp, OpCodes.OC_GET);
        sendPacket(tmp, SubSystems.SUB_SHARED);
    }
    
    void monitorSharedFilesList(uint interval)
    {
        ubyte[] o;
        putVal!(ubyte)(o, OpCodes.OC_MONITOR);
        putVal!(uint)(o, interval);
        sendPacket(o, SubSystems.SUB_SHARED);
    }
    
    
    void handleSharedFilesList(ubyte[] packet)
    {
        ubyte oc = getVal!(ubyte)(packet);
        if (oc == OpCodes.OC_REMOVE)
        {
            uint id = getVal!(uint)(packet);
            auto file = (id in shares);
            if (file)
            {
                //file.onDeleted();
                //onRemoved(files);
                shares.remove(id);
            }
            return;
        }
        else if (oc == OpCodes.OC_CHANGEID)
        {
            uint old_id = getVal!(uint)(packet);
            uint new_id = getVal!(uint)(packet);
            //Iter i = list.find(oldId);
            auto file = (old_id in shares);
            if (file)
            {
                shares.remove(old_id);
                file.changeId(new_id);
                shares[new_id] = *file;
            }
            return;
        }
        else if (oc != OpCodes.OC_LIST && oc != OpCodes.OC_UPDATE)
        {
            //logDebug(boost::format("sharedlist: unknown opcode %d") % oc);
            return; // others not implemented yet
        }

        uint cnt = getVal!(uint)(packet);
        HNSharedFile[] list;
        while (packet && cnt--)
        {
            HNSharedFile d;
            try
            {
                d = new HNSharedFile(packet);
            }
            catch (Exception e) 
            {
                /*logDebug(
                    boost::format("while parsing sharedfile: %s")
                    % e.what()
                );*/
                continue;
            }

            auto d_ = (d.getId in shares);
            if (d_)
            {
                d.update(*d_);
                //onUpdated(*d);
            }
            else 
            {
                shares[d.getId] = d;
                //onAdded(d);
            }
        }
        /*
        if (oc == OpCodes.OC_LIST) {
            onAddedList();
        } else if (oc == OpCodes.OC_UPDATE) {
            onUpdatedList();
        }*/
    }
    void addSharedDir(char[] dir)
    {
        ubyte[] tmp;
        putVal!(ubyte)(tmp, OpCodes.OC_ADD);
        putVal!(ushort)(tmp, dir.length);
        putVal(tmp, dir);
        sendPacket(tmp, SubSystems.SUB_SHARED);
    }

    void remSharedDir(char[] dir)
    {
        ubyte[] tmp;
        putVal!(ubyte)(tmp, OpCodes.OC_REMOVE);
        putVal!(ushort)(tmp, dir.length);
        putVal(tmp, dir);
        sendPacket(tmp, SubSystems.SUB_SHARED);
    }
    
    //Downloads downloads() { return this; }
    //Searches searches() { return this; }
    //Settings settings() { return this; }
    
    //Search[uint] getSearches() { return searches; }
    //Downloads[uint] getDownloads() { return files; }
    //Settings.map getSettings() { return options; }
    
    
    void startSearchResult(uint search_id, uint result_id)
    {
        //TODO: check if result does exist
        if(!(search_id in searches)) return;
        ubyte[] tmp;
        putVal!(ubyte)(tmp, SearchTags.OC_DOWNLOAD);
        putVal!(uint)(tmp, result_id);
        sendPacket(tmp, SubSystems.SUB_SEARCH);
    }

    //TODO: merge with other function ^
    void downloadSearchResult(uint num, char[] dest)
    {
        //TODO: check if search does exist
        ubyte[] tmp;
        putVal!(ubyte)(tmp, SearchTags.OC_DOWNLOAD);
        putVal!(uint)(tmp, num);
        putVal!(ushort)(tmp, dest.length);
        putVal!(char[])(tmp, dest);
        sendPacket(tmp, SubSystems.SUB_SEARCH);
    }

    void handleResults(ubyte[] i)
    {
        ubyte opcode = getVal!(ubyte)(i);
        if (opcode != OpCodes.OC_LIST) return;
        
        //std.vector<Result> list;
        uint cnt = getVal!(uint)(i);
        uint id;
        uint search_id = 1; //this is not implemented by HN, so we assume 0
        while (i.length && cnt--)
        {
            auto result = new HNResult(i);
            id = result.getId;
            
            auto search = searches[search_id];
            if(search) search.addSearchResult(result);
        }
        //if (list.length) {
        //    sigResults(list);
        //}
    }
    /*
void Search::run() {
    lastNum = 0;

    ubyte[] tmp;
    putVal!(ubyte)(tmp, OpCodes.OC_GET);
    ubyte[] tmp2;
    ubyte tc = 2;
    tmp2 << makeTag(TAG_KEYWORDS, keywords);
    tmp2 << makeTag!(uint)(TAG_FILETYPE, fileType);

    if (minSize) {
        tmp2 << makeTag(TAG_MINSIZE, minSize);
        ++tc;
    }
    if (maxSize) {
        tmp2 << makeTag(TAG_MAXSIZE, maxSize);
        ++tc;
    }
    putVal!(ushort)(tmp, tc);
    putVal(tmp, tmp2.str().data(), tmp2.str().length);
    sendPacket(tmp.str());
}
*/
    uint startSearch(char[] keywords)
    {
        if(searches.length > 1)
        {
            Stdout("(E) Hydranode: Only one search allowed at time.").newline;
            return 0;
        }
        
        FileType fileType = FileType.FT_UNKNOWN;
        ulong minSize = 0;
        ulong maxSize = 0;
        
        ubyte[] tmp;
        putVal!(ubyte)(tmp, OpCodes.OC_GET);
        ubyte[] tmp2;
        ubyte tc = 2;
        putVal!(ubyte)(tmp2, SearchTags.TAG_KEYWORDS);
        putVal!(ushort)(tmp2, keywords.length);
        putVal!(char[])(tmp2, keywords);
        
        putVal!(ubyte)(tmp2, SearchTags.TAG_FILETYPE);
        putVal!(ushort)(tmp2, FileType.sizeof);
        putVal!(uint)(tmp2, fileType);
        //tmp2)(Engine.makeTag(TAG_KEYWORDS, keywords);
        //tmp2)(Engine.makeTag!(uint)(TAG_FILETYPE, fileType);

        if (minSize)
        {
            //tmp2)(Engine.makeTag(TAG_MINSIZE, minSize);
            putVal!(ubyte)(tmp2, SearchTags.TAG_MINSIZE);
            putVal!(ushort)(tmp2, ulong.sizeof);
            putVal!(ulong)(tmp2, minSize);
            ++tc;
        }
        if (maxSize)
        {
            
            //tmp2)(Engine.makeTag(TAG_MAXSIZE, maxSize);
            putVal!(ubyte)(tmp2, SearchTags.TAG_MAXSIZE);
            putVal!(ushort)(tmp2, ulong.sizeof);
            putVal!(ulong)(tmp2, maxSize);
            ++tc;
        }
        putVal!(ushort)(tmp, tc);
        tmp ~= tmp2;
        //putVal(tmp, tmp2.str().data(), tmp2.str().length);
        sendPacket(tmp, SubSystems.SUB_SEARCH);
        
        //create search object
        uint id = 1;//search_counter++;
        auto search = new HNSearch(id, keywords, minSize, maxSize); //, this);
        searches[id] = search;
        
        return id;
    }
    
    void downloadFromLink(char[] link)
    {
        ubyte[] tmp;
        putVal(tmp, OpCodes.OC_GETLINK);
        putVal!(ushort)(tmp, link.length);
        putVal(tmp, link);
        sendPacket(tmp, SubSystems.SUB_DOWNLOAD);
    }
    
    void importDownloads(char[] dir)
    {
        ubyte[] tmp;
        putVal(tmp, OpCodes.OC_IMPORT);
        putVal!(ushort)(tmp, dir.length);
        putVal(tmp, dir);
        sendPacket(tmp, SubSystems.SUB_DOWNLOAD);
    }

    private void handleDownloads(ubyte[] packet)
    {
        auto oc = getVal!(ubyte)(packet);
        switch (oc)
        {
            case OpCodes.OC_NAMES:
            case OpCodes.OC_LINKS:
            case OpCodes.OC_COMMENTS:
            {
                uint id = getVal!(uint)(packet);
                auto file = (id in files);
                if (!files) return;
                switch(oc)
                {
                    case OpCodes.OC_NAMES: file.parseNames(packet); break;
                    case OpCodes.OC_LINKS: file.parseLinks(packet); break;
                    case OpCodes.OC_COMMENTS: file.parseComments(packet); break;
                }
                return;
            }
            case OpCodes.OC_LIST:
            case OpCodes.OC_UPDATE: break;
            default:
                /*
                logDebug(
                    boost.format("downloadlist: unknown opcode %d") 
                    % oc
                );*/
                return;
        }

        uint cnt = getVal!(uint)(packet);
        HNDownload[] list;
        while (packet && cnt--)
        {
            HNDownload d;
            try {
                d = new HNDownload(packet);
            } catch (Exception e) {
                /*
                logDebug(
                    boost.format("while parsing download: %s")
                    % e.what()
                );*/
                continue;
            }

            auto d_ = (d.getId in files);
            if (d_) {
                //Stdout()("update Download")(std.newline;
                d_.update(d);
                //onUpdated((it).second);
            } else {
                //Stdout()("new Download")(std.newline;
                files[d.getId] = d;
                //onAdded(d);
            }
        }
        /*
        if (oc == OpCodes.OC_LIST) {
            onAddedList();
        } else if (oc == OpCodes.OC_UPDATE) {
            onUpdatedList();
        }*/
    }

    void handleSettings(ubyte[] i)
    {
        ubyte oc = getVal!(ubyte)(i);
        if (oc == OpCodes.OC_LIST)
        {
            ushort cnt = getVal!(ushort)(i);
            while (i && cnt--)
            {
                char[] key = getVal!(char[])(i);
                char[] val = getVal!(char[])(i);
                options[key] = val;
            }
            //handler(list);
        }
        else if (oc == OpCodes.OC_DATA)
        {
            char[] key = getVal!(char[])(i);
            char[] val = getVal!(char[])(i);
            options[key] = val;
            //handler(list);
        }
    }

    void getSetting(char[] key)
    {
        ubyte[] tmp;
        putVal!(ubyte)(tmp, OpCodes.OC_GET);
        putVal!(char[])(tmp, key);
        sendPacket(tmp, SubSystems.SUB_CONFIG);
    }

    void setSetting(char[] key, char[] value)
    {
        ubyte[] tmp;
        putVal!(ubyte)(tmp, OpCodes.OC_SET);
        putVal!(char[])(tmp, key);
        putVal!(char[])(tmp, value);
        sendPacket(tmp, SubSystems.SUB_CONFIG);
    }
    
    private void getSettingsList()
    {
        ubyte[] tmp;
        putVal!(ubyte)(tmp, OpCodes.OC_LIST);
        sendPacket(tmp, SubSystems.SUB_CONFIG);
    }

    private void monitorSettings()
    {
        ubyte[] tmp;
        putVal!(ubyte)(tmp, OpCodes.OC_MONITOR);
        sendPacket(tmp, SubSystems.SUB_CONFIG);
    }
    
    
        
    void getNetworkList()
    {
        ubyte[] tmp;
        putVal!(ubyte)(tmp, OpCodes.OC_GET);
        sendPacket(tmp, SubSystems.SUB_NETWORK);
    }

    void monitorNetworks(uint interval)
    {
        ubyte[] o;
        putVal!(ubyte)(o, OpCodes.OC_MONITOR);
        putVal!(uint)(o, interval);
        sendPacket(o, SubSystems.SUB_NETWORK);
    }

    //only one network... hm..
    void handleNetwork(ubyte[] i)
    {
        /*
        if (getVal!(ubyte)(i) != OpCodes.OC_LIST) {
            return;
        }
        uint tagCount = getVal!(uint)(i);
        while (i && tagCount--)
        {
            ubyte oc = getVal!(ubyte)(i);
            ushort sz = getVal!(ushort)(i);
            switch (oc)
            {
                case NetworkTags.TAG_UPSPEED:
                    upSpeed = getVal!(uint)(i); break;
                case NetworkTags.TAG_DOWNSPEED:
                    downSpeed = getVal!(uint)(i); break;
                case NetworkTags.TAG_CONNCNT:
                    connCnt       = getVal!(uint)(i); break;
                case NetworkTags.TAG_CONNECTINGCNT:
                    connectingCnt = getVal!(uint)(i); break;
                case NetworkTags.TAG_TOTALUP:
                    totalUp       = getVal!(ulong)(i); break;
                case NetworkTags.TAG_TOTALDOWN:
                    totalDown     = getVal!(ulong)(i); break;
                case NetworkTags.TAG_SESSUP:
                    sessionUp     = getVal!(ulong)(i); break;
                case NetworkTags.TAG_SESSDOWN:
                    sessionDown   = getVal!(ulong)(i); break;
                case NetworkTags.TAG_DOWNPACKETS:
                    downPackets   = getVal!(ulong)(i); break;
                case NetworkTags.TAG_UPPACKETS:
                    upPackets     = getVal!(ulong)(i); break;
                case NetworkTags.TAG_UPLIMIT:
                    upLimit       = getVal!(uint)(i); break;
                case NetworkTags.TAG_DOWNLIMIT:
                    downLimit     = getVal!(uint)(i); break;
                case NetworkTags.TAG_RUNTIMESESS:
                    sessLength    = getVal!(ulong)(i); break;
                case NetworkTags.TAG_RUNTIMETOTAL:
                    totalRuntime  = getVal!(ulong)(i); break;
                default:
                    //i.seekg(sz, std::ios::cur); break;
            }
        }*/
    }

/*
void handleModules(ubyte[] i)
{
    ubyte oc = getVal!(ubyte)(i);
    switch (oc)
    {
        case OpCodes.OC_LIST:
        case OpCodes.OC_UPDATE:
        {
            modules = modules.init;
            uint cnt = getVal!(uint)(i);
            while (i && cnt--)
            {
                auto mod = readModule(i);
                modules[mod.getId] = mod;
            }
            //onUpdated();
            break;
        }
        case OpCodes.OC_ADD:
        {
            auto mod = readModule(i);
            auto mod_ = (mod.getId in modules);
            
            //Iter j = m_list.find(mod.getId);
            if (!mod_)
            {
                modules[mod.getId] = mod;
                //onAdded(mod);
            } else {
                (*mod_).update(mod);
            }
            //onUpdated();
            break;
        }
        case OpCodes.OC_REMOVE:
        {
            auto mod = readModule(i);
            
            auto mod_ = (mod.getId in modules);
            if (mod_)
            {
                //onRemoved((*j).second);
                modules.remove(mod_.getId);
            }
            //onUpdated();
            break;
        }
        case OpCodes.OC_NOTFOUND:
        {
            uint id = getVal!(uint)(i);
            //logDebug(boost::format("Object not found: %d") % id);
            break;
        }
        case OC_OBJLIST:
        {
            uint cnt = getVal!(uint)(i);
            HNObject lastObject; // = HNObject();
            while (i && cnt--)
            {
                auto obj = readHNObject(i);
                auto found = findHNObject(obj.getId);
                if (found)
                {
                    found.update(obj);
                    //updatedObject(found);
                    obj = found;
                } else {
                    objects[obj.getId] = obj;
                }
                lastObject = obj;
            }
            if (lastObject)
            {
                lastObject.findChildren();
                //receivedObject(lastObject);
            }
            break;
        }
        case OpCodes.OC_CADDED:
        {
            uint id = getVal!(uint)(i);
            auto parent = findHNObject(id);
            auto child = readHNObject(i);
            auto found = findHNObject(child.getId());
            if (found)
            {
                found.update(child);
                updatedHNObject(found);
                child = found;
            }
            else
            {
                objects[child.getId] = child;
                if (parent)
                {
                    parent.childIds.insert(id);
                    parent.children[id] = child;
                    parent.childAdded(parent, child);
                    child.parent = parent;
                }
            }
            addedHNObject(child);
            break;
        }
        case OpCodes.OC_CREMOVED:
        {
            uint id = getVal!(uint)(i);
            uint cid = getVal!(uint)(i);
            HNObjectPtr parent = findHNObject(id);
            HNObjectPtr child = findHNObject(cid);
            if (parent && child)
            {
                parent.childIds.remove(cid);
                parent.children.remove(cid);
                parent.childRemoved(parent, child);
            }
            if (child)
            {
                removedHNObject(child);
            }
            break;
        }
        case OpCodes.OC_DESTROY:
        {
             uint id = getVal!(uint)(i);
            HNObjectPtr obj = findHNObject(id);
            if (obj)
            {
                obj.destroy();
                objects.erase(id);
            }
            break;
        }
    }
}

HNObject findHNObject(uint id)
{
    auto obj =(id in objects);
    return obj ? (*obj) : null;
}

HNObject readHNObject(ubyte[] i)
{
    if (getVal!(ubyte)(i) != OpCodes.OC_OBJECT)
    {
        //throw std::runtime_error("Invalid object.");
        return;
    }

    auto obj = new HNObject(this);
    obj.id = getVal!(uint)(i);
    ushort nLen = getVal!(ushort)(i);
    obj.name = getVal!(char[])(i, nLen);
    uint dataCount = getVal!(uint)(i);
    while (i && dataCount--)
    {
        ushort dLen = getVal!(ushort)(i);
        char[] data = getVal!(char[])(i, dLen);
        obj.data ~= (data);
    }
    uint childCount = getVal!(uint)(i);
    while (i && childCount--)
    {
        obj.childIds.insert(getVal!(uint)(i));
    }

    return obj;
}

void readModuleHNObject(ubyte[] i)
{
    if (getVal!(ubyte)(i) != OpCodes.OC_OBJECT)
    {
        //throw std::runtime_error("Invalid object.");
        return;
    }

    auto obj = new HNObject(this);
    obj.id = getVal!(uint)(i);
    ushort nLen = getVal!(ushort)(i);
    obj.name = getVal!(char[])(i, nLen);
    uint dataCount = getVal!(uint)(i);
    while (i && dataCount--)
    {
        ushort dLen = getVal!(ushort)(i);
        char[] data = getVal!(char[])(i, dLen);
        obj.data.push_back(data);
    }
    uint childCount = getVal!(uint)(i);
    while (i && childCount--)
    {
        obj.childIds.insert(getVal!(uint)(i));
    }
}

HNModule readModule(ubyte[] i)
{
    auto mod = new HNModule;
    ubyte oc = getVal!(ubyte)(i);
    if (oc != OpCodes.OC_MODULE) {
        //throw std::runtime_error("invalid module opcode");
        return;
    }
    return new HNModule(i);
}
    
void getModulesList()
{
    ubyte[] tmp;
    putVal!(ubyte)(tmp, OpCodes.OC_LIST);
    sendPacket(tmp, SubSystems.SUB_MODULES);
}

void monitorModules(uint interval)
{
    ubyte[] tmp;
    putVal!(ubyte)(tmp, OpCodes.OC_MONITOR);
    putVal!(uint)(tmp, interval);
    sendPacket(tmp, SubSystems.SUB_MODULES);
}

void getModulesObject(HNModule mod, char[] name, bool recurse, uint timer)
{
    ubyte[] tmp;
    putVal!(ubyte)(tmp, OpCodes.OC_GET);
    putVal!(uint)(tmp, mod.getId);
    putVal!(ushort)(tmp, name.length);
    putVal(tmp, name);
    putVal!(ubyte)(tmp, recurse);
    putVal!(uint)(tmp, timer);
    sendPacket(tmp, SubSystems.SUB_MODULES);
}

void monitorModulesObject(HNObject obj, uint interval)
{
    ubyte[] tmp;
    putVal!(ubyte)(tmp, OpCodes.OC_MONITOR);
    putVal!(uint)(tmp, obj.getId);
    putVal!(uint)(tmp, interval);
    sendPacket(tmp, SubSystems.SUB_MODULES);
}

void doModulesObjectOper(HNObject obj, char[] opName, char[char[]] args)
{
    ubyte[] tmp;
    putVal!(ubyte)(tmp, OpCodes.OC_DOOPER);
    putVal!(uint)(tmp, obj.getId);
    putVal!(ushort)(tmp, opName.length);
    putVal(tmp, opName);
    putVal!(ushort)(tmp, args.length);
    foreach(key, value; args)
    {
        putVal!(ushort)(tmp, key.length);
        putVal(tmp, key);
        putVal!(ushort)(tmp, value.length);
        putVal(tmp, value);
    }
    sendPacket(tmp, SubSystems.SUB_MODULES);
}

void setModulesObjectData(HNObject obj, ubyte dNum, char[] v)
{
    ubyte[] tmp;
    putVal!(ubyte)(tmp, OpCodes.OC_SET);
    putVal!(uint)(tmp, obj.getId);
    putVal!(ubyte)(tmp, dNum);
    putVal!(ushort)(tmp, v.length);
    putVal(tmp, v);
    sendPacket(tmp, SubSystems.SUB_MODULES);
}

*/
//TODO: implement the packet buffer from MLBuffer.d

    ubyte[1024 * 8] buffer;
    uint pos;
    uint begin;
    private void run()
    {
        void reset()
        {
            //move partial packet from begin to position 0
            //TODO: optimize with two slice moves?
            uint k;
            for(uint l = begin; l < pos; k++, l++)
            {
                buffer[k] = buffer[l];
            }
            
            pos = pos - begin;
            begin = 0;
        //Stdout("------------------------------------------------------").newline;
        }
        
        int i = socket.socket.receive(buffer[pos .. $]);
        if(i <= 0)
        {
            disconnect();
            Stdout("(E) Hydranode: Connection failed!");
            return;
        }
        pos += i;
        if(pos >= buffer.length)
        {
            disconnect();
            Stdout("(E) Hydranode: Buffer full!");
            return;
        }
        
        while(true)
        {
            //message header complete?
            if(pos < begin + 5)
            {
                reset();
                break;
            }
            
            ubyte subsys =  *cast(ubyte*) &buffer.ptr[begin];
            uint msg_size =  *cast(uint*) &buffer.ptr[begin + 1];
            
            //message body complete?
            if(pos < begin + 5 + msg_size)
            {
                reset();
                break;
            }
            
            ubyte[] packet = buffer[begin+5..begin + 5 + msg_size];
            //in_pos = 4;
            begin += 5 + msg_size;
            
            handle(subsys, packet);
        }

        /*
        char[] buffer;
        
        char buf = new char[512];
        try {
        while (is_connected)
        {
            if (!socket) { continue; }
        
            uint  read;
            while ((read = socket.readPaket(buf, 512)) > 0)
            {
                buffer.append(buf, read);
                Stdout()("iter ")(read)( std.newline;
            }
            
            read = socket.readPaket(buf, 512);
            //if(read == 0) continue; //needed?
            buffer.append(buf, read);
        
            while (buffer.length >= 6)
            {
                std.istringstream tmp(buffer);
                
                ubyte subsys = getVal!(ubyte)(tmp);
                uint size = getVal!(uint)(tmp);
                
                if (buffer.length < size + 5u) break; //continue first while loop, read more
                
                std.istringstream packet(buffer.substr(5, size));
                
                switch(subsys)
                {
                    case SubSystems.SUB_DOWNLOAD:
                        parseDownloads(tmp); break;
                    case SubSystems.SUB_CONFIG:
                        parseSettings(tmp); break;
                    case SubSystems.SUB_SEARCH:
                        handleresults(tmp); break;
                }
                
                buffer.remove(0, size + 5);
            }
        }} catch(Exception e) {
            disconnect();
            Stdout("(E) Hydranode.run: ")(e.toUtf8)(std.newline;
        }
        
        delete buf;*/
    }
    
    void handle(ubyte subsys, ubyte[] packet)
    {
        try
        {
        switch(subsys)
        {
            case SubSystems.SUB_DOWNLOAD:
                handleDownloads(packet); break;
            case SubSystems.SUB_CONFIG:
                handleSettings(packet); break;
            case SubSystems.SUB_SEARCH:
                handleResults(packet); break;
            case SubSystems.SUB_MODULES:
                //handleModules(packet);
                break;
            default:
                Stdout("(W) Hydranode: Unhandled sub-system: ")(subsys).newline;
        }
        }
        catch(Exception e)
        {
            disconnect();
            Stdout("(E) Hydranode.run: ")(e.toUtf8).newline;
        }
    }
    
private:

    void getDownloads()
    {
        ubyte[] tmp;
        putVal!(ubyte)(tmp, OpCodes.OC_GET);
        sendPacket(tmp, SubSystems.SUB_DOWNLOAD);
    }
        
    //750
    void monitorDownloads(uint interval)
    {
        ubyte[] tmp;
        putVal!(ubyte)(tmp, OpCodes.OC_MONITOR);
        putVal!(uint)(tmp, interval);
        sendPacket(tmp, SubSystems.SUB_DOWNLOAD);
    }

    void sendRequest(ubyte oc, uint id, ubyte subCode)
    {
        ubyte[] tmp;
        putVal!(ubyte)(tmp, oc);
        putVal!(uint)(tmp, id);
        sendPacket(tmp, subCode);
    }
    
    void sendPacket(ubyte[] data, ubyte subCode)
    {
        ubyte[] tmp;
        putVal!(ubyte)(tmp, subCode);
        putVal!(uint)(tmp, data.length);
        tmp ~= data;
        socket.socket.send(tmp);
    }
    
    void sendData(inout ubyte[] data)
    {
        socket.socket.send(data);
    }
    
    Socket socket;

    uint search_counter;
    //HNObject[uint] objects;
    HNModule[uint] modules;
    HNDownload[uint] files;
    char[][char[]] options;
    HNSearch[uint] searches;
    HNResult[uint] results;
    HNSharedFile[uint] shares;
}
