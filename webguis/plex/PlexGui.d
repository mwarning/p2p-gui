module webguis.plex.PlexGui;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/

import webserver.HttpRequest;
import webserver.HttpResponse;

import tango.io.Stdout;
import tango.io.FilePath;
import tango.io.device.File;
import tango.io.device.Conduit;
import tango.core.Array;
import tango.util.container.more.Stack;

import api.File;
import api.Client;
import api.User;
import api.Meta;
import api.Node;
import api.Host;

static import Main = webcore.Main;
static import Utils = utils.Utils;
import webcore.Webroot;
import webcore.Logger;
import webcore.MainUser;
import utils.Storage;

import webguis.plex.HtmlUtils;
import webguis.plex.HtmlElement;
import webguis.plex.HtmlFileBrowser;
import webguis.plex.HtmlDownloads;
import webguis.plex.HtmlServers;
import webguis.plex.HtmlClients;
import webguis.plex.HtmlTitlebar;
import webguis.plex.HtmlModuleSettings;
import webguis.plex.HtmlClientSettings;
import webguis.plex.HtmlUserSettings;
import webguis.plex.HtmlSettings;
import webguis.plex.HtmlConsole;
import webguis.plex.HtmlSearches;
import webguis.plex.HtmlPageRefresh;
import webguis.plex.HtmlUserManagement;
import webguis.plex.HtmlContainer;
import webguis.plex.HtmlAddLinks;
import webguis.plex.HtmlUploads;
import webguis.plex.HtmlQuickConnect;
import webguis.plex.HtmlTranslator;
import webguis.plex.HtmlLogout;

HtmlElement delegate()[ushort] module_loaders;

void core_init()
{
    if(PlexGui.all_css_styles.length == 0)
    {
        auto css_names = Webroot.getFileNames(resource_dir, ".css");
        
        //move "default.css" to array front
        auto pos = find(css_names, "default");
        if(pos && pos < css_names.length)
        {
            Utils.swapValues(css_names, cast(size_t) 0, cast(size_t) pos);
        }
        PlexGui.all_css_styles = css_names;
    }
    
    if(module_loaders.length) return;
    
    module_loaders = [
        Phrase.Titlebar : { return cast(HtmlElement) new HtmlTitlebar; },
        Phrase.FileBrowser : { return cast(HtmlElement) new HtmlFileBrowser; },
        Phrase.Downloads : { return cast(HtmlElement) new HtmlDownloads; },
        Phrase.Servers : { return cast(HtmlElement) new HtmlServers; },
        Phrase.Clients : { return cast(HtmlElement) new HtmlClients; },
        Phrase.Console : { return cast(HtmlElement) new HtmlConsole; },
        Phrase.Searches : { return cast(HtmlElement) new HtmlSearches; },
        Phrase.PageRefresh : { return cast(HtmlElement) new HtmlPageRefresh; },
        Phrase.UserManagement : { return cast(HtmlElement) new HtmlUserManagement; },
        Phrase.UserSettings : { return cast(HtmlElement) new HtmlUserSettings; },
        Phrase.ModuleSettings : { return cast(HtmlElement) new HtmlModuleSettings; },
        Phrase.ClientSettings : { return cast(HtmlElement) new HtmlClientSettings; },
        Phrase.Container : { return cast(HtmlElement) new HtmlContainer; },
        Phrase.AddLinks : { return cast(HtmlElement) new HtmlAddLinks; },
        Phrase.Uploads : { return cast(HtmlElement) new HtmlUploads; },
        Phrase.QuickConnect : { return cast(HtmlElement) new HtmlQuickConnect; },
        Phrase.Translator : { return cast(HtmlElement) new HtmlTranslator; },
        Phrase.Logout : { return cast(HtmlElement) new HtmlLogout; }
    ];
}

final class PlexGui : HtmlElement, Main.Gui
{
    HtmlElement[ushort] elements;
    
    uint client_id = 0;
    
    static const char[] title = "Plex GUI";
    char[] css_style = "default";
    
    //names of css themes in ./webroot/plex/
    static char[][] all_css_styles;
    
    //needed until we can use closures
    private ushort[] getElementIds()
    {
        return elements.keys;
    }
    
