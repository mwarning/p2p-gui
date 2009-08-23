module webguis.plex.HtmlAddLinks;

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
static import tango.io.device.File;

import api.Client;
import api.User;
import api.File;
import api.Node;
import api.Meta;

import webguis.plex.PlexGui;
import webguis.plex.HtmlElement;
import webguis.plex.HtmlUtils;


final class HtmlAddLinks : HtmlElement
{
    this()
    {
        super(Phrase.AddLinks);
    }
    
    void handle(HttpRequest req, Session session)
    {
        char[] action = req.getParameter("do");
        auto client = cast(Client) session.getGui!(PlexGui).getClient();
        if(client is null) return;
        
        if(action == "start_uploaded_torrents")
        {
            //start transmitted files
            char[][] files = req.getFiles();
            foreach(name; files) if(Utils.is_suffix(name, ".torrent")) try
            {
                auto file = new tango.io.device.File.File(name);
                
                if(file.length > 200 * 1024)
                    continue;
                
                auto data = new char[](file.length);
                file.read(data);
                client.addLink(cast(char[]) data);
            }
            catch(Exception e){}
        }
        else if(action == "start_link")
        {
            char[] link = req.getParameter("link");
            client.addLink(link);
        }
    }
    
    void handle(HttpResponse res, Session session)
    {
        HtmlOut o = {res.getWriter(), &session.getUser.translate};
        
        if(session.getGui!(PlexGui).getClientId == 0)
        {
            o("<b>")(Phrase.Not_Available)("</b>\n");
            return;
        }
        
        o("<form action=\"" ~ target_uri ~ "\" method=\"get\">\n\n");
        o("<input type=\"hidden\" name=\"to\" value=\"")(this.getId)("\" />\n");
        o("<input name=\"link\" type=\"text\">\n")(SP2);
        o("<button type=\"submit\" name=\"do\" value=\"start_link\">");
        o(Phrase.Load_Link);
        o("</button>\n");
        o("</form>\n");
        
        
        o("<form enctype=\"multipart/form-data\" action=\"" ~ target_uri ~ "\" method=\"post\">\n\n");
        o("<input type=\"hidden\" name=\"to\" value=\"")(this.getId)("\" />\n");
        o("<input name=\"userfile\" type=\"file\">\n")(SP2);
        o("<button type=\"submit\" name=\"do\" value=\"start_uploaded_torrents\">");
        o(Phrase.Load_Torrent);
        o("</button>\n");
        o("<input type=\"hidden\" name=\"MAX_FILE_SIZE\" value=\"")(100*1024)("\">\n");
        o("</form>\n");
    }
}
