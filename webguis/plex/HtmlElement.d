module webguis.plex.HtmlElement;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/

import webserver.HttpRequest;
import webserver.HttpResponse;

import api.File;
import api.User;
import api.Setting;

import tango.io.protocol.Writer;
import tango.io.Stdout;
import tango.io.FilePath;
import tango.io.device.File;
import tango.core.Traits;
public static import Convert = tango.util.Convert;
public static import Integer = tango.text.convert.Integer;
public import tango.io.stream.Format;

static import SettingsWrapper = webcore.SettingsWrapper;
public import Main = webcore.Main;
public import webcore.Session;
public import webcore.Dictionary;
public import webcore.Logger;
public import webguis.plex.PlexGui;
public import utils.Storage;
public static import Utils = utils.Utils;


//uri target for parameters 
static const char[] target_uri = "plex"; //always followed by "?"
//resources folder inside ./webroot/
static const char[] resource_dir = "plex/";

class HtmlElement : Settings
{
    //insert content into page => call handle(HttpResponse res, ..
    bool visible = false;
    
    //show navigation entry only => call handle(HttpRequest req, ..
    bool exec_only = false;
    
    //display in titlebar
    bool display_in_titlebar = true;
    
    //will be unloaded
    bool remove = false;
    
    Setting[] settings;
    
    char[] css_class_names;
    
    Phrase name;
    Phrase description;
    
public:

    this(Phrase name, char[] css_class_names = "main", Phrase description = Phrase.Nil)
    {
        this.name = name;
        this.css_class_names = css_class_names;
        this.description = description;
    }

    abstract void handle(HttpRequest req, Session session);
    abstract void handle(HttpResponse res, Session session);
    
    /*
    * notify element that some elements
    * have changed or were added/removed
    */
    void changed(HtmlElement[] items) {}
    
    /*
    * Id used in html GET/POST requests to find a HtmlElement.
    * We "abuse" name for that.
    */
    uint getId()
    {
        return cast(uint) name;
    }
    
    Phrase getName() { return name; }
    Phrase getDescription() { return description; }
    
    /*
    * Get string for CSS id.
    */
    char[] getCssIdString()
    {
        return Dictionary.toString(name);
    }
    
    /*
    * Get space separated list of CSS class names.
    */
    char[] getCssClassString()
    {
        return css_class_names;
    }
    
    void save(Storage s)
    {
        //empty default implementation
    }
    
    void load(Storage s)
    {
        //empty default implementation
    }
    
    Setting getSetting(uint id)
    {
        foreach(setting; this.settings)
        {
            if(id == setting.getId) return setting;
        }
        return null;
    }

    Setting[] getSettingArray()
    {
        return settings.dup;
    }
    
    void setSetting(uint id, char[] value)
    {
        auto settings = cast(Settings) getSetting(id);
        
        if(settings)
        {
            settings.setSetting(id, value);
        }
    }
    
    uint getSettingCount() { return settings.length; }
    
    void displaySetting(FormatOutput!(char) o, inout Setting v)
    {
        Logger.addError("HtmlElement/{}: Cannot display setting '{}'. Unknown type!", Dictionary.toString(name), v.getName);
    }
    
    void setSetting(inout Setting v, inout char[] value_string)
    {
        Logger.addError("HtmlElement/{}: Cannot set setting '{}'. Unknown type!", Dictionary.toString(name), v.getName);
    }
    
protected:
    
    //shortcut
    void addSetting(T...)(Phrase name, T params)
    {
        settings ~= SettingsWrapper.createSetting(name, params);
    }
}
