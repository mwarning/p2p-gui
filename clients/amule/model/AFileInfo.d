module clients.amule.model.AFileInfo;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/

import tango.io.Stdout;
import tango.core.ByteSwap;
import tango.time.Clock;

import api.File;
import api.Node;
import api.Meta;
import webcore.Logger;
static import Utils = utils.Utils;

import clients.amule.ECPacket;
import clients.amule.ECCodes;
import clients.amule.ECTag;
import clients.amule.RLE_Data;
import clients.amule.aMule;


const uint FILE_PARTSIZE = 9728000;

final class AFileInfo : NullFile, Nodes, Metas
{
    RLE_Data part_status;
    RLE_Data gap_status;
    
    struct Range
    {
        ulong start;
        ulong end;
    }
    
    //wrap comments
    class aFileComment : NullMeta
    {
        char[] user_name;
        char[] comment;
        short rating;
        
        this(char[] user_name, short rating, char[] comment)
        {
            this.user_name = user_name;
            this.rating = rating;
            this.comment =comment;
        }
        
        short getRating() { return rating; }
        char[] getMeta() { return comment; }
        char[] getName() { return name; }
        Meta_.Type getType() { return Meta_.Type.COMMENT; }
    }
    
    //wrap file names
    class aFileName : NullFile
    {
        char[] name;
        ubyte sources;
        
        this(char[] name, ubyte sources)
        {
            this.name = name;
            this.sources = sources;
        }
        
        char[] getName() { return name; }
        uint getNodeCount(Node_.Type type, Node_.State state)
        {
            return sources;
        }
    }
    
    this(uint id, ubyte[] hash, ECTag tag, aMule amule)
    {
        gap_status = new RLE_Data(2 * ulong.sizeof, true);
        part_status = new RLE_Data(0, true);
        
        this.id = id;
        this.hash = hash;
        this.amule = amule;
        
        update(tag);
    }
    
