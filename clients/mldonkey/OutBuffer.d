module clients.mldonkey.OutBuffer;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import tango.net.device.Socket;
import tango.io.Stdout;
import Float = tango.text.convert.Float;

import Utils = utils.Utils;

/*
* Every outgoing message begin with a size tag (4byte) followed
* by op-code (2Byte) and payload (much more bytes ).
* 
* We store all data beginning at position 4
* so we can store the size header
*/

final class OutBuffer
{
    private ubyte[] buf;
    
    this()
    {
        reset();
    }
    
    void reset()
    {
        buf.length = 4;
    }
    
    private void put(T)(T val)
    {
        uint pos = buf.length;
        buf.length = pos + T.sizeof;
        *cast(T*) &buf.ptr[pos] = val;
    }
    
    alias put!(ubyte) write8;
    alias put!(ushort) write16;
    alias put!(uint) write32;
    alias put!(ulong) write64;
    
    void writeString(char[] data)
    {
        if(data.length < ushort.max)
        {
            put!(ushort)(data.length);
        }
        else
        {
            put!(ushort)(ushort.max);
            put!(uint)(data.length);
        }
        writeArray(data);
    }
    
    void writeArray(char[] data)
    {
        size_t pos = buf.length;
        buf.length = pos + data.length;
        for(size_t i = 0; i < data.length; i++)
        {
            buf[pos + i] = cast(ubyte) data[i];
        }
    }
    
    void send(Socket sc)
    {
        assert(sc);
        //insert content length as first four bytes
        *cast(uint*) &buf.ptr[0] = cast(uint) (buf.length - 4);
        sc.socket.send(buf);
    }
}
