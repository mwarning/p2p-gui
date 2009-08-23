module webguis.plex.HtmlConsole;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/

import webserver.HttpRequest;
import webserver.HttpResponse;

import tango.io.Stdout;
import tango.io.FileSystem;

import api.User;
import api.File;
import api.Node;
import api.Meta;

import webguis.plex.PlexGui;
import webguis.plex.HtmlElement;
import webguis.plex.HtmlUtils;

final class HtmlConsole : HtmlElement
{
    bool cmd_on_top = true;
    
    this()
    {
        super(Phrase.Console);
        addSetting(Phrase.cmd_on_top, &cmd_on_top);
    }
    
    void save(Storage s)
    {
        s.save("cmd_on_top", &cmd_on_top);
    }
    
    void load(Storage s)
    {
        s.load("cmd_on_top", &cmd_on_top);
    }
    
    void handle(HttpRequest req, Session session)
    {
        char[] command = req.getParameter("command");
        if(!command.length) return;
        
        auto client = session.getGui!(PlexGui).getClient();
        Metas metas;
        if(client) metas = client.getMetas;
        if(metas) metas.addMeta(Meta_.Type.CONSOLE, command, 0);
    }
    
    void handle(HttpResponse res, Session session)
    {
        HtmlOut o = { res.getWriter(), &session.getUser.translate};
        auto client = session.getGui!(PlexGui).getClient;
        
        if(client is null)
        {
            o("<b>")(Phrase.Not_Available)("</b>\n");
            return;
        }
        
        Metas metas;
        Meta[] lines;
        if(client) metas = client.getMetas();
        if(metas) lines = metas.getMetaArray(Meta_.Type.CONSOLE, Meta_.State.ANYSTATE, 0);

        if(lines)
        {
            if(cmd_on_top) displayForm(o);
            
            o("<textarea cols=\"150\" rows=\"35\" readonly=\"readonly\">\n");
            foreach(line; lines)
            {
                o(line.getMeta)("\n");
            }
            o("</textarea>\n");
            
            if(!cmd_on_top) displayForm(o);
        }
        else
        {
            o("<b>")(Phrase.Not_Supported)("<b>");
        }
    }
    
    void displayForm(HtmlOut o)
    {
        o("<form action=\"" ~ target_uri ~ "\" method=\"post\">");
        o("<input type=\"text\" name=\"command\" size=\"50\" value=\"\" />   ");
        o("<button type=\"submit\" name=\"to\" value=\"")(this.getId)("\">");
        o(Phrase.Send);
        o("</button>\n");
        o("</form>\n");
        
        o(BN);
    }
}