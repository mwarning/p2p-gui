module webguis.jay.JayGui;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import tango.io.Stdout;

import webserver.HttpRequest;
import webserver.HttpResponse;

import api.File;
import api.User;
import api.Meta;
import api.Node;
import api.Host;

static import Main = webcore.Main;
static import Utils = utils.Utils;
import utils.Storage;
import webcore.Webroot;
import webcore.JsonRPC;
import webcore.Session;
import webcore.Dictionary;
import webcore.Logger;


/*
* Server side part of the Jay gui
*/
class JayGui : Main.Gui
{
    static JsonRPC json_rpc;
    
    this(Storage s)
    {
        if(json_rpc is null)
        {
            json_rpc = new JsonRPC();
        }
        
        load(s);
    }
    
    char[] getGuiName()
    {
        return "Jay";
    }
    
    void save(Storage s)
    {
    }
    
    void load(Storage s)
    {
    }
    
    bool process(HttpRequest req, Session session, HttpResponse res)
    {
        char[] uri = req.getUri();
        
        if(uri.length == 0 || uri == "/" || uri == "/jay/" || uri == "/jay")
        {
            //redirect
            res.setCode(HttpResponse.Code.MULTIPLE_CHOICES);
            res.addHeader("Location: /jay/index.html");
            return true;
        }
        else if(uri == "/jay/rpc")
        {
            handle(req, session, res);
            return true;
        }
        else if(Utils.is_prefix(uri, "/jay/"))
        {
            Webroot.getFile(res, uri);
            return true;
        }
        
        return false;
    }
    
    void handle(HttpRequest req, Session session, HttpResponse res)
    {
        if(req.isParameter("download"))
        {
            session.sendFile(res);
            return;
        }
        
        if(req.getHttpMethod != HttpMethod.POST)
        {
            Logger.addWarning("JayGui: Only POST is supported.");
            return;
        }
        
        auto o = res.getWriter();
        char[] query = req.getBody();
        
        res.setContentType("text/x-json");
        
        json_rpc.parse(cast(void delegate(char[])) &o.emit, cast(User) session.getUser, query);
    }
}
