module clients.mldonkey.model.MLClientKind;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import clients.mldonkey.InBuffer;
import tango.io.Stdout;

final class MLClientKind
{
    public:
    
    this(InBuffer msg)
    {
        update(msg);
    }
    
    void update(InBuffer msg)
    {
        ubyte clientType = msg.read8();
        if(clientType == 1)
        {
            name = msg.readString();
            hash = msg.readHash();
            msg.read8(); //useless data from guiEncoding.ml:94; let buf_hostname
        }
        
        host = msg.readIpAddress();
        geoIp = msg.read8();
        port = msg.read16();
    }
    
    //protected:
    
    ubyte geoIp;
    ushort port;
    char[] host;
    char[] name, hash;
}

