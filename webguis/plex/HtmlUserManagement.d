module webguis.plex.HtmlUserManagement;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/

import webserver.HttpRequest;
import webserver.HttpResponse;

import api.File;
import api.Node;
import api.User;
import api.Setting;

import tango.io.Stdout;
import tango.core.Array;
import tango.text.Util;

import webguis.plex.PlexGui;
import webguis.plex.HtmlElement;
import webguis.plex.HtmlSettings;
import webguis.plex.HtmlUtils;
import utils.Utils;

final class HtmlUserManagement : HtmlElement
{
private:
    
    uint user_id;
    bool show_description = false;
    uint max_per_col = 10;

public:
    
    this()
    {
        super(Phrase.UserManagement);
    }
    
    void handle(HttpRequest req, Session session)
    {
        auto me = session.getUser;
        
        uint id = req.getParameter!(uint)("id");
        char[] action = req.getParameter("do");
        
        if(action == "add")
        {
            char[] name = req.getParameter("name");
            char[] pass = req.getParameter("pass");
            uint user_id = me.addUser(User_.Type.USER, name);
            me.setUserPassword(user_id, pass);
        }
        else if(action == "remove")
        {
            me.removeUser(id);
        }
        else if(action == "rename")
        {
            char[] new_name = req.getParameter("rename");
            me.renameUser(id, new_name);
        }
        else if(action == "show")
        {
            if(user_id == id) { user_id = 0; } else { user_id = id; }
        }
        
        //HtmlSettings:
        setUserSettings(req, me);
    }

    void handle(HttpResponse res, Session session)
    {
        auto me = session.getUser;
        HtmlOut o = { res.getWriter(), &session.getUser.translate};
        
        //add user
        o("<form action=\"" ~ target_uri ~ "\" method=\"get\">\n");
        o("<input type=\"hidden\" name=\"to\" value=\"")(this.getId)("\">\n");
        
        o(Phrase.Name)(": <input type=\"text\" name=\"name\" size=\"14\" maxlength=\"14\" />\n");
        o(Phrase.password)(": <input type=\"text\" name=\"pass\" size=\"10\" maxlength=\"10\" />\n");
        
        o("<button type=\"submit\" name=\"do\" value=\"add\">\n");
        o(Phrase.Add);
        o("</button>\n");
        
        o("</form>\n");
        
        o("<hr>\n");
        
        o("<b>")(Phrase.Users)(":</b>\n");
        
        auto selected_user = me.getUser(user_id);
        auto users = me.getUserArray();
        
        if(users)
        {
            auto c = 0;
            foreach(user; users)
            {
                if(c) o(" | ");
                if(user == selected_user) o("<b>");
                o("<a href=\"" ~ target_uri ~ "?to=")(this.getId)(AMP~"do=show"~AMP~"id=")(user.getId)("\" />");
                o(user.getName);
                o("</a>\n");
                if(user == selected_user) o("</b>\n");
                c++;
            }
        }
        
        if(selected_user is null) 
        {
            o("<h3>No User selected!<h3>\n");
            return;
        }
        
        auto source_id = selected_user.getId;
        Settings sets = selected_user.getSettings();
        
        Setting[] settings;
        if(sets) settings = sets.getSettingArray();

        if(settings is null)
        {
            o("<h3>No Settings available!<h3>\n");
            return;
        }
        
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
            else if(true)
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
                
                o("<a href=\"" ~ target_uri ~ "?to=")(this.getId)(AMP~"category=")(setting.getId)("\">");
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
        
        /*
        o("<form action=\"" ~ target_uri ~ "\" method=\"get\">\n");
        //o("Name: <input type=\"text\" name=\"name\" length=\"10\"/>")(SP2);
        
        o("Password: <input type=\"text\" name=\"pass\" length=\"5\"/>\n");
        o("<input type=\"hidden\" name=\"to\" value=\"")(this.getId)("\"/>\n");
        
        o("<button type=\"submit\" name=\"do\" value=\"set_password\">");
        o(Phrase.Set_Password);
        o("</button>\n");
        
        o("<button type=\"submit\" name=\"do\" value=\"remove\">");
        o(Phrase.Remove);
        o("</button>\n");
        
        o("<form/>\n");
        
        o(BBN);
        */
        //o("<b>Name:</b>")(user.getName)(BN);
        //o("<b>Admin:</b>")(user.getUserType);
        //o("<b>Subuser:</b>")(user.getUserCount)(BN);
        
        /*
        o("<b>Groups:</b>")(BBN);
        o("<table border=\"0\"><tr><td>\n");
        o("<table border=\"0\" cellpadding=\"5\" cellspacing=\"0\">\n");
        o("<tr><td>Group</td><td>See</td><td>Add</td><td>Cancel</td><td>Pause</td><td>Prioritize</td><td>Rename</td></tr>\n");

        o("<tr align=\"center\">\n");
        o("<td><a href=\"index.php?CORE_OP=UserManagement&user=admin&modul=User\">admin</a></td>\n");
        o("<td><input type=\"checkbox\" name=\"User[groups][admin][]\" value=\"see\" checked=\"checked\" /></td>\n");
        o("<td><input type=\"checkbox\" name=\"User[groups][admin][]\" value=\"add\" checked=\"checked\" /></td>\n");
        o("<td><input type=\"checkbox\" name=\"User[groups][admin][]\" value=\"can\" checked=\"checked\" /></td>\n");
        o("<td><input type=\"checkbox\" name=\"User[groups][admin][]\" value=\"res\" checked=\"checked\" /></td>\n");
        o("<td><input type=\"checkbox\" name=\"User[groups][admin][]\" value=\"pri\" checked=\"checked\" /></td>\n");
        o("<td><input type=\"checkbox\" name=\"User[groups][admin][]\" value=\"ren\" checked=\"checked\" /></td>\n");
        o("</tr>\n");
        o("</table>\n");

        o("<table  border=\"0\" cellpadding=\"5\" cellspacing=\"0\">\n");
        o("<tr><td rowspan=\"2\">\n");
        o("<select name=\"elems[groups][]\" style=\"width: ;\" size=\"4\" multiple=\"multiple\">\n");
        o("<option>admin</option>\n");

        o("</select>\n");
        o("</td><td>\n");
        
        o("<button type=\"submit\" name=\"do\" value=\"add_elem\">");
        o("Add");
        o("</button>\n");
        
        o("</td></tr>\n");
        o("<tr><td>\n");
        
        o("<button type=\"submit\" name=\"do\" value=\"remove_elem\">");
        o("Remove");
        o("</button>\n");
        
        o("</td></tr>\n");
        o("</table>\n");
        o("</td></tr>\n");
        o("</table>\n");
        */

    }
    /*
    void insertButtons(HtmlOut o, User user)
    {
        o("<button type=\"submit\" name=\"do\" value=\"set_settings\">");
        o(Phrase.Set);
        o("</button>\n");
        
        o("<button type=\"submit\" name=\"do\" value=\"save_settings\">");
        o(Phrase.Save);
        o("</button>\n");
        
        o("<button type=\"reset\" name=\"_\" value=\"\">");
        o(Phrase.Undo);
        o("</button>\n");
    }*/
}
