module clients.mldonkey.model.MLFileInfo;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import tango.io.Stdout;
import tango.io.model.IFile;
import tango.text.Ascii;
import tango.time.Clock;
import Text = tango.text.Ascii;
import tango.core.Array;
import Integer = tango.text.convert.Integer;

static import Utils = utils.Utils;
static import GeoIP = utils.GeoIP;
import webcore.Logger;

//static import api = api.all;
import api.Host;
import api.Node;
import api.File;
import api.Meta;
import api.User;

import clients.mldonkey.model.MLFileFormat;
import clients.mldonkey.model.MLSharedFile;
import clients.mldonkey.model.MLPartFile;
import clients.mldonkey.InBuffer;
import clients.mldonkey.MLUtils;
import clients.mldonkey.MLDonkey;


final class MLFileInfo
    : MLFileFormat, File, Files, Nodes, Metas, Users
{
    //a dummy to expose the user/group name
    //until users is implemented into MLDonkey.d
    static final class TmpUser : NullUser
    {
        char[] name;
        User_.Type  type;
        this(char[] name, User_.Type type)
        {
            this.name = name;
            this.type = type;
        }
        char[] getName() { return name; }
        User_.Type getType() { return type; }
    }
    
    static final class MLFileComment : Meta
    {
        public:
        this(InBuffer msg)
        {
            host = msg.readIpAddress(); //IP //search for node by IP and assign to source?
            geoip = msg.read8();
            name = msg.readString();
            rating = msg.read8();
            comment = msg.readString();
        }
        
        uint getId() { return 0; }
        short getRating() { return rating; }
        char[] getMeta() { return comment; }
        char[] getLocation() { return GeoIP.getCountryCode(geoip); }
        char[] getHost() { return host; }
        char[] getName() { return name; }
        Meta_.Type getType() { return Meta_.Type.COMMENT; }
        uint getLastChanged() { return 0; }
        Node getSource() { return null; } //TODO: connect with existing node
        Meta_.State getState() { return Meta_.State.ANYSTATE; }
        
        void addMeta(Meta_.Type type, char[] value, int rating) {}
        void removeMeta(Meta_.Type type, uint id) {}
        uint getMetaCount(Meta_.Type type, Meta_.State state) { return 0; }
        Meta[] getMetaArray(Meta_.Type type, Meta_.State state, uint age) { return null; }
        Metas getMetas() { return this; }
        
        private:
        char[] comment, name, host;
        short rating;
        ubyte geoip;
    }
    
    //wrap file names
    static final class MLFileName : NullFile
    {
        char[] name;
        
        this(char[] name)
        {
            this.name = name;
        }
        
        char[] getName() { return name; }
    }
    
    uint last_changed;
    
    void changed()
    {
        last_changed = (Clock.now - Time.epoch1970).seconds;
    }
    
public:
    
    this(uint id, MLDonkey mld, InBuffer msg)
    {
        this.id = id;
        this.mld = mld;
        this.state = File_.State.ACTIVE;
        update(msg);
    }
    
    //preview for part files only
    void previewFile(File_.Type type, uint id)
    {
        if(type != File_.Type.SUBFILE)
            return;
        
        auto partfile = getPartFile(id);
        
        if(partfile is null)
            return;
        
        //preview from disk if preview directory is known
        auto setting = mld.getSetting(MLDonkey.preview_setting_id);
        if(setting && setting.getValue.length)
        {
            mld.previewFromDisk (
                network_id,
                toUpper(this.getHash) ~ FileConst.PathSeparatorChar ~ partfile.getName, 
                partfile.getName
            );
        }
        else //preview over net
        {
            //calculate offset of partfile
            ulong offset;
            foreach(file; partfiles)
            {
                if(file == partfile)
                {
                    break;
                }
                offset += file.getSize();
            }
            
            mld.previewFromNet (
                this.id,
                partfile.getName,
                partfile.getSize,
                offset,
                true
            );
        }
    }
    
    void updateSharedInfo(MLSharedFile file)
    {
        requests = file.requests;
        uploaded = file.uploaded;
    }
    
    void removeClient(uint clientID)
    {
        client_ids.remove(clientID);
    }
    
    void addClientId(uint id)
    {
        client_ids[id] = 0;
    }
    
    //TODO: returned data is in wrong context
    uint getNodeCount(Node_.Type type, Node_.State state)
    {
        if(type == Node_.Type.NETWORK)
        {
            return mld.getNodeCount(type, state);
        }
        else if(type == Node_.Type.CLIENT)
        {
            switch(state)
            {
                case Node_.State.CONNECTED: return active_sources;
                case Node_.State.DISCONNECTED: return all_sources; //all?
                case Node_.State.ANYSTATE: return all_sources + active_sources;
            }
        }
        return 0;
    }
    
    void update(InBuffer msg)
    {
        network_id = msg.read32();
        auto names = msg.readStrings();
        if(names.length && names.length != file_names.length)
        {
            foreach(name; names)
            {
                this.file_names ~= new MLFileName(name);
            }
        }
        hash = msg.readHash(); //filled with zeroes for BT
        size = msg.read64();
        downloaded = msg.read64();
        all_sources = msg.read32();
        active_sources = msg.read32();
        
        ubyte fileState = msg.read8();
        switch(fileState)
        {
            case 0: state = File_.State.ACTIVE; break; //downloading
            case 1: state = File_.State.PAUSED; break;
            case 2: state = File_.State.COMPLETE; break; //downloaded
            case 3: state = File_.State.SHARED; break;
            case 4: state = File_.State.CANCELED; return;  //canceled, remove file
            case 5: break; //new file
            /*
            case 6: state = File_.State.CANCELED; //not send over gui protocol
                char[] reason = msg.readString;
                Host.addWarning("MLFileInfo: Remove file because: " ~ reason);
                return;
            */
            case 7: break; //queued
            default:
                Logger.addWarning(mld, "MLFileInfo: Unknown file state {}", fileState);
        }
        
        chunk_states = msg.readString(); //0=Missing, 1=Partial, 2=Complete, 3=Verified

        ushort len = msg.read16();
        for (int i = 0; i < len; i++)
        {
            msg.read32(); //network number
            msg.readString(); //chunk map
        }
        
        float tf = msg.readFloat(); //work around dmd bug on windows
        download_rate = cast(uint) tf; //speed is already in bytes
        chunk_ages = msg.read32s();
        age = msg.read32();
        readMLFileFormat(msg);

        name = msg.readString();
        
        //MLD encodes "never seen before"/unknown time as 100 days, we use 0
        uint file_age = msg.read32();
        if(file_age == 0)
        {
            last_seen_complete = 1;
        }
        else if(file_age < 100 * 24 * 60 * 60)
        {
            last_seen_complete = file_age;
        }
        else
        {
            last_seen_complete = 0;
        }
        
        priority = cast(byte) msg.read32();
        msg.readString; //comment, always empty
        
        char[][] uids = msg.readStrings();
        
        //get hash
        if(uids.length)
        {
            hash = uids[0];
            //remove "urn:[bt|ed2k]:" prefix and convert to lower case
            uint pos = rfind(hash, ':');
            if(pos != hash.length)
            {
                hash = Text.toLower(hash[pos+1..$]);
            }
        }
        
        //order represents order in MLD temp file
        auto partfile_count = msg.read16();
        if(partfiles.length == partfile_count)
        {
            //skip data
            for(auto i = 0; i < partfiles.length; i++)
            {
                msg.readString(); //name
                msg.read64(); //size
                msg.readString(); //magic_string
            }
        }
        else
        {
            partfiles.length = partfile_count;
            ulong offset;
            for(auto i = 0; i < partfiles.length; i++)
            {
                char[] name = msg.readString(); //name
                ulong size = msg.read64(); //size
                char[] format = msg.readString(); //magic_string
                
                partfiles[i] = new MLPartFile(i, name, size, format, offset, this);
                offset += partfiles[i].getSize();
            }
        }
        
        format = msg.readString();
        
        comments.length = msg.read16();
        for(auto i = 0; i < comments.length; i++)
        {
            comments[i] = new MLFileComment(msg);
        }
        
        user_name = msg.readString();
        group_name = msg.readString();
        
        changed();
    }

    void updateDownload(InBuffer msg)
    {
        //file identifier was already read
        ulong new_downloaded = msg.read64();
        float tf = msg.readFloat(); //work around dmd bug on windows
        uint new_download_rate = cast(uint) tf;
        
        uint seen = msg.read32();
        if(seen == 0)
        {
            last_seen_complete = 1;
        }
        else if(seen < 100 * 24 * 60 * 60)
        {
            last_seen_complete = seen;
        }
        else
        {
            last_seen_complete = 0;
        }
        
        //we don't wan't trigger updates just because last seen rises by time passed
        if(new_downloaded != downloaded || new_download_rate != download_rate)
        {
            changed();
        }
        downloaded = new_downloaded;
        download_rate = new_download_rate;
    }

    Node getNode(Node_.Type type, uint client_id)
    {
        if(type == Node_.Type.NETWORK && client_id == this.network_id)
        {
            return mld.getNode(Node_.Type.NETWORK, client_id);
        }
        else if(type == Node_.Type.CLIENT && (client_id in client_ids))
        {
            return mld.getNode(type, client_id);
        }
        return null;
    }

    Node[] getNodeArray(Node_.Type type, Node_.State state, uint age)
    {
        if(type == Node_.Type.NETWORK )
        {
            auto network = mld.getNode(Node_.Type.NETWORK, this.network_id);
            return network ? [network] : [];
        }
        else if(type == Node_.Type.CLIENT)
        {
            Node[] clients;
            foreach(client_id, dummy_val; client_ids)
            {
                auto client = mld.getNode(Node_.Type.CLIENT, client_id);
                if(client) clients ~= client;
            }
            return Utils.filter!(Node)(clients, state, age);
        }
        return null;
    }

    void disconnect(Node_.Type type, uint clientID)
    {
        mld.fileRemoveSource(id, clientID);
    }

    uint getFileCount(File_.Type type, File_.State state)
    {
        switch(type)
        {
            case File_.Type.CHUNK: return chunk_states.length;
            case File_.Type.SUBFILE: return partfiles.length;
            default: return 0;
        }
    }
    
    File getFile(File_.Type type, uint id)
    {
        switch(type)
        {
            case File_.Type.CHUNK:
                if(id < chunk_states.length)
                {
                    //TODO: make efficient
                    return chunkString2FileArray(size, chunk_states, chunk_ages)[id];
                }
                return null;
            case File_.Type.SUBFILE: return getPartFile(id);
            default: return null;
        }
    }
    
    MLPartFile getPartFile(uint id)
    {
        if(id < partfiles.length)
        {
            return partfiles[id];
        }
        return null;
    }
    
    File[] getFileArray(File_.Type type, File_.State state, uint age)
    {
        if(type == File_.Type.SOURCE)
        {
            return Utils.filter!(File)(file_names, state, age);
        }
        else if(type == File_.Type.SUBFILE)
        {
            return Utils.filter!(File)(partfiles, state, age);
        }
        else if(type == File_.Type.CHUNK)
        {
            return chunkString2FileArray(size, chunk_states, chunk_ages);
        }
        return null;
    }
    
    Files getFiles() { return this; }
    Nodes getNodes() { return this; }
    Metas getMetas() { return this; }
    Users getUsers() { return this; }
    
    uint getId() { return id; }
    
    uint getLastChanged() { return last_changed; }
    char[] getName() { return name; }
    
    Meta[] getMetaArray(Meta_.Type type, Meta_.State state, uint age)
    {
        if(type == Meta_.Type.COMMENT) return Utils.filter!(Meta)(comments, state, age);
        return null;
    }
    
    uint getMetaCount(Meta_.Type type, Meta_.State state)
    {
        return comments.length;
    }
    void addMeta(Meta_.Type type, char[] message, int rating) {}
    void removeMeta(Meta_.Type type, uint id) {}    
    
    File_.Type getType() { return File_.Type.DOWNLOAD; }
    File_.State getState() { return state; }
    ulong getSize() { return size; }
    ulong getDownloaded() { return downloaded; }
    char[] getHash() { return hash; }
    uint getDownloadRate() { return download_rate; }
    ushort getPing() { return 0; }
    uint getUploadRate()
    {
        uint upload_rate;
        foreach(client_id, dummy_val; client_ids)
        {
            auto client = mld.getNode(Node_.Type.CLIENT, client_id);
            if(client) upload_rate += client.getUploadRate();
        }
        return upload_rate;
    }
    uint getLastSeen() { return last_seen_complete; }
    Priority getPriority()
    {
        if(priority == 0) return Priority.NORMAL;
        if(priority <= -20) return Priority.VERY_LOW;
        if(priority >= 20) return Priority.VERY_HIGH;
        if(priority < 0) return Priority.LOW;
        if(priority > 0) return Priority.HIGH;
    }
    
    uint getAge() { return age; }
    ulong getUploaded() { return uploaded; }
    uint getRequests() { return requests; }
    char[] getFormat() { return format; }
    
    uint addUser(User_.Type type, char[] name) { return mld.addUser(type, name); }
    void renameUser(uint id, char[] new_name) { mld.renameUser(id, new_name); }
    void removeUser(uint id) { mld.removeUser(id); }
    void setUserPassword(uint id, char[] password) { mld.setUserPassword(id, password); }
    
    User getUser(uint id) { return null; }
    User[] getUserArray()
    {
        return [ new TmpUser(user_name, User_.Type.USER),
            new TmpUser(group_name, User_.Type.GROUP) ];
    }
    
    void copyFiles(File_.Type type, uint[] sources, uint target) {}
    void moveFiles(File_.Type type, uint[] sources, uint target) {}
    void removeFiles(File_.Type type, uint[] ids) {}
    void renameFile(File_.Type type, uint id, char[] new_name) {}
    void startFiles(File_.Type type, uint[] ids) {}
    void pauseFiles(File_.Type type, uint[] ids) {}
    void stopFiles(File_.Type type, uint[] ids) {}
    void prioritiseFiles(File_.Type type, uint[] ids, Priority priority) {}
    
    void connect(Node_.Type type, uint id) {}

    Node addNode(Node_.Type type, char[] host, ushort port,char[], char[]) { return null; }
    void addLink(char[] link) {}
    void removeNode(Node_.Type type, uint  id) {}
    
    uint getNetworkId() { return network_id; }
    
    char[] getChunkStates()
    {
        return chunk_states;
    }
    
    uint[] getChunkAges()
    {
        return chunk_ages;
    }
    
    MLPartFile[] getPartFiles()
    {
        return partfiles;
    }
    
private:
    
    MLDonkey mld;

    TmpUser[] users;
    
    File_.State state;
    uint id, download_rate, active_sources, all_sources,
        age, last_seen_complete, network_id;
    byte priority;
    ulong size, downloaded;
    MLFileName[] file_names; //list of alternative file names
    MLPartFile[] partfiles;
    MLFileComment[] comments;
    char[] hash, name, comment, format;
    char[] user_name, group_name;
    byte[uint] client_ids;
    char[] chunk_states;
    uint[] chunk_ages;
    
    //from MLSharedFile
    ulong uploaded;
    uint requests;
}

