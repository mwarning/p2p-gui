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
    uint[] category_ids; //selected categories
    uint selected;

public:

    this()
    {
        super(Phrase.ClientSettings);
        
        addSetting(Phrase.show_description, &show_description);
    }

    void handle(HttpRequest req, Session session)
    {
        auto user = session.getUser;
        
        //select category
        category_ids = req.getParameter!(uint[])("category");
        
        /*
        //select module
        char[] mod = req.getParameter("module");
        if(mod.length)
        {
            uint client_id = Convert.to!(uint)(mod, uint.max);
            
            Node node;
            if(auto nodes = user.getNodes)
            {
                node = nodes.getNode(Node_.Type.CORE, client_id);
            }
            
            if(node)
            {
                selected = client_id;
                category_ids = category_ids.init;
            }
            
            return;
        }*/
        
        //get settings handler
        auto client = session.getGui!(PlexGui).getClient();
        Settings settings;
        if(client) settings = client.getSettings();
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
        HtmlOut o = { res.getWriter(), &session.getUser.translate};
        
        auto client = session.getGui!(PlexGui).getClient();
/*
        Client client;
        Node[] clients;
        uint node_count;
        
        if(auto nodes = session.getUser.getNodes)
        {
            client = cast(Client) nodes.getNode(Node_.Type.CORE, selected);
            clients = nodes.getNodeArray(Node_.Type.CORE, Node_.State.ANYSTATE, 0);
            node_count = nodes.getNodeCount(Node_.Type.CORE, Node_.State.ANYSTATE);
        }
    
        if(clients is null)
        {
            o("<b>")(Phrase.Not_Supported)("</b>\n");
            return;
        }
    
        if(node_count == 0)
        {
            o("<b>")(Phrase.Not_Available)("</b>\n");
            return;
        }
    
        //display list of client with settings count
        o("<div class=\"centered\">\n");
        //o("<b>")(Phrase.Clients)(":</b>\n");
        
        foreach(c, Node elem; clients)
        {
            //select first client when nothing selected
            if(client is null)
            {
                client = cast(Client) elem;
                if(client) selected = client.getId();
            }
            
            auto settings = elem.getSettings();
            
            o("<span class=\"nobr\">");
            if(c) o("| ");
            if(elem.getId == selected) o("<b>");
            
            //print accounts
            o("<a href=\"" ~ target_uri ~ "?to=")(this.getId)(AMP~"module=")(elem.getId)("\">");
            o(elem.getSoftware)(" ")(elem.getName)("@")(elem.getHost)(":")(elem.getPort);
            o("</a>");
            
            if(elem.getId == selected) o("</b>");
            if(settings)
            {
                o(" (")(settings.getSettingCount)(")");
            }
            else
            {
                o(" (0)");
            }
            o("</span>\n");
        }
        o("<div>\n");
        */
        
        
        if(client is null)
        {
            o("<b>")(Phrase.Not_Available)("</b>\n");
            return;
        }
        
        auto settings = client.getSettings;
        
        if(settings is null)
        {
            o("<h3>")(Phrase.Not_Supported)("</h3>\n");
            return;
        }
        
        /*
        o("<span class=\"nobr\">");
        o("<b>");
        o(client.getSoftware)(" ")(client.getName)("@")(client.getHost)(":")(client.getPort);
        o("</b>");
        o("</span>\n");
        */
        
        if(category_ids.length)
        {
            char[] path;
            foreach(id; category_ids)
            {
                displayCategories(o, settings, id);
                
                auto tmp = settings.getSetting(id);
                if(tmp && tmp.getType == Setting.Type.MULTIPLE)
                {
                    settings = tmp;
                }
                else
                {
                    break;
                }
            }
        }
        else
        {
            displayCategories(o, settings);
        }
        
        if(auto setting = cast(Setting) settings)
        {
            o("<h3>")(setting.getName)("</h3>\n\n");
        }
        
        auto iter = settings.getSettingArray();
        
        if(iter is null)
        {
            o("<h3>")(Phrase.Not_Available)("</h3>\n");
            return;
        }
        
        //Setting[] categories;
        Setting[] simple;
        Setting[] complex;

        //filter out simple- and complex settings
        foreach(s; iter)
        {
            if(s.getType == Setting.Type.MULTIPLE)
            {
                //categories ~= s;
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
        
        if(!simple.length && !complex.length)
        {
            o("<h3>")(Phrase.Not_Found)("</h3>\n");
            return;
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
        Setting[] iter = setting.getSettingArray();
        if(iter is null) return;
        foreach(s; iter)
        {
            if(s.getType == Setting.Type.MULTIPLE)
            {
                settings ~= s;
            }
        }
        displayCategories(o, settings, select);
    }
    
    void displayCategories(HtmlOut o, Setting[] settings, uint select = 0)
    {
        o("<div class=\"centered\">\n");
        size_t c;
        foreach(setting; settings)
        {
            uint count = setting.getSettingCount();
            if(count == 0) continue; 
            
            o("<span class=\"nobr\">");
            if(c) o("| ");
            
            uint id = setting.getId();
            
            if(id == select) o("<b>");
            
            o("<a href=\"" ~ target_uri ~ "?to=")(this.getId)(AMP~"category=")(id)("\">");
            o(setting.getName);
            o("</a>");
            
            if(id == select) o("</b>");
            
            o(" (")(count)(")");
            
            o("</span>\n");
            c++;
        }
        o("</div>\n\n");
    }
}