    private ushort[] getAllElementIds()
    {
        ushort[] all;
        foreach(i; module_loaders.keys)
        {
            all ~= cast(ushort) i;
        }
        return all;
    }
    
    this(Storage s)
    {
        core_init();
        
        //set defaults
        display_in_titlebar = false;
        
        super(Phrase.Core, "");
        
        elements[this.getId] = this;
        
        addSetting(Phrase.style, &all_css_styles, &css_style);
        addSetting(Phrase.Load_Modules, &getElementIds, &getAllElementIds, &setModules);
        
        load(s);
    }
    
    char[] getGuiName()
    {
        return "Plex";
    }
    
    void load(Storage s)
    {
        s.load("css_style", &setCssStyle);
        
        auto module_settings = new Storage();
        s.load("modules", module_settings);
        
        foreach(char[] name, Storage settings; module_settings)
        {
            auto id = Dictionary.toId(name);
            auto mod = loadModule(id);
            if(mod) mod.load(settings);
        }
        
        if(elements.length < 2)
        {
            //load default modules
            loadModules( [
                Phrase.Titlebar, Phrase.Downloads, Phrase.Searches, Phrase.Servers,
                Phrase.Clients, Phrase.Console, Phrase.AddLinks, Phrase.PageRefresh, Phrase.FileBrowser,
                Phrase.UserSettings, Phrase.ModuleSettings, Phrase.ClientSettings, Phrase.Logout
            ] );
        }
    }
    
    void save(Storage s)
    {
        s.save("css_style", &css_style);
        
        auto module_settings = new Storage();
        foreach(id, element; elements)
        {
            if(element is this) continue;
            auto storage = new Storage();
            element.save(storage);
            auto name = Dictionary.toString(id);
            module_settings.save(name, storage); //element.getCssIdName
        }
        s.save("modules", module_settings);
    }
    
    void setCssStyle(char[] css_style)
    {
        if(Utils.is_in(all_css_styles, css_style))
        {
            this.css_style = css_style;
        }
    }
    
    /*
    * Notify all elements that an element is new or will be removed
    */
    private void notifyAllAbout(HtmlElement[] items)
    {
        if(items.length == 0) return;
        foreach(element; elements)
        {
            element.changed(items);
        }
    }
    
    private void setModules(ushort[] ids)
    {
        auto loaded = elements.keys;
        auto unload = Utils.diff(loaded, ids);
        auto load = Utils.diff(ids, loaded);

        unloadModules(unload);
        loadModules(load);
    }
    
    void unloadModules(ushort[] ids)
    {
        HtmlElement[] unloaded;
        foreach(id; ids)
        {
            if(id == this.getId) continue;
            auto tmp = getModule(id);
            if(tmp)
            {
                tmp.remove = true; //mark as to be removed
                unloaded ~= tmp;
                elements.remove(id);
            }
        }
        notifyAllAbout(unloaded);
    }
    
    HtmlElement loadModule(ushort id)
    {
        if(id == this.getId) return null;
        
        HtmlElement element = null;
        HtmlElement[] all = elements.values;
        
        if(auto loader_ptr = (id in module_loaders))
        {
            element = (*loader_ptr)();
            elements[element.getId] = element;
            element.changed(all);
            notifyAllAbout([element]);
        }
        
        return element;
    }
    
    void loadModules(ushort[] ids)
    {
        if(elements.length + ids.length > 30)
        {
            Logger.addWarning("PlexGui: Too many modules to load!");
            return;
        }
        
        HtmlElement[] all = elements.values;
        Stack!(HtmlElement, 32) loaded;
        
        foreach(id; ids)
        {
            if(id == this.getId) continue;
            
            auto loader_ptr = (id in module_loaders);
            if(loader_ptr)
            {
                auto tmp = (*loader_ptr)();
                elements[tmp.getId] = tmp;
                loaded.push(tmp);
                tmp.changed(all);
            }
        }
        notifyAllAbout(loaded.slice);
    }
    
    HtmlElement getModule(ushort id)
    {
        auto tmp = (id in elements);
        return tmp ? *tmp : null;
    }
    
