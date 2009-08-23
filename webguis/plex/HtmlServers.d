module webguis.plex.HtmlServers;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/

import tango.core.Array;
import tango.io.Stdout;
import tango.io.protocol.Writer;

import webserver.HttpRequest;
import webserver.HttpResponse;

import api.File;
import api.Node;
import api.User;

import Main = webcore.Main;
import webcore.MainUser;
import webcore.Dictionary;

import webguis.plex.PlexGui;
import webguis.plex.HtmlElement;
import webguis.plex.HtmlUtils;

Column delegate()[ushort] column_loaders;

void servers_init()
{
    if(column_loaders.length) return;
    
    column_loaders = [
        Phrase.Id : { return cast(Column) new IdColumn; },
        Phrase.Check : { return cast(Column) new CheckBoxColumn; },
        Phrase.Name : { return cast(Column) new NameColumn; },
        Phrase.Flag : { return cast(Column) new FlagColumn; },
        Phrase.IP_Address : { return cast(Column) new AddressColumn; },
        Phrase.Description : { return cast(Column) new DescriptionColumn; },
        Phrase.Users : { return cast(Column) new UsersColumn; },
        Phrase.Files : { return cast(Column) new FilesColumn; },
        Phrase.Action : { return cast(Column) new ActionColumn; },
        Phrase.Networks : { return cast(Column) new NetworksColumn; },
        Phrase.Uploaded : { return cast(Column) new UploadedColumn; },
        Phrase.Ping : { return cast(Column) new PingColumn; },
        Phrase.DownloadRate : { return cast(Column) new DownloadRateColumn; },
        Phrase.UploadRate : { return cast(Column) new UploadRateColumn; },
        Phrase.Software : { return cast(Column) new SoftwareColumn; }
    ];
}

final class HtmlServers : HtmlElement
{
    Node_.State show_state = Node_.State.CONNECTED;
    
    Column[] columns;
    
    bool delegate(Node, Node) compare;
    bool invert_compare;
    uint network_id; //not used yet
    
    ushort[] getAllColumnIds()
    {
        return column_loaders.keys;
    }

    ushort[] getColumnIds()
    {
        ushort[] ids;
        foreach(column; columns)
        {
            ids ~= cast(ushort) column.getName();
        }
        return ids;
    }
    
    this()
    {
        super(Phrase.Servers);
        servers_init();
        
        setColumns( [Phrase.Check, Phrase.Flag, Phrase.Name,
            Phrase.Description, Phrase.IP_Address, Phrase.Users, Phrase.Files] );
        
        compare = &columns[0].compare;
        
        addSetting(Phrase.column_order, &columns);
        addSetting(Phrase.show_columns, &getColumnIds, &getAllColumnIds, &setColumns);
    }
    
    void save(Storage s)
    {
        s.save("show_state", { return Utils.toString(show_state);});
    }
    
    void load(Storage s)
    {
        s.load("show_state", (char[] s){ Utils.fromString!(Node_.State)(s);});
    }
    
    private void setColumns(ushort[] ids)
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
    
    void handle(HttpRequest req, Session session)
    {
        Nodes nodes = session.getGui!(PlexGui).getClient();
        if(nodes is null) return;
        
        char[] do_str = req.getParameter("do");
        uint[] ids = req.getParameter!(uint[])("ids");
        
        switch(do_str)
        {
        case "connect":
            foreach(id; ids)
            {
                nodes.connect(Node_.Type.SERVER, id);
            }
            break;
        case "disconnect":
            foreach(id; ids)
            {
                nodes.disconnect(Node_.Type.SERVER, id);
            }
            break;
        case "block":
            //TODO: add setState to api
            //nodes.disconnect(Node_.Type.SERVER, id);
            break;
        case "sort":
            uint id = req.getParameter!(uint)("id", uint.max);
            if(id < columns.length)
            {
                if(compare is &columns[id].compare)
                {
                    invert_compare = !invert_compare;
                }
                else
                {
                    compare = &columns[id].compare;
                    invert_compare = false;
                }
            }
            break;
        case "show_connected":
            show_state = Node_.State.CONNECTED;
            break;
        case "show_all":
            show_state = Node_.State.ANYSTATE;
            break;
        case "show_blocked":
            show_state = Node_.State.BLOCKED;
            break;
        case "set_network":
            uint id = req.getParameter!(uint)("id");
            if(id) network_id = id;
            break;
        default:
        }
    }

