module clients.mldonkey.model.MLResult;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import tango.time.Clock;
import Convert = tango.util.Convert;
import tango.io.Stdout;

import api.File;
import api.File_;

import clients.mldonkey.InBuffer;
import clients.mldonkey.model.MLTags;


final class MLResult : NullFile
{
    public:
    
    this(uint id, InBuffer msg)
    {
        this.id = id;
        update(msg);
    }
    
    void update(InBuffer msg)
    {
        networkId = msg.read32;
        file_names = msg.readStrings;
        char[][] uids = msg.readStrings; //meaning?
        if(uids.length) hash = uids[0];
        size = msg.read64;
        format = msg.readString; //used?
        type = msg.readString; //used?
        MLTags tags;
        tags.parse(msg); //availability, completesources, length, codec, bitrate, lastcompl, format, type 
        known_sources = Convert.to!(uint)(tags.get("availability"), 0);
        complete_sources = Convert.to!(uint)(tags.get("completesources"), 0);
        comment = msg.readString;
        already = (msg.read8 == 1); //TODO: replace by api getFile?
        time = msg.read32;
        
        if(uids.length)
            hash = uids[0];
        
        if(format.length)
            format ~= ", ";
        
        format ~= tags.toString(["availability", "completesources"]);
        
        changed();
    }
    
    uint getId() { return id; }
    uint getAge() { return time; }
    ulong getSize() { return size; }
    char[] getHash() { return hash; }
    char[] getFormat() { return format; }
    uint getLastChanged() { return last_changed; }
    char[] getName()
    {
        return (file_names.length) ? file_names[0] : "";
    }
    
//are source files or nodes?
    uint getFileCount(File_.Type type, File_.State state)
    {
        //TODO: filter by type, too?
        if(state == File_.State.COMPLETE) return complete_sources;
        if(state == File_.State.ANYSTATE) return known_sources;
        return 0;
    }
    
    File_.State getState() { return File_.State.PAUSED; }
    File_.Type getType() { return File_.Type.SOURCE; }
    
    char[][] getfile_names() { return file_names; }
    
private:
    
    void changed()
    {
        last_changed = (Clock.now - Time.epoch1970).seconds;
    }

    uint last_changed;
    uint known_sources;
    uint complete_sources;
    uint id, networkId, time;
    ulong size;
    bool already;
    char[][] file_names;
    char[] hash, comment, format, type;
}