    void setClientId(uint id)
    {
        client_id = id;
    }

    Node getClient()
    {
        auto user = cast(MainUser) Main.getThreadOwner();
        if(user)
        {
            return user.getNodes.getNode(Node_.Type.CORE, client_id);
        }
        else
        {
            return null;
        }
    }
    
    uint getClientId()
    {
        return client_id;
    }

    bool process(HttpRequest req, Session session, HttpResponse res)
    {
        char[] uri = req.getUri();
        
        if(uri.length == 0 || uri == "/" || uri == "/plex/")
        {
            //redirect
            res.setCode(HttpResponse.Code.FOUND);
            res.addHeader("Location: /plex");
            return true;
        }
        else if(Utils.is_prefix(uri, "/plex/"))
        {
            Webroot.getFile(res, uri);
            return true;
        }
        else if(uri != "/plex")
        {
            return false;
        }
        
        //may set source variable in session
        handle(req, session);
        
        if(session.getSourceStream())
        {
            session.sendFile(res);
            return true;
        }
        
        handle(res, session);
        return true;
    }
    
    void handle(HttpRequest req, Session session)
    {
        uint to = req.getParameter!(uint)("to", 0);
        if(to == 0 || to == this.getId) return;
        
        auto item = getModule(to);
        if(item) try
        {
            item.handle(req, session);
        }
        catch(Object o)
        {
            Logger.addError("PlexGui: {}: '{}'", item.getCssIdString, o.toString);
        }
    }
    
    void handle(HttpResponse res, Session session)
    {
        //select a client if none is selected yet
        if(client_id == 0)
        {
            auto nodes = session.getUser.getNodes();
            auto clients = cast(Client[]) nodes.getNodeArray(Node_.Type.CORE, Node_.State.ANYSTATE, 0);
            foreach(client; clients)
            {
                if(client.getState == Node_.State.CONNECTED)
                {
                    client_id = client.getId();
                }
            }
        }
        
        res.setContentType("text/html");
        
        //disable caching
        res.addHeader("Cache-Control: no-cache, must-revalidate");
        res.addHeader("Pragma: no-cache");

        HtmlOut o = {res.getWriter(), &session.getUser.translate};

        o("<!DOCTYPE html>\n\n");
        o("<html>\n");
        o("<head>\n");
        o("<meta http-equiv=\"Content-Type\" content=\"text/html;charset=utf-8\" />\n");
        o("<title>" ~ title ~ "</title>\n");
        o("<script type=\"text/javascript\" src=\"" ~ resource_dir ~ "scripts.js\"></script>\n");
        o("<link rel=\"stylesheet\" href=\"" ~ resource_dir)(css_style)(".css\" type=\"text/css\" media=\"screen\" />\n");
        o("</head>\n\n");
        o("<body>\n");
        
        foreach(item; elements)
        {
            if(!item.visible) continue;
            o("<div id=\"")(item.getCssIdString)("\" class=\"")(item.getCssClassString)("\">\n");
            try
            {
                item.handle(res, session);
            }
            catch(Object o)
            {
                Logger.addError("PlexGui: {}: '{}'", item.getCssIdString, o.toString);
            }
            o("</div>\n\n");
        }
        
        insertFooter(o);
        
        o("</body>\n\n");
        o("</html>");
    }
    
    void insertFooter(HtmlOut o)
    {
        o("<div id=\"Footer\">\n");
        o("<hr />\n");
        
        o("<a href=\"")(Host.main_weblink)("\">"); // target=\"_blank\" >");
        o(Host.main_name);
        o("</a> ");
        o(Host.main_version);
        
        auto client = this.getClient();
        if(client)
        {
            o(" |  ");
            o(client.getSoftware);
            if(client.getState == Node_.State.CONNECTED)
            {
                o(" ")(client.getVersion);
                auto prot = client.getProtocol();
                if(prot.length)
                {
                    o(" [")(prot)("]");
                }
                o(" |  ");
                if(auto name = client.getName)
                {
                    o(client.getName)("@");
                }
                o(client.getHost)(":")(client.getPort);
            }
        }
        
        o("\n</div>\n\n");
    }
}