    void handle(HttpResponse res, Session session)
    {
        HtmlOut o = { res.getWriter(), &session.getUser.translate};
        Node client = session.getGui!(PlexGui).getClient();
        
        if(client is null)
        {
            o("<b>")(Phrase.Not_Available)("</b>\n");
            return;
        }
        
        //selected specific network
        if(network_id)
        {
            auto net = client.getNode(Node_.Type.NETWORK, network_id);
            if(net) client = net;
        }
        
        Node[] servers = client.getNodeArray(Node_.Type.SERVER, show_state, 0);
        
        if(servers is null)
        {
            o("<b>")(Phrase.Not_Supported)("</b>\n");
            return;
        }
        
        uint server_count = client.getNodeCount(Node_.Type.SERVER, Node_.State.ANYSTATE);
        o("<b>")(server_count)(" ")(Phrase.Servers)("</b>" ~ BN);
        
        o("<form action=\"" ~ target_uri ~ "\" method=\"get\">\n");
        o("<input type=\"hidden\" name=\"to\" value=\"")(this.getId)("\">\n");
        insertNetworkSelection(o, session);
        o("</form>\n");
        
        o("<b>")(Phrase.Show)("</b>:");
        o(" <a href=\"" ~ target_uri ~ "?to=")(this.getId)(AMP~"do=show_all\">")(Phrase.All)("</a>\n");
        o(" | <a href=\"" ~ target_uri ~ "?to=")(this.getId)(AMP~"do=show_connected\">")(Phrase.Connected)("</a>\n");
        o(" | <a href=\"" ~ target_uri ~ "?to=")(this.getId)(AMP~"do=show_blocked\">")(Phrase.Blocked)("</a>\n");
        
        o(BBN);
        
        o("<form action=\"" ~ target_uri ~ "\" method=\"get\">\n");
        o("<input type=\"hidden\" name=\"to\" value=\"")(this.getId)("\">\n");
        
        o("<table class=\"max\">\n");
        
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
        
        auto mod_id = this.getId;
        
        sort(servers, compare);
        if(invert_compare) servers.reverse;
        
        foreach(c, server; servers)
        {
            if(c%2) o("<tr class=\"odd\">\n");
            else o("<tr class=\"even\">\n");
            
            foreach(col; columns)
            {
                col.getCell(o, server, mod_id);
            }
            
            o("</tr>\n");
        }
        
        if(servers.length == 0)
        {
            o("<tr class=\"even\"><td colspan=\"")(columns.length)("\">");
            o(Phrase.No_Items_Found);
            o("<td><tr>\n");
        }
        
        //insert checkbox selectors
        if(servers.length > 15)
        {
            o("<tr class=\"selectors\">\n");
            o("<td colspan=\"")(columns.length)("\">");
            insertJsSelectors(o);
            o("</td>\n");
            o("</tr>\n");
        }
        
        o("</table>\n");
        
        inserMenu(o);
        
        o("</form>\n");
    }
    
    void inserMenu(HtmlOut o)
    {
        o("<button type=\"submit\" name=\"do\" value=\"connect\">");
        o(Phrase.Connect);
        o("</button>\n");
        
        o(SP4);
        
        o("<button type=\"submit\" name=\"do\" value=\"disconnect\">");
        o(Phrase.Disconnect);
        o("</button>\n");
        
        o("<button type=\"submit\" name=\"do\" value=\"block\">");
        o(Phrase.Block);
        o("</button>\n");
        
        o("<button type=\"submit\" name=\"do\" value=\"unblock\">");
        o(Phrase.Unblock);
        o("</button>\n");
        
        o("<button type=\"submit\" name=\"do\" value=\"remove\">");
        o(Phrase.Remove);
        o("</button>\n");
    }
    
