module clients.hydranode.model.HNModule;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import clients.hydranode.opcodes;
import clients.hydranode.Hydranode;
//import clients.hydranode.model.HNObject;
import api.File;

class HNModule
{
    public:
    
    this(ubyte[] i)
    {
        this.id = getVal!(uint)(i);
        ushort tagCount = getVal!(ushort)(i);
        while (i && tagCount--)
        {
            ubyte tc = getVal!(ubyte)(i);
            ushort len = getVal!(ushort)(i);
            switch (tc)
            {
                case ModuleTags.TAG_NAME: 
                    this.name = getVal!(char[])(i,len);
                    break;
                case ModuleTags.TAG_DESC:
                    this.desc = getVal!(char[])(i,len);
                    break;
                case NetworkTags.TAG_SESSUP:
                    this.sessUp = getVal!(ulong)(i);
                    break;
                case NetworkTags.TAG_SESSDOWN:
                    this.sessDown = getVal!(ulong)(i);
                    break;
                case NetworkTags.TAG_TOTALUP:
                    this.totalUp = getVal!(ulong)(i);
                    break;
                case NetworkTags.TAG_TOTALDOWN:
                    this.totalDown = getVal!(ulong)(i);
                    break;
                case NetworkTags.TAG_UPSPEED:
                    this.upSpeed = getVal!(uint)(i);
                    break;
                case NetworkTags.TAG_DOWNSPEED:
                    this.downSpeed = getVal!(uint)(i);
                    break;
                default: break;
            }
        }
    }
    /*
    HNObject findObject(uint id)
    {
        OCIter i = m_objects.find(id);
        if (i != m_objects.end()) {
            return i->second;
        } else {
            return ObjectPtr();
        }
    }*/
    void update(HNModule o)
    {
    
    }
    
    uint getId() { return id;}
    
    
    HNModule[uint] list;
    //HNObject[uint] objects;

    //ModulePtr readModule(std::istream &i);
    //ObjectPtr readObject(std::istream &i);
    uint id;
    char[] name;
    char[] desc;
    ulong sessUp;
    ulong sessDown;
    ulong totalDown;
    ulong totalUp;
    uint downSpeed;
    uint upSpeed;
}

