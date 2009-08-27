module webguis.plex.HtmlUtils;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/

import tango.io.Stdout;
import tango.io.stream.Format;
import tango.text.Util;
import tango.text.Ascii;
import tango.text.convert.Format;
static import Float = tango.text.convert.Float;
static import Convert = tango.util.Convert;

import api.Connection;
import api.Node;
import api.File;

import webcore.Dictionary;


//some helpfull constants
const char[] N = "\n";
const char[] BN = "<br />\n";
const char[] BBN = "<br /><br />\n";

const char[] AMP = "&amp;";

const char[] SP = "&nbsp;";
const char[] SP2 = "&nbsp;&nbsp;";
const char[] SP4 = "&nbsp;&nbsp;&nbsp;&nbsp;";

/*
* Output wrapper to hide basic formatting
*/
struct HtmlOut
{
    FormatOutput!(char) o;
    char[] delegate(Phrase) translate;
    
    HtmlOut format(T...)(char[] fmt, T params)
    {
        o.format(fmt, params);
        return *this;
    }
    
    HtmlOut opCall(T)(T data)
    {
        assert(o && translate);
        
        static if(is(T == Phrase))
        {
            o(translate(data));
        }
        else static if(is(T == Priority))
        {
            o(translate( formatPriority(data) ));
        }
        else
        {
            o(data);
        }
        return *this;
    }
}

/*
* Insert JavaScript selectors for tables
*/
void insertJsSelectors(HtmlOut o)
{
    //<a ...> wouldn't allow access to "this"
    o("<span onclick=\"allBoxes(this, 1);\">")(Phrase.All)("</span> | ");
    o("<span onclick=\"allBoxes(this, 0);\">")(Phrase.None__empty)("</span> | ");
    o("<span onclick=\"invertBoxes(this);\">")(Phrase.Invert)("</span> | ");
    o("<span onclick=\"rangeBoxes(this);\">")(Phrase.Range)("</span>\n");
}

/*
* Crop file name but preserve last 4 chars (extension).
*/
char[] cropFileName(char[] name, uint len)
{
    if(name.length <= len) { return name; }
    if(len <= 5) { len = 6; }
    return (name[0..len-4] ~ "*" ~ name[$-4..$]);
}

//precision is 2
void formatSize(FormatOutput!(char) o, ulong bytes)
{
    o(formatSize(bytes));
}

char[] formatSize(ulong bytes)
{
    auto o = &Format.convert;
    if (bytes < 1024)
    {
        return o("{}  B", bytes);
    }
    else if (bytes < 1024 * 1024)
    {
        return o("{0:0.1} KB", bytes / 1024.0);
    }
    else if (bytes < 1024 * 1024 * 1024)
    {
        return o("{0:0.1} MB", bytes / (1024.0 * 1024.0));
    }
    else if (bytes < 1024uL * 1024uL * 1024uL * 1024uL)
    {
        return o("{0:0.1} GB", bytes / (1024.0 * 1024.0 * 1024.0));
    }
    
    return o("{0:0.1} TB", bytes / (1024.0 * 1024.0 * 1024.0 * 1024.0));
}

void formatTime(FormatOutput!(char) o, uint seconds)
{
    o(formatTime(seconds));
}

char[] formatTime(uint seconds)
{
    auto convert = &Format.convert;
    
    if(seconds == 0 || seconds == typeof(seconds).max)
    {
        return "-";
    }
    
    if(seconds < 60)
    {
        return convert("{}s", seconds);
    }
    
    if(seconds < 60 * 60)
    {
        return convert("{:f1}m", seconds / (60.0));
    }
    
    if(seconds < 60 * 60 * 24)
    {
        return convert("{:f1}h", seconds / (60.0 * 60.0));
    }
    
    if(seconds < 60 * 60 * 24 * 356)
    {
        return convert("{:f1}d", seconds / (60.0 * 60.0 * 24.0));
    }
    
    if(seconds < 60 * 60 * 24 * 356 * 100)
    {
        return convert("{:f1}y", seconds / (60.0 * 60.0 * 24.0 * 356.0));
    }
    
    return "-";
}

void formatSpeed(FormatOutput!(char) o, uint bytes)
{
    o(formatSpeed(bytes));
}

char[] formatSpeed(uint bytes)
{
    auto o = &Format.convert;

    if (bytes == 0)
    {
        return o("-");
    }
    else if (bytes < 1024*1024)
    {
        return o("{0:0.1} KB/s", bytes/1024.0);
    } 
    else if (bytes < 1024*1024*1024)
    {
        return o("{0:0.1} MB/s", bytes/1024.0/1024.0);
    }
    return o("{0:0.1} GB/s", bytes/1024.0/1024.0/1024.0);
}

alias Connection.Priority Priority;

Phrase formatPriority(Priority priority)
{
    switch(priority)
    {
        case Priority.NONE: return Phrase.None__priority;
        case Priority.AUTO: return Phrase.Auto;
        case Priority.VERY_LOW: return Phrase.Very_Low;
        case Priority.LOW: return Phrase.Low;
        case Priority.NORMAL: return Phrase.Normal;
        case Priority.HIGH: return Phrase.High;
        case Priority.VERY_HIGH: return Phrase.Very_High;
    }
}

Phrase formatNodeState(Node_.State state)
{
    switch(state)
    {
        case Node_.State.CONNECTED: return Phrase.Connected;
        case Node_.State.CONNECTING: return Phrase.Connecting;
        case Node_.State.DISCONNECTED: return Phrase.Disconnected;
        case Node_.State.BLOCKED: return Phrase.Blocked;
        case Node_.State.REMOVED:
        case Node_.State.ANYSTATE: return Phrase.Nil;
    }
}


Phrase formatFileState(File_.State state)
{
    switch(state)
    {
        case File_.State.ACTIVE: return Phrase.Active;
        case File_.State.PAUSED: return Phrase.Paused;
        case File_.State.STOPPED: return Phrase.Stopped;
        case File_.State.COMPLETE: return Phrase.Complete;
        case File_.State.PROCESS: return Phrase.Process;
    }
}

/*
* Parse a size string with suffix and convert to bytes.
* 10.2 mb => 10.2*1024*1024
*/
ulong parseSize(char[] str, ulong def = 0)
{
    uint ate;
    float number = Float.parse(str, &ate);
    char[] suffix = trim(str[ate..$]);
    
    //no suffix found
    if(suffix.length == 0)
    {
        return (cast(ulong) number * 1024) * 1024; //assume MB
    }
    
    suffix = toLower(suffix);
    
    switch(suffix)
    {
        case "b":
        case "kb":
        case "kib": return cast(ulong) number * 1024;
        case "m":
        case "mb":
        case "mib": return (cast(ulong) number * 1024) * 1024;
        case "g":
        case "gb":
        case "gib": return (cast(ulong) number * 1024) * 1024 * 1024;
        default:
            //throw new Exception("HtmlUtils: Unknown size suffix '" ~ suffix ~ "'!");
            return def;
    }
}

/*
* Get a balanced distribution of elements over multiple rows.
*/
T[][] getPartition(T)(T[] elems, uint rows)
{
    uint count = elems.length;
    if(rows > count) rows = count;
    if(rows == 0) rows = 1;
    
    uint[] distrib = new uint[rows];
    uint i;
    while(count--)
    {
        distrib[i%rows]++;
        i++;
    }
    
    //apply partition to elements:
    T[][] ret;
    i = 0;
    foreach(c; distrib)
    {
        ret ~= elems[i..i+c].dup;
        i += c;
    }
    
    return ret;
}
