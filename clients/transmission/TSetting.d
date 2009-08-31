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
        //map to unified id
        switch(name)
        {
            case "download-dir":
                id = Phrase.download_dir__setting;
                break;
            case "peer-limit":
                id = Phrase.peer_limit__setting;
                break;
            case "peer-port":
                id = Phrase.port__setting;
                break;
            case "port-forwarding-enabled":
                id = Phrase.port_forwarding_enabled__setting;
                break;
            case "speed-limit-down":
                id = Phrase.speed_limit_down__setting;
                break;
            case "speed-limit-up":
                id = Phrase.speed_limit_up__setting;
                break;
            default:
        }
        
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
