module clients.mldonkey.model.MLServerInfo;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import tango.io.Stdout;

import api.Node;
import api.File;

static import GeoIP = utils.GeoIP;

import clients.mldonkey.MLDonkey;
import clients.mldonkey.InBuffer;
import clients.mldonkey.MLUtils;
import clients.mldonkey.model.MLClientState;
import clients.mldonkey.model.MLAddr;
import clients.mldonkey.model.MLTags;


final class MLServerInfo : NullNode
{
private:
    MLClientState clientState;
    MLTags tags;
    MLAddr addr;
    
public:
    
    this(uint id, InBuffer msg, MLDonkey mld)
    {
        this.mld = mld;
        this.id = id;
        update(msg);
    }
    
    void update(InBuffer msg)
    {
        network_id = msg.read32();
        addr = new MLAddr(msg);
        addr.port = msg.read16();
        score = msg.read32();
        tags.parse(msg);
        nUsers = msg.read64();
        nFiles = msg.read64();
        clientState = new MLClientState(msg);
        name = msg.readString();
        description = msg.readString();
        preferred = (msg.read8() == 0);
        version_name = msg.readString();
        max_users = msg.read64();
        soft_limit = msg.read64();
        hard_limit = msg.read64();
        lowid_users = msg.read64();
        ping = msg.read32();
    }

    void connect()
    {
        mld.connectServer(id);
    }
    
    void disconnect()
    {
        mld.disconnectServer(id);
    }
    
    void readMLClientState(InBuffer msg)
    {
        clientState.update(msg);
    }
    
    Nodes getNodes()
    {
        return this;
    }
    
    Node[] getNodeArray(Node_.Type type, Node_.State state, uint age)
    {
        if(type != Node_.Type.NETWORK) return null;
        return [ mld.getNode(Node_.Type.NETWORK, network_id) ];
    }
    
    uint getId() { return id; }
    
    char[] getName() { return name; }
    Node_.Type getType() { return Node_.Type.SERVER; }
    
    char[] getSoftware() { return name; }
    char[] getVersion() { return version_name; }
    char[] getDescription() { return description; }
    char[] getLocation() { return GeoIP.getCountryCode(addr.geoIp); }
    ushort getPing() { return ping; }
    
    uint getNodeCount(Node_.Type type, Node_.State state) { return nUsers; }
    uint getFileCount(File_.Type type, File_.State state) { return nFiles; }
    uint getUserCount(/*User.State state*/) { return nUsers; }
    
    Node_.State getState() { return clientState.state; }
    char[] getHost() { return addr.host; }
    ushort getPort() { return addr.port; }
    
    private:
    MLDonkey mld;
    
    uint id, network_id;
    uint score;
    uint nUsers, nFiles;
    char[] name, description, version_name;
    ulong max_users, soft_limit, hard_limit, lowid_users;
    uint ping;
    bool preferred;
}
