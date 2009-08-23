module api.Connection;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/

/*
* Connection class, not fully used yet;
* would be necessary if want to distinguish
* different transfers by file...
*/
interface Connection
{
    public:
    
    uint getId();
    
    //deprecated
    enum Type {
        UPLOAD,
        DOWNLOAD
        //TCP,UDP?
    };
    /*
    enum State {
        STOPPED
    };*/
    
    //help for client interface implementations
    public enum Priority
    {
        NONE,
        AUTO,
        VERY_LOW,
        LOW,
        NORMAL,
        HIGH,
        VERY_HIGH
    }
    
    Priority getPriority(); //remove from here, priority/score/rating is for Nodes/Files
    ushort getPing(); //get msecs
    //char[] getProtocol();
    
    uint getUploadRate();
    uint getDownloadRate();
    
    ulong getUploaded();
    ulong getDownloaded();
}

interface Connections
{
    public:
    
    //addConnection(host, port, user, password)
    //void setAuth(const std::string &name, const std::string &pass) { }
    //void setLocation(const std::string &host, ushort port) { }
    //connect / disconnect , in Node replace by remove/add Node?
    
    uint getConnectionCount(Connection.Type type);
    Connection getConnection(Connection.Type type, uint id);
    //int opApply(int delegate(inout uint, inout char) dg)
    
    Connection[] getTransferArray(Connection.Type type);
}
