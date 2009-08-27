module webguis.plex.HtmlLogout;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/

import webserver.HttpRequest;
import webserver.HttpResponse;

import tango.io.Stdout;

static import Main = webcore.Main;

import webguis.plex.HtmlElement;
import webguis.plex.HtmlUtils;


/*
* Logout, remove current session.
*/
final class HtmlLogout : HtmlElement
{
    this()
    {
        exec_only = true;
        super(Phrase.Logout);
    }
    
    void handle(HttpRequest req, Session session)
    {
        Main.invalidateSession();
    }
    
    void handle(HttpResponse res, Session session)
    {
        //Main.invalidateSession();
        //HtmlOut o = {res.getWriter(), &session.getUser.translate};
        //o("<meta http-equiv=\"refresh\" content=\"0;url=/\" />\n");
    }
}
