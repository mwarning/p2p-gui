module webserver.HttpRequest;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import tango.core.Thread;
import tango.core.Array;
import tango.core.Exception;
import tango.core.Traits;
import tango.net.device.Socket;
import tango.io.FilePath;
import tango.io.stream.Format;
import tango.io.Stdout;
import tango.io.device.File;
import tango.io.device.TempFile;
import tango.io.model.IConduit;
import tango.text.Util;
import tango.time.Time;
import tango.time.StopWatch;
static import Convert = tango.util.Convert;

static import Utils = utils.Utils;

enum HttpMethod
{
    GET,
    POST,
    HEAD,
    PUT,
    DELETE,
    OPTIONS,
    TRACE,
    UNKNOWN
}

private extern (C) void memmove (void* dst, void* src, size_t bytes);

/*
* Handles a HTTP request.
* Supports "multipart/form-data".
*/
final class HttpRequest
{
private:

    /*
    * concatenate values  with identical variable names values by ','
    * e.g. "http://foo?x=1&x=23&x=7"
    * true => x ="1,23,7"
    * false => x = "7"
    */
    const bool concat = true;
    
    HttpMethod method = HttpMethod.UNKNOWN;

    char[] uri;
    
    char[][char[]] params; //parameter given in uri
    char[][char[]] headers; //header parameters
    
    char[] body_data;
    char[][] files; //uploaded files

    Socket sc;
    char[8*1024] buffer;
    
    //directory to temporary save downloaded files
    package static char[] temp_directory;

    static this()
    {
        temp_directory = TempFile.tempPath(); //"/tmp/" on posix...
    }
    
    ~this()
    {
        reset();
    }
    
    public uint getRemoteIP()
    {
        if(sc)
        {
            return (cast(IPv4Address) sc.socket.remoteAddress).addr;
        }
        return 0;
    }
    
    private void addQueryParam(char[] name_, char[] value_)
    {
        //decode and dup
        char[] name = url_decode(name_).dup;
        char[] value = url_decode(value_).dup;
        
        if(!concat)
        {
            params[name] = value;
        }
        else
        {
            auto value_ptr = (name in params);
            if(value_ptr)
            {
                (*value_ptr) ~= ',' ~ value;
            }
            else
            {
                params[name] = value;
            }
        }
    }
    
    /**
    * Parses URI for finding query parameters. 
    * Names and value are url encoded (%xy).
    * 
    * @param query - the query string
    */
    private void parseQuery(char[] query)
    {
        char[] name;
        char[] value;
        
        uint end;
        uint pos;
        
        while((end = find(query, '&')) != query.length)
        {
            char[] pair = query[0..end];
            pos = find(pair, '=');
            if(pos != pair.length)
            {
                name = pair[0..pos];
                value = pair[pos+1..$];
                if(name.length) addQueryParam(name, value);
            }
            query = query[end+1..$];
        }
        
        pos = find(query, '=');
        if(pos != query.length)
        {
            name = query[0..pos];
            value = query[pos+1..$];
            if(name.length) addQueryParam(name, value);
        }
    }  

    private void parseHeader(char[] data)
    {
        uint start = 0;
        uint pos;
        
        //method
        pos = find(data, ' ');
        
        if(pos == data.length)
        {
            Stdout("(E) HttpRequest: The received request isn't HTTP compliant. (1)");
            return;
        }
        
        switch(data[0..pos])
        {
            case "GET":
                method = HttpMethod.GET;
                break;
            case "POST":
                method = HttpMethod.POST;
                break;
            case "HEAD":
                method = HttpMethod.HEAD;
                break;
            case "PUT":
                method = HttpMethod.PUT;
                break;
            case "DELETE":
                method = HttpMethod.DELETE;
                break;
            case "OPTIONS":
                method = HttpMethod.OPTIONS;
                break;
            case "TRACE":
                method = HttpMethod.TRACE;
                break;
            default:
                method = HttpMethod.UNKNOWN;
        }
        
        //URI
        start = pos + 1;
        pos = locate(data, ' ', start);
        if(pos == data.length)
        {
            method = HttpMethod.UNKNOWN;
            Stdout("(E) HttpRequest: The received request isn't HTTP compliant. (2)");
            return;
        }
        char[] raw_uri = data[start..pos];
        auto uri_pos = find(raw_uri, '?');
        uri = url_decode(raw_uri[0..uri_pos]);
        
        //retrieve parameters
        if(uri_pos != raw_uri.length)
        {
            parseQuery(raw_uri[uri_pos+1..$]);
        }
        
        //HTTP version
        start = pos + 1;
        pos = locate(data, '\r', start); //actually the line ends with CR+LF
        if(pos == data.length)
        {
            method = HttpMethod.UNKNOWN;
            Stdout("(E) HttpRequest: The received request isn't HTTP compliant. (3)");
            return;
        }
        
        //get headers
        foreach(line ; split(data[pos..$], "\r\n"))
        {
            uint delim = find(line, ": ");
            if(delim == line.length) continue;
            headers[line[0..delim].dup] = line[delim + 2..$].dup;
        }
    }

public:

