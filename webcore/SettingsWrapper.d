module webcore.SettingsWrapper;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import tango.io.Stdout;
import tango.core.Traits;
import tango.core.Array;

import api.Setting;

import Utils = utils.Utils;
static import Main = webcore.Main;
import webcore.MainUser;
import webcore.Dictionary;
import webcore.Logger;

static import Convert = tango.util.Convert;
import tango.text.Util;

uint counter;

/*
* Implementations for the Setting interface
* for use in the html gui and core parts.
*/

private class GenericOptionSetter(T)
{
    T* value;
    T[]* options; 
    
    this(T* value, T[]* options)
    {
        assert(value && options);
        this.value = value;
        this.options = options;
    }

    void setValue(T new_value)
    {
        foreach(option; *options)
        {
            if(option == new_value)
            {
                *value = new_value;
            }
        }
    }
}

private class GenericValueSetter(T)
{
    T* value;
    
    this(T* value)
    {
        assert(value);
        this.value = value;
    }

    void setValue(T new_value)
    {
        *value = new_value;
    }
}

Setting createSetting(T)(Phrase name, T* value, T[]* options, void delegate(T) set = null, Phrase desc = Phrase.Nil)
{
    assert(value && options);
    if(set is null)
    {
        auto setter = new GenericOptionSetter!(T)(value, options);
        set = &setter.setValue;
    }
    return new SelectSetting!(T)(name, desc, Utils.toDgGetter(value), Utils.toDgGetter(options), set);
}

Setting createSetting(T)(Phrase name, T[]* options, T* value, void delegate(T) set = null, Phrase desc = Phrase.Nil)
{
    assert(options && value);
    if(set is null)
    {
        auto setter = new GenericOptionSetter!(T)(value, options);
        set = &setter.setValue;
    }
    return new SelectSetting!(T)(name, desc, Utils.toDgGetter(options), Utils.toDgGetter(value), set);
}

Setting createSetting(T)(Phrase name, T delegate() getvalue, T[] delegate() getoptions, void delegate(T) set, Phrase desc = Phrase.Nil)
{
    assert(getvalue && getoptions && set);
    return new SelectSetting!(T)(name, desc, getvalue, getoptions, set);
}

Setting createSetting(T)(Phrase name, T[] delegate() getoptions, T delegate() getvalue, void delegate(T) set, Phrase desc = Phrase.Nil)
{
    assert(getoptions && getvalue && set);
    return new SelectSetting!(T)(name, desc, getoptions, getvalue, set);
}

Setting createSetting(T)(Phrase name, T delegate() get, void delegate(T) set, Phrase desc = Phrase.Nil)
{
    assert(get && set);
    return new ValueSetting!(T)(name, get, set, desc);
}

Setting createSetting(T)(Phrase name, T* value, void delegate(T) set = null, Phrase desc = Phrase.Nil)
{
    assert(value);
    static if(isIntegerType!(T) || is(T == char[]) || is(T == enum) || is(T == bool))
    {
        if(set is null)
        {
            auto setter = new GenericValueSetter!(T)(value);
            set = &setter.setValue;
        }
        return new ValueSetting!(T)(name, Utils.toDgGetter(value), set, desc);
    }
    else static if(is(typeof(T.init[0])[] == T)) //is array
    {
        //uses internal generic setter
        return new OrderSetting!(T)(name, desc, value);
    }
    assert(0);
}

Setting createSetting(T)(Phrase name, T[] delegate() values, T[] delegate() options, void delegate(T[]) set, Phrase desc = Phrase.Nil)
{
    assert(values && options && set);
    return new CheckSetting!(T)(name, desc, values, options, set);
}

private:

/**
* A select setting consists of a group of
* options with _one_ selection.
*
* This class may represent a select list or an option list
*/
class SelectSetting(T) : Setting , Settings
{
    Phrase name;
    Phrase description;
    Setting.Type type = Setting.Type.SELECT;
    
    alias void delegate(T) SetValue;
    alias T delegate() GetValue;
    alias T[] delegate() GetOptions;
    
    SetValue setvalue;
    GetValue getvalue;
    GetOptions getoptions;
    
