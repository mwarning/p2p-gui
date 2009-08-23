module clients.gift.model.giFTSource;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import clients.gift.MsgParser;
import utils.Utils;
import api.Node;
import api.Nodes;

import Utils = utils.Utils;


final class giFTSource : Node
{
public:

    this(MsgParser msg)
    {
        id = toInt(msg["ADDSOURCE"]);
        user = msg["user"];
        hash  = msg["hash"];
        size  = Utils.to!(ulong)(msg["size"]);
        //hash  = msg["url"];
        //save  = msg["save"];
    }

    uint getId()
    {
        return id;
    }
    
    private:
    
    uint id;
    char[] hash;
    char[] state;
    char[] name;
    char[] mime;
    ulong transmit;
    ulong size;
}
