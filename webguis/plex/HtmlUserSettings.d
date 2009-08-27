module webguis.plex.HtmlUserSettings;

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


final class HtmlUserSettings : HtmlElement
{
private:

    bool show_description = false;
    uint max_per_col = 10;
    uint category_id;
    uint selected_module;

public:

    this()
    {
        selected_module = this.getId;
        
        super(Phrase.UserSettings);
        
        addSetting(Phrase.show_description, &show_description);
    }

    void handle(HttpRequest req, Session session)
    {
        //HtmlSettings.d:
        setUserSettings(req, session.getUser);
    }

    void handle(HttpResponse res, Session session)
    {
        auto me = session.getUser;
        HtmlOut o = { res.getWriter(), &session.getUser.translate};

        o("<h2>Me: '")(me.getName)("'</h2>\n");
        
        auto source_id = me.getId;
        Settings sets = me.getSettings();
        
        Setting[] settings;
        if(sets) settings = sets.getSettingArray();

        if(settings is null)
        {
            o("<b>")(Phrase.Not_Available)("</b>\n");
            return;
        }
        
        Setting[] categories;
        Setting[] simple;
        Setting[] complex;

        //filter out simple- and complex settings
        foreach(s; settings)
        {
            auto type = s.getType();
            
            if(type == Setting.Type.MULTIPLE)
            {
                categories ~= s;
            }
            else if(type != Setting.Type.ORDER && type != Setting.Type.CHECK)
            {
                simple ~= s;
            }
            else
            {
                complex ~= s;
            }
        }
        
        //display category settings
        auto c = 0;
        if(categories.length)
        {
            o("<b>Categories:</b>\n");
            foreach(setting; categories)
            {
                o("<span class=\"nobr\">");
                if(c) o("| ");
                
                o("<a href=\"" ~ target_uri ~ "to=")(this.getId)(AMP~"category=")(setting.getId)("\">");
                o(setting.getName);
                o("</a>");
                
                o(" (")(setting.getSettingCount)(")");
                
                o("</span>\n");
                c++;
            }
        }
    
        o("<hr />\n");
        
        if(!simple.length && complex.length) o("<h2>None<h2>\n");

        //display simple settings
        if(simple.length)
        {
            uint from = 0;
            uint to = max_per_col;
            while(true)
            {
                //new table
                if(to > simple.length) to = simple.length;
                
                displaySimpleSettingTable(o, source_id, simple[from..to], this);
                o("\n");
                
                if(to == simple.length) break;
                from = to;
                to += max_per_col;
            }
        }
    
        //display complex settings
        foreach(setting; complex)
        {
            displayComplexSetting(o, source_id, setting, this);
        }
    }
}
