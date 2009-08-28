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
    uint peers_connected;
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
                tc.torrentSet([id], "priority-low", ids);
                break;
            case Priority.NONE:
            case Priority.AUTO:
            case Priority.NORMAL:
                tc.torrentSet([id], "priority-normal", ids);
                break;
            case Priority.HIGH:
            case Priority.VERY_HIGH:
                tc.torrentSet([id], "priority-high", ids);
                break;
        }
    }
    
    void pauseFiles(File_.Type type, uint[] ids)
    {
        stopFiles(type, ids);
    }
    
    void stopFiles(File_.Type type, uint[] ids)
    {
        tc.torrentSet([id], "files-unwanted", ids);
    }
    
    void startFiles(File_.Type type, uint[] ids)
    {
        tc.torrentSet([id], "files-wanted", ids);
    }
    
    void update(JsonObject object)
    {
        foreach(char[] key, JsonValue value; object)
        {
            //Stdout("'")(key)("'").newline;
            switch(key)
            {
            case "activityDate":
                //activityDate = value.toInteger();
                break;
            case "addedDate":
                //addedDate = value.toInteger();
                break;
            case "announceResponse":
                //announceResponse = value.toString();
                break;
            case "announceURL":
                //announceURL = value.toString();
                break;
            case "bandwidthPriority":
                //bandwidthPriority = value.toInteger();
                break;
            case "comment":
                if(comment.length == 0)
                {
                    comment = value.toString();
                }
                break;
            case "corruptEver":
                //corruptEver = value.toInteger();
                break;
            case "creator":
                //creator = value.toString();
                break;
            case "dateCreated":
                //dateCreated = value.toInteger();
                break;
            case "desiredAvailable":
                //desiredAvailable = value.toInteger();
                break;
            case "doneDate":
                //doneDate = value.toInteger();
                break;
            case "downloadDir":
                //downloadDir = value.toString();
                break;
            case "downloadedEver":
                //downloadedEver = value.toInteger();
                break;
            case "downloaders":
                downloaders = value.toInteger();
                break;
            case "downloadLimit":
                download_limit = value.toInteger();
                break;
            case "downloadLimited":
                //downloadLimited = value.toBool();
                break;
            case "error":
                //errorString = value.toInteger();
                break;
            case "errorString":
                //errorString = value.toString();
                break;
            case "eta":
                //eta = value.toInteger();
                break;
            case "files":
                if(files.length) break;
                TFile[] files;
                foreach(JsonValue v; value)
                {
                    if(auto data = cast(JsonObject) v.ptr)
                    {
                        files ~= new TFile(data);
                    }
                }
                this.files = files;
                break;
            case "fileStats":
                foreach(uint i, JsonValue d; value)
                {
                    if(i >= files.length)
                        break;
                    
                    if(auto data = cast(JsonObject) d.ptr)
                    {
                        files[i].update(data);
                    }
                }
                break;
            case "hashString":
                if(hash.length == 0)
                {
                    hash = value.toString();
                }
                break;
            case "haveUnchecked":
                //haveUnchecked = value.toInteger();
                break;
            case "haveValid":
                //haveValid = value.toInteger();
                break;
             case "honorsSessionLimits":
                //honorsSessionLimits = value.getBool();
            case "id":
                id = value.toInteger();
                break;
               case "isPrivate": //private tracker
                //isPrivate = value.toBool();
                break;
            case "lastAnnounceTime":
                //lastAnnounceTime = value.toInteger();
                break;
            case "lastScrapeTime":
                //lastScrapeTime = value.toInteger();
                break;
            case "leechers":
                //leechers = value.toInteger();
                break;
            case "leftUntilDone":
                left_until_done = value.toInteger();
                break;
            case "manualAnnounceTime":
                //manualAnnounceTime = value.toInteger();
                break;
            case "maxConnectedPeers":
                //maxConnectedPeers = value.toInteger();
                break;
            case "name":
                if(name.length == 0)
                {
                    name = value.toString();
                }
                break;
            case "nextAnnounceTime":
                //nextAnnounceTime = value.toInteger();
                break;
            case "nextScrapeTime":
                //nextScrapeTime = value.toInteger();
                break;
            case "peer-limit":
                //peer_limit = value.toInteger();
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
            case "peersConnected":
                peers_connected = value.toInteger();
                break;
            case "peersFrom":
                if(auto peers_from = cast(JsonObject) value.ptr)
                {
                    parsePeersFrom(peers_from);
                }
                break;
            case "peersGettingFromUs":
                //peersGettingFromUs = value.toInteger();
                break;
            case "peersKnown":
                //peersKnown = value.toInteger();
                break;
            case "peersSendingToUs":
                //peersSendingToUs = value.toInteger();
                break;
            case "percentDone":
                //percentDone = value.toFloat();
                break;
            case "pieces":
                //pieces = value.toString();
                break;
            case "pieceCount":
                //pieceCount = value.toInteger();
                break;
            case "pieceSize":
                //pieceSize = value.toInteger();
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
            case "rateDownload":
                download_rate = value.toInteger();
                break;
            case "rateUpload":
                upload_rate = value.toInteger();
                break;
            case "recheckProgress":
                //recheckProgress = value.toFloat();
                break;
            case "scrapeResponse":
                //scrapeResponse = value.toString();
                break;
            case "scrapeURL":
                //scrapeURL = value.toString();
                break;
            case "seeders":
                //seeders = value.toInteger();
                break;
            case "seedRatioLimit":
                //seedRatioLimit = value.toFloat();
                break;
            case "seedRatioMode":
                //seedRatioMode = value.toInteger();
                break;
            case "sizeWhenDone":
                //sizeWhenDone = value.toInteger();
                break;
            case "startDate":
                //startDate = value.toInteger();
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
            case "swarmSpeed":
                swarm_speed = value.toInteger();
                break;
            case "timesCompleted":
                //timesCompleted = value.toInteger();
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
            case "totalSize":
                if(total_size == 0)
                {
                    total_size = value.toInteger();
                }
                break;
            case "torrentFile":
                //torrentFile = value.toString();
                break;
            case "uploadedEver":
                //uploadedEver = value.toInteger();
                break;
            case "uploadLimit":
                //uploadLimit = value.toInteger();
                break;
            case "uploadLimited":
                //uploadLimited = value.toBool();
                break;
            case "uploadRatio":
                //uploadRatio = value.toFloat();
                break;
            case "wanted":
                break;
            case "webseeds":
                break;
            case "webseedsSendingToUs":
                //webseedsSendingToUs = value.toInteger();
                break;
            default:
                debug
                {
                    Logger.addWarning(tc, "TTorrent: Unhandled value for '{}'.", key);
                }
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
                    debug
                    {
                        Logger.addWarning(tc, "TTorrent: Unhandled peer value for '{}'.", key);
                    }
            }
        }
    }
}
