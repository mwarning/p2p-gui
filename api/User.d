module api.User;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/

import api.Node;
import api.Meta;
import api.Connection;
import api.Setting;
import api.File;
public import api.User_;

interface Users
{
    uint addUser(User_.Type type, char[] name);
    void renameUser(uint id, char[] new_name);
    void removeUser(uint id);
    void setUserPassword(uint id, char[] password);
    
    //void setUserState();
    User getUser(uint id);
    User[] getUserArray();
}

interface User : Users
{
    uint getId();
    
    char[] getName();
    char[] getPassword();
    //uint getMaxSize();
    //uint getMaxVolume();
    //uint getMaxVolume();
    
    //uint getCurrent
    
    uint getUserCount();
    
    //char[] getDefaultUser(); //normla case is getName
/*
    uint addFileConduit(FileConduit fc);
    void connect(uint id);
    void disconnect(uint id);
*/
    //settings, for storing values etc. will be written and loaded to disk.
    User_.Type getType();
    User_.State getState();
    
    Files getFiles();
    Nodes getNodes();
    Settings getSettings(); //incoming dir, language etc. gui settings
    Metas getMetas();
}

class NullUser : User
{
    uint getId()  { return 0; }
    
    char[] getName() { return null; }
    char[] getPassword() { return null; }
    uint getUserCount() { return 0; }
    
    User_.Type getType() { return User_.Type.UNKNOWN; }
    User_.State getState() { return User_.State.ANYSTATE; }
    
    Files getFiles() { return null; }
    Nodes getNodes() { return null; }
    Settings getSettings() { return null; }
    Metas getMetas() { return null; }
    
    uint addUser(User_.Type type, char[] name) { return 0; }
    void renameUser(uint id, char[] new_name) {}
    void removeUser(uint id) {}
    void setUserPassword(uint id, char[] password) {}
    
    User getUser(uint id) { return null; }
    User[] getUserArray() { return null; }
}
