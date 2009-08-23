module clients.hydranode.model.HNSharedFile;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import clients.hydranode.opcodes;
import clients.hydranode.Hydranode;
import api.File;

class HNSharedFile //: Download
{
    public:
    
    this(ubyte[] i)
    {
        ubyte objCode = getVal!(ubyte)(i);
        ushort objSize = getVal!(ushort)(i);
        if (objCode != OP_SHAREDFILE)
        {
            /*
            i.seekg(objSize, std::ios::cur);
            throw std::runtime_error(
                "Invalid ObjCode in DownloadList::readDownload!"
            );*/
            return;
        }

        uint id = getVal!(uint)(i);
        HNSharedFile obj; // = new HNSharedFile(id);

        ushort tc = getVal!(ushort)(i); // tagcount
        while (i && tc--)
        {
            ubyte toc = getVal!(ubyte)(i);
            ushort sz = getVal!(ushort)(i);
            switch (toc)
            {
                case SearchTags.TAG_FILENAME:
                    name = getVal!(char[])(i, sz);
                    break;
                case SearchTags.TAG_FILESIZE:
                    size = getVal!(ulong)(i);
                    break;
                case DownloadTags.TAG_LOCATION:
                    location = getVal!(char[])(i, sz);
                    break;
                case NetworkTags.TAG_TOTALUP:
                    uploaded = getVal!(ulong)(i);
                    break;
                case NetworkTags.TAG_UPSPEED:
                    speed = getVal!(uint)(i);
                    break;
                case DownloadTags.TAG_CHILD: {
                    /*
                    Iter j = m_list.find(getVal!(uint)(i));
                    if (j != m_list.end()) {
                        obj->m_children.insert((*j).second);
                    }*/
                    break;
                }
                case SharedFileTags.TAG_PDPOINTER:
                    partDataId = getVal!(uint)(i);
                    break;
                default:
                    //i.seekg(sz, std::ios::cur);
                    break;
            }
        }
    }

    void parse() //ubyte[] i)
    {
        
    }
    
    void update(HNSharedFile o)
    {
        name       = o.name;
        location   = o.location;
        size       = o.size;
        uploaded   = o.uploaded;
        speed      = o.speed;
        partDataId = o.partDataId;
    
        //onUpdated();
    }
    
    void parseNames(ubyte[] packet)
    {
        ushort nameCount =getVal!(ushort)(packet);
        names = names.init;
        while (packet && nameCount--)
        {
            ushort nameLen =getVal!(ushort)(packet);
            char[] name =getVal!(char[])(packet, nameLen);
            uint nameFreq =getVal!(uint)(packet);
            names[name] = nameFreq;
        }
    }
    
    void parseComments(ubyte[] packet)
    {
        //uint id = getVal!(uint)(packet);
        
        //auto download = (id in downloads);
        //if (!download) return;
        ushort commentCount = getVal!(ushort)(packet);
        comments = comments.init;
        while (packet.length && commentCount--)
        {
            ushort cLen = getVal!(ushort)(packet);
            char[] comment = getVal!(char[])(packet, cLen);
            comments ~= comment;
        }
        //download.onUpdated();
        //onUpdated(*download);
        //onUpdatedComments(*download);
    }

    void parseLinks(ubyte[] packet)
    {
        ushort linkCount =getVal!(ushort)(packet);
        links = links.init;
        while (packet && linkCount--)
        {
            ushort lLen = getVal!(ushort)(packet);
            char[] link = getVal!(char[])(packet, lLen);
            links ~= link;
        }
    }
    void changeId(uint id) { this.id = id; }
    uint getId() { return id; }
    char[] getName() { return name; }
    ulong getSize() { return size; }
    ulong getCompleted() { return completed; }
    uint getSpeed() { return speed; }
    char[] getHash() { return ""; }
    ubyte getPriority() { return 0; }
    uint getLastSeen() { return 0; }
    File_.State getState() { return state; }
    
    private:
    
    File_.State state;
    ubyte avail;
    uint id;
    char[] name, destDir, location;
    ulong size, completed;
    ulong uploaded;
    uint srcCnt, speed;
    uint fullSrcCnt;
    uint partDataId;
    //only available on request
    char[][] comments;
    uint[char[]] names;
    char[][] links;
    HNSharedFile[] children;
}

