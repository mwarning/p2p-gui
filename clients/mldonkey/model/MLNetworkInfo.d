module clients.mldonkey.model.MLNetworkInfo;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

static import Utils = utils.Utils;

import api.Node;
import api.Search;
import api.File;

import clients.mldonkey.InBuffer;
import clients.mldonkey.MLDonkey;

final class MLNetworkInfo : public NullNode
{
    public:
    
    this(uint id, InBuffer msg, MLDonkey mld)
    {
        this.mld = mld;
        this.id = id;
        update(msg);
    }
    
    void update(InBuffer msg)
    {
        auto n = msg.readString();
        switch(n)
        {
            case "G1": name = "Gnutella"; break;
            case "G2": name = "Gnutella2"; break;
            case "Direct Connect": name = "DirectConnect"; break;
            default: name = n;
        }
        
        enabled = (msg.read8() == 1);
        /*configFile =*/ msg.readString();
        uploaded = msg.read64();
        downloaded = msg.read64();
        connected_servers = msg.read32();
        flags = msg.read16s();
        //changed();
        if(name == "Donkey") searchable = true;
    }
    
    uint getId() { return id; }

    void connect()
    {
        mld.enableNetwork(id);
    }
    
    void disconnect()
    {
        mld.disableNetwork(id);
    }
    
    Node_.State getState()
    {
        if(enabled) return Node_.State.CONNECTED;
        return Node_.State.DISCONNECTED;
    }
    
    Node_.Type getType() { return Node_.Type.NETWORK; }
    char[] getHost() { return mld.getHost(); }
    ushort getPort() { return mld.getPort(); }
    char[] getSoftware() { return mld.getSoftware(); }
    char[] getVersion() { return mld.getVersion(); }
    char[] getName() { return name; }
    char[] getDescription() { return ""; }
    uint getUploadRate() { return mld.getUploadRate(); }
    uint getDownloadRate() { return mld.getDownloadRate(); }

    Searches getSearches() { return searchable ? mld : null; }
    Files files() { return mld; }
    Nodes nodes() { return mld; }
    
    ulong getUploaded() { return uploaded; }
    ulong getDownloaded() { return downloaded; }

    Node addNode(Node_.Type type, char[] host, ushort port, char[] user, char[] password)
    {
        if(type == Node_.Type.SERVER)
        {
            mld.addServer(id, Utils.toIpNum(host), port);
        }
        return null;
    }
    
    private:
    
    MLDonkey mld;
    
    uint id, connected_servers;
    ulong uploaded, downloaded;
    char[] name; //, configFile;
    ushort[] flags;
    bool enabled;
    bool searchable;
}