    void update(ECTag t)
    {
        ECTag[] tags = t.getTags();
        ubyte[] part_status_raw;
        
        foreach(ECTag tag; tags)
        {
            ECTagNames tag_code = tag.getCode();
            switch(tag_code)
            {
            case ECTagNames.EC_TAG_PARTFILE_NAME:
                name = tag.getString();
                break;
            
            case ECTagNames.EC_TAG_PARTFILE_PARTMETID:
                //will be send only once after connect for detail level 4
                //but not for updates
                part_id = tag.get16();
                break;
            
            case ECTagNames.EC_TAG_PARTFILE_SIZE_FULL:
                size = tag.get32();
                break;
            
            case ECTagNames.EC_TAG_PARTFILE_SIZE_XFER:
                uploaded = tag.get32();
                break;
            case ECTagNames.EC_TAG_PARTFILE_SIZE_XFER_UP:
                up_speed = tag.get32();
                break;
            
            case ECTagNames.EC_TAG_PARTFILE_SIZE_DONE:
                downloaded = tag.get32();
                break;
            
            case ECTagNames.EC_TAG_PARTFILE_SPEED:
                down_speed = tag.get32();
                break;
            
            case ECTagNames.EC_TAG_PARTFILE_STATUS:
                ubyte status = tag.get8();
                switch(status)
                {
                    case PS.READY: state = File_.State.ACTIVE; break;
                    case PS.PAUSED: state = File_.State.PAUSED; break;
                    case PS.COMPLETE: state = File_.State.COMPLETE; break;
                    case PS.COMPLETING:
                    case PS.WAITINGFORHASH:
                    case PS.HASHING: state = File_.State.PROCESS; break;
                    case PS.EMPTY: break;
                    /*
                    case PS.ERROR:
                    case PS.INSUFFICIENT: //Insufficient Diskspace
                    case PS.UNKNOWN:
                    */
                    default:
                        Logger.addDebug("AFileInfo: Unknown status {}.", status);
                }
                break;
                
            case ECTagNames.EC_TAG_PARTFILE_PRIO:
                auto prio = tag.get8();
                switch(prio)
                {
                    case 0: priority = Priority.LOW; break;
                    case 1: priority = Priority.NORMAL; break;
                    case 2: priority =  Priority.HIGH; break;
                    case 10: //low
                    case 11: //normal
                    case 12: priority =  Priority.AUTO; break; //high
                    default:
                        Logger.addDebug("AFileInfo: Unknown priority {} for file hash {}.", prio, this.getHash);
                        priority = Priority.NONE;
                }
                break;
                
            case ECTagNames.EC_TAG_PARTFILE_SOURCE_COUNT:
                source_count = tag.get16();
                break;
            /*
            case ECTagNames.EC_TAG_PARTFILE_SOURCE_COUNT_A4AF:
                tag.get16();
                break;
            case ECTagNames.EC_TAG_PARTFILE_SOURCE_COUNT_NOT_CURRENT:
                tag.get16();
                break;
            */
            case ECTagNames.EC_TAG_PARTFILE_SOURCE_COUNT_XFER:
                source_count_xfer = tag.get16();
                break;
            /*
            case ECTagNames.EC_TAG_PARTFILE_ED2K_LINK:
                tag.getString();
                break;
            case ECTagNames.EC_TAG_PARTFILE_CAT:
                tag.get8();
                break;
            case ECTagNames.EC_TAG_PARTFILE_LAST_RECV: //used?
                break;
            */
            
            case ECTagNames.EC_TAG_PARTFILE_LAST_SEEN_COMP:
                last_seen = tag.get64(); //seconds since 1970
                break;
            
            case ECTagNames.EC_TAG_PARTFILE_PART_STATUS:
                //array of bytes; each byte corresponds to one chunk; number of sources?
            
                if(part_status.m_len == 0 && size)
                {
                    part_status.Realloc((size / FILE_PARTSIZE) + 1);
                }
                
                auto data = tag.getRawValue();
                part_status.Decode(data);
                break;
                
            case ECTagNames.EC_TAG_PARTFILE_GAP_STATUS:
                //[num_of_gaps] [ulong range pairs of file gaps]
                
                auto data = tag.getRawValue();
                uint gap_count = Utils.swapBytes(*cast(uint*) data.ptr);
                
                gap_status.Realloc(gap_count * 2 * ulong.sizeof);
                gap_status.Decode(data, 4);
                break;
            
            case ECTagNames.EC_TAG_PARTFILE_REQ_STATUS:
                //[ulong range pairs]
                auto data = tag.getRawValue();
                if(data.length % 4) break;
                requested_ranges = cast(Range[]) data;
                break;
            
            case ECTagNames.EC_TAG_PARTFILE_COMMENTS:
                auto sub_tags = tag.getTags();
                if(sub_tags.length % 4) break;
                
                comments = null;
                auto i = 0;
                while(i < sub_tags.length)
                {
                    char[] user_name = sub_tags[i++].getString();
                    char[] file_name = sub_tags[i++].getString();
                    ubyte rating = sub_tags[i++].get8();
                    char[] comment = sub_tags[i++].getString();
                    comments ~= new aFileComment(user_name, rating, comment);
                }
                break;
            case ECTagNames.EC_TAG_PARTFILE_SOURCE_NAMES:
                auto sub_tags = tag.getTags();
                if(sub_tags.length % 2) break;
                
                file_names = null;
                auto i = 0;
                while(i < sub_tags.length)
                {
                    char[] name = sub_tags[i++].getString();
                    ubyte sources = sub_tags[i++].get8();
                    file_names ~= new aFileName(name, sources);
                }
                break;
            default:
                break;
            }
        }
    }
    
    uint getId() { return id; }
    char[] getName() { return name; }
    ulong getSize() { return size; }
    ulong getDownloaded() { return downloaded; }
    uint getUploadRate() { return up_speed; }
    uint getDownloadRate() { return down_speed; }
    File_.State getState() { return state; }
    char[] getHash() { return Utils.toHexString(hash.dup.reverse); }
    ubyte[] getRawHash() { return hash; }
    Priority getPriority() { return priority; }
    uint getLastSeen()
    {
        if(last_seen == 0) return 0;
        return (Clock.now - Time.epoch1970).seconds - last_seen;
    }
    
    Files getFiles() { return this; }
    Nodes getNodes() { return this; }
    Metas getMetas() { return this; }
    
    void connect(Node_.Type type, uint id) {}
    void disconnect(Node_.Type type, uint id) {}
    Node addNode(Node_.Type type, char[] host, ushort  port, char[] user, char[] password)
    {
        return null;
    }
    void addLink(char[] link) {}
    void removeNode(Node_.Type type, uint id) {}
    
    Node getNode(Node_.Type type, uint id)
    {
        return amule.getNode(type, id);
    }
    
