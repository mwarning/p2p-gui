module clients.amule.model.AResultInfo;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/

import tango.io.Stdout;

import api.File;
import webcore.Logger;
static import Utils = utils.Utils;

import clients.amule.ECPacket;
import clients.amule.ECCodes;
import clients.amule.ECTag;

final class AResultInfo : NullFile
{
private:

    uint id;
    ubyte[] hash;
    char[] name;
    ulong size;
    ushort sources_complete;
    ushort sources_partial;
    
public:

    this(uint id, ubyte[] hash, ECTag tag)
    {
        this.id = id;
        this.hash = hash;
        update(tag);
    }
    
    ubyte[] getRawHash()
    {
        return hash;
    }
    
    void update(ECTag tag_)
    {
        ECTag[] tags = tag_.getTags();
        
        foreach(ECTag tag; tags)
        {
            auto tag_code = tag.getCode();
            
            switch(tag_code)
            {
            //next two only send when detail_level == EC_DETAIL_UPDATE
            case ECTagNames.EC_TAG_PARTFILE_SOURCE_COUNT:
                sources_partial = tag.get16;
                break;
            case ECTagNames.EC_TAG_PARTFILE_SOURCE_COUNT_XFER:
                sources_complete = tag.get16;
                break;
            case ECTagNames.EC_TAG_PARTFILE_NAME:
                name = tag.getString;
                break;
            case ECTagNames.EC_TAG_PARTFILE_SIZE_FULL:
                size = tag.get64;
                break;
            case ECTagNames.EC_TAG_KNOWNFILE:
                //already downloaded when present
                break;
            default:
                Logger.addDebug("AResultInfo: Unhandled tag code {}", tag_code);
            }
        }
    }

    uint getId() { return id; }
    char[] getName() { return name; }
    ulong getSize() { return size; }
    char[] getHash() { return Utils.toHexString(hash.dup.reverse); }
    uint getFileCount(File_.Type type, File_.State state)
    {
        if(state == File_.State.COMPLETE) return sources_complete;
        if(state == File_.State.ANYSTATE) return sources_partial;
        return 0;
    }
}
