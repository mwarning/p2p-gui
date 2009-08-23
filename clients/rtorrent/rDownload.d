module clients.rtorrent.rDownload;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import tango.core.Exception;
import tango.core.Array;
import tango.io.Stdout;
static import Convert = tango.util.Convert;
import tango.time.Clock;
import tango.text.Ascii;
import tango.text.Util;

import api.File;
import api.Node;
import api.User;
import api.Meta;

static import Utils = utils.Utils;

import clients.rtorrent.XmlOutput;
import clients.rtorrent.XmlInput;
import clients.rtorrent.rPeer;
import clients.rtorrent.rTracker;
import clients.rtorrent.rTorrent;


final class rDownload : File, Nodes
{
    static char[] full_update_request;
    static char[] partial_update_request;
    
    static const char[][] subfile_items =
    [
        "default", "f.get_path=", "f.get_size_bytes=", "f.get_completed_chunks=", /*"f.get_size_chunks=",*/ "f.get_priority="
    ];
    
    static void construct()
    {
        if(full_update_request.length) return;
        
        static const char[][] download_base =
        [
            "default", "d.get_hash=", "d.get_name=",
            "d.get_chunk_size=", "d.get_completed_chunks=", "d.get_size_chunks=",
            "d.get_state=", "d.get_peers_accounted=", "d.get_peers_complete=",
            /*"d.is_hash_checking=",*/ "d.get_tracker_size=", "d.get_message=", //d.is_active= //d.is_open=
            "d.get_creation_date=", "d.get_priority=", "d.get_size_files="
        ];
        
        static const char[][] download_update =
        [
            "d.get_down_rate=",
            "d.get_up_rate=",
            "d.get_down_total=",
            "d.get_up_total="
        ];
        //d.get_peers_connected
        
        auto tmp1 = new XmlOutput("d.multicall");
        tmp1.addArgs(download_base ~ download_update);
        full_update_request = tmp1.toString();
        
        auto tmp2 = new XmlOutput("d.multicall");
        tmp2.addArgs(download_update);
        partial_update_request = tmp2.toString();
    }

    final class SubFile : NullFile
    {
        this(uint id, uint chunk_size, XmlInput res)
        {
            this.id = id;
            this.chunk_size = chunk_size;
            parse(res);
        }
        
        void parse(XmlInput res)
        {
            name = res.getString();
            size = res.getULong();
            uint completed_chunks = res.getUInt();
            //uint size_chunks = res.getUInt();
            priority = res.getUInt();
            
            downloaded = cast(ulong) completed_chunks * chunk_size;
            //size = cast(ulong) size_chunks * chunk_size;
        }
        
        uint getId()
        {
            return id;
        }
        
        char[] getName()
        {
            return name;
        }
        
        ulong getSize()
        {
            return size;
        }
        
        ulong getDownloaded()
        {
            return downloaded;
        }
        
        Priority getPriority()
        {
            return rDownload.toPriority(priority);
        }
        
        private:
        
        uint id;
        ubyte priority;
        char[] name;
        uint chunk_size;
        ulong size, downloaded;
    }
    
    this(uint id, XmlInput res, rTorrent rtorrent)
    {
        this.id = id;
        this.rtorrent = rtorrent;
        parseFull(res);
    }

    void parseFull(XmlInput res)
    {
        hash = toLower( res.getString() );
        name = res.getString();
        chunk_size = res.getUInt();
        uint completed_chunks = res.getUInt();
        chunk_count = res.getUInt(); //"get_size_chunks"
        state = res.getUInt();
        peers_accounted = res.getUInt();
        peers_complete = res.getUInt();
        tracker_size = res.getUInt();
        message = res.getString();
        creation_date = res.getUInt();
        priority = res.getUInt();
        subfile_count = res.getUInt();
        
        parseUpdate(res);
        
        downloaded = cast(ulong) completed_chunks * chunk_size;
        size = cast(ulong) chunk_count * chunk_size;
    }
    
    void parseUpdate(XmlInput res)
    {
        down_rate = res.getUInt();
        up_rate = res.getUInt();
        up_total = res.getULong();
        down_total = res.getULong();
    }
    
    void requestSubfiles()
    {
        auto req = new XmlOutput("f.multicall");
        req.addArg(hash);
        req.addArgs(subfile_items);
        
        if(auto res = rtorrent.send(req))
        {
            SubFile[] tmp;
            uint i;
            while(!res.allConsumed())
            {
                tmp ~= new SubFile(++i, chunk_size, res);
            }
            this.subfiles = tmp;
        }
    }
    
    void updateTracker(XmlInput res)
    {
        if(tracker)
        {
            tracker.parseFull(res);
        }
        else
        {
            tracker = new rTracker(this.id, res);
        }
    }
    
    void updateAllPeers(XmlInput res)
    {
        rPeer[] new_peers;
        uint i;
        while(!res.allConsumed())
        {
            new_peers ~= new rPeer(++i, res, this);
        }
        peers = new_peers;
    }
    
    uint getId() { return id; }
    uint getLastChanged() { return last_changed; }
    char[] getName() { return name; }
    ulong getSize() { return size; }
    
