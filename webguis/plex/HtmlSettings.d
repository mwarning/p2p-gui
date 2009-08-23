module webguis.plex.HtmlSettings;

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
static import Convert = tango.util.Convert;

import webguis.plex.PlexGui;
import webguis.plex.HtmlUtils;
import webguis.plex.HtmlElement;
import utils.Utils;

/*
* This is a collection of classes to display settings in a HTML format
*/

static const char delim = '_';


void setUserSettings(HttpRequest req, User me)
{
    char[][char[]] params = req.getAllParameters();
    
    foreach(name_string, value_string; params)
    {
        uint pos = find(name_string, delim);
        
        if(pos >= name_string.length) continue;
    
        uint user_id = Convert.to!(uint)( name_string[0..pos], uint.max );
        uint setting_id = Convert.to!(uint)( name_string[pos+1..$], uint.max );

        if(user_id == uint.max || setting_id == uint.max) continue;
    
        if(auto user = me.getUser(user_id))
        {
            auto settings = user.getSettings();
            if(settings) settings.setSetting(setting_id, value_string);
        }
    }
}

void displaySimpleSettingTable(HtmlOut o, uint source_id, Setting[] settings, HtmlElement elem, bool show_description = false)
{
    o("<form action=\"" ~ target_uri ~ "\" method=\"post\">\n");
    o("<table>\n");
    o("<tr><th>")(Phrase.Name)("</th><th>")(Phrase.Value)("</th>");
    if(show_description)
    {
        o("<th>")(Phrase.Description)("</th>");
    }
    o("</tr>\n");
    
    auto c = 0;
    foreach(setting; settings)
    {
        if(c%2) o("<tr class=\"odd\">\n");
        else o("<tr class=\"even\">\n");
        
        displaySimpleSettingRow(o, source_id, setting, elem, show_description);
        
        o("</tr>\n");
        c++;
    }
    o("</table>\n");
    
    o("<button type=\"submit\" name=\"to\" value=\"")(elem.getId)("\">");
    o(Phrase.Apply);
    o("</button>\n");
    o("</form>\n\n");
}

private void displaySimpleSettingRow(HtmlOut o, uint source_id, Setting s, HtmlElement elem, bool show_description)
{
    o("<td>")(s.getName)(":</td>\n");
    Setting.Type type = s.getType;
    uint setting_id = s.getId();
    Setting[] settings;
    
    if(type == Setting.Type.STRING || type == Setting.Type.NUMBER)
    {
        o("<td>");
        o("<input type=\"text\" name=\"")(source_id)(delim)(setting_id)("\" value=\"")(s.getValue)("\" />");
        o("</td>\n");
    }
    else if(type == Setting.Type.PASSWORD)
    {
        o("<td>");
        o("<input type=\"password\" name=\"")(source_id)(delim)(setting_id)("\" value=\"")(s.getValue)("\" />");
        o("</td>\n");
    }
    else if(type == Setting.Type.BOOL)
    {
        bool value = Convert.to!(bool)(s.getValue, false);
        o("<td>");
        o("<input type=\"radio\" name=\"")(source_id)(delim)(setting_id)("\" value=\"true\" ");
        o( (value) ? "checked=\"checked\" />": "/>")("On");
        o("<input type=\"radio\" name=\"")(source_id)(delim)(setting_id)("\" value=\"false\" ");
        o( (!value) ? "checked=\"checked\" />": "/>")("Off");
        o("</td>\n");
    }
    else if(type == Setting.Type.RADIO)
    {
        settings = s.getSettingArray;
        if(settings)
        {
            char[] selected = s.getValue();
            o("<td>\n");
            foreach(setting; settings)
            {
                char[] value = setting.getValue();
                char[] name = setting.getName();
                o("<input type=\"radio\" name=\"")(source_id)(delim)(setting_id)("\" value=\"")(value)("\" ");
                o( (value == selected) ? "checked=\"checked\" />": "/>")(name)("\n");
            }
            o("</td>\n");
        }
        else
        {
            o("<td>Invalid Format!</td>\n");
        }
    }
    else if(type == Setting.Type.CHECK)
    {
        settings = s.getSettingArray;
        if(settings)
        {
            char[] value = s.getValue();
            
            o("<td>\n");
            foreach(setting; settings)
            {
                bool is_selected = Convert.to!(bool)(setting.getValue, false);
                o("<input type=\"checkbox\" name=\"")(source_id)(delim)(setting_id)("\" value=\"")(setting.getValue)("\" ");
                o(is_selected ? "checked=\"checked\" />": "/>")(setting.getName)("\n");
            }
            o("</td>\n");
        }
        else
        {
            o("<td>Invalid Format!</td>\n");
        }
    }
    else if(type == Setting.Type.SELECT)
    {
        settings = s.getSettingArray;
        if(settings)
        {
            char[] selected = s.getValue();
            
            o("<td>\n");
            o("<select name=\"")(source_id)(delim)(setting_id)("\">\n");
            foreach(setting; settings)
            {
                char[] name = setting.getName();
                char[] value = setting.getValue();
                
                if(value == selected)
                {
                    o("<option value=\"")(value)("\" selected=\"selected\">")(name)("</option>\n");
                }
                else
                {
                    o("<option value=\"")(value)("\">")(name)("</option>\n");
                }
            }
            o("</select>");
            o("</td>\n");
        }
        else
        {
            o("<td>Invalid Format!</td>\n");
        }
    }
    else
    {
        o("<td>Unknown Format!</td>\n");
    }
    
    //description
    if(show_description)
    {
        o("<td>")(s.getDescription)("</td>\n");
    }
}

