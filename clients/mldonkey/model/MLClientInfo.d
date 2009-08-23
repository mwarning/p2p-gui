module clients.mldonkey.model.MLClientInfo;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/
import tango.time.Clock;
import tango.io.Stdout;

static import Utils = utils.Utils;
static import GeoIP = utils.GeoIP;

import api.Node;
import api.File;
import api.Search;
import api.User;
import api.Meta;
import api.Setting;

import clients.mldonkey.model.MLClientKind;
import clients.mldonkey.model.MLClientState;
import clients.mldonkey.model.MLTags;
import clients.mldonkey.model.MLFileInfo;
import clients.mldonkey.MLDonkey;
import clients.mldonkey.InBuffer;
import clients.mldonkey.MLUtils;


final class MLClientInfo : Node, Files
{
    this(uint id, MLDonkey mld, InBuffer msg)
    {
        this.id = id;
        this.mld = mld;
        update(msg);
    }
    
    void update(InBuffer msg)
    {
        network_id = msg.read32();
        clientKind = new MLClientKind(msg);
        clientState = new MLClientState(msg);
        type = msg.read8(); //0: not set, 1: friend, 2: contact
        tags.parse(msg);
        name = msg.readString();
        rating = msg.read32();
        
        char[] soft = msg.readString();
        switch(soft)
        {
            case "unk": software = "Unknown"; break;
            case "eMU": software = "eMule"; break;
            case "oML":
            case "nML": software = "MLDonkey"; break;
            case "eDK": software = "eDonkey"; break;
            case "OVR": software = "Overnet"; break;
            case "SER": software = "Server"; break;
            case "cDK": software = "cDonkey"; break;
            case "xMU": software = "xMule"; break;
            case "sZA": software = "Shareaza"; break;
            case "lPH": software = "lPhant"; break;
            case "eM+": software = "eMulePlus"; break;
            case "VCD": software = "VeryCD"; break;
            case "IMP": software = "IMPmule"; break;
            default:
            if(soft == "uTorrent")
            {
                software = "\u00b5Torrent";
            }
            else if(Utils.is_prefix(soft, "tML"))
            {
                software = "MLDonkey";
                parseOS(soft);
            }
            else if(Utils.is_prefix(soft, "aMU"))
            {
                software = "aMule";
                parseOS(soft);
            }
            else if(Utils.is_prefix(soft, "Hyd"))
            {
                software = "Hydranode";
                parseOS(soft);
            }
            else if(soft == "unknown")
            {
                software = "Unknown";
            }
            else
            {
                software = soft;
            }
        }
        
        auto new_downloaded = msg.read64();
        auto new_uploaded = msg.read64();
        
        auto new_last_changed = (Clock.now - Time.epoch1970).seconds;
        
        //compute speed and smooth a bit
        if(auto seconds = (new_last_changed - this.last_changed))
        {
            download_rate = (download_rate + ((new_downloaded - this.downloaded) / seconds)) / 2;
            upload_rate = (upload_rate + ((new_uploaded - this.uploaded) / seconds)) / 2;
        }
        else
        {
            download_rate = 0;
            upload_rate = 0;
        }
        
        auto file_name = msg.readString(); //the file the client is downloading
        if(file_name.length && shared_file_id == 0)
        {
            shared_file_id = mld.getSharedFileByName(file_name);
        }
        connectTime = msg.read32();
        char[] mod = msg.readString();
        version_name = msg.readString();
        if(mod.length) version_name ~= " " ~ mod;
        sui_verified = msg.read8();
        
        this.last_changed = new_last_changed;
        this.downloaded = new_downloaded;
        this.uploaded = new_uploaded;
    }
    
    private void parseOS(char[] soft)
    {
        switch(soft[$-1])
        {
            case 'l': tags.add("OS", "Linux"); break;
            case 'n': tags.add("OS", "NetBSD"); break;
            case 'm': tags.add("OS", "MacOS X"); break;
            case 'f': tags.add("OS", "FreeBSD"); break;
            //case 'm': tags.add("OS", "MinGW"); break; //??
            case 'c': tags.add("OS", "Cygwin"); break;
            default: if(soft.length > 4) tags.add("OS", soft[4..$]); break;
        }
    }

