module clients.amule.ECTag;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/

import tango.text.convert.Format;
import tango.io.Stdout;

import Utils = utils.Utils : swapBytes, toHexString;
import webcore.Logger;

import clients.amule.Utf8_Numbers;
import clients.amule.ECCodes;

final class ECTag
{
    static Exception exception_wrong_size;
    static Exception exception_wrong_type;
    
    static this()
    {
        exception_wrong_size = new Exception("ECTag: Value doesn't match data size.");
        exception_wrong_type = new Exception("ECTag: Value type can't be interpreted.");
    }
    
    ECTagTypes tag_type;
    ubyte[] value;
    
    ECTagNames tag_code;
    ECTag[] tags;

public:
    
    this()
    {
    }
    
    this(ECTagNames tag_code)
    {
        this.tag_code = tag_code;
    }
    
    this(ECTagNames tag_code, char[] str)
    {
        this.tag_code = tag_code;
        this.tag_type = ECTagTypes.EC_TAGTYPE_STRING;
        this.value.length = str.length + 1;
        this.value[0..$-1] = cast(ubyte[]) str;
        this.value[$-1] = '\0';
    }
    
    this(ECTagNames tag_code, ubyte[] value)
    {
        this.tag_code = tag_code;
        this.tag_type = ECTagTypes.EC_TAGTYPE_HASH16;
        this.value = value;
    }
    
    this(ECTagNames tag_code, ubyte value)
    {
        this.tag_code = tag_code;
        this.tag_type = ECTagTypes.EC_TAGTYPE_UINT8;
        this.value.length = ubyte.sizeof;
        this.value[0] = value;
    }
    
    //TODO: improvement, add number adjustment, when a ulong fit into ubyte, then send it as ubyte
    this(ECTagNames tag_code, ushort value)
    {
        this.tag_code = tag_code;
        this.tag_type = ECTagTypes.EC_TAGTYPE_UINT16;
        this.value.length = ushort.sizeof;
        *cast(ushort*) &this.value[0] = Utils.swapBytes(value);
    }
    
    this(ECTagNames tag_code, uint value)
    {
        this.tag_code = tag_code;
        this.tag_type = ECTagTypes.EC_TAGTYPE_UINT32;
        this.value.length = uint.sizeof;
        *cast(uint*) &this.value[0] = Utils.swapBytes(value);
    }
    
    this(ECTagNames tag_code, ulong value)
    {
        this.tag_code = tag_code;
        this.tag_type = ECTagTypes.EC_TAGTYPE_UINT64;
        this.value.length = ulong.sizeof;
        *cast(ulong*) &this.value[0] = Utils.swapBytes(value);
    }
    
    this(ECTagNames tag_code, uint ip, ushort port)
    {
        this.tag_code = tag_code;
        this.tag_type = ECTagTypes.EC_TAGTYPE_IPV4;
        this.value.length = uint.sizeof + ushort.sizeof;
        *cast(uint*) &this.value[0] = Utils.swapBytes(ip);
        *cast(ushort*) &this.value[4] = Utils.swapBytes(port);
    }
    
    uint write(ubyte[] packet)
    {
        uint size = getSize() - 7; //we only want the payload size
        if(tags.length) size -= 2;
        
        ushort code = tag_code << 1;
        if(tags.length) code += 1; //set in-code flag: subtags are present!
        
        *cast(ushort*) &packet[0] = Utils.swapBytes(code); //TAGNAME
        *cast(ubyte*) &packet[2] = tag_type; //TAGTYPE
        *cast(uint*) &packet[3] = Utils.swapBytes(size); //TAGLEN
        
        uint pos = 7;
        
        if(tags.length)
        {
            *cast(ushort*) &packet[pos] = Utils.swapBytes(cast(ushort) tags.length); //TAGCOUNT
            
            pos += 2;
            
            foreach(tag; tags)
            {
                pos += tag.write(packet[pos..$]);
            }
        }
        
        packet[pos..pos+value.length] = this.value;
        pos += value.length;
        
        return pos;
    }
    
