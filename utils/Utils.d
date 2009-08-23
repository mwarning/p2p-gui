module utils.Utils;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import tango.io.Stdout;
import tango.io.digest.Md5;
import tango.io.device.Conduit;
import tango.time.Clock;
import tango.core.Exception;
import tango.core.Array;
import tango.core.Traits;
import tango.text.convert.Format;
static import Convert = tango.util.Convert;
static import Integer = tango.text.convert.Integer;

import api.Host;
import api.Client;
import api.User;
import api.User_;
import api.Search;
import api.Node_;
import api.File_;
import api.Search_;
import api.Meta_;
import api.Setting;
import api.Connection;


/*
* A collection for usefull functions that doesn't have a place elsewhere for now.
*/


/*
* Often used function to filter an array or assoc array
* and convert it to an newly allocated array;
* The return value should always satisfy (ret !is null).
*/
template filter(R)
{
    R[] filter(A, B)(A items, B state, uint age)
    {
        R[] ret;
        ret.length = items.length;
        size_t c;
        
        if(age)
        {
            uint now = (Clock.now - Time.epoch1970).seconds;
            if(state == B.ANYSTATE)
            {
                foreach(item; items)
                {
                    if((now - item.getLastChanged) < age)
                    {
                        ret[c] = item;
                        ++c;
                    }
                }
            }
            else
            {
                foreach(item; items)
                {
                    if((state == item.getState) && (now - item.getLastChanged) < age)
                    {
                        ret[c] = item;
                        ++c;
                    }
                }
            }
        }
        else if(state != B.ANYSTATE)
        {
            foreach(item; items)
            {
                if(state == item.getState)
                {
                    ret[c] = item;
                    ++c;
                }
            }
        }
        else
        {
            foreach(item; items)
            {
                ret[c] = item;
                ++c;
            }
        }
    
        if(c == 0)
        {
            delete ret;
            static const R[] empty = [];
            assert(empty !is null);
            return empty;
        }
        
        return ret[0..c];
    }
}

/*
* Convert a foreach-able value to an array of type R[] by implicit casts.
*/
template convert(R)
{
    R[] convert(A)(A items)
    {
        R[] ret;
        ret.length = items.length;
        size_t c;
        
        foreach(item; items)
        {
            ret[c] = item;
            ++c;
        }
        
        if(c == 0)
        {
            delete ret;
            static const R[] empty = [];
            assert(empty !is null);
            return empty;
        }
        
        return ret;
    }
}


/*
* Helper functions to build up an query structure.
*/
alias void delegate(Search_.BoolType, char[]) AddQuery;
alias void delegate(Search_.ValueType, char[]) AddKey;

/*
* Parse a query string and call given delegates for every value and subquery.
*
* Query = ( '(' + Pair + ')' | Pair )*
* Pair = Type? + Value
* Value = word | '"' + word +  '"'
* Type = "maxsize" | "media" | "title" ...
*/
void parseQuery(char[] query, AddKey add_value, AddQuery add_query)
{
    debug(Search)
        Stdout("(D) Utils.parseQuery: query: '")(query)("'").newline;
    
    uint findNext(char[] str, char c, uint start = 0)
    {
        for(uint i = start + 1; i < str.length; i++)
        {
            if(str[i] == c && !isEscaped(str, i))
            {
                return i;
            }
        }
        return str.length;
    }
    
    auto bool_type = Search_.BoolType.AND;
    auto value_type = Search_.ValueType.KEYWORD;
    
    bool parse_value;
    char[] value;
    for(ushort i; i < query.length; i++)
    {
        switch(query[i])
        {
            case ' ': case '\n': case '\t': break;
            case '+':
                bool_type = Search_.BoolType.AND;
                break;
            case '|':
                bool_type = Search_.BoolType.OR;
                break;
            case '-':
                bool_type = Search_.BoolType.NOT;
                break;
            case '"':
                uint pos = findNext(query, '"', i);
                if(pos == query.length) return;
                value = query[i+1..pos];
                
                add_value(value_type, value);
                
                value = null;
                parse_value = false;
                value_type = Search_.ValueType.KEYWORD;
                bool_type = Search_.BoolType.AND;
                i = pos;
                break;
            case '(':
                uint pos = findScopeEnd(query, '(', ')', i);
                add_query(bool_type, query[i+1..pos]);
                i = pos;
                break;
            default:
                uint pos = findNext(query, ' ', i);
                
                char[] tmp = query[i..pos];
                
                if(parse_value)
                {
                    debug(Search)
                        Stdout("(D) Search: Pair1: '")(value_type)("' : '")(tmp)("'").newline;
                    add_value(value_type, tmp);
                    
                    value = null;
                    parse_value = false;
                    value_type = Search_.ValueType.KEYWORD;
                    bool_type = Search_.BoolType.AND;
                }
                else
                {
                    auto type = toValueType(query[i..pos]);
                    
                    if(type == Search_.ValueType.KEYWORD)
                    {
                        debug(Search)
                            Stdout("(D) Search: Pair2: '")(value_type)("' : '")(tmp)("'").newline;
                        
                        add_value(value_type, tmp);
                    }
                    else
                    {
                        value_type = type;
                        parse_value = true;
                    }
                }
                i = pos;
                break;
        }
    }
}