    uint getNodeCount(Node_.Type type, Node_.State state)
    {
        if(type == Node_.Type.NETWORK)
        {
            return 1;
        }
        else if(type == Node_.Type.CLIENT)
        {
            if(state == Node_.State.CONNECTED) return source_count_xfer;
            if(state == Node_.State.DISCONNECTED) return source_count;
            if(state == Node_.State.ANYSTATE) return source_count + source_count_xfer;
        }
        return 0;
    }
    
    Node[] getNodeArray(Node_.Type type, Node_.State state, uint age)
    {
        if(type == Node_.Type.NETWORK)
        {
            return Utils.filter!(Node)([amule.edonkey], state, age);
        }
        return null;
    }
    
    uint getFileCount(File_.Type type, File_.State state)
    {
        switch(type)
        {
            case File_.Type.CHUNK: return size / FILE_PARTSIZE;
            default: return 0;
        }
    }
    
    File getFile(File_.Type type, uint id)
    {
        return null;
    }
    
    File[] getFileArray(File_.Type type, File_.State state, uint age)
    {
        if(type == File_.Type.SOURCE)
        {
            return Utils.filter!(File)(file_names, state, age);
        }
        
        if(type != File_.Type.CHUNK) return null;
        
        class Part : NullFile
        {
            uint id;
            ulong size;
            ubyte sources;
            bool complete;
            
            this(uint id, ulong size, ubyte sources, bool complete)
            {
                this.id = id;
                this.size = size;
                this.sources = sources;
                this.complete = complete;
            }
            
            ulong getSize()
            {
                return size;
            }
            
            ulong getDownloaded()
            {
                return complete ? size : 0;
            }
            
            uint getNodeCount(Node_.Type type, Node_.State state)
            {
                return (type == Node_.Type.CLIENT) ? sources : 0;
            }
        }
        
        auto data = gap_status.m_buff.dup;
        
        debug(AFileInfo)
        {
            Logger.addDebug("AFileInfo: gap_status {}", data.length);
            Logger.addDebug("AFileInfo: part_status {}", part_status.m_buff.length);
        }
        
        if(data.length % 8) return null;
        ByteSwap.swap64(data);
        auto gaps = cast(Range[]) data;
        
        File[] chunks = new File[2 * gaps.length + 1];
        ulong pre;
        uint id;
        foreach(i, gap; gaps)
        {
            //chunk number
            uint start = gap.start / FILE_PARTSIZE;
            uint end = (gap.end / FILE_PARTSIZE) + 1;
            uint sources;
        
            auto chunk_sources = part_status.m_buff;
            //TODO: more accurate source assignment
            for(auto j = start; j < end; j++)
            {
                sources += chunk_sources[j];
            }
            //chunk that spans the gap
            chunks[id] = new Part(id, gap.start - pre, sources, true);
            id++;
            //chunk that spans the completed area
            chunks[id] = new Part(id, gap.end - gap.start, 0, false);
            id++;
            pre = gap.end;
        }
        
        if(pre < size)
        {
            uint sources;
            for(auto i = pre / FILE_PARTSIZE; i < size / FILE_PARTSIZE + 1; i++)
            {
                sources += part_status.m_buff[i];
            }
            chunks[id] = new Part(id, size - pre, sources, true);
            id++;
        }
    
        return chunks[0..id];
    }
    
    Meta[] getMetaArray(Meta_.Type type, Meta_.State state, uint age)
    {
        if(type != Meta_.Type.COMMENT) return null;
        return Utils.filter!(Meta)(comments, state, age);
    }
    
    uint getMetaCount(Meta_.Type type, Meta_.State state)
    {
        if(type != Meta_.Type.COMMENT) return 0;
        return comments.length;
    }
    
    void addMeta(Meta_.Type type, char[] message, int rating) {}
    void removeMeta(Meta_.Type type, uint id) {}    
    
    ushort getPartId()
    {
        return part_id;
    }
    
    void markActive()
    {
        state = File_.State.ACTIVE;
    }
    
    private:
    
    aMule amule;
    char[] name;
    ubyte[] hash;
    Range[] requested_ranges;
    Priority priority;
    uint id;
    uint down_speed, up_speed;
    ulong size;
    ulong downloaded;
    ulong uploaded;
    ushort source_count;
    ushort source_count_xfer;
    ulong last_seen;
    ushort part_id;
    File_.State state;
    aFileName[] file_names;
    aFileComment[] comments;
}
