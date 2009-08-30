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

import webcore.SessionManager;

import webguis.plex.HtmlElement;
import webguis.plex.HtmlUtils;
import webguis.plex.HtmlTitlebar;


/*
* Logout, remove current session.
*/
final class HtmlLogout : HtmlElement
{
    this()
    {
        //exec_only = true;
        super(Phrase.Logout);
    }
    
    void handle(HttpRequest req, Session session)
    {
        SessionManager.invalidateSession();
    }
    
    void handle(HttpResponse res, Session session)
    {
        if(Main.use_basic_auth)
        {
            HtmlOut o = {res.getWriter(), &session.getUser.translate};
            o("<b><center>Please clear the browser cache to logout.</center></b>\n");
        }
        
        /*
        auto titlebar = cast(HtmlTitlebar) session.getGui!(PlexGui).getModule(Phrase.Titlebar);
        if(titlebar)
        {
            //make sure this site isn't displayed on the next login
            titlebar.resetSelected();
        }
        
        if(SessionManager.invalidateSession())
        {
            HtmlOut o = {res.getWriter(), &session.getUser.translate};
            o("<meta http-equiv=\"refresh\" content=\"1\" />\n");
        }
        */
    }
}