void displayComplexSetting(HtmlOut o, uint source_id, Setting s, HtmlElement elem, bool show_description = false)
{
    //name
    o("<h4>")(s.getName)(":</h4>\n");
    auto type = s.getType;
    Setting[] settings;
    
    if(type == Setting.Type.ORDER)
    {
        settings = s.getSettingArray;
        if(!settings) goto END;
        
        uint pos;
        uint last = s.getSettingCount() - 1;
        uint prev, next;
        foreach(setting; settings)
        {
            //calculate where the elements should move to
            prev = pos - 1;
            next = pos + 1;
            if(pos) o(" | ");
            else prev = last;
            if(pos == last) next = 0;
            
            o("<nobr>\n");
            o("<a href=\"" ~ target_uri ~ "?to=")(elem.getId)(AMP)(source_id)(delim)(s.getId)("=")(pos)(delim)(prev)("\">&larr;</a>");
            o(setting.getName);
            o("<a href=\"" ~ target_uri ~ "?to=")(elem.getId)(AMP)(source_id)(delim)(s.getId)("=")(pos)(delim)(next)("\">&rarr;</a>\n");
            o("</nobr>");
            pos++;
        }
        o("\n");
    }
    else if(type == Setting.Type.CHECK)
    {
        settings = s.getSettingArray;
        if(!settings) goto END;
        
        Setting[][] partition = getPartition!(Setting)(settings, 5);
        o("<form action=\"" ~ target_uri ~ "\" method=\"post\">\n");
        
        o("<table>\n");
        foreach(line; partition)
        {
            o("<tr>\n");
            foreach(setting; line)
            {
                o("<td>")(setting.getName)(":</td>\n");
                o("<td>");
                bool is_selected = Convert.to!(bool)(setting.getValue, false);
                o("<input type=\"checkbox\" name=\"")(source_id)(delim)(s.getId)("\" value=\"")(setting.getId)("\" ");
                o(is_selected ? "checked=\"checked\" />" : "/>");
                o("</td>\n");
            }
            o("</tr>\n");
        }
        o("</table>\n");
        
        o(BN);
        o("<button type=\"submit\" name=\"to\" value=\"")(elem.getId)("\">");
        o(Phrase.Apply);
        o("</button>\n");
        o("</form>\n");
    }
    END:
    
    //description
    if(show_description)
    {
        o(BBN);
        o(s.getDescription)("\n");
    }
}
