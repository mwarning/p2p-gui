module clients.mldonkey.model.MLSetting;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import tango.io.Stdout;

import api.Setting;

import clients.mldonkey.MLDonkey;


class MLSetting : Setting
{
    uint id;
    char[] name;
    char[] value;
    Setting.Type type;

    this(char[] name, char[] value, Setting.Type type, uint id)
    {
        this.id = id;
        this.name = name;
        this.value = value;
        this.type = type;
    }
    
    uint getId() { return id; }
    char[] getName() { return name; }
    char[] getValue() { return value; }
    char[] getDescription() { return ""; }
    Setting.Type getType() { return type; }
    void update(inout char[] value) { this.value = value; }
    Settings getSettings() { return this; }
    
    //from Settings
    Setting getSetting(uint id) { return null; }
    void setSetting(uint id, char[] value) {}
    uint getSettingCount() { return 0; }
    Setting[] getSettingArray() { return null; }
}

class MLSettings : MLSetting
{
    uint[] childs;
    MLDonkey mld;

public:

    this(char[] name, MLDonkey mld, uint id)
    {
        this.mld = mld;
        super(name, "", Setting.Type.MULTIPLE, id);
    }
    
    Setting getSetting(uint id)
    {
        return mld.getSetting(id);
    }
    
    void setSetting(uint id, char[] value)
    {
        mld.setSetting(id, value);
    }
    
    uint getSettingCount() { return childs.length; }
    
    void addSettingId(uint id)
    {
        childs ~= id;
    }
    
    Setting[] getSettingArray()
    {
        Setting[] settings;
        foreach(id; childs)
        {
            auto setting = cast(MLSetting) mld.getSetting(id);
            if(setting) settings ~= setting;
        }
        return settings;
    }
}

