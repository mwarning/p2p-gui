module api.Node;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/

import api.File;
import api.Meta;
import api.User;
import api.Search;
import api.Setting;
import api.Connection;

public import api.Node_;
public import api.File_;

interface Nodes
{
    public:
    
    void connect(Node_.Type type, uint id);
    void disconnect(Node_.Type type, uint id);
    //use (type, <user:password@host:port>) ?
    Node addNode(Node_.Type type, char[] host, ushort  port, char[] user, char[] password);
    void removeNode(Node_.Type type, uint id);
    
    uint getNodeCount(Node_.Type type, Node_.State state);
    
    Node getNode(Node_.Type type, uint id);
    Node[] getNodeArray(Node_.Type type, Node_.State state, uint age);
}

/*
Reason for Unification: simplicity
Against: Source Node for Comment get's blown up... (we want to get geoip, name, host)
*/
//TODO: move out Connection(s)
interface Node : Nodes, Connection
{
    uint getId();
    uint getLastChanged();
    
    char[] getHost();
    ushort getPort();
    char[] getLocation(); //a two char abbreviaton
    
    //char[] getUsername();
    //char[] getPassword();
    
    char[] getName();
    char[] getSoftware();
    char[] getVersion();
    /*
    * name of used protocol to connect to a client
    * when unconnected then the newest supported protocol 
    */
    char[] getProtocol(); //move to Connection class?
    
    //used by server, but usefull for Clients, too; maybe move to Metas ??
    char[] getDescription();
    
    Node_.State getState();
    uint getAge();
    Node_.Type getType();
    
    uint getFileCount(File_.Type type, File_.State state);
    uint getNodeCount(Node_.Type type, Node_.State state);
    uint getUserCount(/*User.State state*/);
    
    Searches getSearches();
    Nodes getNodes();
    Files getFiles();
    Settings getSettings();
    Users getUsers();
    //for console like access, chat, file Metas, (descriptions?)
    Metas getMetas();
}

class NullNode : Node
{
    uint getId() { return 0; }
    uint getLastChanged() { return 0; }
    
    char[] getHost() { return null; }
    ushort getPort() { return 0; }
    char[] getLocation() { return "--"; } //default for GeoIP two char country code
    
    char[] getName() { return null; }
    char[] getSoftware() { return null; }
    char[] getVersion(){ return null; }
    char[] getProtocol() { return null; } //move to Connection class?
    
    //used by server, but usefull for Clients, too; maybe move to Metas ??
    char[] getDescription() { return null; }
    
    Node_.State getState() { return Node_.State.ANYSTATE; }
    uint getAge() { return 0; }
    Node_.Type getType() { return Node_.Type.UNKNOWN; }
    
    uint getFileCount(File_.Type type, File_.State state) { return 0; }
    uint getNodeCount(Node_.Type type, Node_.State state) { return 0; }
    
    uint getUserCount(/*User.State state*/) { return 0; }
    
    Searches getSearches() { return null; }
    Nodes getNodes() { return null; }
    Files getFiles() { return null; }
    Settings getSettings() { return null; }
    Metas getMetas() { return null; }
    Users getUsers() { return null; }
    
    Priority getPriority() { return Priority.NONE; }
    ushort getPing() { return 0; }
    
    uint getUploadRate() { return 0; }
    uint getDownloadRate() { return 0; }
    
    ulong getUploaded() { return 0; }
    ulong getDownloaded() { return 0; }

//from Nodes:
    
    Node addNode(Node_.Type type, char[] host, ushort  port, char[] user, char[] password) { return null; }
    void removeNode(Node_.Type type, uint id) {}

    void connect(Node_.Type type, uint id) {}
    void disconnect(Node_.Type type, uint id) {}
    
    Node getNode(Node_.Type type, uint id) { return null; }
    Node[] getNodeArray(Node_.Type type, Node_.State state, uint age) { return null; }
}
