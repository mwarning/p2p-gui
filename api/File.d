module api.File;

import api.Node;
import api.Meta;
import api.User;
import api.Connection;
import api.Setting;

public import api.Node_;
public import api.File_;

import tango.io.model.IConduit;


alias Connection.Priority Priority;

interface Files
{
    public:
    
    uint getFileCount(File_.Type type, File_.State state);
    File getFile(File_.Type type, uint id);
    File[] getFileArray(File_.Type type, File_.State state, uint age);
    //uint addFile(Type, char[] name); //for adding directories?! and files?? starting torrent files?
    void previewFile(File_.Type type, uint id);
    
    //TODO: cleanup, too many functions
    //void setState(File_.Type type, uint id, File_.State state) //PAUSE, RUNNING, STOP etc.
    void removeFiles(File_.Type type, uint[] id);
    void copyFiles(File_.Type type, uint[] sources, uint target);
    void moveFiles(File_.Type type, uint[] sources, uint target);
    void renameFile(File_.Type type, uint id, char[] new_name);
    void startFiles(File_.Type type, uint[] ids); //for download resume and search result start
    void pauseFiles(File_.Type type, uint[] ids);
    void stopFiles(File_.Type type, uint[] ids);
    void prioritiseFiles(File_.Type type, uint[] ids, Priority priority);
}

interface File : Files, Connection
{
    uint getId();
    uint getLastChanged();
    char[] getName();
    ulong getSize();
    File_.State getState();
    File_.Type getType();
    char[] getHash();
    uint getLastSeen();
    uint getRequests(); //for Transfer interface, shared files
    uint getAge(); //time how long the type was this way
    
    char[] getFormat(); //get information about the file type
    
    uint getFileCount(File_.Type type, File_.State state);
    uint getNodeCount(Node_.Type type, Node_.State state);
    
    Files getFiles();
    Nodes getNodes();
    Users getUsers();
    Metas getMetas();
}

class NullFile : File
{
    private this() {}
    uint getId() { return 0; }
    uint getLastChanged() { return 0; }
    char[] getName() { return null; }
    ulong getSize() { return 0; }
    File_.State getState()  { return File_.State.ANYSTATE; }
    File_.Type getType() { return File_.Type.UNKNOWN; }
    char[] getHash() { return null; }
    uint getLastSeen() { return 0; }
    uint getRequests() { return 0; }
    uint getAge() { return 0; }
    char[] getFormat() { return null; }
    
    uint getFileCount(File_.Type type, File_.State state) { return 0; }
    uint getNodeCount(Node_.Type type, Node_.State state) { return 0; }
    
    Files getFiles() { return null; }
    Nodes getNodes() { return null; }
    Users getUsers() { return null; }
    Metas getMetas() { return null; }
    
    Priority getPriority() { return Priority.NONE; }
    ushort getPing() { return 0; }
    
    uint getUploadRate() { return 0; }
    uint getDownloadRate() { return 0; }
    
    ulong getUploaded() { return 0; }
    ulong getDownloaded() { return 0; }

//from Files
    File getFile(File_.Type type, uint id) { return null; }
    File[] getFileArray(File_.Type type, File_.State state, uint age) { return null; }

    void previewFile(File_.Type type, uint id) {}

    void removeFiles(File_.Type type, uint[] ids) {}
    void copyFiles(File_.Type type, uint[] source, uint target) {}
    void moveFiles(File_.Type type, uint[] source, uint target) {}
    void renameFile(File_.Type type, uint id, char[] new_name) {}
    //for download resume and search result start
    void startFiles(File_.Type type, uint[] ids) {} 
    void pauseFiles(File_.Type type, uint[] ids) {}
    void stopFiles(File_.Type type, uint[] ids) {}
    void prioritiseFiles(File_.Type type, uint[] ids, Priority priority) {}
}