    this(Phrase name, Phrase description, GetOptions getoptions, GetValue getvalue, SetValue setvalue = null)
    {
        this.type = Setting.Type.RADIO;
        this(name, description, getvalue, getoptions, setvalue);
    }
    
    this(Phrase name, Phrase description, GetValue getvalue, GetOptions getoptions, SetValue setvalue = null)
    {
        this.name = name;
        this.description = description;
        this.getvalue = getvalue;
        this.getoptions = getoptions;
        this.setvalue = setvalue;
    }

    uint getId() { return name; }
    char[] getName() { return MainUser.tr(name); }
    char[] getDescription() { return MainUser.tr(description); }
    Setting.Type getType() { return type; }
    char[] getValue() { return Utils.toString( getvalue() );}
    Settings getSettings() { return this; }
    
    Setting getSetting(uint id) { return null; }
    
    void setSetting(uint id, char[] new_value)
    {
        T val = Utils.fromString!(T)(new_value);
        if(setvalue)
        {
            setvalue(val);
        }
    }
    
    uint getSettingCount() { return getoptions().length; }
    
    Setting[] getSettingArray()
    {
        Setting[] childs;
        foreach(x; getoptions() )
        {
            static if(is(T == Phrase))
            {
                char[] name = MainUser.tr(x);
            }
            else static if(is(T == char[]))
            {
                char[] name = x;
            }
            char[] value = Utils.toString(x);
            childs ~= new StringValueSetting(Setting.Type.STRING, name, value);
        }
        return childs;
    }
}

class CheckSetting(T) : Setting , Settings
{
    Phrase name;
    Phrase description;
    
    alias void delegate(T[]) Setter;
    alias T[] delegate() Getter;
    Getter values;
    Getter options;
    Setter set;
    
    this(Phrase name, Phrase description, Getter values, Getter options, Setter set)
    {
        this.name = name;
        this.values = values;
        this.options = options;
        this.description = description;
        this.set = set;
    }

    uint getId() { return name; }
    char[] getName() { return MainUser.tr(name); }
    char[] getDescription() { return MainUser.tr(description); }
    Setting.Type getType() { return Setting.Type.CHECK; }
    char[] getValue() { return null; }
    Settings getSettings() { return this; }
    Setting getSetting(uint id) { return null; }
    
    void setSetting(uint id, char[] value_str)
    {
        if(set)
        {
            auto checked = Utils.split!(T[])(value_str, ',');
            set(checked);
        }
    }
    
    uint getSettingCount() { return options().length; }
    
    Setting[] getSettingArray()
    {
        Setting[] childs;
        T[] vals = values();
        T[] opts = options();
        
        foreach(opt; opts)
        {
            char[] name = MainUser.tr(cast(Phrase) opt);
            char[] value = "false";
            foreach(val; vals)
            {
                if(val == opt) { value = "true"; break; }
            }
            childs ~= new StringValueSetting(cast(uint) opt, Setting.Type.BOOL, name, value);
        }
        
        return childs;
    }
}

class OrderSetting(T) : Setting , Settings
{
    alias typeof(T.init[0]) S;
    
    Phrase name;
    Phrase description;
    Setting.Type type = Setting.Type.STRING;
    S[]* values;
    
    alias void delegate(T) Setter;
    
    this(Phrase name, Phrase desc, S[]* values)
    {
        this.name = name;
        this.values = values;
        this.description = description;
    }
    
    uint getId() { return name; }
    char[] getName() { return MainUser.tr(name); }
    char[] getDescription() { return MainUser.tr(description); }
    Setting.Type getType() { return Setting.Type.ORDER; }
    char[] getValue() { return null; }
    Settings getSettings() { return this; }
    Setting getSetting(uint id) { return null; }
    uint getSettingCount() { return (*values).length; }
    