    /*
    * read EC-tags
    * only available inside zlib compressed packets
    */
    uint read(ubyte[] packet)
    {
        if(packet.length <= 6) throw new Exception("(E) ECTag: Not enough data!");
        uint pos;
        
        //read ECTagNames
        ushort tmp = *cast(ushort*) &packet.ptr[pos];
        pos += 2;
        tmp = Utils.swapBytes(tmp);
        
        //read ECTagType
        tag_type = cast(ECTagTypes) packet[pos];
        pos += 1;
        
        uint tag_len = *cast(uint*) &packet.ptr[pos];
        pos += 4;
        tag_len = Utils.swapBytes(tag_len);
        
        //shift out lowest bit to get tag code
        tag_code = cast(ECTagNames) (tmp >> 1);
        
        uint value_len = tag_len;
        //lowest bit indicates presence of tag count
        if(tmp & 0x0001)
        {
            ushort tag_count = *cast(ushort*) &packet.ptr[pos];
            
            //why do we need no swap for this??
            //tag_count = Utils.swapBytes(tag_count);
            
            pos += 2;
            tag_count = Utils.swapBytes(tag_count);
            
            debug(ECTag)
                Logger.addDebug("ECTag: tag_count: {}", tag_count);
            
            value_len = pos; // + tag_len;
            
            while(tag_count--)
            {
                ECTag tag = new ECTag();
                pos += tag.read(packet[pos..$]);
                tags ~= tag;
            }
            value_len = tag_len - (pos - value_len);
        }
        
        //the last bytes left are the tag value
        value = packet[pos..pos+value_len];
        pos += value_len;
        return pos;
    }
    
    /*
    * read UTF8 encoded EC-tags
    *
    * tag code, tag length and subtag count are UTF-8 encoded,
    * but the tag length value does not take this into account
    * and assume the numbers aren't encoded.
    */
    uint readUTF8(ubyte[] packet)
    {
        uint pos;
        ushort tmp = void; //encoded tag code
        pos += readUtf8Val(tmp, packet); //read tag code and bool for tag count field presence
        tag_code = cast(ECTagNames) (tmp >> 1); //shift out lowest bit to get tag code
        
        tag_type = cast(ECTagTypes) packet[pos];
        
        debug(ECTag)
            Stdout("ECTag: tag_type is {}", packet[pos]);
        
        pos += 1;
        
        uint tag_len = void;
        pos += readUtf8Val(tag_len, packet[pos..$]);
        
        debug(ECTag)
            Stdout("(D) ECTag: tag_len is {}", tag_len);

        if(tag_type > tag_type.max)
        {
            throw new Exception (
                Format("(E) ECTag: Invalid tag type {}!", tag_type)
            );
        }
        
        uint value_len = tag_len;
        //lowest bit indicates presence of tag count
        if(tmp & 0x0001)
        {
            ushort tag_count;
            pos += readUtf8Val(tag_count, packet[pos..$]);
            
            while(tag_count--)
            {
                ECTag tag = new ECTag();
                pos += tag.readUTF8(packet[pos..$]);
                tags ~= tag;
            }
            
            //we can't rely on tag_len when there are subtags
            //so we need to derive them by value type
            switch(tag_type)
            {
                case ECTagTypes.EC_TAGTYPE_UINT8: value_len = 1; break;
                case ECTagTypes.EC_TAGTYPE_UINT16: value_len = 2; break;
                case ECTagTypes.EC_TAGTYPE_UINT32: value_len = 4; break;
                case ECTagTypes.EC_TAGTYPE_UINT64: value_len = 8; break;
                case ECTagTypes.EC_TAGTYPE_DOUBLE: value_len = 4; break;
                case ECTagTypes.EC_TAGTYPE_IPV4: value_len = 6; break;
                case ECTagTypes.EC_TAGTYPE_HASH16: value_len = 16; break;
                case ECTagTypes.EC_TAGTYPE_CUSTOM: value_len = 0; break; //we _assume_ that there is no value
                case ECTagTypes.EC_TAGTYPE_STRING:
                case ECTagTypes.EC_TAGTYPE_UNKNOWN: //is this an error case?
                
                default:
                    Logger.addWarning("ECTag: Try to guess value size, dangerous.");
                    value_len = tag_len - getSubTagSize(); break; //try to guess size, can fail!!
            }
        }
        
        value = packet[pos..pos+value_len];
        pos += value_len;
        
        return pos;
    }
    
