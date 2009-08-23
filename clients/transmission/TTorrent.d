module clients.transmission.TTorrent;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/

import tango.io.Stdout;

import api.File;
import api.Node;
import api.Meta;
import utils.json.JsonBuilder;
static import Utils = utils.Utils;
import webcore.Logger;

import clients.transmission.Transmission;
import clients.transmission.TFile;
import clients.transmission.TPeer;
import clients.transmission.TTracker;

class TTorrent : NullFile, Nodes, Metas
{
    uint id;
    char[] name;
    uint download_limit;
    uint swarm_speed;
    ulong total_size;
    ulong left_until_done;
    char[] comment;
    char[] hash;
    uint uploaders;
    uint downloaders;
    uint download_rate;
    uint upload_rate;
    Utils.Set!(TPeer) peers;
    Utils.Set!(TTracker) trackers;
    TFile[] files;
    Transmission tc;
    File_.State state;
    
    alias JsonBuilder!().JsonValue JsonValue;
    alias JsonBuilder!().JsonString JsonString;
    alias JsonBuilder!().JsonNumber JsonNumber;
    alias JsonBuilder!().JsonNull JsonNull;
    alias JsonBuilder!().JsonBool JsonBool;
    alias JsonBuilder!().JsonArray JsonArray;
    alias JsonBuilder!().JsonObject JsonObject;
    
    this(JsonObject object, Transmission tc)
    {
        this.tc = tc;
        update(object);
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
        return total_size;
    }
    
    char[] getHash()
    {
        return hash;
    }
    
    ulong getUploaded()
    {
        return 0;
    }
    
    ulong getDownloaded()
    {
        return total_size - left_until_done;
    }
    
    uint getUploadRate()
    {
        return upload_rate;
    }
    
    uint getDownloadRate()
    {
        return download_rate;
    }
    
    File_.State getState()
    {
        return state;
    }
    
    File_.Type getType()
    {
        return File_.Type.DOWNLOAD;
    }
    
    Priority getPriority()
    {
        double priority = 0;
        foreach(file; files)
        {
            priority += file.priority;
        }
        
        priority /= files.length;
        
        if(priority <= -0.5)
            return Priority.LOW;
        
        if(priority >= 0.5)
            return Priority.HIGH;
        
        return Priority.NORMAL;
    }
    
    Metas getMetas() { return this; }
    Files getFiles() { return this; }
    Nodes getNodes() { return this; }
    
    void connect(Node_.Type type, uint id) {}
    void disconnect(Node_.Type type, uint id) {}
    Node addNode(Node_.Type type, char[] host, ushort  port, char[] user, char[] password) { return null; }
    void removeNode(Node_.Type type, uint id) {}
    
    uint getNodeCount(Node_.Type type, Node_.State state)
    {
        if(type == Node_.Type.CLIENT)
        {
            return peers.length;
        }
        else if(type == Node_.Type.SERVER)
        {
            return trackers.length;
        }
        else if(type == Node_.Type.NETWORK)
        {
            return 1;
        }
    }
    
    Node getNode(Node_.Type type, uint id)
    {
        if(type == Node_.Type.CLIENT)
        {
            foreach(peer; peers.slice)
            {
                if(peer.getId == id) return peer;
            }
        }
        else if(type == Node_.Type.SERVER)
        {
            foreach(tracker; trackers.slice)
            {
                if(tracker.getId == id) return tracker;
            }
        }
        else if(type == Node_.Type.NETWORK && id == Transmission.bittorrent_net_id)
        {
            return tc.network;
        }
        return null;
    }
    
    Node[] getNodeArray(Node_.Type type, Node_.State state, uint age)
    {
        if(type == Node_.Type.CLIENT)
        {
            return Utils.filter!(Node)(peers.slice, state, age);
        }
        else if(type == Node_.Type.SERVER)
        {
            return Utils.filter!(Node)(trackers.slice, state, age);
        }
        else if(type == Node_.Type.NETWORK)
        {
            return Utils.filter!(Node)([tc.network], state, age);
        }
        return null;
    }
    
    
    uint getFileCount(File_.Type type)
    {
        if(type == File_.Type.SUBFILE)
        {
            return files.length;
        }
        return 0;
    }
    
    File getFile(File_.Type type, uint id)
    {
        if(type == File_.Type.SUBFILE)
        {
            foreach(file; files)
            {
                if(file.getId == id)
                    return file;
            }
        }
        return null;
    }
    
    File[] getFileArray(File_.Type type, File_.State state, uint age)
    {
        if(type == File_.Type.SUBFILE)
        {
            return Utils.filter!(File)(files, state, age);
        }
        return null;
    }
    
    void addMeta(Meta_.Type type, char[] value, int rating) {}
    void removeMeta(Meta_.Type type, uint id) {}
    
    uint getMetaCount(Meta_.Type type, Meta_.State state)
    {
        return comment.length ? 1 : 0;
    }
    
