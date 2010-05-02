module webguis.plex.HtmlClients;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import tango.core.Array;
import tango.io.Stdout;
import tango.text.Ascii;

import webserver.HttpRequest;
import webserver.HttpResponse;

import api.Client;
import api.File;
import api.Node;
import api.User;
import api.Host;

static import Main = webcore.Main;
import webguis.plex.PlexGui;
import webguis.plex.HtmlElement;
import webguis.plex.HtmlUtils;
import webguis.plex.HtmlServers;

Column delegate()[ushort] column_loaders;

void downloads_init()
{
    if(column_loaders.length) return;
    
    column_loaders = [
        Phrase.Id : { return cast(Column) new IdColumn; },
        Phrase.Check : { return cast(Column) new CheckBoxColumn; },
        Phrase.Name : { return cast(Column) new NameColumn; },
        Phrase.IP_Address : { return cast(Column) new AddressColumn; },
        Phrase.Downloaded : { return cast(Column) new DownloadedColumn; },
        Phrase.Uploaded : { return cast(Column) new UploadedColumn; },
        Phrase.DownloadRate : { return cast(Column) new DownloadRateColumn; },
        Phrase.UploadRate : { return cast(Column) new UploadRateColumn; },
        Phrase.Users : { return cast(Column) new UsersColumn; },
        Phrase.Software : { return cast(Column) new SoftwareColumn; },
        Phrase.Connect : { return cast(Column) new ConnectColumn; }
    ];
}


final class HtmlClients : HtmlElement
{
private:
    
    Column[] columns;
    bool delegate(Node, Node) compare;
    bool invert_compare;

    ushort[] getAllColumnIds()
    {
        return column_loaders.keys;
    }

    ushort[] getColumnIds()
    {
        ushort[] ids;
        ids.length = columns.length;
        foreach(i, column; columns)
        {
            ids[i] = cast(ushort) column.getName;
        }
        return ids;
    }
    
    void setColumns(ushort[] ids)
    {
        //preserve order
        ids = Utils.applyOrder(ids, getColumnIds);
        
        Column[] columns;
        foreach(id; ids)
        {
            auto loader_ptr = (id in column_loaders);
            if(loader_ptr)
            {
                columns ~= (*loader_ptr)();
            }
        }
        this.columns = columns;
    }

public:
    
    this()
    {
        super(Phrase.Clients);
        
        downloads_init();
        
        setColumns ([
            Phrase.Check, Phrase.Id, Phrase.Software, Phrase.Name, Phrase.IP_Address, Phrase.Connect
        ]);
        
        compare = &columns[0].compare;
        
        addSetting(Phrase.column_order, &columns);
        addSetting(Phrase.show_columns, &getColumnIds, &getAllColumnIds, &setColumns);
    }
    