    HttpMethod getHttpMethod()
    {
        return method;
    }
    
    char[] getMethod()
    {
        switch(method)
        {
            case HttpMethod.GET: return "GET";
            case HttpMethod.POST: return "POST";
            case HttpMethod.HEAD: return "HEAD";
            case HttpMethod.PUT: return "PUT";
            case HttpMethod.DELETE: return "DELETE";
            case HttpMethod.OPTIONS: return "OPTIONS";
            case HttpMethod.TRACE: return "TRACE";
            case HttpMethod.UNKNOWN: return "UNKNOWN";
        }
    }

    /*
    * Returns the uri without any parameters if exist.
    */ 
    char[] getUri()
    {
        return uri;
    }
    
    char[] getBody()
    {
        return body_data; 
    }

    bool isParameter(char[] name)
    {
        return (name in params) ? true : false;
    }
    
    char[] getParameter()(char[] name)
    {
        char[]* value = (name in params);
        return value ? *value : null;
    }
    
    T getParameter(T = char[])(char[] name, T def = T.init)
    {
        char[]* value = (name in params);
        
        static if(!is(T == char[]) && isDynamicArrayType!(T))
        {
            return value ? Utils.split!(T)(*value, ',') : def;
        }
        else
        {
            return value ? Utils.fromString!(T)(*value, def) : def;
        }
    }
    
    //all parameters after link?foo=1&bar=abc
    char[][char[]] getAllParameters()
    {
        return params;
    }
    
    //all key/value pairs in the http header
    char[][char[]] getAllHeaders()
    {
        return headers;
    }

    char[] getHeader()(char[] name)
    {
        char[]* value = (name in headers);
        return value ? *value : null;
    }
    
    T getHeader(T = char[])(char[] name, T def = T.init)
    {
        char[]* value = (name in headers);
        return value ? Utils.fromString!(T)(*value, def) : def;
    }
    
    char[] getContentType()
    {
        return getHeader("Content-Type");
    }
    
    /*
    * split header values
    * e.g. foo="12"; bar=xyz; luu=1
    */
    private static char[][char[]] splitHeaderPairs(char[] pairs)
    {
        char[][char[]] values;
        uint pos;
        uint value_begin, value_end, name_begin, name_end = void;
        while(true)
        {
            pos = locate(pairs, '=', pos);
            if(pos == pairs.length) break;
            
            if(pairs[pos + 1] == '"')
            {
                value_begin = pos + 2;
                value_end = locate(pairs, '"', value_begin);
            }
            else
            {
                value_begin = pos + 1;
                value_end = findIf(pairs[value_begin..$], (char c) { return c == ' ' || c == '"'; });
                value_end += pos;
            }
            
            name_end = pos;
            name_begin = locatePrior (pairs, ' ', name_end) + 1;
            
            if(name_begin > name_end) name_begin = 0;
            
            char[] name = pairs[name_begin..name_end];
            char[] value = pairs[value_begin..value_end];
            
            values[name.dup] = value.dup;
            
            pos = value_end + 1;
        }
        return values;
    }
    
    char[][] getFiles()
    {
        return files;
    }
    
    package void init(Socket sc)
    {
        this.sc = sc;
    }
    
