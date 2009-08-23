module clients.rtorrent.XmlOutput;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

static import Integer = tango.text.convert.Integer;
import tango.core.Array;
import tango.io.Stdout;

/*
* Helper class to build up XML RPC requests
* with a cgi dummy header
*/

final class XmlOutput
{
    char[] body_;
    
    this(char[] method)
    {
        body_ ~=
        "<?xml version=\"1.0\"?>\n"
        "<methodCall>\n"
        "<methodName>"
        ~ method ~
        "</methodName>\n"
        "<params>\n";
    }
    
    this(char[] method, char[] string_arg)
    {
        this(method);
        addArg(string_arg);
    }
    
    char[] toString()
    {
        char[] body_end = "</params>\n</methodCall>";
        
        char[] head = "CONTENT_LENGTH\000" ~ Integer.toString(body_.length + body_end.length) ~ "\000";
        return Integer.toString(head.length) ~ ":" ~ head ~ "," ~ body_ ~ body_end;
    }
    
    private void addParam(char[] param)
    {
        body_ ~= "<param>\n<value>" ~ param ~ "</value>\n</param>\n";
    }
    
    XmlOutput addArg(int i)
    {
        addParam("<i4>" ~ Integer.toString(i) ~ "</i4>");
        return this;
    }
    
    XmlOutput addArg(long i)
    {
        addParam("<i8>" ~ Integer.toString(i) ~ "</i8>");
        return this;
    }
    
    XmlOutput addArg(char[] str)
    {
        addParam("<string>" ~ str ~ "</string>");
        return this;
    }
    
    XmlOutput addArg(ubyte[] data)
    {
        //add base64 encode
        //addParam("<base64>" ~ data ~ "</base64>");
        return this;
    }
    
    XmlOutput addArgs(char[][] strs)
    {
        foreach(str; strs)
        {
            addArg(str);
        }
        return this;
    }
    
    XmlOutput addArg(bool b)
    {
        addParam("<boolean>" ~ (b ? "1" : "0") ~ "</boolean>");
        return this;
    }
}

class Multicall
{
    char[] body_ = "<?xml version=\"1.0\"?>\n"
        "<methodCall>\n"
        "<methodName>system.multicall</methodName>\n"
        "<params>\n"
        "<param>"
        "<value>"
        "<array>"
        "<data>";
    
    char[] toString()
    {
        char[] body_end = 
            "</data>"
            "</array>"
            "</value>"
            "</param>"
            "</params>\n"
            "</methodCall>";
        
        char[] head = "CONTENT_LENGTH\000" ~ Integer.toString(body_.length + body_end.length) ~ "\000";
        return Integer.toString(head.length) ~ ":" ~ head ~ "," ~ body_ ~ body_end;
    }
    
    Multicall addMethod(char[] method_name, char[][] params = null)
    {
        body_ ~=
        "<value>"
        "<struct>"
        "<member>"
        "<name>methodName</name>"
        "<value>"
        "<string>" ~ method_name ~ "</string>"
        "</value>"
        "</member>"
        "<member>"
        "<name>params</name>"
        "<value>"
        "<array>"
        "<data>";
        
        foreach(param; params)
        {
            body_ ~= "<value><string>" ~ param ~ "</string></value>\n";
        }
        
        body_ ~=
        "</data>"
        "</array>"
        "</value>"
        "</member>"
        "</struct>"
        "</value>";
        
        return this;
    }
}