    void handle(HttpRequest req, Session session)
    {
        auto gui = session.getGui!(PlexGui)();
        assert(gui);
        
        char[] action = req.getParameter("do");
        if(!action.length) return;
        
        uint[] ids = req.getParameter!(uint[])("ids");
        auto nodes = session.getUser.getNodes();

        if(nodes is null) return;
        
        if(action == "connect")
        {
            foreach(id; ids)
            {
                nodes.connect(Node_.Type.CORE, id);
            }
            
            //select first when nothing selected yet
            if(gui.getClient() is null && ids.length)
            {
                gui.setClientId(ids[0]);
            }
        }
        else if(action == "disconnect")
        {
            foreach(id; ids)
            {
                nodes.disconnect(Node_.Type.CORE, id);
            }
        }
        else if(action == "select")
        {
            if(ids.length) gui.setClientId(ids[0]);
        }
        else if(action == "enable")
        {
            uint id = req.getParameter!(uint)("id");
            auto client = gui.getClient();
            if(client) client.connect(Node_.Type.NETWORK, id);
        }
        else if(action == "disable")
        {
            uint id = req.getParameter!(uint)("id");
            auto client = gui.getClient();
            if(client) client.disconnect(Node_.Type.NETWORK, id);
        }
        else if(session.getUser.getType == User_.Type.ADMIN)
        {
            if(action == "remove")
            {
                foreach(id; ids)
                {
                    nodes.removeNode(Node_.Type.CORE, id);
                }
            }
            else if(action == "shutdown" && req.isParameter("sure"))
            {
                foreach(id; ids)
                {
                    auto client = cast(Client) nodes.getNode(Node_.Type.CORE, id);
                    if(client) client.shutdown();
                }
            }
            else if(action == "add")
            {
                char[] host = req.getParameter("host");
                ushort port = req.getParameter!(ushort)("port");
                char[] type = req.getParameter("type");
                char[] username = req.getParameter("user");
                char[] password = req.getParameter("pass");
                
                Client.Type ctype;
                
                switch(toUpper(type))
                {
                    case "MLDONKEY": ctype = Client.Type.MLDONKEY; break;
                    case "AMULE": ctype = Client.Type.AMULE; break;
                    case "GIFT": ctype = Client.Type.GIFT; break;
                    case "RTORRENT": ctype = Client.Type.RTORRENT; break;
                    case "TRANSMISSION": ctype = Client.Type.TRANSMISSION; break;
                    default: return;
                }
            
                nodes.addNode (
                    cast(Node_.Type) ctype,
                    host, port, username, password
                );
            }
        }
    }

    void handle(HttpResponse res, Session session)
    {
        auto client_sel = session.getGui!(PlexGui).getClient();
        HtmlOut o;
        o.init(res.getWriter(), &session.getUser.translate);
        
        Node[] clients = null;
        
        if(auto nodes = session.getUser.getNodes)
        {
            clients = nodes.getNodeArray(Node_.Type.CORE, Node_.State.ANYSTATE, 0);
        }
        else
        {
            o("<b>")(Phrase.Not_Supported)("</b>\n");
            return;
        }
        
        if(clients is null)
        {
            o("<b>")(Phrase.Not_Available)("</b>\n");
            return;
        }
        
        o("<form action=\"" ~ target_uri ~ "\" method=\"post\">\n");
        o("<input type=\"hidden\" name=\"to\" value=\"")(this.getId)("\"/>\n");
        
        //print clients
        o("<table class=\"mid\">\n");
        
        //insert checkbox selectors
        o("<tr class=\"selectors\">\n");
        o("<td colspan=\"")(columns.length)("\">");
        insertJsSelectors(o);
        o("</td>\n");
        o("</tr>\n");
        
        o("<tr>\n");
        foreach(i, col; columns)
        {
            o("<th><a href=\"" ~ target_uri ~ "?to=")(this.getId)(AMP~"do=sort")(AMP~"id=")(i)("\">");
            o(col.getName);
            o("</a></th>\n");
        }
        o("</tr>\n");

        uint mod_id = this.getId();
        uint client_id = client_sel ? client_sel.getId : 0;
        
        sort(clients, compare);
        if(invert_compare) clients.reverse;
        
        foreach(c, client; clients)
        {
            if(c%2) o("<tr class=\"odd");
            else o("<tr class=\"even");
            if(client_id == client.getId)
            {
                o(" selected");
            }
            o("\">\n");
            
            foreach(col; columns)
            {
                col.getCell(o, client, mod_id);
            }
            
            o("</tr>\n");
        }
        
        if(clients.length == 0)
        {
            o("<tr class=\"even\"><td colspan=\"")(columns.length)("\">");
            o(Phrase.No_Items_Found);
            o("<td><tr>\n");
        }
        
        //insert checkbox selectors
        if(clients.length > 15)
        {
            o("<tr class=\"selectors\">\n");
            o("<td colspan=\"")(columns.length)("\">");
            insertJsSelectors(o);
            o("</td>\n");
            o("</tr>\n");
        }
        
        o("</table>\n");
        
        o("<button type=\"submit\" name=\"do\" value=\"connect\">");
        o(Phrase.Connect);
        o("</button>\n");
        
        o("<button type=\"submit\" name=\"do\" value=\"disconnect\">");
        o(Phrase.Disconnect);
        o("</button>\n");
        
        o("<button type=\"submit\" name=\"do\" value=\"select\">");
        o(Phrase.Select);
        o("</button>\n");
        
        if(session.getUser.getType == User_.Type.ADMIN)
        {
            o("<button type=\"submit\" name=\"do\" value=\"remove\">");
            o(Phrase.Remove);
            o("</button>\n");
            
            o("<button type=\"submit\" name=\"do\" value=\"shutdown\">");
            o(Phrase.Shutdown);
            o("</button>\n");
            
            o("Sure? <input type=\"checkbox\" name=\"sure\" value=\"\"/>\n");
            
            o("</form>\n");
            
            insertAddClientMenu(o);
        }
        else
        {
            o("</form>\n");
        }
        
        insertNetworks(o, client_sel);
    }
    
