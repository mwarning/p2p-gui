module api.Client;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/

import api.Node;
import api.File;
import api.Meta;
import api.User;
import api.Search;
import api.Setting;
import api.Connection;

/*
* Class for special Client methods and 
* functions we haven't yet
* assigned to another interface
*/
interface Client : Node
{
    enum Type
    {
        UNKNOWN = Node_.Type.max + 1, //to be able to move addClient(Node_.Type,...) to Node interface
        MLDONKEY,
        AMULE,
        RTORRENT,
        TRANSMISSION,
        GIFT
    }
    
    void setHost(char[] host);
    void setPort(ushort port);
    
    void addLink(char[] link);
    
    void setUsername(char[] user);
    void setPassword(char[] pass);
    char[] getUsername();
    char[] getPassword();
    
    //void start();
    void shutdown();
    void connect();
    void disconnect();
}
