module clients.rtorrent.XmlInput;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

static import Convert = tango.util.Convert;
import tango.core.Array;
import tango.io.Stdout;

/*
* Get the string between the first occurence of start_pattern and end_pattern.
*/
char[] getValue(char[] data, char[] start_pattern, char[] end_pattern = "<")
{
    assert(start_pattern.length > 0);
    
    auto begin = find(data, start_pattern);
    if(begin == data.length) return null;
    begin += start_pattern.length;
    
    auto end = begin + find(data[begin..$], end_pattern);
    if(end == data.length) return null;
    return data[begin..end];
}

char[] getValueCopy(char[] data, char[] start_pattern, char[] end_pattern = "<")
{
    char[] str = getValue(data, start_pattern, end_pattern);
    return str.dup;
}

/*
* Get all substrings between start_pattern and end_pattern
*/
char[][] getValues(char[] data, char[] start_pattern, char[] end_pattern = "<")
{
    assert(start_pattern.length > 0);
    
    char[][] values;
    size_t begin, end;
    while(true)
    {
        begin = find(data, start_pattern);
        if(begin == data.length) break;
        
        begin += start_pattern.length;
        
        end = begin + find(data[begin..$], end_pattern);
        if(end == data.length) break;
        values ~= data[begin..end];
        
        data = data[end..$];
    }
    return values;
}

final class XmlInput
{
    char[] xml_str;
    char[][] numbers;
    char[][] strings;
    
    this(char[] res)
    {
        xml_str = res;
        numbers = getValues(res, "<i4>");
        if(numbers.length == 0) //workaround for older versions
        {
            numbers = getValues(res, "<i8>");
        }
        strings = getValues(res, "<string>", "</string>");
    }
    
    uint getUInt()
    {
        if(numbers.length == 0)
        {
            throw new Exception("(E) XmlInput.getUInt: No more numbers to read.");
        }
        
        char[] tmp = numbers[0];
        numbers = numbers[1..$];
        return Convert.to!(uint)(tmp, 0);
    }
    
    ulong getULong()
    {
        if(numbers.length == 0)
        {
            throw new Exception("(E) XmlInput.getULong: No more numbers to read.");
        }
        
        char[] tmp = numbers[0];
        numbers = numbers[1..$];
        return Convert.to!(ulong)(tmp, 0);
    }
    
    bool getBoolean()
    {
        if(numbers.length == 0)
        {
            throw new Exception("(E) XmlInput.getBoolean: No more numbers to read.");
        }
        
        char[] tmp = numbers[0];
        numbers = numbers[1..$];
        return (tmp == "1");
    }
    
    char[] getString()
    {
        if(strings.length == 0)
        {
            throw new Exception("(E) XmlInput.getString: No more strings to read.");
        }
        
        char[] tmp = strings[0];
        strings = strings[1..$];
        return tmp.dup;
    }
    
    char[] peekStringSlice()
    {
        if(strings.length)
        {
            return strings[0];
        }
        else
        {
            return null;
        }
    }
    
    char[] peekNumberSlice()
    {
        if(numbers.length)
        {
            return numbers[0];
        }
        else
        {
            return null;
        }
    }
    
    bool allConsumed()
    {
        return (numbers.length + strings.length) == 0;
    }
    
    char[] toString()
    {
        return xml_str;
    }
}