    private void insertAddClientMenu(HtmlOut o)
    {
        o("<form action=\"" ~ target_uri ~ "\" method=\"post\">\n");
        o("<input type=\"hidden\" name=\"to\" value=\"")(this.getId)("\"/>\n");
        
        o("<table>\n");
        o("<tr>\n");
            o("<td>")(Phrase.Host)(":</td><td><input type=\"text\" name=\"host\" /><td>\n");
            o("<td>")(Phrase.Port)(":</td><td><input type=\"text\" name=\"port\" /><td>\n");
        o("</tr>\n");
        o("<tr>\n");
            o("<td>")(Phrase.User)(":</td><td><input type=\"text\" name=\"user\" /><td>\n");
            o("<td>")(Phrase.Password)(":</td><td><input type=\"password\" name=\"pass\" /><td>\n");
        o("</tr>\n");
        o("</table>\n");
        
        o("<select name=\"type\">\n");
        foreach(ref c; Host.client_infos)
        {
            o("<option>")(c.name)("</option>\n");
        }
        o("</select>\n");
        
        o("<button type=\"submit\" name=\"do\" value=\"add\">");
        o(Phrase.Add);
        o("</button>\n");
        
        o("</form>\n");
    }
    
    private void insertNetworks(HtmlOut o, Node client_sel)
    {
        Node[] networks;
        
        if(client_sel)
        {
            networks = client_sel.getNodeArray(Node_.Type.NETWORK, Node_.State.ANYSTATE, 0);
        }
        
        if(networks is null) return;
        
        //print networks
        o("<table class=\"mid\">\n");
        o("<tr>");
        o("<th>")(Phrase.Id)("</th>");
        o("<th>")(Phrase.Network)("</th>"); //for network image
        o("<th>")(Phrase.Name)("</th>");
        o("<th>")(Phrase.Downloaded)("</th>");
        o("<th>")(Phrase.Uploaded)("</th>");
        o("</tr>\n");

        foreach(c, network; networks)
        {
            if(c%2) o("<tr class=\"odd\">\n");
            else  o("<tr class=\"even\">\n");
            
            o("<td>")(network.getId)("</td>\n");
            bool connected = (network.getState == Node_.State.CONNECTED);
            
            o("<td><a href=\"" ~ target_uri ~ "?to=")(this.getId)(AMP~"do=")(connected ? "disable" : "enable")(AMP~"id=")(network.getId)("\">\n");
                o("<img src=\"/net_img/")(network.getName);
                o(connected ? "_connected.gif\" />\n" : "_disabled.gif\" />\n");
            o("</a></td>\n");
            
            o("<td>")(network.getName)("</td>\n");
            o("<td>")(formatSize(network.getDownloaded))("</td>\n");
            o("<td>")(formatSize(network.getUploaded))("</td>\n");
            
            o("</tr>\n");
        }
        
        if(networks.length == 0)
        {
            o("<tr class=\"even\" ><td colspan=\"5\">");
            o(Phrase.No_Items_Found);
            o("</td></tr>\n");
        }
        
        o("</table>\n");
    }
}