    File_.State getState()
    {
        if(size == downloaded) return File_.State.COMPLETE;
        //if(priority == 0) return File_.State.PAUSED; //?
        switch(state)
        {
            case 0: return File_.State.STOPPED;
            case 1: return File_.State.ACTIVE;
            default:
                Stdout("rDownload: Unkown state ")(state)(".").newline;
                return File_.State.ANYSTATE;
        }
    }
    
    File_.Type getType() { return File_.Type.DOWNLOAD; }
    char[] getHash() { return hash; }
    uint getLastSeen() { return last_changed; }
    uint getRequests() { return 0; }
    uint getAge() { return 0; }
    char[] getFormat() { return null; }
    
    uint getNodeCount(Node_.Type type, Node_.State state)
    {
        if(type == Node_.Type.NETWORK) //only Bittorrent
        {
            return 1;
        }
        else if(type == Node_.Type.CLIENT) //peers
        {
            //TODO: fix context!
            switch(state)
            {
                case Node_.State.CONNECTED:
                    return peers_accounted;
                default:
            }
        }
        else if(type == Node_.Type.SERVER) //only one tracker
        {
            return 1;
        }
        return 0;
    }
    
    Node[] getNodeArray(Node_.Type type, Node_.State state, uint age)
    {
        if(type == Node_.Type.NETWORK)
        {
            return rtorrent.getNodeArray(type, state, age);
        }
        else if(type == Node_.Type.CLIENT)
        {
            return Utils.filter!(Node)(peers, state, age);
        }
        else if(type == Node_.Type.SERVER)
        {
            return Utils.filter!(Node)([tracker], state, age);
        }
        return null;
    }
    
    Node getNode(Node_.Type type, uint id)
    {
        if(type == Node_.Type.CLIENT) //peer
        {
            return null;
        }
        else if(type == Node_.Type.SERVER && tracker && id == tracker.id) //tracker
        {
            return tracker;
        }
        
        return null;
    }
    
    Files getFiles() { return this; }
    Nodes getNodes() { return this; }
    Users getUsers() { return null; }
    Metas getMetas() { return null; }
    
    static Priority toPriority(ubyte priority)
    {
        switch(priority)
        {
            case 0: return Priority.NONE; //off, no downloading, no upload/download slots are allocated
            case 1: return Priority.NORMAL;
            case 2: return Priority.HIGH;
            default: return Priority.NONE;
        }
    }
    
    Priority getPriority()
    {
        return toPriority(priority);
    }
    
    ushort getPing() { return 0; }
    
    uint getUploadRate() { return up_rate; }
    uint getDownloadRate() { return down_rate; }
    
    ulong getUploaded() { return up_total; }
    ulong getDownloaded() { return downloaded; }

    File getFile(File_.Type type, uint id)
    {
        if(id && id <= subfiles.length)
        {
            return subfiles[--id];
        }
        return null;
    }
    
    File[] getFileArray(File_.Type type, File_.State state, uint age)
    {
        if(type == File_.Type.SUBFILE)
        {
            if(subfile_count) requestSubfiles();
            return Utils.filter!(File)(subfiles, state, age);
        }
        return null;
    }
    
    uint getFileCount(File_.Type type, File_.State state)
    {
        switch(type)
        {
            case File_.Type.CHUNK: return chunk_count;
            case File_.Type.SUBFILE: return subfile_count;
            default: return 0;
        }
    }

    void connect(Node_.Type type, uint id) {}
    void disconnect(Node_.Type type, uint id) {}
    Node addNode(Node_.Type type, char[] host, ushort  port, char[] user, char[] password)
    {
        return null;
    }
    void addLink(char[] link) {}
    void removeNode(Node_.Type type, uint id) {}
    
    void previewFile(File_.Type type, uint id)
    {
        if(id && id <= subfiles.length)
        {
            rtorrent.previewFile(subfiles[--id].name, name);
        }
    }

    void removeFiles(File_.Type type, uint[] ids) {}
    void copyFiles(File_.Type type, uint[] source, uint target) {}
    void moveFiles(File_.Type type, uint[] source, uint target) {}
    void renameFile(File_.Type type, uint id, char[] new_name) {}
    
    void startFiles(File_.Type type, uint[] ids) {} 
    void pauseFiles(File_.Type type, uint[] ids) {}
    void stopFiles(File_.Type type, uint[] ids) {}
    void prioritiseFiles(File_.Type type, uint[] ids, Priority priority) {}

    rTracker getTracker()
    {
        return tracker;
    }
    
    rPeer[] getPeers()
    {
        return peers;
    }
    
private:

    void changed()
    {
        last_changed = (Clock.now - Time.epoch1970).seconds;
    }
    
    rTorrent rtorrent;
    rTracker tracker;
    rPeer[] peers;
    
    uint last_changed;
    
    uint id;
    uint subfile_count;
    char[] hash;
    char[] name;
    uint down_rate, up_rate;
    ulong up_total, down_total;
    ulong downloaded, size;
    uint chunk_count;
    ubyte state;
    uint peers_accounted;
    uint peers_complete;
    ubyte priority;
    uint tracker_size;
    char[] message;
    uint creation_date;
    uint chunk_size;
    
    SubFile[] subfiles;
}
