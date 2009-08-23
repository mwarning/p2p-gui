module clients.multiuser.Multiuser;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import api.Node;
import api.File;
import api.User;
import api.Meta;
import api.Setting;


/*
* This class wraps other client classes to
* add/enhance multi user features
*
* this is a stub
*/
/*
* Scenarios:
* - A fully wrapped single client instance, shared by MultiUser instances.
* - Every MultIUser instance owns a Client instance
* - mix of previous
*/
class MultiUser : User, Users, Files //Client
{
    static MultiUser[char[]] all_users;
    
    uint id;
    
    User user; //user of client
    Client client; //client to be wrapped
    
    //set by admin..
    char[] username;
    char[] password;
    bool allow_manual_disconnect
    ushort max_download_count;
    ushort max_download_volume; //in MiB
    
    this(uint id)
    {
        this.id = id;
        client = new Client;
    }

    char[] getName() { return username; }
    char[] getPassword() { return password; }
    
    Files getFiles() { return null; }
    Users getUsers() { return this; }
    Nodes getNodes() { return null; }
    Settings getSettings() { return null; }
    Metas getMetas()  { return null; }
    
    void createUser(char[] name) {}
    void renameUser(uint id, char[] new_name) {}
    void removeUser(uint id, char[] user_name) {}
    void setPassword(uint id, char[] password) {}
    
    uint getFileCount(File_.Type type, File_.State state) {}
    File getFile(File_.Type type, uint id) {}
    File[] getFileArray(File_.Type type, File_.State state, uint age)
    {
        //TODO: apply filtering by User
        Files file_view = client.getFiles;
        if(file_view) return null; //file_view.getFileIterator(type, state, age);
        return null;
    }

    void onComplete()
    {
        //move file to destination
        //get file source
    }
    
    
    uint previewFile(File_.Type type, uint id) {}
    
    //void setState(File_.Type type, uint id, File_.State state) //PAUSE, RUNNING, STOP etc.
    
    void removeFile(File_.Type type, uint id) {}
    void renameFile(File_.Type type, uint id, char[] new_name) {}
    void startFile(File_.Type type, uint id) {} //for download resume and search result start
    void pauseFile(File_.Type type, uint id) {}
    void prioritiseFile(File_.Type type, uint id, ubyte priority) {}
}
