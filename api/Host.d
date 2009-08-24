module api.Host;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/

/*
* Represent the host application
*/

import tango.io.model.IConduit;
import tango.core.Thread;
import api.Client;


struct Host
{
    /*
    * Information about this application.
    */
    static char[] main_version;
    static char[] main_name;
    static char[] main_weblink;
    
    /*
    * Names and default settings for clients.
    */
    struct ClientInfo
    {
        Client.Type type;
        char[] name;
        char[] user;
        char[] pass;
        char[] host;
        ushort port;
    }

    /*
    * Array of all supported clients with default settings
    */
    static ClientInfo[] client_infos;
    
    static ClientInfo* getClientInfo(Client.Type type)
    {
        foreach(ref info; client_infos)
        {
            if(info.type == type)
            {
                return &info;
            }
        }
        return null;
    }
    
    static this()
    {
        version(MLDONKEY)
        {
            client_infos ~= ClientInfo(Client.Type.MLDONKEY, "MLDonkey", "admin", "", "127.0.0.1", 4001);
        }
        
        version(AMULE)
        {
            client_infos ~= ClientInfo(Client.Type.AMULE, "aMule", "admin", "", "127.0.0.1", 4712);
        }
        
        version(RTORRENT)
        {
            client_infos ~= ClientInfo(Client.Type.RTORRENT, "rTorrent", null, null, "127.0.0.1", 5000);
        }
        
        version(TRANSMISSION)
        {
            client_infos ~= ClientInfo(Client.Type.TRANSMISSION, "Transmission", null, null, "127.0.0.1", 9091);
        }
        
        version(GIFT)
        {
            client_infos ~= ClientInfo(Client.Type.GIFT, "giFT", null, null, "127.0.0.1", 1213);
        }
    }
    
    /*
    * Download a file with the browser.
    * The function should offer a save/download file dialog on call.
    */
    static void function(InputStream source, char[] name, ulong size) saveFile;
}
