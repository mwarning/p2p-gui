module clients.mldonkey.model.MLTags;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import tango.io.Stdout;
static import Integer = tango.text.convert.Integer;

import api.Node_;
import api.File_;

import clients.mldonkey.InBuffer;

import webcore.Logger;

struct MLTags
{
private:

    struct Tag
    {
        char[] name;
        char[] value;
    }
    
    Tag[] tags;
    
public:
    
    void parse(InBuffer msg)
    {
        ushort len = msg.read16();
        
        char[] name, value;
        for (auto i = 0; i < len; i++)
        {
            name = msg.readString();
            ubyte type = msg.read8();
            
            switch (type)
            {
                case 0:
                    uint x = msg.read32();
                    value = Integer.toString(x);
                    break;
                case 1:
                    uint x = msg.read32(); //signed value...hmm
                    value = Integer.toString(x);
                    break;
                case 2:
                    value =  msg.readString();
                    break;
                case 3: //IP Adress
                    value = msg.readIpAddress();
                    break;
                case 4:
                    ushort x = msg.read16();
                    value = Integer.toString(x);
                    break;
                case 5:
                    ushort x = msg.read8();
                    value = Integer.toString(x);
                    break;
                case 6:
                    uint x = msg.read32();
                    uint y = msg.read32();
                    value = Integer.toString(x) ~ "/" ~ Integer.toString(y);
                    break;
                default:
                    Logger.addWarning("MLTags: Invalid type received!");
                    continue;
            }
            
            if(value)
                add(name, value);
        }
    }
    
    void clear()
    {
        tags = tags.init;
    }
    
    //if we want to put interesting information
    //in here from somewhere else
    void add(char[] name, char[] value)
    {
        foreach(tag; tags)
        {
            if(tag.name == name)
            {
                if(tag.value != value)
                {
                    tag.value = value;
                }
                return;
            }
        }
        
        tags ~= Tag(name, value);
    }
    
    char[] get(char[] key)
    {
        foreach(tag; tags)
        {
            if(tag.name == key)
            {
                return tag.value;
            }
        }
        return null;
    }
    
    char[] toString(char[][] omit_tags = null)
    {
        //ignore tag?
        bool omit(char[] name)
        {
            foreach(omit_tag; omit_tags)
            {
                if(omit_tag == name)
                    return true;
            }
            return false;
        }
        
        char[] ret;
        bool c;
        foreach(tag; tags)
        {
            if(tag.name is null || omit(tag.name))
                continue;
            
            if(c) { ret ~= ", "; }
            else { c = true; }
            ret ~= tag.name ~ " : " ~ tag.value;
        }
        return ret;
    }
}
