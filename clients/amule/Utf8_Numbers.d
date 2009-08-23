module clients.amule.Utf8_Numbers;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/

import tango.io.Stdout;

//read utf8 encoded numbers
/*
ushort readUtf8Val(ubyte[] data, uint* ate)
{
    ushort val;
    (*ate) = readUtf8Val(val, data);
    return val;
}*/

uint readUtf8Val(inout ushort val, ubyte[] data)
{
    static char[] error_msg = "(E) readUtf8Val: Reading behind array.";
    
    if(data.length < 1) throw new Exception(error_msg);
    ubyte tmp = data[0];
    
    // 0xxxxxxx
    if(tmp < 128)
    {
        val = tmp;
        return 1;
    }
    // 110xxxxx 10xxxxxx
    else if(tmp > 191 && tmp < 224)
    {
        if(data.length < 2) throw new Exception(error_msg);
        
        val = ((tmp & 0x1F) << 6) |
            (data[1] & 0x3F);
        return 2;
    }
    // 1110xxxx 10xxxxxx 10xxxxxx
    else if(tmp > 223 && tmp < 240)
    {
        if(data.length < 3) throw new Exception(error_msg);
        
        val = ((tmp & 0x0F) << 12) |
            ((data[1] & 0x3F) << 6) |
            (data[2] & 0x3F);
        return 3;
    }
    else
    {
        throw new Exception("(E) readUtf8Val: Value is not an UTF-8 encoded 2 Byte value.");
    }
}

uint readUtf8Val(inout uint val, ubyte[] data)
{
    static char[] error_msg = "(E) readUtf8Val: Reading behind array.";
    
    if(data.length < 1) throw new Exception(error_msg);
    ubyte tmp = data[0];

    // 0xxxxxxx
    if(tmp < 128)
    {
        val = tmp;
        return 1;
    }
    // 110xxxxx 10xxxxxx
    else if(tmp > 191 && tmp < 224)
    {
        if(data.length < 2) throw new Exception(error_msg);
        
        val = ((tmp& 0x1F) << 6) |
            (data[1] & 0x3F);
        return 2;
    }
    // 1110xxxx 10xxxxxx 10xxxxxx
    else if(tmp > 223 && tmp < 240)
    {
        if(data.length < 3) throw new Exception(error_msg);
        
        val = ((tmp& 0x0F) << 12) |
            ((data[1] & 0x3F) << 6) |
            (data[2] & 0x3F);
        return 3;
    }
    // 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
    else if(tmp > 239 && tmp < 248)
    {
        if(data.length < 4) throw new Exception(error_msg);
        
        val = ((tmp& 0x0F) << 18) |
            ((data[1] & 0x3F) << 12) |
            ((data[2] & 0x3F) << 6) |
            (data[3] & 0x3F);
        return 4;
    }
    // 111110xx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
    else if(tmp > 247 && tmp < 252)
    {
        if(data.length < 5) throw new Exception(error_msg);
        
        val = ((tmp& 0x0F) << 24) |
            ((data[1] & 0x3F) << 18) |
            ((data[2] & 0x3F) << 12) |
            ((data[3] & 0x3F) << 6) |
            (data[4] & 0x3F);
        return 5;
    }
    // 1111110x 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
    else if(tmp > 251 && tmp < 254)
    {
        if(data.length < 6) throw new Exception(error_msg);
        
        val = ((tmp& 0x0F) << 30) |
            ((data[1] & 0x3F) << 24) |
            ((data[2] & 0x3F) << 18) |
            ((data[3] & 0x3F) << 12) |
            ((data[4] & 0x3F) << 6) |
            (data[5] & 0x3F);
        return 6;
    }
    else
    {
        throw new Exception("(E) readUtf8Val: Value is not an UTF-8 encoded 4 Byte value.");
    }
}