    ECTagNames getCode()
    {
        return tag_code;
    }
    
    ECTagTypes getType()
    {
        return tag_type;
    }
    
    ECTag opIndex(ECTagNames tag_code)
    {
        foreach(ECTag tag; tags)
        {
            if(tag_code == tag.getCode) return tag;
        }
        return null;
    }
    
    ECTag[] getTags()
    {
        return tags;
    }
    
    private uint getSubTagSize()
    {
        uint size;
        if(tags.length) size += 2; //for tag counter
        
        foreach(ECTag tag; tags)
        {
            size += tag.getSize();
        }
        
        return size;
    }
    
    uint getSize()
    {
        uint size = 2 + 1 + 4; //ECTagNames + ECTagType + tag_len
        if(tags.length) size += 2; //tagcount
        
        foreach(ECTag tag; tags)
        {
            size += tag.getSize();
        }
        
        size += value.length; //data
        
        return size;
    }
    
    uint getValueLength()
    {
        return value.length;
    }
    
    char[] getString()
    {
        if(tag_type != ECTagTypes.EC_TAGTYPE_STRING)
        {
            throw new Exception("ECTag.getString: Type isn't string.");
        }
        else if(value.length)
        {
            return (cast(char[]) value[0..$-1]).dup; //we cut off the \0 here
        } 
        else
        {
            return null;
        }
    }
    
    ubyte[] getRawValue()
    {
        return value;
    }
    
    char[] getHash()
    {
        //TODO: check for tag type?
        auto hex = value.dup;
        return Utils.toHexString(value.reverse);
    }
    
    uint getIp()
    {
        if(tag_type != ECTagTypes.EC_TAGTYPE_IPV4 || value.length != 6)
        {
            throw exception_wrong_size;
        }
        
        uint ip = *cast(uint*) &value.ptr[0];
        return Utils.swapBytes(ip);
    }
    
    ushort getPort()
    {
        if(tag_type != ECTagTypes.EC_TAGTYPE_IPV4 || value.length != 6)
        {
            throw exception_wrong_size;
        }
        
        ushort port = *cast(ushort*) &value.ptr[4];
        return Utils.swapBytes(port);
    }
    
    private T get(T)()
    {
        T val = *cast(T*) value.ptr;
        static if(is(T == ubyte))
        {
            return val;
        }
        else
        {
            return Utils.swapBytes(val);
        }
    }
    
    bool getBool()
    {
        if(value.length != 1)
        {
            throw new Exception("ECTag.getBool: Value doesn't match data size.");
        }
        
        return cast(bool) value[0];
    }
    
    ubyte get8()
    {
        if(value.length != 1)
        {
            throw new Exception("ECTag.get8: Value doesn't match data size.");
        }
        
        return value[0];
    }

    uint get16()
    {
        if(value.length > 2)
        {
            throw new Exception("ECTag.get16: Value is bigger than data.");
        }
        
        switch(tag_type)
        {
            case ECTagTypes.EC_TAGTYPE_UINT16: return get!(ushort);
            case ECTagTypes.EC_TAGTYPE_UINT8: return get!(ubyte);
            default:
                throw new Exception("ECTag.get16: Value type doesn't match data.");
        }
    }
    