/*
* Checks if a character in a string is escaped by '\'.
* str: string to look at
* pos: postion of the character in question
*/
int isEscaped(char[] str, uint pos)
{
    assert(pos < str.length);
    
    int i = 0; 
    while(pos > 0 && str[--pos] is '\\')
    {
           ++i;
    }
    return i & 1;
}

/*
* Find the end of a scope marked by open and close.
* Takes care of escaped open/close chars.
*/
uint findScopeEnd(char[] str, char open, char close, uint start = 0)
{
    //number of visited '{'
    uint opens = 0;
    
    //+1 because we don't want to 
    //find the '{' at the beginning
    uint next = start + 1; 
    
    while(true)
    {
        char c;
        //find first of
        while(next < str.length)
        {
            c = str[next];
            if(c == open || c == close) break;
            next++;
        }
        
        if(next == str.length) return next;
        
        if(!isEscaped(str, next))
        {
            if(c == close)
            {
                if(opens == 0) return next;
                --opens;
            }
            else
            {
                ++opens;
            }
        }
        ++next;
    }
}

private Search_.ValueType toValueType(char[] str)
{
    switch(str)
    {
        case "MAXSIZE": return Search_.ValueType.MAXSIZE;
        case "MINSIZE": return Search_.ValueType.MINSIZE;
        case "MEDIA": return Search_.ValueType.MEDIA;
        case "ARTIST": return Search_.ValueType.ARTIST;
        case "TITLE": return Search_.ValueType.TITLE;
        case "MAXRESULTS": return Search_.ValueType.MAXRESULTS;
        case "MINAVAIL": return Search_.ValueType.MINAVAIL;
        case "NETWORKID": return Search_.ValueType.NETWORKID;
        default: return Search_.ValueType.KEYWORD;
    }
}

void appendSlash(ref char[] path)
{
    if(path.length && path[$-1] != '/')
    {
        path ~= "/";
    }
}

bool begins(char[] str, char[] begin)
{
    if(begin.length > str.length) return false;
    return (str[0..begin.length] == begin);
}

bool ends(char[] str, char[] end)
{
    if(end.length > str.length) return false;
    return (str[$-end.length..$] == end);
}

bool is_prefix(char[] str, char[] prefix)
{
    if(prefix.length >= str.length) return false;
    return (str[0..prefix.length] == prefix);
}

bool is_suffix(char[] str, char[] suffix)
{
    if(suffix.length >= str.length) return false;
    return (str[$-suffix.length..$] == suffix);
}

bool is_in(T)(T[] array, T item)
{
    foreach(a; array)
    {
        if(a == item)
        {
            return true;
        }
    }
    return false;
}

bool is_in(T)(T[] src, T[] pattern)
{
    auto pos = find(src, pattern);
    return (pos < src.length);
}

void swapValues(T)(T[] items, size_t i, size_t j)
{
    T tmp = items[i];
    items[i] = items[j];
    items[j] = tmp;
}

T[] map(S, V, T)(S[V] input, T function(S) conv)
{
    T[] output;
    output.length = input.length;
    foreach(i, item; input)
    {
        output[i] = conv(item);
    }
    return output;
}

T[] map(S, T)(S[] input, T function(S) conv)
{
    return map(input, toDg(conv));
}

T[] map(S, T)(S[] input, T delegate(S) conv)
{
    T[] output;
    output.length = input.length;
    for(auto i = 0; i < input.length; ++i)
    {
        output[i] = conv(input[i]);
    }
    return output;
}

