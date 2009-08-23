module webguis.plex.HtmlQuickConnect;

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

import api.Client;
import api.User;
import api.File;
import api.Node;
import api.Meta;

import webguis.plex.PlexGui;
import webguis.plex.HtmlElement;
import webguis.plex.HtmlUtils;
import webcore.SessionManager;

/*
* Show a connect/disconnect button
* on the navigation bar for the first
* available client.
*/
final class HtmlQuickConnect : HtmlElement
{
    this()
    {
        super(Phrase.QuickConnect);
        exec_only = true;
    }
    
    override Phrase getName()
    {
        const Phrase def = Phrase.Nothing_Selected;
        
        auto session = SessionManager.getThreadSession();
        if(session is null) return def;
        auto client = session.getGui!(PlexGui).getClient();
        if(client is null) return def;
        
        switch(client.getState)
        {
            case Node_.State.CONNECTED:
                return Phrase.Disconnect;
            case Node_.State.DISCONNECTED:
                return Phrase.Connect;
            default:
                return def;
        }
    }
    
    void handle(HttpRequest req, Session session)
    {
        auto client = cast(Client) session.getGui!(PlexGui).getClient();
        if(client is null) return;
        
        switch(client.getState)
        {
            case Node_.State.CONNECTED:
                client.disconnect();
                break;
            case Node_.State.DISCONNECTED:
                client.connect();
                break;
            default:
        }
    }
    
    void handle(HttpResponse res, Session session) {}
}