    uint get32()
    {
        if(value.length > 4)
        {
            throw new Exception("ECTag.get32: Value is bigger than data.");
        }
        
        switch(tag_type)
        {
            case ECTagTypes.EC_TAGTYPE_UINT32: return get!(uint);
            case ECTagTypes.EC_TAGTYPE_UINT16: return get!(ushort);
            case ECTagTypes.EC_TAGTYPE_UINT8: return get!(ubyte);
            default:
                throw new Exception("ECTag.get32: Value type doesn't match data.");
        }
    }
    
    ulong get64()
    {
        if(value.length > 8)
        {
            throw new Exception("ECTag.get64: Value is bigger than data.");
        }
        
        switch(tag_type)
        {
            case ECTagTypes.EC_TAGTYPE_UINT64: return get!(ulong);
            case ECTagTypes.EC_TAGTYPE_UINT32: return get!(uint);
            case ECTagTypes.EC_TAGTYPE_UINT16: return get!(ushort);
            case ECTagTypes.EC_TAGTYPE_UINT8: return get!(ubyte);
            default:
                throw new Exception("ECTag.get64: Value type doesn't match data.");
        }
    }

    void addTag(T...)(ECTagNames code, T val)
    {
        tags ~= new ECTag(code, val);
    }
    
    void addTag(dummy1 = void, dummy2 = void)(ECTag tag)
    {
        tags ~= tag;
    }
    
    /*
    * Prints tag structure to console.
    * For debugging, developing.
    * Used by ECPacket.print().
    */
    void print(char[] indent = "")
    {
        indent ~= "  ";
        Stdout(indent)("tag_code: ")(Utils.toHexString(cast(ushort) tag_code))("\n");
        
        Stdout(indent)("tag_type: ");
        switch(tag_type)
        {
            case ECTagTypes.EC_TAGTYPE_UNKNOWN: Stdout("UNKNOWN"); break;
            case ECTagTypes.EC_TAGTYPE_CUSTOM: Stdout("CUSTOM"); break;
            case ECTagTypes.EC_TAGTYPE_UINT8: Stdout("UINT8"); break;
            case ECTagTypes.EC_TAGTYPE_UINT16: Stdout("UINT16"); break;
            case ECTagTypes.EC_TAGTYPE_UINT32: Stdout("UINT32"); break;
            case ECTagTypes.EC_TAGTYPE_UINT64: Stdout("UINT64"); break;
            case ECTagTypes.EC_TAGTYPE_STRING: Stdout("STRING"); break;
            case ECTagTypes.EC_TAGTYPE_DOUBLE: Stdout("DOUBLE"); break;
            case ECTagTypes.EC_TAGTYPE_IPV4: Stdout("IPV4"); break;
            case ECTagTypes.EC_TAGTYPE_HASH16: Stdout("HASH16"); break;
            default: Stdout("???");
        }
        Stdout(" (")(tag_type)(")\n");
        
        Stdout(indent)("value: ");
        switch(tag_type)
        {
            case ECTagTypes.EC_TAGTYPE_UINT8: Stdout(get8); break;
            case ECTagTypes.EC_TAGTYPE_UINT16: Stdout(get16); break;
            case ECTagTypes.EC_TAGTYPE_UINT32: Stdout(get32); break;    
            case ECTagTypes.EC_TAGTYPE_UINT64: Stdout(get64); break;
            case ECTagTypes.EC_TAGTYPE_STRING: Stdout(getString); break;
            //TODO: implement double..
            case ECTagTypes.EC_TAGTYPE_IPV4:
                Stdout(Utils.toIpString(getIp))(":")(getPort); break;
            default:
                Stdout(Utils.toHexString(getRawValue));
        }
        Stdout("\n");
        Stdout(indent)("tags: ")(tags.length)("\n");
        foreach(tag; tags)
        {
            tag.print(indent);
            Stdout("\n");
        }
    }
}