char[] rotX(char[] str, uint shift = 13)
{
    foreach(i, ref c; str)
    {
        if (c >= 'a' && c  <= 'z')
        {
            c = ((c - 'a' + shift) % 26) + 'a';
        }
        else if(c >= 'A' && c  <= 'Z')
        {
            c = ((c - 'A' + shift) % 26) + 'A';
        }
    }
    return str;
}



char[] l33t(char[] str)
{
    static char[][128] l33t_table= [
        'a' : "4",
        'c' : "<",
        'e' : "3",
        'g' : "9",
        'i' : "1",
        'o' : "0",
        's' : "5",
        't' : "7",
        'z' : "2",
        'A' : "/-\\",
        'K' : "|<",
        'H' : "|-|",
        'W' : "\\/\\/"
    ];
    
	char[] ret;
    ret.length = str.length;
    ret.length = 0;
    
	for(auto i = 0; i < str.length; ++i)
	{
        char c = str[i];
        if(c >= 128) //utf8 string
            continue;
        
        //convert ascii value
        char[] r = l33t_table[c];
		if(r.length)
            ret ~= r;
        else
            ret ~= c;
	}
	return ret;
}

/*
* apply the order of n2 to n1
*
* n1 = ['A', 'B', 'C', 'D', 'E' ]
* n2 = ['B', 'A', 'D', 'G']
* ->  ['B', 'A', 'D', 'C', 'E']
*/
T[] applyOrder(T)(T[] n1, T[] n2)
{
    T[] ret = intersect(n2, n1);
    ret ~= diff(n1, ret);
    return ret;
}

/*
* return every element in a that is not in b
*
* replacement for buggy tango.core.Array.missingFrom #747
*/
T[] diff(T)(T[] a, T[] b)
{
    T[] ret;
    foreach(i; a)
    {
        bool c = true;
        foreach(j; b)
        {
            if(i == j) { c = false; break; }
        }
        if(c) ret ~= i;
    }
    return ret;
}

/*
* returns all elements that are in a and b
*/
T[] intersect(T)(T[] a, T[] b)
{
    T[] ret;
    foreach(i; a)
    {
        foreach(j; b)
        {
            if(i == j) { ret ~= i; break; }
        }
    }
    return ret;
}