    /*
    * Display a select list of networks
    */
    void insertNetworkSelection(HtmlOut o, Session session)
    {
        auto client = session.getGui!(PlexGui).getClient;
        
        Node[] networks;
        if(client) networks = client.getNodeArray(Node_.Type.NETWORK, Node_.State.CONNECTED, 0);
        
        if(networks.length == 0)
        {
            return;
        }
        
        o("<b>")(Phrase.Networks)("</b>: \n");
        
        o("<form action=\"" ~ target_uri ~ "\" method=\"get\">\n");
        o("<input type=\"hidden\" name=\"to\" value=\"")(this.getId)("\">\n");
        o("<input type=\"hidden\" name=\"do\" value=\"set_network\">\n");
        
        o("<select name=\"id\">\n");
        o("<option value=\"0\">")(Phrase.All)("</option>\n");
        foreach(network; networks)
        {
            if(network.getId == network_id)
            {
                o("<option value=\"")(network.getId)("\">")(network.getName)("</option>\n");
            }
            else
            {
                o("<option value=\"")(network.getId)("\">")(network.getName)("</option>\n");
            }
        }
        o("</select>\n");
        o("</form>\n");
    }
}

interface Column
{
    public:
    Phrase getName();
    void getCell(HtmlOut o, Node n, ushort mod_id);
    bool compare(Node a, Node b);
}

final class CheckBoxColumn : public Column
{
    Phrase getName() { return Phrase.Check; }
    void getCell(HtmlOut o, Node n, ushort mod_id)
    {
        o("<td class=\"check\">");
        o("<input type=\"checkbox\" name=\"ids\" value=\"")(n.getId)("\" />");
        o("</td>\n");
    }
    
    bool compare(Node a, Node b)
    {
        return false;
    }
}

final class IdColumn : public Column
{
    Phrase getName() { return Phrase.Id; }
    void getCell(HtmlOut o, Node n, ushort mod_id)
    {
        o("<td class=\"id\">");
        o(n.getId);
        o("</td>\n");
    }
    
    bool compare(Node a, Node b)
    {
        return a.getId < b.getId;
    }
}

final class DescriptionColumn : public Column
{
    Phrase getName() { return Phrase.Description; }
    void getCell(HtmlOut o, Node n, ushort mod_id)
    {
        o("<td class=\"description\">");
        char[] descr = n.getDescription;
        if(descr.length > 60) {o(descr[0..60]); } else { o(descr); }
        o("</td>\n");
    }
    
    bool compare(Node a, Node b)
    {
        return a.getDescription < b.getDescription;
    }
}

final class UsersColumn : public Column
{
    Phrase getName() { return Phrase.Users; }
    void getCell(HtmlOut o, Node n, ushort mod_id)
    {
        o("<td class=\"users\">");
        o(n.getUserCount);
        o("</td>\n");
    }
    
    bool compare(Node a, Node b)
    {
        return a.getUserCount > b.getUserCount;
    }
}

final class FilesColumn : public Column
{
    Phrase getName() { return Phrase.Files; }
    void getCell(HtmlOut o, Node n, ushort mod_id)
    {
        o("<td class=\"files\">");
        o(n.getFileCount(File_.Type.UNKNOWN, File_.State.ANYSTATE));
        o("</td>\n");
    }
    
    bool compare(Node a, Node b)
    {
        auto x = a.getFileCount(File_.Type.UNKNOWN, File_.State.ANYSTATE);
        auto y = b.getFileCount(File_.Type.UNKNOWN, File_.State.ANYSTATE);
        return x > y;
    }
}

final class NameColumn : public Column
{
    Phrase getName() { return Phrase.Name; }
    void getCell(HtmlOut o, Node n, ushort mod_id)
    {
        o("<td class=\"name\">");
        char[] name = n.getName;
        if(name.length > 70) {o(name[0..70]); } else { o(name); }
        o("</td>\n");
    }
    
    bool compare(Node a, Node b)
    {
        return a.getName < b.getName;
    }
}

final class FlagColumn : public Column
{
    Phrase getName() { return Phrase.Flag; }
    void getCell(HtmlOut o, Node n, ushort mod_id)
    {
        o("<td class=\"flag\">");
        char[] flag = n.getLocation();
        o("<img src=\"/flag_img/")(flag.length ? flag : "--")(".gif\" />");
        o("</td>\n");
    }
    
