module clients.hydranode.model.HNDownload;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import clients.hydranode.opcodes;
import clients.hydranode.Hydranode;
import api.File;

class HNDownload //: Download
{
    public:
/*
    enum DownloadState {
        DSTATE_RUNNING   = ::CGComm::DSTATE_RUNNING,
        DSTATE_VERIFYING = ::CGComm::DSTATE_VERIFYING,
        DSTATE_MOVING    = ::CGComm::DSTATE_MOVING,
        DSTATE_COMPLETED = ::CGComm::DSTATE_COMPLETE,
        DSTATE_CANCELED  = ::CGComm::DSTATE_CANCELED,
        DSTATE_PAUSED    = ::CGComm::DSTATE_PAUSED,
        DSTATE_STOPPED   = ::CGComm::DSTATE_STOPPED
    };*/
    enum { OP_PARTDATA = 0x90 };
    
    this(ubyte[] i)
    {
        ubyte objCode = getVal!(ubyte)(i);
        ushort objSize =getVal!(ushort)(i);
        if (objCode != OP_PARTDATA)
        {
            /*
            i.seekg(objSize, std.ios::cur);
            throw std.runtime_error(
                "Invalid ObjCode in DownloadList.readDownload!"
            );*/
        }
        id =getVal!(uint)(i);
        //DownloadPtr obj(new DownloadInfo(this, id));

        ushort tc =getVal!(ushort)(i); // tagcount
        while (i && tc--)
        {
            ubyte toc =getVal!(ubyte)(i);
            ushort sz = getVal!(ushort)(i);
            switch (toc)
            {
            case SearchTags.TAG_FILENAME:
                name =getVal!(char[])(i, sz);
                break;
            case SearchTags.TAG_FILESIZE:
                size =getVal!(ulong)(i);
                break;
            case DownloadTags.TAG_DESTDIR:
                destDir =getVal!(char[])(i, sz);
                break;
            case DownloadTags.TAG_LOCATION:
                location =getVal!(char[])(i, sz);
                break;
            case SearchTags.TAG_SRCCNT:
                srcCnt =getVal!(uint)(i);
                break;
            case DownloadTags.TAG_FULLSRCCNT:
                fullSrcCnt =getVal!(uint)(i);
                break;
            case DownloadTags.TAG_COMPLETED:
                completed =getVal!(ulong)(i);
                break;
            case NetworkTags.TAG_DOWNSPEED:
                speed =getVal!(uint)(i);
                break;
            case DownloadTags.TAG_STATE:
                uint stateNum =getVal!(uint)(i);
                switch(stateNum) {
                    case FileState.DSTATE_RUNNING: state = File_.State.ACTIVE; break;
                    case FileState.DSTATE_VERIFYING: state = File_.State.PROCESS; break;
                    case FileState.DSTATE_MOVING: state = File_.State.PROCESS; break;
                    case FileState.DSTATE_COMPLETE: state = File_.State.CANCELED; break;
                    case FileState.DSTATE_CANCELED: state = File_.State.CANCELED; break;
                    case FileState.DSTATE_PAUSED: state = File_.State.PAUSED; break;
                    case FileState.DSTATE_STOPPED: state = File_.State.STOPPED; break;
                }/*
                state = static_cast<DownloadState>(
                    Utils.getVal!(uint)(i)
                );*/
                break;
            case DownloadTags.TAG_AVAIL:
                avail =getVal!(ubyte)(i);
                break;
            case DownloadTags.TAG_CHILD: {
                /*
                Iter j = m_list.find(Utils.getVal!(uint)(i));
                if (j != m_list.end()) {
                    obj->m_children.insert((*j).second);
                */
                }
                break;
            
                //! TODO: handle DownloadTags.TAG_COMPLETEDCHUNKS (RangeList64)
            default:
                //i.seekg(sz, std.ios::cur);
                break;
            }
        }
    }

    void parse() //ubyte[] i)
    {
        
    }
    
    void update(HNDownload o)
    {
        assert(id == o.id);
        name = o.name;
        size = o.size;
        completed = o.completed;
        destDir = o.destDir;
        location = o.location;
        srcCnt = o.srcCnt;
        fullSrcCnt = o.fullSrcCnt;
        speed = o.speed;
        state = o.state;
        avail = o.avail;
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
    uint srcCnt, speed;
    uint fullSrcCnt;
    
    //only available on request
    char[][] comments;
    uint[char[]] names;
    char[][] links;
    //std::set<DownloadInfoPtr> m_children;
    //DownloadList *m_parent;
}