/*
* Wrapper for tango.util.Convert to
* fit in own types and enhancements.
*
* Strings can converted into enums
* by numerical and alphabetical strings.
*/
T fromString(T)(char[] str, T def = T.init)
{
    static if(is(T == char[]))
    {
        return str.dup;
    }
    else static if(!is(T == enum))
    {
        return Convert.to!(T)(str, def);
    }
    else
    {
        //if string is numerical
        if(str.length && str[0] >= '0' && str[0] <= '9')
        {
            auto x = Convert.to!(uint)(str, def);
            return (x <= T.max) ? cast(T) x : def;
        }
        
        static if(is(T == Node_.Type))
        {
            switch(str)
            {
                case "CLIENT": return Node_.Type.CLIENT;
                case "SERVER": return Node_.Type.SERVER;
                case "NETWORK": return Node_.Type.NETWORK;
                case "CORE": return Node_.Type.CORE;
                //hack to circumvent API limitation //also present in MainUser.d
                case "MLDONKEY": return cast(Node_.Type) (Node_.Type.max + 1);
                case "AMULE": return cast(Node_.Type) (Node_.Type.max + 2);
                case "GIFT": return cast(Node_.Type) (Node_.Type.max + 3);
                case "RTORRENT": return cast(Node_.Type) (Node_.Type.max + 4);
                default: return Node_.Type.UNKNOWN;
            }
        }
        else static if(is(T == Node_.State))
        {
            switch(str)
            {
                case "CONNECTED": return Node_.State.CONNECTED;
                case "DISCONNECTED": return Node_.State.DISCONNECTED;
                //case "INITIATING": return Node_.State.INITIATING;
                case "CONNECTING": return Node_.State.CONNECTING;
                case "BLOCKED": return Node_.State.BLOCKED;
                case "REMOVED": return Node_.State.REMOVED;
                default: return Node_.State.ANYSTATE;
            }
        }
        else static if(is(T == File_.Type))
        {
            switch(str)
            {
                case "DOWNLOAD": return File_.Type.DOWNLOAD;
                case "FILE": return File_.Type.FILE;
                case "DIRECTORY": return File_.Type.DIRECTORY;
                case "CHUNK": return File_.Type.CHUNK;
                case "SUBFILE": return File_.Type.SUBFILE;
                case "SOURCE": return File_.Type.SOURCE;
                //case "SEARCH": return File_.Type.SEARCH;    
                default: return File_.Type.UNKNOWN;
            }
        }
        else static if(is(T == File_.State))
        {
            switch(str)
            {
                case "ACTIVE": return File_.State.ACTIVE;
                case "PAUSED": return File_.State.PAUSED;
                case "STOPPED": return File_.State.STOPPED;
                case "SHARED": return File_.State.SHARED;
                case "COMPLETE": return File_.State.COMPLETE;
                case "PROCESS": return File_.State.PROCESS;
                case "CANCELED": return File_.State.CANCELED;
                default: return File_.State.ANYSTATE;
            }
        }
        else static if(is(T == Search_.MediaType))
        {
            switch(str)
            {
                case "PROGRAM": return Search_.MediaType.PROGRAM;
                case "DOCUMENT": return Search_.MediaType.DOCUMENT;
                case "IMAGE": return Search_.MediaType.IMAGE;
                case "AUDIO": return Search_.MediaType.AUDIO;
                case "VIDEO": return Search_.MediaType.VIDEO;
                case "ARCHIVE": return Search_.MediaType.ARCHIVE;
                case "COPY": return Search_.MediaType.COPY;
                default: return Search_.MediaType.UNKNOWN;
            }
        }
        else static if(is(T == Search_.State))
        {
            switch(str)
            {
                case "ACTIVE": return Search_.State.ACTIVE;
                case "STOPPED": return Search_.State.STOPPED;
                case "PAUSED": return Search_.State.PAUSED;
                case "REMOVED": return Search_.State.REMOVED;
                default: return Search_.State.ANYSTATE;
            }
        }
        else static if(is(T == Meta_.Type))
        {
            switch(str)
            {
                case "COMMENT": return Meta_.Type.COMMENT;
                case "LOG": return Meta_.Type.LOG;
                case "CHAT": return Meta_.Type.CHAT;
                case "CONSOLE": return Meta_.Type.CONSOLE;
                case "INFO": return Meta_.Type.INFO;
                case "STATUS": return Meta_.Type.STATUS;
                case "WARNING": return Meta_.Type.WARNING;
                case "ERROR": return Meta_.Type.ERROR;
                case "FATAL": return Meta_.Type.FATAL;
                case "DEBUG": return Meta_.Type.DEBUG;
                default: return Meta_.Type.UNKNOWN;
            }
        }
        else static if(is(T == Meta_.State))
        {
            switch(str)
            {
                default: return Meta_.State.ANYSTATE;
            }
        }
        else static if(is(T == User_.Type))
        {
            switch(str)
            {
                case "USER": return User_.Type.USER;
                case "ADMIN": return User_.Type.ADMIN;
                case "GROUP": return User_.Type.GROUP;
                default: return User_.Type.UNKNOWN;
            }
        }
        else static if(is(T == User_.State))
        {
            switch(str)
            {
                case "ENABLED": return User_.State.ENABLED;
                case "DISABLED": return User_.State.DISABLED;
                default: return User_.State.ANYSTATE;
            }
        }
        else static if(is(T == Setting.Type))
        {
            switch(str)
            {
                case "BOOL": return Setting.Type.BOOL;
                case "STRING": return Setting.Type.STRING;
                case "NUMBER": return Setting.Type.NUMBER;
                case "PASSWORD": return Setting.Type.PASSWORD;
                case "RADIO": return Setting.Type.RADIO;
                case "CHECK": return Setting.Type.CHECK;
                case "SELECT": return Setting.Type.SELECT;
                case "ORDER": return Setting.Type.ORDER;
                case "MULTIPLE": return Setting.Type.MULTIPLE;
                default: return Setting.Type.UNKNOWN;
            }
        }
        else static if(is(T == Connection.Priority))
        {
            alias Connection.Priority Priority;
            switch(str)
            {
                case "AUTO": return Priority.AUTO;
                case "NONE": return Priority.NONE;
                case "VERY_LOW": return Priority.VERY_LOW;
                case "LOW": return Priority.LOW;
                case "NORMAL": return Priority.NORMAL;
                case "HIGH": return Priority.HIGH;
                case "VERY_HIGH": return Priority.VERY_HIGH;
                default: return Priority.NONE;
            }
        }
        else static if(is(T == Client.Type))
        {
            foreach(ref client; Host.client_infos)
            {
                if(client.name == str)
                {
                    return client.type;
                }
            }
            return Client.Type.UNKNOWN;
        }
        else
        {
            return cast(T) Convert.to!(uint)(str);
        }
    }
}

