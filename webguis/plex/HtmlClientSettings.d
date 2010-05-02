module webguis.plex.HtmlClientSettings;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/

import webserver.HttpRequest;
import webserver.HttpResponse;

import api.Client;
import api.File;
import api.User;
import api.Node;
import api.Setting;

import tango.io.Stdout;
import tango.core.Array;
import tango.text.Util;
import tango.core.Traits;

import webguis.plex.PlexGui;
import webguis.plex.HtmlUtils;
import webguis.plex.HtmlElement;
import webguis.plex.HtmlSettings;
import utils.Utils;


final class HtmlClientSettings : HtmlElement
{
private:

    bool show_description = false;
    uint max_per_col = 10;
    uint selected;

public:

    this()
    {
        super(Phrase.ClientSettings);
        
        addSetting(Phrase.show_description, &show_description);
    }

    void handle(HttpRequest req, Session session)
    {
        char[] select = req.getParameter("select");
        if(select.length)
        {
            selected = Convert.to!(uint)(select, 0);
            return;
        }

        //get settings handler
        auto client = session.getGui!(PlexGui).getClient();
        Settings settings = client ? client.getSettings() : null;
        if(settings is null) return;
        
        //change settings
        char[][char[]] params = req.getAllParameters();
        foreach(name_string, value_string; params)
        {
            uint pos = locate(name_string, delim);
            if(pos == name_string.length) continue;
            
            uint source_id = Convert.to!(uint)( name_string[0..pos], uint.max );
            uint setting_id = Convert.to!(uint)( name_string[pos+1..$], uint.max );
            
            if(source_id == uint.max || setting_id == uint.max) continue;
            
            settings.setSetting(setting_id, value_string);
        }
    }

    void handle(HttpResponse res, Session session)
    {
        HtmlOut o;
        o.init(res.getWriter(), &session.getUser.translate);
        
        auto client = session.getGui!(PlexGui).getClient();

        if(client is null)
        {
            o("<h3>")(Phrase.Not_Available)("</h3>\n");
            return;
        }
        
        auto settings = client.getSettings();
        
        if(settings is null)
        {
            o("<h3>")(Phrase.Not_Supported)("</h3>\n");
            return;
        }
        
        //reset selection
        o("<a class=\"reset\" href=\"" ~ target_uri ~ "?to=")(this.getId)(AMP~"select=0\">");
        o(Phrase.Categories);
        o("</a>:\n");
        
        if(selected)
        {
            displayCategories(o, settings, selected);
            
            auto tmp = settings.getSetting(selected);
            if(tmp && tmp.getType == Setting.Type.MULTIPLE)
            {
                settings = tmp;
            }
            else
            {
                o("<h3>")(Phrase.Not_Found)("</h3>\n");
                selected = 0;
                return;
            }
        }

        auto array = settings.getSettingArray();
        
        Setting[] categories;
        Setting[] simple;
        Setting[] complex;

        //filter settings
        foreach(s; array)
        {
            if(s.getType == Setting.Type.MULTIPLE)
            {
                categories ~= s;
            }
            else if(true)
            {
                simple ~= s;
            }
            else
            {
                complex ~= s;
            }
        }
        
        //display categories
        if(categories.length)
        {
            displayCategories(o, categories);
        }
        
        //display simple settings
        if(simple.length)
        {
            uint from = 0;
            uint to = max_per_col;
            while(true)
            {
                //new table
                if(to > simple.length) to = simple.length;
                
                displaySimpleSettingTable(o, client.getId, simple[from..to], this, show_description);
                
                if(to == simple.length) break;
                from = to;
                to += max_per_col;
            }
        }
    
        //display complex settings
        foreach(setting; complex)
        {
            o(BBN);
            displayComplexSetting(o, client.getId, setting, this, show_description);
        }
    }
    
    void displayCategories(HtmlOut o, Settings setting, uint select = 0)
    {
        Setting[] settings;
        Setting[] array = setting.getSettingArray();
        if(array is null) return;
        foreach(s; array)
        {
            if(s.getType == Setting.Type.MULTIPLE)
            {
                settings ~= s;
            }
        }
        displayCategories(o, settings, select);
    }
    
    /*
    * Display category selection
    */
    void displayCategories(HtmlOut o, Setting[] settings, uint select = 0)
    {
        size_t c;
        foreach(setting; settings)
        {
            uint count = setting.getSettingCount();
            if(count == 0) continue; 
            
            o("<span class=\"nobr\">");
            if(c) o("| ");
            
            uint id = setting.getId();
            
            if(id == select) o("<b>");
            
            o("<a href=\"" ~ target_uri ~ "?to=")(this.getId)(AMP~"select=")(id)("\">");
            o(setting.getName);
            o("</a>");
            
            if(id == select) o("</b>");
            
            o(" (")(count)(")");
            
            o("</span>\n");
            c++;
        }
    }
}