    bool compare(Node a, Node b)
    {
        return a.getLocation < b.getLocation;
    }
}

final class ActionColumn : public Column
{
    Phrase getName() { return Phrase.Action; }
    void getCell(HtmlOut o, Node n, ushort mod_id)
    {
        o("<td class=\"action\">");
        auto state = n.getState;
        if(state == Node_.State.CONNECTED)
        {
            o("<a href=\"" ~ target_uri ~ "?to=")(mod_id)(AMP~"action=disconnect"~AMP~"ids=")(n.getId)("\">")(MainUser.tr(Phrase.Disconnect))("</a>");
        }
        else if(state == Node_.State.DISCONNECTED)
        {
            o("<a href=\"" ~ target_uri ~ "?to=")(mod_id)(AMP~"action=connect"~AMP~"ids=")(n.getId)("\">")(MainUser.tr(Phrase.Connect))("</a>");
        }
        else if(state == Node_.State.BLOCKED)
        {
            o("<a href=\"" ~ target_uri ~ "?to=")(mod_id)(AMP~"action=unblock"~AMP~"ids=")(n.getId)("\">")(MainUser.tr(Phrase.Unblock))("</a>");
        }
        else
        {
            o("-");
        }
        o("</td>\n");
    }
    
    bool compare(Node a, Node b)
    {
        return a.getState > b.getState;
    }
}

final class AddressColumn : public Column
{
    Phrase getName() { return Phrase.IP_Address; }
    void getCell(HtmlOut o, Node n, ushort mod_id)
    {
        o("<td class=\"address\">");
        char[] host = n.getHost();
        if(host.length)
        {
            o(host)(":")(n.getPort);
        }
        else
        {
            o("-");
        }
        o("</td>\n");
    }
    
    bool compare(Node a, Node b)
    {
        return a.getHost > b.getHost;
    }
}

final class UploadedColumn : Column
{
    Phrase getName() { return Phrase.Uploaded; }
    void getCell(HtmlOut o, Node n, ushort mod_id)
    {
        o("<td class=\"uploaded\">");
        o(formatSize(n.getUploaded));
        o("</td>\n");
    }
    
    bool compare(Node a, Node b)
    {
        return a.getUploaded > b.getUploaded;
    }
}

final class DownloadedColumn : Column
{
    Phrase getName() { return Phrase.Downloaded; }
    void getCell(HtmlOut o, Node n, ushort mod_id)
    {
        o("<td class=\"downloaded\">");
        o(formatSize(n.getDownloaded));
        o("</td>\n");
    }
    
    bool compare(Node a, Node b)
    {
        return a.getDownloaded > b.getDownloaded;
    }
}

final class DownloadRateColumn : Column
{
    Phrase getName() { return Phrase.DownloadRate; }
    void getCell(HtmlOut o, Node n, ushort mod_id)
    {
        o("<td>");
        o( formatSpeed(n.getDownloadRate) );
        o("</td>\n");
    }
    
    bool compare(Node a, Node b)
    {
        return a.getDownloadRate > b.getDownloadRate;
    }
}

final class UploadRateColumn : Column
{
    Phrase getName() { return Phrase.UploadRate; }
    void getCell(HtmlOut o, Node n, ushort mod_id)
    {
        o("<td>");
        o( formatSpeed(n.getUploadRate) );
        o("</td>\n");
    }
    
    bool compare(Node a, Node b)
    {
        return a.getUploadRate > b.getUploadRate;
    }
}

final class StateColumn : Column
{
    Phrase getName() { return Phrase.State; }
    void getCell(HtmlOut o, Node n, ushort mod_id)
    {
        o("<td class=\"state\">");
        switch(n.getState)
        {
            case Node_.State.CONNECTED: o(Phrase.Connected); break;
            case Node_.State.CONNECTING: o(Phrase.Connecting); break;
            case Node_.State.DISCONNECTED: o(Phrase.Disconnected); break;
            case Node_.State.BLOCKED: o(Phrase.Blocked); break;
            default: o("?");
        }
        o("</td>\n");
    }
    