char[] toString(T)(T value)
{
    static if(isIntegerType!(T))
    {
        return Integer.toString(value);
    }
    else static if(is(T == char[]))
    {
        return value;
    }
    else static if(is(T == bool))
    {
        return value ? "true" : "false";
    }
    else static if(is(typeof(value.getId)))
    {
        return Integer.toString(value.getId);
    }
    else static if(is(typeof(value.toHash)))
    {
        return Integer.toString(value.toHash);
    }
    else static if(is(typeof(value.getName)))
    {
        return value.getName;
    }
    else static if(isPointerType!(T))
    {
        return toString(*value);
    }
    else static if(is(T == Node_.State))
    {
        switch(value)
        {
            case Node_.State.CONNECTED: return "CONNECTED";
            case Node_.State.DISCONNECTED: return "DISCONNECTED";
            //case Node_.State.INITIATING: return "INITIATING";
            case Node_.State.BLOCKED: return "BLOCKED";
            case Node_.State.REMOVED: return "REMOVED";
            case Node_.State.CONNECTING: return "CONNECTING";
            case Node_.State.ANYSTATE: return "ANYSTATE";
        }
    }
    else static if(is(T == Node_.Type))
    {
        switch(value)
        {
            case Node_.Type.CLIENT: return "CLIENT";
            case Node_.Type.SERVER: return "SERVER";
            case Node_.Type.NETWORK: return "NETWORK";
            case Node_.Type.CORE: return "CORE";
            case Node_.Type.UNKNOWN: return "UNKNOWN";
        }
    }
    else static if(is(T == File_.Type))
    {
        switch(value)
        {
            case File_.Type.DOWNLOAD: return "DOWNLOAD";
            case File_.Type.FILE: return "FILE";
            case File_.Type.DIRECTORY: return "DIRECTORY";
            case File_.Type.CHUNK: return "CHUNK";
            case File_.Type.SUBFILE: return "SUBFILE";
            case File_.Type.SOURCE: return "SOURCE";
            //case File_.Type.SEARCH: return "SEARCH";
            case File_.Type.UNKNOWN: return "UNKNOWN";
        }
    }
    else static if(is(T == File_.State))
    {
        switch(value)
        {
            case File_.State.ACTIVE: return "ACTIVE";
            case File_.State.PAUSED: return "PAUSED";
            case File_.State.STOPPED: return "STOPPED";
            case File_.State.SHARED: return "SHARED";
            case File_.State.COMPLETE: return "COMPLETE";
            case File_.State.PROCESS: return "PROCESS";
            case File_.State.CANCELED: return "CANCELED";
            case File_.State.ANYSTATE: return "ANYSTATE";
        }
    }
    else static if(is(T == Search_.MediaType))
    {
        switch(value)
        {
            case Search_.MediaType.PROGRAM: return "PROGRAM";
            case Search_.MediaType.DOCUMENT: return "DOCUMENT";
            case Search_.MediaType.IMAGE: return "IMAGE";
            case Search_.MediaType.AUDIO: return "AUDIO";
            case Search_.MediaType.VIDEO: return "VIDEO";
            case Search_.MediaType.ARCHIVE: return "ARCHIVE";
            case Search_.MediaType.COPY: return "COPY";
            case Search_.MediaType.UNKNOWN: return "UNKNOWN";
        }
    }
    else static if(is(T == Search_.State))
    {
        switch(value)
        {
            case Search_.State.ACTIVE: return "ACTIVE";
            case Search_.State.STOPPED: return "STOPPED";
            case Search_.State.PAUSED: return "PAUSED";
            case Search_.State.REMOVED: return "REMOVED";
            case Search_.State.ANYSTATE: return "ANYSTATE";
        }
    }
    else static if(is(T == Meta_.Type))
    {
        switch(value)
        {
            case Meta_.Type.UNKNOWN: return "UNKNOWN";
            case Meta_.Type.COMMENT: return "COMMENT";
            case Meta_.Type.LOG: return "LOG";
            case Meta_.Type.CHAT: return "CHAT";
            case Meta_.Type.CONSOLE: return "CONSOLE";
            case Meta_.Type.INFO: return "INFO";
            case Meta_.Type.STATUS: return "STATUS";
            case Meta_.Type.WARNING: return "WARNING";
            case Meta_.Type.ERROR: return "ERROR";
            case Meta_.Type.FATAL: return "FATAL";
            case Meta_.Type.DEBUG: return "DEBUG";
        }
    }
    else static if(is(T == Meta_.State))
    {
        switch(value)
        {
            case Meta_.State.ANYSTATE: return "ANYSTATE";
        }
    }
    else static if(is(T == User_.Type))
    {
        switch(value)
        {
            case User_.Type.USER: return "USER";
            case User_.Type.ADMIN: return "ADMIN";
            case User_.Type.GROUP: return "GROUP";
            case User_.Type.UNKNOWN: return "UNKNOWN";
        }
    }
    else static if(is(T == User_.State))
    {
        switch(value)
        {
            case User_.State.ENABLED: return "ENABLED";
            case User_.State.DISABLED: return "DISABLED";
            case User_.State.ANYSTATE: return "ANYSTATE";
        }
    }
    else static if(is(T == Setting.Type))
    {
        switch(value)
        {
            case Setting.Type.BOOL: return "BOOL";
            case Setting.Type.STRING: return "STRING";
            case Setting.Type.NUMBER: return "NUMBER";
            case Setting.Type.RADIO: return "RADIO";
            case Setting.Type.CHECK: return "CHECK";
            case Setting.Type.SELECT: return "SELECT";
            case Setting.Type.ORDER: return "ORDER";
            case Setting.Type.MULTIPLE: return "MULTIPLE";
            case Setting.Type.PASSWORD: return "PASSWORD";
            case Setting.Type.UNKNOWN: return "UNKNOWN";
        }
    }
    else static if(is(T == Search_.ValueType))
    {
        switch(value)
        {
            case Search_.ValueType.KEYWORD: return "KEYWORD";
            case Search_.ValueType.MAXSIZE: return "MAXSIZE";
            case Search_.ValueType.MINSIZE: return "MINSIZE";
            case Search_.ValueType.MEDIA: return "MEDIA";
            case Search_.ValueType.ARTIST: return "ARTIST";
            case Search_.ValueType.TITLE: return "TITLE";
            case Search_.ValueType.MAXRESULTS: return "MAXRESULTS";
            case Search_.ValueType.MINAVAIL: return "MINAVAIL";
            case Search_.ValueType.NETWORKID: return "NETWORKID";
        }
    }
    else static if(is(T == Priority))
    {
        switch(value)
        {
            case Priority.AUTO: return "AUTO";
            case Priority.NONE: return "NONE";
            case Priority.VERY_LOW: return "VERY_LOW";
            case Priority.LOW: return "LOW";
            case Priority.NORMAL: return "NORMAL";
            case Priority.HIGH: return "HIGH";
            case Priority.VERY_HIGH: return "VERY_HIGH";
        }
    }
    else static if(is(T == Client.Type))
    {
        foreach(ref client; Host.client_infos)
        {
            if(client.type == value)
            {
                return client.name;
            }
        }
        return "Unknown";
    }
    else static if(is(T == enum))
    {
        return Integer.toString(value);
    }
    else
    {
        static assert(false, "(E) Utils.toString: Unsupported Type " ~ T.stringof ~ "!");
    }
}


