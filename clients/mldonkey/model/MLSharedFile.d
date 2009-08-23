module clients.mldonkey.model.MLSharedFile;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import api.File;

import clients.mldonkey.InBuffer;


final class MLSharedFile : NullFile
{
public:
    
    this(uint id, InBuffer msg)
    {
        this.id = id;
        update(msg);
    }
    
    void update(InBuffer msg)
    {
        networkId = msg.read32();
        name = msg.readString();
        size = msg.read64();
        uploaded = msg.read64();
        requests = msg.read32(); 
        //OCAML code:
        //buf_list buf buf_uid s.shared_uids;
        //buf_sub_files proto buf s.shared_sub_files;
        //buf_string buf (magic_string s.shared_magic)
    }
    
    uint getId() {return id; }
    uint getRequests() {return requests; }
    char[] getName() { return name; }
    ulong getSize() { return size; }
    File_.State getState() {return File_.State.ACTIVE; }
    File_.Type getType() {return File_.Type.FILE; }
    
    uint download_id;
    char[] name;
    uint id, networkId, requests;
    ulong size, uploaded;
}
