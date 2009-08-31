module clients.transmission.TSetting;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/

import webcore.Dictionary; //for unified settings

import api.Setting;


class TSetting : NullSetting
{
    uint id;
    char[] name;
    char[] value;
    Setting.Type type;
    
    this(uint id, char[] name, char[] value, Setting.Type type)
    {
        this.id = id;
        this.name = name;
        this.value = value;
        this.type = type;
    }
    
    uint getId() { return id; }
    Setting.Type getType() { return type; }
    char[] getName() { return name; }
    char[] getValue() { return value; }
    char[] getDescription() { return null; }
    Settings getSettings() { return null; }
}