    Meta[] getMetaArray(Meta_.Type type, Meta_.State state, uint age)
    {
        class TComment : NullMeta
        {
            char[] comment;
            this(char[] comment) { this.comment = comment; }
            char[] getMeta() { return comment; }
        }
        
        return [ new TComment(comment)];
    }
    
    void previewFile(File_.Type type, uint id)
    {
        if(type != File_.Type.SUBFILE) return;
        
        foreach(file; files)
        {
            if(file.getId == id)
            {
                tc.previewFile(file.full_name);
                break;
            }
        }
    }
    
    void prioritiseFiles(File_.Type type, uint[] ids, Priority priority)
    {
        if(ids.length == 0)
            return;
        
        switch(priority)
        {
            case Priority.VERY_LOW:
            case Priority.LOW:
                tc.torrentSet("priority-low", [id], ids);
                break;
            case Priority.NONE:
            case Priority.AUTO:
            case Priority.NORMAL:
                tc.torrentSet("priority-normal", [id], ids);
                break;
            case Priority.HIGH:
            case Priority.VERY_HIGH:
                tc.torrentSet("priority-high", [id], ids);
                break;
        }
    }
    
    void update(JsonObject object)
    {
        foreach(char[] key, JsonValue value; object)
        {
            switch(key)
            {
            case "leftUntilDone":
                left_until_done = value.toInteger();
                break;
            case "swarmSpeed":
                swarm_speed = value.toInteger();
                break;
            case "rateDownload":
                download_rate = value.toInteger();
                break;
            case "rateUpload":
                upload_rate = value.toInteger();
                break;
            case"peersGettingFromUs":
                uploaders = value.toInteger();
                break;
            case"peersSendingToUs":
                downloaders = value.toInteger();
                break;
            case "id":
                id = value.toInteger();
                break;
            case "name":
                if(name.length == 0)
                {
                    name = value.toString();
                }
                break;
            case "downloadLimit":
                download_limit = value.toInteger();
                break;
            case "totalSize":
                if(total_size == 0)
                {
                    total_size = value.toInteger();
                }
                break;
            case "comment":
                if(comment.length == 0)
                {
                    comment = value.toString();
                }
                break;
            case "hashString":
                if(hash.length  == 0)
                {
                    hash = value.toString();
                }
                break;
            case "startDate":
                break;
            case "pieceCount":
                break;
            case "pieceSize":
                break;
            case "files":
                if(files.length == 0)
                {
                    TFile[] files;
                    foreach(JsonValue f; value)
                    {
                        if(auto file = cast(JsonObject) f.ptr)
                        {
                            files ~= new TFile(file);
                        }
                    }
                    this.files = files;
                }
                break;
            case "peers":
                foreach(p; value)
                {
                    if(auto peer = cast(JsonObject) p.ptr)
                    {
                        peers.add (
                            new TPeer(peer, tc)
                        );
                    }
                }
                break;
            case "peersFrom":
                if(auto peers_from = cast(JsonObject) value.ptr)
                {
                    parsePeersFrom(peers_from);
                }
                break;
            case "priorities":
                auto array = value.toJsonArray();
                if(array is null || files.length != array.length)
                    break;
                
                foreach(sid, priority; array)
                {
                    files[sid].priority = priority.toInteger();
                }
                break;    
            case "trackers":
                foreach(t; value)
                {
                    if(auto tracker = cast(JsonObject) t.ptr)
                    {
                        trackers.add (
                            new TTracker(tracker)
                        );
                    }
                }
                break;
            case "status":
                auto state_num = value.toInteger();
                switch(state_num)
                {
                case 1:
                    state = File_.State.PROCESS; //Torrent._StatusWaitingToCheck
                    break;
                case 2:
                    state = File_.State.PROCESS; //Torrent._StatusChecking
                    break;
                case 4:
                    state = File_.State.ACTIVE; //Torrent._StatusDownloading
                    break;
                case 8:
                    state = File_.State.ACTIVE; //Torrent._StatusSeeding
                    break;
                case 16: 
                    state = File_.State.PAUSED; //Torrent._StatusPaused
                    break;
                default:
                    Logger.addWarning(tc, "TTorrent: Unknown file state {}.", state_num);
                }
                break;    
            default:
            }
        }
    }
    
    private void parsePeersFrom(JsonObject obj)
    {
        foreach(char[] key, JsonValue value; obj)
        {
            switch(key)
            {
                case "fromCache":
                    //auto from_cache = value.toInteger();
                    break;
                case "fromIncoming":
                    //auto from_incoming = value.toInteger();
                    break;
                case "fromPex":
                    //auto from_pex = value.toInteger();
                    break;
                case "fromTracker":
                    //auto from_tracker = value.toInteger();
                    break;
                default:
                    Logger.addWarning(tc, "TTorrent: Unknown name for '{}'.", name);
            }
        }
    }
}
