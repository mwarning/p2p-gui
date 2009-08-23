module clients.mldonkey.InBuffer;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import tango.io.Stdout;
import tango.net.device.Socket;
import tango.io.model.IConduit;
import tango.core.ByteSwap;
import tango.io.device.Array;
import Convert = tango.util.Convert;

import Utils = utils.Utils;
import Debug = utils.Debug;


final class InBuffer
{
private:

    Array buffer;
    void[] packet; //a slice into buffer
    uint pos; //read position

public:

    this()
    {
        buffer = new Array(1024, 2 * 1024);
    }
    
    size_t receive(Socket sc)
    {
        return Utils.transfer(&sc.read, &buffer.write);
    }
    
    //on disconnect
    void reset()
    {
        pos = 0;
        packet = null;
        buffer.clear();
    }
    
    bool nextPacket()
    {
        if(packet.length)
        {
            buffer.seek(packet.length, IOStream.Anchor.Current);
            packet = null;
        }
        
        auto slice = buffer.slice();
        
        //message header incomplete
        if(slice.length < 4)
        {
            return false;
        }
        
        auto size = *cast(uint*) &slice[0];
        size += 4;
        
        if(size > 16 * 1024 * 1024) // > 16 MB
        {
            throw new Exception("InBuffer: Message size is too big.");
        }
        
        //message body is complete
        if(slice.length >= size)
        {
            pos = 4;
            packet = slice[0..size];
            return true;
        }
        else
        {
            return false;
        }
    }

    private T read(T)()
    {
        if(pos + T.sizeof > packet.length)
        {
            throw new Exception("InBuffer: Read out of bounds for type " ~ T.stringof ~ ".");
        }
        T tmp = *cast(T*) &packet.ptr[pos];
        pos += T.sizeof;
        return tmp;
    }

    ubyte read8() { return read!(ubyte); }
    ushort read16() { return read!(ushort); }
    uint read32() { return read!(uint ); }
    ulong read64() { return read!(ulong); }

    char[] readString()
    {
        uint len = read!(ushort);
        if(len == ushort.max)
        {
            len = read!(uint);
        }
        
        if(pos + len > packet.length)
        {
            throw new Exception("InBuffer: Read out of bounds for string.");
        }
        char[] str = cast(char[]) packet[pos..pos+len].dup;
        pos += len;
        return str;
    }
    
    float readFloat()
    {
        char[] float_str = readString();
        return Convert.to!(float)(float_str, 0);
    }
    
    char[] readIpAddress()
    {
        //value comes in as BigEndian (dispite all other values)
        uint ip = read!(uint);
        version(LittleEndian)
        {
            ByteSwap.swap32(&ip, 4);
        }
        char[] str = Utils.toIpString(ip);
        return str;
    }
    
    char[][] readStrings()
    {
        ushort len = read!(ushort);
        char[][] vec = new char[][len];
    
        for (int i = 0; i < len; i++)
        {
            vec[i] = readString();
        }
        return vec;
    }

    ushort[] read16s()
    {
        ushort len = read!(ushort);
        ushort[] vec = new ushort[len];
        
        for (int i = 0; i < len; i++)
        {
            vec[i] = read!(ushort);
        }
        return vec;
    }

    uint[] read32s()
    {
        ushort len = read!(ushort);
        uint[] vec = new uint[len];
        
        for (int i = 0; i < len; i++)
        {
            vec[i] = read!(uint);
        }
        return vec;
    }

    /*
    * read a 16 byte long binary hash,
    * and convert it into a human readable form
    */
    char[] readHash()
    {
        if(pos + 16 > packet.length)
        {
            throw new Exception("InBuffer: Not enough bytes in packet to get hash value.");
        }
        void[16] tmp = packet[pos..pos+16];
        pos += 16;
        return Utils.toHexString(tmp.reverse);
    }
    
    /*
    * Get a hex dump in case something went wrong.
    */
    void hexDump()
    {
        Debug.hexDump(packet, pos);
    }
}