private static Md5 md5;

//hex digest
char[] md5_hex(char[] input)
{
    if(md5 is null)
        md5 = new Md5();
    
    synchronized(md5)
    {
        md5.update(cast(ubyte[]) input);
        return md5.hexDigest();
    }
}

//binary digest
ubyte[] md5_bin(char[] input)
{
    if(md5 is null)
        md5 = new Md5();
    
    synchronized(md5)
    {
        md5.update(input);
        return md5.binaryDigest();
    }
}


//TODO: replace by tango swapBytes when it get usability improvements
version (LittleEndian)
{
    ubyte swapBytes(ubyte val)
    {
        return val;
    }

    ushort swapBytes(ushort val)
    {
        return (
            ((val & 0x00ffU) << 8)  | ((val & 0xff00U) >> 8)
        );
    }

    uint swapBytes(uint val)
    {
        return (
            ((val & 0x000000ffU) << 24) |
            ((val & 0x0000ff00U) <<  8) |
            ((val & 0x00ff0000U) >>  8) |
            ((val & 0xff000000U) >> 24)
        );
    }

    ulong swapBytes(ulong val)
    {
        return (
            ((val &  0x00000000000000ffUL) << 56) |
            ((val &  0x000000000000ff00UL) << 40) |
            ((val &  0x0000000000ff0000UL) << 24) |
            ((val &  0x00000000ff000000UL) <<  8) |
            ((val &  0x000000ff00000000UL) >>  8) |
            ((val &  0x0000ff0000000000UL) >> 24) |
            ((val &  0x00ff000000000000UL) >> 40) |
            ((val &  0xff00000000000000UL) >> 56)
        );
    }
}
version (BigEndian)
{
    ubyte swapBytes(ubyte val)
    {
        return val;
    }

    ushort swapBytes(ushort val)
    {
        return val;
    }

    uint swapBytes(uint val)
    {
        return val;
    }

    ulong swapBytes(ulong val)
    {
        return val;
    }
}

