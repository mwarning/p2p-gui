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
    }
    
    void handle(HttpResponse res, Session session)
    {
        HtmlOut o;
        o.init(res.getWriter(), &session.getUser.translate);
        
        if(Main.use_basic_auth)
        {
            o("<b><center>Please clear the browser cache to logout.</center></b>\n");
        }
        else if(auto titlebar = cast(HtmlTitlebar) session.getGui!(PlexGui).getModule(Phrase.Titlebar))
        {
           //make sure this site isn't displayed on the next login
            titlebar.resetSelected();
            SessionManager.invalidateSession(); //logout
            o("<meta http-equiv=\"refresh\" content=\"0\" />\n");
        }
    }
}