    package void reset()
    {
        method = HttpMethod.UNKNOWN;
        uri = null;
        params = null;
        headers = null;
        body_data = null;
        sc = null;
        
        //remove uploaded files
        foreach(file; files)
        {
            try
            {
                auto path = new FilePath(file);
                if(path.exists)
                {
                    debug(HttpRequest)
                        Stdout("(D) HttpRequest: Remove temporary file: '")(file)("'.").newline;
                    
                    path.remove;
                }
            }
            catch(Object o)
            {
                Stdout("(E) HttpRequest: Exception: ")(o.toString).newline;
            }
        }
        files = files.init;
    }
    
    void receive()
    {
        alias void delegate() Caller;
        size_t begin, end;
        size_t header_size;
        ulong body_size;
        Caller call;
        char[] window;
        char[] boundary;
        File file;
        
        void skip(uint amount)
        {
            if(amount > window.length)
            {
                amount = window.length;
            }
            begin += amount;
            window = buffer[begin..end];
        }
        
//################################
    
    /*
    * Parse a multipart form data body. 
    * Format example:
    * "<http-header>\r\n\r\n--<boundary>\r\n<header>\r\n\r\n<data>\r\n--<boundary>\r\n<header>\r\n\r\n<data>\r\n--<boundary>--\r\n"
    */
    void readMultiPart()
    {
        void parse(char[] line, inout char[] name, inout char[] filename)
        {
            uint name_start = find(line, "name=\"");
            if(name_start == line.length) return;
            name_start += 6;
            uint name_end = locate(line, '"', name_start);
            if(name_end == line.length) return;
            name = line[name_start..name_end];
            
            line = line[name_end..$];
            
            uint filename_start = find(line, "filename=\"");
            if(filename_start == line.length) return;
            filename_start += 10;
            uint filename_end= locate(line, '"', filename_start);
            if(filename_end == line.length) return;
            filename = line[filename_start..filename_end];
        }

        uint pos;
        while((pos = kfind(window, boundary)) != window.length)
        {
            //write rest to file
            if(file)
            {
                debug(HttpRequest)
                    Stdout("(D) HttpRequest: Close file, write ")(pos).newline;
                
                file.write(window[0..pos]);
                skip(pos);
                file.close();
                file = null;
                pos = 0;
            }
            
            uint header_beg = pos + boundary.length + 1; //end of boundary
            
            if(header_beg + 4 <= window.length && window[header_beg..header_beg+4] == "--\r\n")
            {
                call = null;
                return;
            }
            
            uint header_end = header_beg + locatePattern(window[header_beg..$], "\r\n\r\n");
            
            //ensure complete multi-part section header
            if(header_end == window.length)
            {
                return;
            }
            
            uint data_begin = header_end + 4;
            uint data_end = header_beg + kfind(window[header_beg..$], boundary);
            
            char[] name, filename;
            parse(window[header_beg..header_end], name, filename);
            
            if(filename.length)
            {
                debug(HttpRequest)
                    Stdout("(D) HttpRequest: Create file: '")(temp_directory ~ filename)("', write ")(data_end - data_begin).newline;
                
                //begin to write data to file
                try
                {
                    char[] path = temp_directory ~ filename;
                    file = new File(path, File.WriteCreate);
                    this.files ~= path;
                    file.write(window[data_begin..data_end]);
                }
                catch(Object o)
                {
                    Stdout("(E) HttpRequest: ")(o.toString).newline;
                    file.close();
                    file = null;
                }
            }
            else if(name.length)
            {
                //ensure complete multi-part section data
                if(data_end == window.length)
                {
                    return;
                }
                
                auto value = window[data_begin..data_end];
    
                debug(HttpRequest)
                    Stdout("(D) HttpRequest:  Add parameter: '")(name)("' = '")(value)("'").newline;
                
                addQueryParam(name, value);
            }
            else
            {
                Stdout("(E) HttpRequest: Empty value name!").newline;
                call = null;
                return;
            }
            
            if(window[data_end-4..data_end] == "--\r\n")
            {
                call = null;
                return;
            }
            
            skip(data_end);
        }
        
        //write all to file
        if(file && window.length)
        {
            file.write(window);
            skip(window.length);
        }
    }

    void readBody()
    {
        debug(HttpRequest)
        {
            Stdout("(D) HttpRequest: readBody").newline;
            Stdout("(D) HttpRequest: header_size '")(header_size)("', body_size '")(body_size)("'").newline;
        }
        
        char[] content_type = getHeader("Content-Type");
        if(containsPattern(content_type, "multipart/form-data"))
        {
            auto pairs = splitHeaderPairs(content_type);
            if(auto tmp = ("boundary" in pairs))
            {
                boundary = "\r\n--" ~ *tmp; //use modified boundary

                call = &readMultiPart;
                debug(HttpRequest)
                    Stdout("(D) HttpRequest: readMultiPart").newline;
                
                call();
            }
            else
            {
                Stdout("(E) HttpRequest: Boundary for multipart/form-data not found!").newline;
                call = null;
            }
        }
        else if(window.length > 2)
        {
            body_data = window[2..$].dup;
            parseQuery(window[2..$]);
            call = null;
        }
    }
    
    void readHeader()
    {
        debug(HttpRequest)
            Stdout("(D) HttpRequest: readHeader").newline;
        
        header_size = find(window, "\r\n\r\n");
        
        //header incomplete => get more data
        if(header_size == window.length)
        {
            debug(HttpRequest)
                Stdout("(D) HttpRequest: Header incomplete => read more data.").newline;
            
            return;
        }
        
        parseHeader(window[0..header_size+2]);
        
        body_size = getHeader!(ulong)("Content-Length");
        
        skip(header_size + 2); //we leave one "\r\n" pair for readMultiPart to work with
        
        if(body_size || method == HttpMethod.POST)
        {
            call = &readBody;
            call();
        }
        else
        {
            debug(HttpRequest)
                Stdout("(D) HttpRequest: receive_body:\n<nothing>").newline;
            
            call = null;
        }
    }
    
//################################
        
        call = &readHeader;
    
        while(true)
        {
            auto read = sc.read(buffer[end .. $]);
            
            if(read == IConduit.Eof)
            {
                break;
            }
            
            end += read;
            window = buffer[begin..end];
            
            call();
            
            //abort/end parsing
            if(call is null)
                break;
            
            //still place at the end of buffer
            if(end < buffer.length)
                continue;
            
            if(begin > 0)
            {
                //move memory to begin
                if(window.length)
                {
                    memmove(buffer.ptr, buffer.ptr + begin, end - begin);
                    end = end - begin;
                    begin = 0;
                }
                else
                {
                    end = 0;
                    begin = 0;
                }
            }
            else
            {
                Stdout("(E) HttpRequest: Buffer too small to hold content!").newline;
                break;
            }
        }
        
        //will only be called for misformed data
        if(file)
        {
            file.close();
            file = null;
        }
    }

