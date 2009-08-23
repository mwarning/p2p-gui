module utils.Debug;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import tango.io.Console;
import tango.text.convert.Format;
static import Integer = tango.text.convert.Integer;

/**
* Print a hex dump:
*
* Length: 27 bytes
* 0       54 68 69 73 20 69 73 20  61 20 73 61 6d 70 6c 65   |This.is. a.sample|
* 16     20 73 74 72 69 6e 67 20  31 32 33                               |.string. 123         |
*
* mark_pos: marker '|' appears before position in hex field
*/
public void hexDump(void[] data_, uint mark_pos = 0)
{
    static const char hex_chars[16]  = "0123456789abcdef";
    
    ubyte[] data = cast(ubyte[]) data_;
    char[64] buf = void;
    
    alias Cout o;
    
    o("Hex Dump:\n");
    o("Length: ")(Integer.format(buf, data.length))(" bytes");
    if(mark_pos)
    {
        o("; Mark Position: ");
        if(mark_pos < data.length)
        {
            o(Integer.format(buf, mark_pos));
            o(", Line ");
            o(Integer.format(buf, mark_pos / 16 + 1));
        }
        else
        {
            o(Integer.format(buf, mark_pos));
            o(" [out of range]");
        }
    } 
    else
    {
        mark_pos = data.length;
    }
    o("\n");
    
    char[2] hex;
    
    //convert byte to hex
    void putHex(ubyte x)
    {
        hex[0] = hex_chars[x >> 4];
        hex[1] = hex_chars[x & 0xF];
        o(hex);
    }
    
    void putChar(char c)
    {
        o((c > 32 && c < 127) ? [c] : ".");
    }
    
    //insert padding
    void putPad(uint i)
    {
        static char[16] pads = ' ';
        while(i)
        {
            size_t min = i > pads.length ? pads.length : i;
            o(pads[0..min]);
            i -= min;
        }
    }
    
    //print all full lines
    uint pos = 0;
    for(auto line = 0; line < data.length/16; line++)
    {
        //print current position
        o(Integer.format(buf, pos));
        o("\t");
        
        for (auto i = 0; i < 8; i++, pos++)
        {
            o((mark_pos == pos) ? "|" : " ");
            putHex(data[pos]);
        }
        o(" ");
        for (auto i = 0; i < 8; i++, pos++)
        {
            o((mark_pos == pos) ? "|" : " ");
            putHex(data[pos]);
        }
        
        o("  |");
        pos -= 16;
        
        for (auto i = 0; i < 8; i++, pos++)
        {
            putChar(data[pos]);
        }
        o(" ");
        for (auto i = 0; i < 8; i++, pos++)
        {
            putChar(data[pos]);
        }
        o("|\n");
        o.flush();
    }
    
    uint lpos = data.length - pos;
    if(lpos == 0) return;

    o(Integer.format(buf, pos));
    o("\t");
    
    if(lpos <= 8) //print lines with 8 or less hex values
    {
        for (auto i = 0; i < lpos; i++, pos++)
        {
            o((mark_pos == pos) ? "|" : " ");
            putHex(data[pos]);
        }
        
        //padding for hex field
        putPad(3 * 16 - 3 * lpos);
        
        o("  |");
        pos -= lpos;
        
        for (auto i = 0; i < lpos; i++, pos++)
        {
            putChar(data[pos]);
        }
        o(" ");
        
        //padding for text field
        putPad(16 - lpos);
        
        o("|\n");
    }
    else //print lines with less then 16 hex values
    {
        for (auto i = 0; i < 8; i++, pos++)
        {
            o((mark_pos == pos) ? "|" : " ");
            putHex(data[pos]);
        }
        o(" ");
        for (auto i = 0; i < lpos - 8; i++, pos++)
        {
            o((mark_pos == pos) ? "|" : " ");
            putHex(data[pos]);
        }
        
        //padding for hex field
        putPad(3 * 16 - 3 * lpos);
        
        o("  |");
        pos -= lpos;
        
        for (auto i = 0; i < 8; i++, pos++)
        {
            putChar(data[pos]);
        }
        o(" ");
        for (auto i = 0; i < lpos - 8; i++, pos++)
        {
            putChar(data[pos]);
        }
        
        //padding for text field
        putPad(16 - lpos);
        
        o("|\n");
    }
    o.flush();
}

/*
* Shows a position in a text.
* Prints out a section of the text with a position marker.
* Also add column and line position.
*
* TODO: proper unicode support (calculate padding)
*/
char[] getErrorMessage(char[] text, uint pos)
{
    char* beg = &text[0];
    char* ptr = beg + pos;
    char* end = beg + text.length;
    
    if(pos >= text.length)
    {
        return "<out of bounds>";
    }
    
    assert(beg <= end);
    assert(beg <= ptr);
    assert(end >= ptr);
    
    //size_t pos = ptr - beg;
    size_t col = 0;
    size_t row = 0;
    
    auto p = beg;
    char* row_beg = beg;
    while(p < ptr)
    {
        if(*p is '\n')
        {
            ++row;
            row_beg = p+1;
        }
        ++p;
    }
    col = ptr - row_beg;
    
    char* row_end = row_beg;
    while(row_end < end)
    {
        if(*row_end is '\n')
        {
            break;
        }
        ++row_end;
    }
    
    char[] indent = new char[](col);
    indent[] = ' ';
    
    char[] line = row_beg[0..row_end-row_beg].dup;
    
    //replace all tabs from the line
    //to get the marker to the right position
    for(auto i = 0; i < line.length; ++i)
    {
        if(line[i] == '\t')
            line[i] = ' ';
    }
    
    return Format("({}, {}):\n{}\n{}^", row + 1, col + 1, line, indent);
}
