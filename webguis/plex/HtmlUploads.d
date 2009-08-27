module webguis.plex.HtmlUploads;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/

import tango.io.Stdout;
import tango.text.Util;
import tango.core.Array;

import webserver.HttpRequest;
import webserver.HttpResponse;

import api.File;
import api.Node;
import api.User;
import api.Meta;

import webguis.plex.PlexGui;
import webguis.plex.HtmlUtils;
import webguis.plex.HtmlElement;
import webguis.plex.HtmlServers;
import utils.Utils;


Column delegate()[ushort] column_loaders;

void uploads_init()
{
    if(column_loaders.length) return;
    
    column_loaders = [
        Phrase.Id : { return cast(Column) new IdColumn; },
        Phrase.Check : { return cast(Column) new CheckBoxColumn; },
        Phrase.Name : { return cast(Column) new NameColumn; },
        Phrase.IP_Address : { return cast(Column) new AddressColumn; },
        Phrase.Uploaded : { return cast(Column) new UploadedColumn; },
        Phrase.Downloaded : { return cast(Column) new DownloadedColumn; },
        Phrase.Software : { return cast(Column) new SoftwareColumn; },
        Phrase.State : { return cast(Column) new StateColumn; },
        Phrase.Flag : { return cast(Column) new FlagColumn; },
        Phrase.Action : { return cast(Column) new ActionColumn; },
        Phrase.Networks : { return cast(Column) new NetworksColumn; },
        Phrase.Filename: { return cast(Column) new FilenameColumn; },
        Phrase.DownloadRate : { return cast(Column) new DownloadRateColumn; },
        Phrase.UploadRate : { return cast(Column) new UploadRateColumn; }
    ];
}


final class HtmlUploads : HtmlElement
{
private:
    
    Node_.State state_filter = Node_.State.CONNECTED;
    uint node_id;

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
        foreach(column; columns)
        {
            ids ~= cast(ushort) column.getName;
        }
        return ids;
    }
    
public:

    this()
    {
        super(Phrase.Uploads);
        uploads_init();
        
        setColumns([Phrase.Check, Phrase.Networks, Phrase.Flag, Phrase.Name, Phrase.Filename, Phrase.Uploaded, Phrase.Downloaded, Phrase.Software]);
        compare = &columns[0].compare;
        
        addSetting(Phrase.column_order, &columns);
        addSetting(Phrase.show_columns, &getColumnIds, &getAllColumnIds, &setColumns);
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
        char[] do_str = req.getParameter("do");
        uint id = req.getParameter!(uint)("id");
        
        auto client = session.getGui!(PlexGui).getClient;
        if(client is null) return;
        
        if(do_str == "sort")
        {
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
        }
        else if(do_str == "disconnect")
        {
            return;
        }
        else if(do_str == "show")
        {
            if(node_id == id) { node_id = 0; } else { node_id = id; }
            return;
        }
        else if(do_str == "show_connected")
        {
            state_filter = Node_.State.CONNECTED;
        }
        else if(do_str == "show_all")
        {
            state_filter = Node_.State.ANYSTATE;
        }
        else if(do_str == "show_blocked")
        {
            state_filter = Node_.State.BLOCKED;
        }
    }

    void handle(HttpResponse res, Session session)
    {
        HtmlOut o = {res.getWriter(), &session.getUser.translate};
        Node[] uploaders;
        
        Nodes nodes;
        if(auto client = session.getGui!(PlexGui).getClient)
        {
            nodes = client.getNodes();
        }
        else
        {
            o("<b>")(Phrase.Not_Available)("</b>\n");
            return;
        }
        
        if(nodes) uploaders = nodes.getNodeArray(Node_.Type.CLIENT, Node_.State.ANYSTATE, 0);
        
        if(uploaders is null)
        {
            o("<b>")(Phrase.Not_Supported)("</b>\n");
            return;
        }
        
        o("<form action=\"" ~ target_uri ~ "\" method=\"post\">\n");
        o("<table class=\"max\">\n");
        
        //print header column
        o("<tr>\n");
        foreach(i, col; columns)
        {
            o("<th><a href=\"" ~ target_uri ~ "?to=")(this.getId)(AMP~"do=sort")(AMP~"id=")(i)("\">");
            o(col.getName);
            o("</a></th>\n");
        }
        o("</tr>\n");
        
        sort(uploaders, compare);
        if(invert_compare) uploaders.reverse;
        
        auto mod_id = this.getId;
        foreach(c, node; uploaders)
        {
            if(c%2) o("<tr class=\"odd\">\n");
            else o("<tr class=\"even\">\n");
            
            foreach(col; columns)
            {
                col.getCell(o, node, mod_id);
            }
            
            o("</tr>");
        }
        
        if(uploaders.length == 0)
        {
            o("<tr class=\"odd\" ><td colspan=\"")(columns.length)("\">");
            o(Phrase.No_Items_Found);
            o("</td></tr>\n");
        }
        
        o("</table>\n");
        
        o("<input type=\"hidden\" name=\"to\" value=\"")(this.getId)("\" />");

        o("<button type=\"submit\" name=\"do\" value=\"disconnect\">");
        o(Phrase.Disconnect);
        o("</button>\n");
    
        o("</form>\n");
        
        if(nodes && node_id)
        {
            insertDetails(res, nodes);
        }
    }
    
    
    void insertDetails(HttpResponse res, Nodes nodes)
    {
        auto o = res.getWriter;
        Node node = nodes.getNode(Node_.Type.CLIENT, node_id);
        if(!node)
        {
            o("<b>")(Phrase.Not_Found)("</b>");
            return;
        }
        
        o("<div class=\"details\">");
        o("<b>")(Phrase.Name)(":</b>\n")(node.getName)(BN);
        o("<b>")(Phrase.Uploaded)(":</b>\n")( formatSize(node.getUploaded) )(BN);
        o("<b>")(Phrase.Downloaded)(":</b>\n") (formatSize(node.getDownloaded) )(BN);
        o("</div>");
    }
}
