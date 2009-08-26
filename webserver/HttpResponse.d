module webserver.HttpResponse;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import webserver.HttpServer;

import tango.io.Stdout;
import tango.io.device.Array;
import tango.io.stream.Buffered;
import tango.io.stream.Format;
import tango.io.device.File;
import tango.net.device.Socket;
import tango.text.convert.Layout;
import tango.core.Thread;
import tango.core.Array;
static import Integer = tango.text.convert.Integer;

char[][ushort] descriptions;

final class HttpResponse
{
    enum Code
    {
        CONTINUE = 100,
        OK = 200,
        MULTIPLE_CHOICES = 300,
        MOVED_PERMANENTLY = 301,
        FOUND = 302,
        SEE_OTHER = 303,
        NOT_MODIFIED = 304,
        TEMPORARY_REDIRECT = 307,
        BAD_REQUEST = 400,
        UNAUTHORIZED = 401,
        FORBIDDEN = 403,
        NOT_FOUND = 404,
        CONFLICT = 409,
        NOT_IMPLEMENTED = 501
    }
    
    Code code = Code.OK;
    
    char[] content_type;
    char[][16] headers;
    uint header_count;
    
    //alternative source for the body data
    InputStream source; //no delegate because we need to call .close()
    ulong source_size;
    
    Array buffer;
    FormatOutput!(char) writer;
    
    Socket sc;

public:

    static this()
    {
        descriptions[100] = "Continue";
        descriptions[101] = "Switching Protocols";
        descriptions[200] = "OK";
        descriptions[201] = "Created";
        descriptions[202] = "Accepted";
        descriptions[203] = "Non-Authoritative Information";
        descriptions[204] = "No Content";
        descriptions[205] = "Reset Content";
        descriptions[206] = "Partial Content";
        descriptions[300] = "Multiple Choices";
        descriptions[301] = "Moved Permanently";
        descriptions[302] = "Found";
        descriptions[303] = "See Other";
        descriptions[304] = "Not Modified";
        descriptions[305] = "Use Proxy";
        descriptions[307] = "Temporary Redirect";
        descriptions[400] = "Bad Request";
        descriptions[401] = "Unauthorized";
        descriptions[402] = "Payment Required";
        descriptions[403] = "Forbidden";
        descriptions[404] = "Not Found";
        descriptions[405] = "Method Not Allowed";
        descriptions[406] = "Not Acceptable";
        descriptions[407] = "Proxy Authentification Required";
        descriptions[408] = "Request Time-Out";
        descriptions[409] = "Conflict";
        descriptions[410] = "Gone";
        descriptions[411] = "Length Required";
        descriptions[412] = "Precondition Failed";
        descriptions[413] = "Request Entity Too Large";
        descriptions[414] = "Request-URI Too Large";
        descriptions[415] = "Unsupported Media Type";
        descriptions[416] = "Requested range not satisfiable";
        descriptions[417] = "Expectation Failed";
        descriptions[500] = "Internal Server Error";
        descriptions[501] = "Not Implemented";
        descriptions[502] = "Bad Gateway";
        descriptions[503] = "Service unavailable";
        descriptions[504] = "Gateway Time-out";
        descriptions[505] = "HTTP Version not supported";
    }
    
    this()
    {
        buffer = new Array(1024, 1024);
        writer = new FormatOutput!(char)(new Layout!(char), buffer);
    }

public:

    public uint getRemoteIP()
    {
        return sc ? (cast(IPv4Address) sc.socket.remoteAddress).addr : 0;
    }

    package void init(Socket sc)
    {
        buffer.clear();
        this.sc = sc;
    }
    
    package void reset()
    {
        content_type = content_type.init;
        headers[0..header_count] = null;
        header_count = 0;
        buffer.clear();
        code = Code.OK;
        sc = null;
        if(source) source.close();
        source = null;
    }
    
    void setCode(Code code)
    {
        assert(code in descriptions);
        this.code = code;
    }

    void addHeader(char[] line)
    {
        if(header_count >= headers.length)
        {
            throw new Exception("Maximum header lines reached.");
        }
        headers[header_count++] = line;
    }
    
    void setContentType(char[] type)
    {
        content_type = type;
    }

    FormatOutput!(char) getWriter()
    {
        return writer;
    }
    
    void setBodySource(InputStream source, ulong source_size)
    {
        this.source = source;
        this.source_size = source_size;
    }
    
    void send()
    {
        auto sbuf = new BufferedOutput(sc);
    
        sbuf.append("HTTP/1.1 ");
        sbuf.append(Integer.toString(code));
        sbuf.append(" ");
        sbuf.append(descriptions[code]);
        sbuf.append("\r\n");
    
        sbuf.append("Server: ");
        sbuf.append(HttpServer.server_name);
        sbuf.append("\r\n");
        sbuf.append("Accept-Ranges: none\r\n"); //no range support implemented yet
        sbuf.append("Connection: close\r\n");
        
        foreach(line; headers[0..header_count])
        {
            sbuf.append(line);
            sbuf.append("\r\n");
        }
    
        if(code >= 400)
        {
            //prevent data to be send in error cases
            source = null;
            source_size = 0;
        }
        
        if(content_type.length)
        {
            sbuf.append("Content-Type: ");
            sbuf.append(content_type);
            sbuf.append("\r\n");
        }
        
        if(source is null)
        {
            sbuf.append("Content-Length: ");
            sbuf.append(Integer.toString(buffer.limit));
            sbuf.append("\r\n\r\n");
            
            debug(HttpResponse)
                Stdout("(D) HttpResponse: send header:\n")(cast(char[]) sbuf.slice).flush;
            
            uint h_pos = sbuf.limit;
            sbuf.append(buffer.slice);
            
            debug(HttpResponse)
            {
                char[] tmp = cast(char[]) sbuf.slice[h_pos..$];
                if(tmp.length > 70) tmp = tmp[0..70] ~ "[skipped]";
                Stdout("(D) HttpResponse: send body:\n")(tmp).newline;
            }
        }
        else //file download
        {
            sc.timeout = 5 * 1000; //give user time to accept the file download
            
            sbuf.append("Content-Length: ");
            sbuf.append(Integer.toString(source_size));
            sbuf.append("\r\n\r\n");
            
            debug(HttpResponse)
                Stdout("(D) HttpResponse: send header:\n")(cast(char[]) sbuf.slice).flush;
            
            sbuf.copy(source);
            
            debug(HttpResponse)
                Stdout("(D) HttpResponse: send body:\n<file>").newline;
        }
        
        sbuf.flush();
    }
}