    /*
    * decode percent-encoded strings
    * according to RFC 3986
    */
    private char[] url_decode(char[] str)
    {
        char[] ret;
        ret.length = str.length;
        ret.length = 0;
        
        static uint toNum(char c)
        {
            if (c >= '0' && c <= '9')
            {
                c -= '0';
            }
            else if (c >= 'a' && c <= 'f')
            {
                c -= ('a' - 10);
            }
            else if (c >= 'A' && c <= 'F')
            {
                c -= ('A' - 10);
            }
            return c;
        }
        
        uint next()
        {
            foreach(i, c; str)
            {
                if(c == '%') return i;
            }
            return str.length;
        };
        
        if(str.length == 0) return ret;
        
        uint pos = next();
        
        if(pos == str.length)
        {
            ret = str.dup;
            
            //replace '+' with ' '
            foreach(i, c; ret)
            {
                if(c == '+') ret[i] = ' ';
            }
            
            return ret;
        }
        
        ret = str[0..pos].dup;
        
        foreach(i, c; ret)
        {
            if(c == '+') ret[i] = ' ';
        }
        
        for(; pos < str.length; pos++)
        {
            char c = str[pos];
            
            if(c == '+')
            {
                c = ' ';
            }
            else if(c == '%' && (pos + 2) < str.length)
            {
                c = 16 * toNum(str[pos+1]) + toNum(str[pos+2]);
                pos += 2;
            }
            
            ret ~= c;
        }
        
        return ret;
    }
}
