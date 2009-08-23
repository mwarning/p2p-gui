module clients.transmission.TTracker;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/

import tango.text.Util : jhash;

import utils.json.JsonBuilder;
import api.Node;


class TTracker : NullNode
{
    uint id;
    char[] announce;
    char[] scrape;
    uint tier;
    
    alias JsonBuilder!().JsonValue JsonValue;
    alias JsonBuilder!().JsonString JsonString;
    alias JsonBuilder!().JsonNumber JsonNumber;
    alias JsonBuilder!().JsonNull JsonNull;
    alias JsonBuilder!().JsonBool JsonBool;
    alias JsonBuilder!().JsonArray JsonArray;
    alias JsonBuilder!().JsonObject JsonObject;
    
    uint getId()
    {
        return id;
    }
    
    char[] getName()
    {
        return announce;
    }
    
    this(JsonObject obj)
    {
        update(obj);
    }
    
    void update(JsonObject obj)
    {
        foreach(char[] name, JsonValue value; obj)
        {
            switch(name)
            {
            case "announce":
                announce = value.toString();
                if(id == 0)
                {
                    id = jhash(name);
                    if(id == 0) ++id;
                }
                break;
            case "scrape":
                scrape = value.toString();
                break;
            case "tier":
                tier = value.toInteger();
                break;
            default:
            }
        }
    }
}
