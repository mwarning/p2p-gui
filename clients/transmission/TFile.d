module clients.transmission.TFile;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/


import tango.text.Util : jhash;
import tango.io.Stdout;
import tango.core.Array;

import utils.json.JsonBuilder;
import api.File;


class TFile : NullFile
{
    uint id;
    int priority; //-1, 0, 1
    char[] name;
    char[] full_name; //includes path
    ulong length;
    ulong bytes_completed;
    bool wanted = true;
    
    alias JsonBuilder!().JsonValue JsonValue;
    alias JsonBuilder!().JsonString JsonString;
    alias JsonBuilder!().JsonNumber JsonNumber;
    alias JsonBuilder!().JsonNull JsonNull;
    alias JsonBuilder!().JsonBool JsonBool;
    alias JsonBuilder!().JsonArray JsonArray;
    alias JsonBuilder!().JsonObject JsonObject;
    
    this(JsonObject obj)
    {
        update(obj);
    }
    
    uint getId()
    {
        return id;
    }
    
    char[] getName()
    {
        return name;
    }
    
    ulong getSize()
    {
        return length;
    }
    
    ulong getUploaded()
    {
        return 0;
    }
    
    ulong getDownloaded()
    {
        return bytes_completed;
    }
    
    Priority getPriority()
    {
        switch(priority)
        {
            case -1: return Priority.LOW;
            case 0: return Priority.NORMAL;
            case 1: return Priority.HIGH;
        }
    }
    
    File_.State getState()
    {
        return File_.State.ACTIVE;
    }
    
    File_.Type getType()
    {
        return File_.Type.SUBFILE;
    }
    
    void update(JsonObject obj)
    {
        foreach(char[] key, JsonValue value; obj)
        {
            switch(key)
            {
            case "bytesCompleted":
                bytes_completed = value.toInteger();
                break;
            case "name":
                if(name.length == 0)
                {
                    //can be preceded by a path
                    full_name = value.toString();
                    auto pos = rfind(full_name, '/');
                    if(pos < full_name.length)
                    {
                        name = full_name[pos+1..$];
                    }
                    else
                    {
                        name = full_name;
                    }
                    if(id == 0) id = jhash(name);
                }
                break;
            case "length":
                if(length == 0)
                {
                    length = value.toInteger();
                }
                break;
            case "priority":
                priority = value.toInteger();
                break;
            case "wanted":
                wanted = value.toBool();
                break;
            default:
            }
        }
    }
}
