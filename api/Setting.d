module api.Setting;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/

/*
* Settings are rarly changing key-value structures
* that are used to control behavior
*/

interface Settings
{
    public:

    Setting getSetting(uint id);
    void setSetting(uint id, char[] value);
    //uint addSetting(char[] name, char[] value);
    uint getSettingCount();
    
    Setting[] getSettingArray();
}

interface Setting : Settings
{
    public:
    
    /*
    * Indicates how the data should be displayed,
    * rather then what the data really is (integer, rational)
    */
    enum Type : ubyte
    {
        UNKNOWN,
        BOOL, //checkbox
        //VALUE, //value field
        PASSWORD, //value field not visible
        STRING,
        NUMBER,
        //TIME, DATE..
        
        //sub settings form..
        RADIO, //radio selection
        CHECK, //check boxes
        SELECT, //select list
        ORDER, //order sensitive list
        
        MULTIPLE //setting directory
    };
    
    /*not used, yet
    enum State
    {
        ANYSTATE,
        READONLY,
        GLOBAL,
        READONLY_GLOBAL
    }*/
    
    uint getId();
    Setting.Type getType();
    char[] getName();
    char[] getValue();
    char[] getDescription();
    Settings getSettings();
}

class NullSetting : Setting, Settings
{
    uint getId() { return 0; }
    Setting.Type getType() { return Setting.Type.UNKNOWN; }
    char[] getName() { return null; }
    char[] getValue() { return null; }
    char[] getDescription() { return null; }
    
    Settings getSettings() { return null; }
    
    Setting getSetting(uint id) { return null; }
    void setSetting(uint id, char[] value) { }
    uint getSettingCount() { return 0; }
    Setting[] getSettingArray() { return null; }
}
