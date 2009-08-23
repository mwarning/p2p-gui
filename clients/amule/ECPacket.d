module clients.amule.ECPacket;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/

import clients.amule.ECCodes;
import clients.amule.ECTag;
import clients.amule.Utf8_Numbers;
import Utils = utils.Utils : swapBytes, toHexString;

import tango.io.Stdout;

/**
* High level EC packet handler class
* for the application layer data
*/

final class ECPacket
{
    ECTag[] tags;
    ECOpCodes op_code;
    
    bool utf8_numbers;
    
public:
    
    this(ECOpCodes op_code)
    {
        this.op_code = op_code;
    }
    
    this()
    {
        this.op_code = ECOpCodes.EC_OP_NOOP;
    }
    
    uint write(inout ubyte[] packet)
    {
        uint size;
        
        foreach(tag; tags)
        {
            size += tag.getSize();
        }
        
        packet.length = 8 + 3 + size; //protocol header + packet header + tags length
        
        //protocol header
        *cast(uint*)&packet[0] = Utils.swapBytes(cast(uint) 0x20); //flag
        *cast(uint*)&packet[4] = Utils.swapBytes(size + 3);
        
        //packet header
        packet[8] = cast(ubyte) op_code; //OPCODE
        *cast(ushort*)&packet[9] = Utils.swapBytes(cast(ushort) tags.length); //TAGCOUNT
        
        uint write = 11;
        
        foreach(tag; tags)
        {
            write += tag.write(packet[write..$]);
        }
        
        return write;
    }
    
    uint read(ubyte[] packet, bool utf8_numbers)
    {
        this.utf8_numbers = utf8_numbers;
        if(utf8_numbers)
        {
            return readUTF8(packet);
        }
        else
        {
            return readPlain(packet);
        }
    }
    
    private uint readPlain(ubyte[] packet)
    {
        debug(ECPacket)
            Stdout("(D) ECPacket: readPlain").newline;
        
        op_code = cast(ECOpCodes) packet.ptr[0];
        ushort tag_count = *cast(ushort*) &packet.ptr[1];
        uint pos = 3;
        tag_count = Utils.swapBytes(tag_count);
        
        debug(ECPacket)
            Stdout("(D) ECPacket: tag_count ")(tag_count).newline;
        
        while(tag_count--)
        {
            ECTag tag = new ECTag();
            pos += tag.read(packet[pos..$]);
            tags ~= tag;
        }
        return pos;
    }
    
    private uint readUTF8(ubyte[] packet)
    {
        debug(ECPacket)
            Stdout("(D) ECPacket: readUTF8").newline;
        
        utf8_numbers = true;
        op_code = cast(ECOpCodes) packet[0]; //it's utf8?
        ushort tag_count = packet[1]; //it's utf8? //no need to swap a byte
        
        uint pos = 2;
        
        while(tag_count--)
        {
            ECTag tag = new ECTag();
            pos += tag.readUTF8(packet[pos..$]);
            tags ~= tag;
        }
        
        return pos;
    }
    
    ECOpCodes getOpCode()
    {
        return op_code;
    }

    ECTag[] getTags()
    {
        return tags;
    }
    
    ECTag getTagByName(ECTagNames code)
    {
        foreach(tag; tags)
        {
            if(tag.getCode == code)
            {
                return tag;
            }
        }
        return null;
    }
    
    void addTag(T)(ECTagNames code, T val)
    {
        tags ~= new ECTag(code, val);
    }
    
    void addTag(dummy1 = void, dummy2 = void)(ECTag tag)
    {
        tags ~= tag;
    }
    
    /*
    * Prints packet structure to console.
    * For debugging, developing
    */
    void print()
    {
        Stdout("op_code: ")(Utils.toHexString(op_code))("\n");
        Stdout("utf8: ")(utf8_numbers)("\n");
        Stdout("tags: ")(tags.length)("\n\n");
        foreach(tag; tags)
        {
            tag.print("");
            Stdout("\n");
        }
        Stdout.flush;
    }
}