/*
* convert IP uint in host byte order to string
*/
char[] toIpString(uint ip)
{
    ubyte[4] nums = void;
    *cast(uint*) &nums[0] = ip;
    
    version(LittleEndian)
    {
        return Format("{}.{}.{}.{}", nums[3], nums[2], nums[1], nums[0]);
    }
    
    version(BigEndian)
    {
        return Format("{}.{}.{}.{}", nums[0], nums[1], nums[2], nums[3]);
    }
}

/*
* Convert IP to host byte order.
* "127.0.0.1" -> 2130706433 (0x7f000001)
* Returns 0.0.0.0 if IP cannot be translated.
*/
uint toIpNum(char[] str)
{
    static uint invalid_ip = 0;
    uint ip;
    uint pos;
    
    static ubyte parse (char[] s)
        {       
                int n;
                for(auto i = 0; i < s.length; ++i)
        {
            n = n * 10 + (s[i] - '0');
        }
                return cast(ubyte) n;
        }
    
    pos = find(str, '.');
    if(pos == str.length) return 0;
    (cast(ubyte*) &ip)[3] = parse(str[0..pos]);
    str = str[++pos..$];
    
    pos = find(str, '.');
    if(pos == str.length) return 0;
    (cast(ubyte*) &ip)[2] = parse(str[0..pos]);
    str = str[++pos..$];
    
    pos = find(str, '.');
    if(pos == str.length) return 0;
    (cast(ubyte*) &ip)[1] = parse(str[0..pos]);
    str = str[++pos..$];
    
    (cast(ubyte*) &ip)[0] = parse(str);
    
    return ip;
}

T split(T = char[][], bool KeepEmpty = false)(char[] str, char delimiter = ',')
{
    alias typeof(T.init[0]) S;
    
    S[] values;
    uint pos, start = 0;
    
    if(str.length == 0)
        return values;
    
    while(true)
    {
        pos = start + str[start..$].find(delimiter);
        static if(KeepEmpty)
        {
            if((pos - start) >= 0)
            {
                values ~= fromString!(S)(str[start..pos]);
            }
        }
        else
        {
            if((pos - start) != 0)
            {
                values ~= fromString!(S)(str[start..pos]);
            }
        }
        if(pos == str.length) break;
        start = pos + 1;
    }
    
    return values;    
}

/*
* Transfer data from one source to a destination.
* src must be non-blocking!
*/
size_t transfer(size_t delegate(void[]) src, size_t delegate(void[]) dst)
{
    byte[8 * 1024] tmp;
    size_t read = 0;
    size_t all = 0;
    
    while(true)
    {
        read = src(tmp[0..tmp.length]);
        
        if(read == 0)
        {
            return all ? all : 0;
        }
        
        if(read > tmp.length)
        {
            return read;
        }
        
        auto wrote = dst(tmp[0..read]);
        assert(wrote == read);
        
        all += read;
        
        if(read < tmp.length)
        {
            return all;
        }
    }
}

