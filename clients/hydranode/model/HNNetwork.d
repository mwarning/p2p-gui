module clients.hydranode.model.HNNetwork;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import clients.hydranode.opcodes;
import clients.hydranode.Hydranode;
import api.File;

class HNNetwork
{
    public:
    
    this(ubyte[] i)
    {
        
    }
    
    void update(HNNetwork o)
    {
    
    }

    uint getUpSpeed()   { return upSpeed;       }
    uint getDownSpeed() { return downSpeed;     }
    uint getConnCnt()   { return connCnt;       }
    uint getConnectingCnt() { return connectingCnt; }
    ulong getTotalUp()   { return totalUp;       }
    ulong getTotalDown() { return totalDown;     }
    ulong getSessionUp() { return sessionUp;     }
    ulong getSessionDown() { return sessionDown;   }
    ulong getUpPackets() { return upPackets;     }
    ulong getDownPackets() { return downPackets;   }
    uint getUpLimit()   { return upLimit;       }
    uint getDownLimit() { return downLimit;     }
    ulong getSessionLength()  { return sessLength;    }
    ulong getOverallRuntime() { return totalRuntime;  }
protected:
    //virtual void handle(std::istream &i);
private:
    uint upSpeed,   downSpeed, connCnt,   connectingCnt;
    ulong totalUp,   totalDown, sessionUp, sessionDown;
    ulong upPackets, downPackets;
    uint upLimit, downLimit;
    ulong sessLength,totalRuntime;
    //UpdateHandler handler;    
}

