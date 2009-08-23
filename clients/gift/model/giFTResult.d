module clients.gift.model.giFTResult;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import clients.gift.giFTParser;
import Convert = tango.util.Convert;


final class giFTResult
{
public:
    
    this(giFTParser msg, uint id)
    {
        this.id = id;
        update(msg);
    }
    
    void update(giFTParser msg)
    {
        //search_id = atoi!(uint)(msg["ITEM"]);
        size = Convert.to!(ulong)(msg["size"], 0);
        mime = msg["mime"];
        availability = Convert.to!(uint)(msg["availability"], 0);
        name = msg["file"];
        hash = msg["hash"];
        user = msg["user"];
        url = msg["url"];
        //giFTParser meta(msg["META"]);
        
    }

    uint getId() { return id; }
    ulong getSize() { return size; }
    char[] getName() { return name; }
    char[] getHash() { return hash; }
    char[] getUser() { return user; }
    char[] getUrl() { return url; }
    char[] getType() { return mime; }
    
private:
    uint id;
    uint search_id;
    ulong size;
    char[] user;
    char[] url;
    char[] mime;
    char[] name;
    char[] hash;
    ushort availability;
}