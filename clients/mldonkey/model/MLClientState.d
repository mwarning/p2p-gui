module clients.mldonkey.model.MLClientState;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import tango.io.Stdout;

import clients.mldonkey.InBuffer;
import api.File_;
import api.Node_;

import webcore.Logger;

final class MLClientState
{
public:
    
    this(InBuffer msg)
    {
        update(msg);
    }
    
    void update(InBuffer msg)
    {
        ubyte stateNum = msg.read8();
        
        switch(stateNum)
        {
            case 0: state = Node_.State.DISCONNECTED; break; //NOT_CONNECTED
            case 1: //CONNECTING
            case 2: state = Node_.State.CONNECTING; break; //CONNECTED_INIT
            case 3: //CONNECTED_DOWNLOADING
            case 4: //CONNECTED
            case 5: //CONNECTED_QUEQUED
            case 6: state = Node_.State.CONNECTED; break; //NEW??
            case 7: state = Node_.State.REMOVED; break; //REMOVED
            case 8: state = Node_.State.BLOCKED; break; //BLACKLISTED
            case 9: state = Node_.State.DISCONNECTED; break; //NOT_CONNECTED_QUEQUED
            case 10: state = Node_.State.CONNECTED; break; //??
            default:
                Logger.addWarning("MLClientState: Unknown state: {}.", stateNum);
                state = Node_.State.ANYSTATE;
        }
        
        if (stateNum == 3 || stateNum == 5 || stateNum == 9)
        {
            rank = msg.read32();
        }
        else
        {
            rank = 0; //set to max value?
        }
    }
    
    Node_.State state;
    ubyte rank;
}