    bool compare(Node a, Node b)
    {
        return a.getState > b.getState;
    }
}

final class SoftwareColumn : public Column
{
    Phrase getName() { return Phrase.Software; }
    void getCell(HtmlOut o, Node n, ushort mod_id)
    {
        char[] software = n.getSoftware();
        if(software.length == 0)
        {
            software = "Unknown";
        }
        o("<td class=\"software\">");
        o("<img src=\"/client_img/")(software)(".gif\" />");
        o(software)(" ")(n.getVersion);
        o("</td>\n");
    }
    
    bool compare(Node a, Node b)
    {
        return a.getSoftware > b.getSoftware;
    }
}

final class NetworksColumn : public Column
{
    Phrase getName() { return Phrase.Networks; }
    void getCell(HtmlOut o, Node n, ushort mod_id)
    {
        auto networks = n.getNodeArray(Node_.Type.NETWORK, Node_.State.ANYSTATE, 0);
        o("<td class=\"networks\">");
        if(networks)
        {
            foreach(network; networks)
            {
                char[] name = network.getName();
                bool connected = (network.getState == Node_.State.CONNECTED);
                o("<img src=\"/net_img/")(name)(connected ? "_connected.gif\" />\n" : "_disabled.gif\" />\n");
            }
        }
        else
        {
            o("<img src=\"/net_img/Unknown_connected.gif\" />");
        }
        o("</td>\n");
    }
    
    bool compare(Node a, Node b)
    {
        return false; //a.getNetwork > b.getNetwork;
    }
}

final class PingColumn : Column
{
    Phrase getName() { return Phrase.Ping; }
    void getCell(HtmlOut o, Node n, ushort mod_id)
    {
        float time = n.getPing() / 1000.0;
        o("<td class=\"ping\">");
        if(time)
        {
            o(time)(" sec");
        }
        else
        {
            o("-");
        }
        o("</td>\n");
    }
    
    bool compare(Node a, Node b)
    {
        auto x = a.getPing();
        auto y = b.getPing();
        if(x == 0) x = typeof(x).max;
        if(y == 0) y = typeof(y).max;    
        return x < y;
    }
}

//display name of first download the client has 
final class FilenameColumn : Column
{
    Phrase getName() { return Phrase.Filename; }
    void getCell(HtmlOut o, Node n, ushort mod_id)
    {
        File[] array = null;
        if(auto files = n.getFiles)
        {
            array = files.getFileArray(File_.Type.DOWNLOAD, File_.State.ANYSTATE, 0);
        }
        
        o("<td class=\"filename\">");
        if(array.length)
        {
            o(cropFileName(array[0].getName, 50));
        }
        o("</td>\n");
    }
    
    bool compare(Node a, Node b)
    {
        char[] name1 = null;
        char[] name2 = null;
        if(auto files = a.getFiles)
        {
            auto array = files.getFileArray(File_.Type.DOWNLOAD, File_.State.ANYSTATE, 0);
            if(array.length) name1 = array[0].getName;
        }
        if(auto files = b.getFiles)
        {
            auto array = files.getFileArray(File_.Type.DOWNLOAD, File_.State.ANYSTATE, 0);
            if(array.length) name2 = array[0].getName;
        }
        return name1 < name2;
    }
}


final class ConnectColumn : Column
{
    Phrase getName() { return Phrase.Connect; }
    void getCell(HtmlOut o, Node n, ushort mod_id)
    {
        if(n.getState == Node_.State.CONNECTED)
        {
            o("<td><a href=\"" ~ target_uri ~ "?to=")(mod_id)(AMP~"do=disconnect"~AMP~"ids=")(n.getId)("\">")(Phrase.Disconnect)("</a></td>\n");
        }
        else if(n.getState == Node_.State.DISCONNECTED)
        {
            o("<td><a href=\"" ~ target_uri ~ "?to=")(mod_id)(AMP~"do=connect"~AMP~"ids=")(n.getId)("\">")(Phrase.Connect)("</a></td>\n");
        }
        else
        {
            o("<td></td>\n");
        }
    }
    
    bool compare(Node a, Node b)
    {
        return a.getState() < a.getState();
    }
}
