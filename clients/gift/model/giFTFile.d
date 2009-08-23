module clients.gift.model.giFTFile;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

static import Convert = tango.util.Convert;

import api.File;
static import Utils = utils.Utils;

import clients.gift.giFTParser;

final class giFTFile : NullFile
{
    public:
    /*
    enum State {
        ACTIVE,
                    WAITING, PAUSED, QUEUED,
                    Queued (Remotely), Queued (queue
                    position), COMPLETED, CANCELLED
                    (Remotely), TIMED_OUT
    }*/
    
    this(giFTParser msg)
    {
        speed = 0;
        id = Convert.to!(uint)(msg["ADDDOWNLOAD"]);
        hash = msg["hash"];
        //state = msg["state"];
        state = parseState(msg["state"]);
        completed = Convert.to!(ulong)(msg["transmit"]);
        size = Convert.to!(ulong)(msg["size"]);
        name = msg["file"];
        mime = msg["mime"];
        
    }
    
    void update(giFTParser msg)
    {
        uint throughput = Convert.to!(uint)(msg["throughput"]);
        uint elapsed = Convert.to!(uint)(msg["elapsed"]);
    
        //we should use the average speed, according to the protocol doc
        if(elapsed > 0) speed = (speed + ((throughput * 1000) / elapsed)) / 2;
    
        completed = Convert.to!(ulong)(msg["transmit"]);
        state = parseState(msg["state"]);
        
        //MsgParser(msg["SOURCE"]) source;
    }
    
    uint getId() { return id; }
    char[] getName() { return name; }
    ulong getSize() { return size; }
    ulong getCompleted() { return completed; }
    Priority getPriority() { return Priority.NONE; }
    uint getLastSeen() { return 0; }
    uint getSpeed() { return speed; }
    File_.State getState() { return state; }
    char[] getHash() { return hash; }
    
    private:
    
    File_.State parseState(char[] state)
    {
        if(state == "Active") return File_.State.ACTIVE;
        else if(state == "Paused") return File_.State.PAUSED;
        else if(state == "Completed") return File_.State.COMPLETE;
        return File_.State.ACTIVE;
    }
    
    
    File_.State state;
    uint id;
    uint speed;
    char[] hash;
    char[] name;
    char[] mime;
    ulong completed;
    ulong size;
}
