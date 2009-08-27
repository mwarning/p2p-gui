module webguis.plex.HtmlPageRefresh;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/

import tango.core.Array;
import tango.io.Stdout;

import api.File;
import api.User;

import webserver.HttpRequest;
import webserver.HttpResponse;

import webguis.plex.PlexGui;
import webguis.plex.HtmlElement;
import webguis.plex.HtmlUtils;
import webguis.plex.HtmlUtils;
import webcore.Logger;
import utils.Utils;


/*
* Display a site refresh option.
* Get handled by HtmlTitleBar.
*/
final class HtmlPageRefresh : HtmlElement
{
private:
    uint min_refresh = 5;
    bool use_javascript;
    
    //uint refresh;
    uint[uint] refresh_times;
    
    struct Pair
    {
        uint first;
        char[] second;
    }
    
    static const Pair[] pairs = [{0, "&infin;"}, {2, "2"}, {5, "5"}, {10, "10"}, {30, "30"}, {60, "60"}, {120, "120"}];
    
    public this()
    {
        super(Phrase.PageRefresh, "");
        
        display_in_titlebar = false;
        visible = false;
        
        addSetting(Phrase.min_refresh, &min_refresh);
        addSetting(Phrase.use_javascript, &use_javascript);
    }
    
    override public void handle(HttpRequest req, Session session)
    {
        uint refresh = req.getParameter!(uint)("refresh");
        
        //get html element we want to set the refresh for
        foreach(mod; session.getGui!(PlexGui).elements)
        {
            if(!mod.display_in_titlebar || !mod.visible) continue; //filter out always displayed
            uint id = mod.getId();
            if(refresh && refresh < min_refresh)
            {
                Logger.addInfo("HtmlPageRefresh: Page refresh too low!");
                refresh = min_refresh;
            }
            refresh_times[id] = refresh;
            //this.refresh = refresh;
        }
    }
    
    override public void handle(HttpResponse res, Session session)
    {
        uint refresh = 0;
        //get refresh time for current html element
        foreach(mod; session.getGui!(PlexGui).elements)
        {
            if(!mod.display_in_titlebar || !mod.visible) continue;
            uint id = mod.getId();
            
            auto ptr = (id in refresh_times);
            if(ptr) refresh = *ptr;
            break;
        }
        
        HtmlOut o = {res.getWriter(), &session.getUser.translate};
        
        o("<form action=\"" ~ target_uri ~ "\" method=\"get\" id=\"PageRefresh\" name=\"PageRefresh\">\n"); //name for JS submit
        o("<input type=\"hidden\" name=\"to\" value=\"")(this.getId)("\">\n");
        
        char[] text = o.translate(Phrase.Refreshing_every_x_seconds);
        auto pos = find(text, "{}");
        
        //insert first part text
        o(text[0..pos]);
        
        if(use_javascript)
        {
            o("\n<select name=\"refresh\" onchange=\"javascript:document.PageRefresh.submit()\" style=\"width: 50px\">\n");
        }
        else
        {
            o("\n<select name=\"refresh\" style=\"width: 50px\">\n");
        }
        
        foreach(pair; pairs)
        {
            if(pair.first != 0 && pair.first < min_refresh) continue;
            if(pair.first == refresh)
            {
                o("<option value=\"")(pair.first)("\" selected=\"selected\">");
            }
            else
            {
                o("<option value=\"")(pair.first)("\">");
            }
            o(pair.second);
            o("</option>\n");
        }
        o("</select>\n");
        
        //insert last text part
        if(pos != text.length)
        {
            o(text[pos+2..$])("\n");
        }

        if(!use_javascript)
        {
            o("<button type=\"submit\" name=\"_\" value=\"\">");
            o(Phrase.Refresh);
            o("</button>\n");
        }
        o("</form>\n");
        
        if(refresh) o("<meta http-equiv=\"refresh\" content=\"")(refresh)("; URL=" ~ target_uri ~ "\" />\n");
    }
}
