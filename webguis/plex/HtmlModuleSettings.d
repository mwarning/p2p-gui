module webguis.plex.HtmlModuleSettings;

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

final class HtmlModuleSettings : HtmlElement
{
private:

    bool show_description = false;
    uint max_per_col = 10;
    uint category_id;
    uint selected;

public:

    this()
    {
        super(Phrase.ModuleSettings);
        
        addSetting(Phrase.show_description, &show_description);
    }

    void handle(HttpRequest req, Session session)
    {
        //select category
        char[] category = req.getParameter("category");
        if(category.length)
        {
            category_id = Convert.to!(uint)(category, uint.max);
        }
        
        //select module
        char[] selected_module = req.getParameter("module");
        if(selected_module.length)
        {
            uint new_selected = Convert.to!(uint)(selected_module, uint.max);
            auto selected_obj = session.getGui!(PlexGui).getModule(new_selected);
            
            if(selected_obj)
            {
                selected = new_selected;
                category_id = uint.max;
            }
            return;
        }
        
        //change settings
        char[][char[]] params = req.getAllParameters();
        foreach(name_string, value_string; params)
        {
            uint pos = locate(name_string, delim);
            if(pos == name_string.length) continue;
            
            uint source_id = Convert.to!(uint)( name_string[0..pos], uint.max );
            uint setting_id = Convert.to!(uint)( name_string[pos+1..$], uint.max );
            
            if(source_id == uint.max || setting_id == uint.max) continue;
            
            auto mod = session.getGui!(PlexGui).getModule(source_id);
            if(mod) mod.setSetting(setting_id, value_string);
        }
    }

    void handle(HttpResponse res, Session session)
    {
        HtmlOut o = { res.getWriter(), &session.getUser.translate};
        
        Setting[] settings;
        uint source_id;
        
        o("<b>")(Phrase.User)(":</b>   ");
        o("<a href=\"" ~ target_uri ~ "?to=")(this.getId)(AMP~"category=0\">"); //reset selection
        o(session.getUser.getName);
        o("</a>\n\n");
        o(BBN);
    
        //web module header
        o("<b>")(Phrase.Modules)(":</b>\n");
        auto c = 0;
        foreach(element; session.getGui!(PlexGui).elements)
        {
            uint count = element.getSettingCount();
            if(!count) continue;
            
            o("<span class=\"nobr\">");
            if(c) o("| ");
            if(element.getId == selected) o("<b>");
            
            o("<a href=\"" ~ target_uri ~ "?to=")(this.getId)(AMP~"module=")(element.getId)("\">");
            o(element.getName);
            o("</a>");
            
            if(element.getId == selected) o("</b>");
            
            o(" (")(count)(")");
            
            o("</span>\n");
            c++;
        }
        o(BN);
        
        //access settings
        if(selected)
        {
            auto mod = session.getGui!(PlexGui).getModule(selected);
            settings = mod.getSettingArray();
            source_id = selected;
        }
        else
        {
            o("<h3>")(Phrase.Nothing_Selected)("</h3>");
        }
        
        if(settings is null) return;

        Setting[] categories;
        Setting[] simple;
        Setting[] complex;
        
        //filter out simple- and complex settings
        foreach(s; settings)
        {
            if(s.getType == Setting.Type.MULTIPLE)
            {
                categories ~= s;
            }
            else if(s.getType != Setting.Type.ORDER && s.getType != Setting.Type.CHECK)
            {
                simple ~= s;
            }
            else
            {
                complex ~= s;
            }
        }
        
        //display category settings
        if(categories.length)
        {
            o("<b>")(Phrase.Categories)(":</b>\n");
            c = 0;
            foreach(setting; categories)
            {
                o("<span class=\"nobr\">");
                if(c) o("| ");
                
                o("<a href=\"" ~ target_uri ~ "?to=")(this.getId)(AMP~"category=")(setting.getId)("\">");
                o(setting.getName);
                o("</a>");
                
                o(" (")(setting.getSettingCount)(")");
                
                o("</span>\n");
                c++;
            }
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
                
                displaySimpleSettingTable(o, source_id, simple[from..to], this, show_description);
                o("\n");
                
                if(to == simple.length) break;
                from = to;
                to += max_per_col;
            }
        }
    
        //display complex settings
        foreach(setting; complex)
        {
            displayComplexSetting(o, source_id, setting, this, show_description);
        }
    }

}
