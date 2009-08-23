module clients.hydranode.model.HNResult;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import clients.hydranode.Hydranode;
import clients.hydranode.opcodes;
import api.Search;

class HNResult// : SearchResult
{
    public:

    this(ubyte[] i)
    {
        id = getVal!(uint)(i);
        ubyte tc = getVal!(ubyte)(i);
        
        while (i.length && tc--)
        {
            ubyte toc = getVal!(ubyte)(i);
            ushort tsz = getVal!(ushort)(i);
            switch (toc) {
            case SearchTags.TAG_FILENAME:
                name = getVal!(char[])(i, tsz);
                break;
            case SearchTags.TAG_FILESIZE:
                size = getVal!(ulong)(i);
                break;
            case SearchTags.TAG_SRCCNT:
                sources = getVal!(uint)(i);
                break;
            case DownloadTags.TAG_FULLSRCCNT:
                fullSources = getVal!(uint)(i);
                break;
            case SearchTags.TAG_BITRATE:
                bitrate = getVal!(uint)(i);
                break;
            case SearchTags.TAG_CODEC:
                rcodec = getVal!(char[])(i, tsz);
                break;
            case SearchTags.TAG_LENGTH:
                length = getVal!(uint)(i);
                break;
            default:
                //logDebug(boost.format("Unknown tag %d (len=%d)") % (int)tc % tsz);
                //i.seekg(tsz, std.ios::cur);
                break;
            }
        }
        assert(name.length);
    }

    void update(HNResult result)
    {
        name = result.getName();
        size = result.getSize();
        sources = result.getSources();
        fullSources = result.getFullSources();
        //onUpdated();
    }
    
    uint getId() { return id; }
    char[] getName() { return name; }
    ulong getSize() { return size; }
    uint getSources() { return sources; }
    uint getFullSources() { return fullSources; }
    
    char[] getHash() {
        return "";
    }

    char[] getType() {
        return "";
    }
    
    private:
    
    uint id;
    char[] name, rcodec;
    ulong size;
    uint fullSources, sources, bitrate, length;
}

