module clients.gift.model.giFTNetwork;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

static import Convert = tango.util.Convert;

import api.Node;

import clients.gift.giFTParser;


final class giFTNetwork : NullNode
{
    public:
    this(uint id, char[] name,  char[] group)
    {
        this.id = id;
        this.name = name;
        auto parser = new giFTParser(group);
        users = Convert.to!(uint)(parser["users"], 0);
        files = Convert.to!(uint)(parser["files"], 0);
        size = Convert.to!(ulong)(parser["size"], 0);
    }
    
    Node_.Type getType() { return Node_.Type.NETWORK; }
    uint getId() { return id; }
    char[] getName() { return name; }
    uint getUserCount() { return users; }
    uint getFileCount() { return files; }
    ulong getSize() { return size; }
    bool getEnabled() { return true; }
    ulong getUploaded() { return 0; }
    ulong getDownloaded() { return 0; }
    
    private:
    
    uint id;
    char[] name;
    uint users;
    uint files;
    ulong size;
}