    uint getId() { return id; }
    char[] getName() { return name; }
    ulong getDownloaded() { return downloaded; }
    ulong getUploaded() { return uploaded; }
    char[] getProtocol() { return null; }
    char[] getSoftware() { return software; }
    char[] getVersion() { return version_name; }
    Node_.Type getType() { return Node_.Type.CLIENT; }
    Node_.State getState() { return clientState.state; }
    uint getAge() { return connectTime; }
    ushort getPort() { return clientKind.port; }
    char[] getHost() { return clientKind.host; }
    char[] getLocation() { return GeoIP.getCountryCode(clientKind.geoIp); }
    char[] getHash() { return clientKind.hash; }
    uint getLastChanged() { return last_changed; }
    
    void connect(Node_.Type type, uint id) {}
    void disconnect(Node_.Type type, uint id) {}
    Node addNode(Node_.Type type, char[] host, ushort  port, char[] user, char[] password) { return null; }
    void addLink(char[] link) {}
    void removeNode(Node_.Type type, uint id) {}
    
    Node getNode(Node_.Type type, uint id) { return null; }
    char[] getDescription() { return null; }
    uint getNodeCount(Node_.Type type, Node_.State state) { return 0; }
    uint getUserCount(/*User.State state*/) { return 0; }
    
    Searches getSearches() { return null; }
    Nodes getNodes() { return this; }
    Files getFiles() { return this; }
    Settings getSettings() { return null; }
    Users getUsers() { return null; }
    Metas getMetas() { return null; }
    
    Priority getPriority() { return Priority.NONE; }
    ushort getPing() { return 0; }
    
    uint getUploadRate() { return upload_rate; }
    uint getDownloadRate() { return download_rate; }
    
    void previewFile(File_.Type type, uint id) {}
    
    void removeFiles(File_.Type type, uint[] id) {}
    void copyFiles(File_.Type type, uint[] sources, uint target) {}
    void moveFiles(File_.Type type, uint[] sources, uint target) {}
    void renameFile(File_.Type type, uint id, char[] new_name) {}
    void startFiles(File_.Type type, uint[] ids) {}
    void pauseFiles(File_.Type type, uint[] ids) {}
    void stopFiles(File_.Type type, uint[] ids) {}
    void prioritiseFiles(File_.Type type, uint[] ids, Priority priority){}
    
    Node[] getNodeArray(Node_.Type type, Node_.State state, uint age)
    {
        if(type == Node_.Type.NETWORK)
        {
            auto network = mld.getNode(Node_.Type.NETWORK, network_id);
            return network ? [network] : [];
        }
        return null;
    }
    
    void readMLClientState(InBuffer msg)
    {
        clientState.update(msg);
    }
    
    void updateAvailability(uint file_id, char[] chunk_states)
    {
        //availability[file_id] = chunk_states;
    }
    
    class ClientFile : NullFile
    {
        MLFileInfo file;
        char[] chunk_states;
    
        this(MLFileInfo file, char[] chunk_states)
        {
            this.file = file;
            this.chunk_states = chunk_states;
        }
    
        char[] getName()
        {
            return file.getName();
        }
    
        ulong getSize()
        {
            return file.getSize();
        }
        
        File_.Type getType() { return File_.Type.CHUNK; }
    
        File[] getFileArray(File_.Type type, File_.State state, uint age)
        {
            if(type != File_.Type.CHUNK) return null;
            return chunkString2FileArray(file.getSize, chunk_states);
        }
    }
    
    uint getFileCount(File_.Type type, File_.State state)
    {
        return getFileArray(type, state, 0).length;
    }
    
    File getFile(File_.Type type, uint id)
    {
        if(type == File_.Type.DOWNLOAD && id == shared_file_id)
        {
            return mld.getFile(File_.Type.FILE, id);
        }
        return null;
    }
    
    File[] getFileArray(File_.Type type, File_.State state, uint age)
    {
        if(type == File_.Type.DOWNLOAD)
        {
            auto file = mld.getFile(File_.Type.FILE, shared_file_id);
            return file ? [file] : [];
        }
        return null;
    }
    
    private:

    MLClientState clientState;
    MLClientKind clientKind;
    MLTags tags;
    
    uint last_changed;
    MLDonkey mld;
    
    public uint shared_file_id;
    char[] file_name;
    char[] name, software, version_name;
    uint id, network_id, rating, connectTime;
    ubyte type, sui_verified;
    ulong downloaded, uploaded;
    uint download_rate, upload_rate;
}
