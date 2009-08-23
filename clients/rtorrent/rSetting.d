module clients.rtorrent.rSetting;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import api.Setting;


final class rSetting : Setting
{
private:

    uint id;
    Setting.Type type;
    char[] name;
    char[] value;
    
public:
    
    this(uint id, char[] name, char[] value, Setting.Type type)
    {
        this.id = id;
        this.type = type;
        this.name = name;
        this.value = value;
    }
    
    void setValue(char[] value)
    {
        this.value = value;
    }
    
    uint getId() { return id; }
    char[] getName() { return name; }
    char[] getValue() { return value; }
    char[] getDescription() { return null; }
    Setting.Type getType() { return type; }
    Settings getSettings() { return this; }
    
    //from Settings
    Setting getSetting(uint id) { return null; }
    void setSetting(uint id, char[] value) {}
    uint getSettingCount() { return 0; }
    Setting[] getSettingArray() { return null; }
}
