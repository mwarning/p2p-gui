module clients.mldonkey.model.MLAddr;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import tango.io.Stdout;

import clients.mldonkey.InBuffer;


final class MLAddr
{
    public:
    
    this(InBuffer msg)
    {
        ubyte addr_type = msg.read8();
        if (addr_type == 0)
        {
            host = msg.readIpAddress(); //IP string
        }
        else if (addr_type == 1)
        {
            host = msg.readString(); //host name
        }
        else
        {
            Stdout("(W) MLAddr: Invalid address type!").newline;
        }
        
        geoIp = msg.read8();
        isBlocked = (msg.read8() == 1);
    }
    
    ubyte geoIp;
    char[] host;
    ushort port;
    bool isBlocked;
}