    void setSetting(uint id, char[] new_value)
    {
        //extract
        uint pos = locate(new_value, '_');
        if(pos == new_value.length) return;
        
        uint from = Convert.to!(uint)( new_value[0..pos] );
        uint to = Convert.to!(uint)( new_value[pos+1..$] );
        
        //temp
        S[] vals = (*values);
        if(!vals.length) return;
        uint last = vals.length - 1;
        
        //apply
        if(from == 0 && to == last)
        {
            S tmp = vals[0];
            vals = vals[1..$];
            vals ~= tmp;
            (*values) = vals;
        }
        else if(from == last && to == 0)
        {
            S[] tmp; tmp ~= vals[last];
            tmp ~= vals[0..last];
            (*values) = tmp;
        }
        else if(from <= last && to <= last) //just swap
        {
            S tmp = vals[from];
            vals[from] = vals[to];
            vals[to] = tmp;
            (*values) = vals;
        }
    }
    
    Setting[] getSettingArray()
    {
        Setting[] childs;
        
        foreach(x; *values)
        {
            static if(is(typeof(x.getName)))
            {
                alias ReturnTypeOf!(typeof(x.getName)) R;
                static if(is(R == enum) || is(R == ushort))
                {
                    char[] name = MainUser.tr(cast(Phrase) x.getName);
                }
                else static if(is(R == char[]))
                {
                    char[] name = x.getName();
                }
                else static assert(false, "(E) Invalid Type in class OrderSetting!");
            }
            else
            {
                char[] name = Utils.toString(x);
            }
        
            childs ~= new StringValueSetting(Setting.Type.STRING, name, null);
        }
        return childs;
    }
}

class ValueSetting(T) : Setting, Settings
{
    uint id;
    Phrase name;
    Phrase description;
    Setting.Type type = Setting.Type.STRING;
    Setter set;
    Getter get;
    T* value;
    
    alias void delegate(T) Setter;
    alias T delegate() Getter;
    
    this(Phrase name, Getter get, Setter set, Phrase description = Phrase.Nil)
    {
        this.get = get;
        this(name, name, null, set, description);
    }
    
    this(Phrase name, T* value, Setter set = null, Phrase description = Phrase.Nil)
    {
        this(name, name, value, set, description);
    }
    
    this(uint id, Phrase name, T* value, Setter set = null,  Phrase description = Phrase.Nil)
    {
        static if(is(T == bool)) type = Setting.Type.BOOL;
        else if(is(T == char[])) type = Setting.Type.STRING;
        
        this.id = id;
        this.name = name;
        this.description = description;
        this.value = value;
        this.set = set;
    }
    
    uint getId() { return id; }
    char[] getName() { return MainUser.tr(name); }
    char[] getDescription() { return MainUser.tr(description); }
    Setting.Type getType() { return type; }
    char[] getValue()
    {
        if(get)
        {
            return Utils.toString(get());
        }
        else
        {
            return Utils.toString(value);
        }
    }
    
    Settings getSettings() { return null; }
    Setting[] getSettingArray() { return null; }
    Setting getSetting(uint id) { return null; }
    uint getSettingCount() { return 0; }
    
    void setSetting(uint id, char[] value_str)
    {
        T new_value;
        try
        {
            new_value = Convert.to!(T)(value_str);
        }
        catch(Exception e)
        {
            Logger.addError(e.toString);
            return;
        }
        
        if(set)
        {
            set(new_value);
        }
        else if(new_value != *value)
        {
            *value = new_value;
        }
    }
}

/*
* Store name and value as char[].
* Should be reinstantiated after every use.
*/
class StringValueSetting : Setting, Settings
{
    uint id;
    char[] name;
    char[] description;
    Setting.Type type;
    char[] value;
    
    this(Setting.Type type, char[] name, char[] value, char[] description = null)
    {
        static uint id = 1;
        this(id++, type, name, value, description);
    }
    
    this(uint id, Setting.Type type, char[] name, char[] value, char[] description = null)
    {
        this.id = id;
        this.type = type;
        this.name = name;
        this.value = value;
        this.description = description;
    }
    
    uint getId() { return id; }
    char[] getName() { return name; }
    char[] getDescription() { return description; }
    Setting.Type getType() { return type; }
    char[] getValue() { return value; }
    
    Settings getSettings() { return null; }
    Setting[] getSettingArray() { return null; }
    Setting getSetting(uint id) { return null; }
    uint getSettingCount() { return 0; }
    void setSetting(uint id, char[] value_str) {}
}