/*
* Read from a Conduit up to max bytes until a pattern is found
* but without reading behind the pattern.
*
* It returns chars read from the conduit.
*/
char[] readUntil(Conduit source, char[] pattern, uint max)
{
    char[] buffer = new char[max];
    uint pos;
    uint x;
    
    loop: while(true)
    {
        //max chars we can read without
        //reading behind a possible pattern
        max = pos + pattern.length - x; 
        
        if(max > buffer.length) break; //buffer exhausted
        
        uint read = source.read(buffer[pos..max]);
        
        if(read == 0) break; //conduit exhausted
        
        //check new chars
        for(uint i = pos; i < pos + read; i++)
        {
            if(buffer[i] == pattern[x])
            {
                x++;
                if(x == pattern.length) //pattern found
                {
                    pos += read;
                    break loop;
                }
            }
            else
            {
                x = 0;
            }
        }
        pos += read;
    }
    
    return buffer[0..pos];
}

/*
* A very simple set.
*/
struct Set(T)
{
    private T[] items = null;
    
    void opCatAssign(T item)
    {
        add(item);
    }
    
    void opCatAssign(T[] items)
    {
        add(items);
    }
    
    void opCatAssign(Set!(T) set)
    {
        add(set);
    }
    
    void add(T item)
    {
        if(!contains(item))
        {
            items.length = items.length + 1;
            items[$-1] = item;
        }
    }
    
    void add(T[] items)
    {
        foreach(item; items)
        {
            add(item);
        }
    }
    
    void add(Set!(T) set)
    {
        add(set.slice);
    }
    
    bool contains(T c_item)
    {
        foreach(item; items)
        {
            if(c_item == item)
            {
                return true;
            }
        }
        return false;
    }
    
    void remove(T old_item)
    {
        foreach(i, item; items)
        {
            if(old_item == item)
            {
                items = items[0..i] ~ items[i+1..$];
                break;
            }
        }
    }
    
    /*
    void replace(T old_item, T new_item)
    {
        foreach(i, item; items)
        {
            if(old_item == item)
            {
                items[i] = new_item;
            }
        }
    }*/
    
    size_t length()
    {
        return items.length;
    }
    
    void clear()
    {
        items.length = 0;
    }
    
    T[] slice()
    {
        return items;
    }
}

/*
* Wrap a function pointer to get a delegate.
*/
R delegate(T) toDg(R, T...)(R function(T) fp)
{
    struct dg
    {
        R opCall(T t)
        {
            return (cast(R function(T)) this) (t);
        }
    }
    
    R delegate(T) t;
    t.ptr = fp;
    t.funcptr = &dg.opCall;
    return t;
}

/*
* Create a getter delegate for a pointer.
* Can be dropped for D2 (full closures)
*/
R delegate() toDgGetter(R)(R* ptr)
{
    struct Wrapper
    {
        R* ptr;
        R get()
        {
            return *ptr;
        }
    };
    auto x = new Wrapper;
    x.ptr = ptr;
    return &x.get;
}

/*
* Convert an arbitrary value or array to a hex string.
*/
char[] toHexString(T)(T value, char[] dst = null)
{
    static const char hex_chars[16]  = "0123456789abcdef";
    
    static if(isDynamicArrayType!(T) || isStaticArrayType!(T))
    {
        void[] array = cast(void[]) value;
        
        if(dst is null)
        {
            dst.length = 2 * array.length;
        }
        else
        {
            assert(dst.length >= (2 * array.length), "toHexString: Buffer is too small!");
        }
        
        ubyte a = void;
        auto j = array.length;
        for(auto i = 0; i < array.length; ++i)
        {
            --j;
            a = (cast(byte*) array.ptr)[i];
            dst[j * 2] = hex_chars[a >> 4];
            dst[j * 2 + 1] = hex_chars[a & 0xF];
        }
        
        return dst[0..2 * array.length];
    }
    else
    {
        if(dst is null)
        {
            dst.length = 2 * T.sizeof;
        }
        else
        {
            assert(dst.length < 2 * T.sizeof, "toHexString: Buffer is too small");
        }
        
        ubyte a = void;
        auto j = T.sizeof;
        for(auto i = 0; i < T.sizeof; ++i)
        {
            --j;
            a = (cast(byte*) &value)[i];
            dst[j * 2] = hex_chars[a >> 4];
            dst[j * 2 + 1] = hex_chars[a & 0xF];
        }
        
        return dst[0..2 * T.sizeof];
    }
}
