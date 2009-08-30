module webguis.plex.HtmlSearches;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/

import tango.io.Stdout;
import tango.core.Array;
import tango.text.Util;

import webserver.HttpRequest;
import webserver.HttpResponse;

import api.File;
import api.Node;
import api.User;
import api.Search;
import api.Host;

import webcore.Dictionary;
import webcore.Logger;

import webguis.plex.PlexGui;
import webguis.plex.HtmlElement;
import webguis.plex.HtmlUtils;
import utils.Utils;


Column delegate()[ushort] column_loaders;

void searches_init()
{
    if(column_loaders.length) return;
    
    column_loaders = [
        Phrase.Id : { return cast(Column) new IdColumn; },
        Phrase.Check : { return cast(Column) new CheckBoxColumn; },
        Phrase.Name : { return cast(Column) new NameColumn; },
        Phrase.Size : { return cast(Column) new SizeColumn; },
        Phrase.Sources : { return cast(Column) new SourcesColumn; },
        Phrase.Format : { return cast(Column) new FormatColumn; }
    ];
}

final class HtmlSearches : HtmlElement
{
private:
    
    Column[] columns;
    
    bool delegate(File, File) compare;
    bool invert_compare;

    uint search_id;
    bool show_advanced;
    bool show_help;
    
    struct MaxResultsPair
    {
        ushort number;
        char[] string;
    }
    
    uint default_max_results;
    static const MaxResultsPair[] max_results_steps= [{0, "&infin;"}, {50, "50"}, {100, "100"}, {200, "200"}, {400, "400"}];
    
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
        super(Phrase.Searches);
        searches_init();
        
        setColumns( [Phrase.Check, Phrase.Name, Phrase.Format, Phrase.Sources, Phrase.Size] );
        compare = &columns[0].compare;
        
        addSetting(Phrase.show_help, &show_help);
        addSetting(Phrase.column_order, &columns);
        addSetting(Phrase.show_columns, &getColumnIds, &getAllColumnIds, &setColumns);
    }
    
    void save(Storage s)
    {
        s.save("show_advanced", &show_advanced);
    }
    
    void load(Storage s)
    {
        s.load("show_advanced", &show_advanced);
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
        auto client = session.getGui!(PlexGui).getClient();
        if(client is null) return;
        auto searches = client.getSearches;
        if(searches is null) return;
        char[] action = req.getParameter("do");
        
        if(action == "search") try
        {
            char[] query = trim( req.getParameter("query") );
            if(query.length == 0)
            {
                Logger.addInfo("No keywords found!");
                return;
            }
            
            char[] media = trim( req.getParameter("media") );
            if(media.length) query ~= (" + MEDIA \"" ~ media ~"\"");
            
            auto max_results = req.getParameter!(uint)("max_results");
            if(max_results)
            {
                default_max_results = max_results;
                query ~= (" + MAXRESULTS \"" ~ Utils.toString(max_results) ~"\"");
            }
            
            auto network_id = req.getParameter!(uint)("network_id", uint.max);
            if(network_id != uint.max) query ~= (" + NETWORKID \"" ~ Utils.toString(network_id) ~"\"");
            
            auto max_avail = req.getParameter!(uint)("max_avail");
            auto min_avail = req.getParameter!(uint)("min_avail");
            if(max_avail) query ~= (" + MAXAVAIL \"" ~ Utils.toString(min_avail) ~"\"");
            if(min_avail) query ~= (" + MINAVAIL \"" ~ Utils.toString(min_avail) ~"\"");
            
            ulong min_size = parseSize( req.getParameter("min_size") );
            ulong max_size = parseSize( req.getParameter("max_size") );
            if(min_size) query ~= (" + MINSIZE \"" ~ Utils.toString(min_size) ~"\"");
            if(max_size) query ~= (" + MAXSIZE \"" ~ Utils.toString(max_size) ~"\"");
            
            searches.addSearch(query);
            return;
        }
        catch(Exception e)
        {
            Logger.addError(e.toString);
            return;
        }
        
        uint id = req.getParameter!(uint)("id", uint.max);
        
        if(action == "sort") //for results only
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
        else if(action == "show")
        {
            search_id = id;
        }
        else if(action == "stop")
        {
            searches.stopSearch(id);
        }
        else if(action == "cancel")
        {
            searches.removeSearch(id);
        }
        /*
        else if(action == "details")
        {
            if(result_id == id) { result_id = 0; } else { result_id  = id; }
        }*/
        else if(action == "download")
        {
            uint[] ids = req.getParameter!(uint[])("ids");
            if(ids.length && id != uint.max && ids.length)
            {
                searches.startSearchResults(id, ids);
            }
        }
        else if(action == "remove")
        {
            uint[] ids = req.getParameter!(uint[])("ids");
            if(ids.length && id != uint.max && ids.length)
            {
                searches.removeSearchResults(id, ids);
            }
        }
    }
    
    void handle(HttpResponse res, Session session)
    {
        HtmlOut o = {res.getWriter(), &session.getUser.translate};
        
        Searches s;
        if(auto client = session.getGui!(PlexGui).getClient)
        {
            s = client.getSearches();
        }
        else
        {
            o("<b>")(Phrase.Not_Available)("</b>");
            return;
        }
        
        if(s is null)
        {
            o("<b>")(Phrase.Not_Supported)("</b>");
            return;
        }
        
        o("<form id=\"search-form\" action=\"" ~ target_uri ~ "\" method=\"get\">\n");
        o("<input type=\"hidden\" name=\"to\" value=\"")(this.getId)("\">\n\n");
        
        //input query
        o("<p>\n");
        o("<div class=\"label\">")(Phrase.Text)(":</div>\n");
        o("<input type=\"text\" name=\"query\" size=\"30\">\n");
        o("</p>\n\n");
        
        if(show_help)
        {
            o("<p>\n");
            o("<div class=\"label\">" ~ SP ~"</div>\n");
            o("<b> + - ( ) | \"foo bar\"</b>\n");
            o("</p>\n\n");
        }
        
        //select size
        o("<p>\n");
        o("<div class=\"label\">")(Phrase.Size)(":</div>\n");
        o("<input type=\"text\" name=\"min_size\" value=\"0 MB\" size=\"10\">\n");
        o("<b>-</b>\n");
        o("<input type=\"text\" name=\"max_size\" value=\"&infin; MB\" size=\"10\">\n");
        o("</p>\n\n");
        
        //select availability
        o("<p>\n");
        o("<div class=\"label\">")(Phrase.Availability)(":</div>\n");
        o("<input type=\"text\" name=\"min_avail\" value=\"0\" size=\"10\">\n");
        /*
        o("<select name=\"min_avail\">\n");
        o("<option value=\"0\">0</option>\n");
        o("<option value=\"3\">3</option>\n");
        o("<option value=\"5\">5</option>\n");
        o("<option value=\"10\">10</option>\n");
        o("<option value=\"25\">25</option>\n");
        o("<option value=\"50\">50</option>\n");
        o("</select>\n");
        */
        o("<b>-</b>\n");
        o("<input type=\"text\" name=\"max_avail\" value=\"&infin;\" size=\"10\">\n");
        o("</p>\n\n");
        
        //select content type
        o("<p>\n");
        o("<div class=\"label\">")(Phrase.Content_Type)(":</div>\n");
        o("<select name=\"media\">\n");
        o("<option value=\"\" selected=\"selected\">")(Phrase.All)("</option>\n");
        o("<option value=\"PROGRAM\">")(Phrase.Program)("</option>\n");
        o("<option value=\"DOCUMENT\">")(Phrase.Document)("</option>\n");
        o("<option value=\"IMAGE\">")(Phrase.Image)("</option>\n");
        o("<option value=\"AUDIO\">")(Phrase.Audio)("</option>\n");
        o("<option value=\"VIDEO\">")(Phrase.Video)("</option>\n");
        o("<option value=\"ARCHIVE\">")(Phrase.Archive)("</option>\n");
        o("</select>\n");
        o("</p>\n\n");
        
        //select max results
        o("<p>\n");
        o("<div class=\"label\">")(Phrase.Results)(":</div>\n");
        o("<input type=\"text\" value=\"0\" disabled=\"disabled\" size=\"10\">\n");
        o("<b>-</b>\n");
        o("<select name=\"max_results\">\n");
        foreach(step; max_results_steps)
        {
            o("<option value=\"")(step.number)("\"");
            if(step.number == default_max_results)
            {
                o(" selected=\"selected\"");
            }
            o(">")(step.string)("</option>\n");
        }
        o("</select>\n");
        o("</p>\n\n");
        
        o("<p>\n");
        insertNetworkSelection(o, session);
        o("</p>\n\n");
        
        o("<p>\n");
        o("<button type=\"submit\" name=\"do\" value=\"search\">");
        o(Phrase.Search);
        o("</button>\n");
        o("</p>\n\n");
        
        o("</form>\n\n");
        
        //searches
        o("<table id=\"search-list\">\n");

        o("<tr>\n");
        o("<th>")(Phrase.Id)("</th>\n");
        o("<th>")(Phrase.Keywords)("</th>\n");
        o("<th>")(Phrase.Found)("</th>\n");
        o("<th>")(Phrase.Actions)("</th>\n");
        o("</tr>\n");
        
        Search[] searches;
        if(s) searches = s.getSearchArray();
        
        foreach(c, search; searches)
        {
            if(c%2) { o("<tr class=\"odd\">"); }
            else     { o("<tr class=\"even\">"); }
            
            o("<td>")(search.getId)("</td>\n");
            o("<td>")(search.getName)("</td>\n");
            o("<td>")(search.getResultCount(File_.State.ANYSTATE))("</td>\n");
            o("<td>\n");
            o("[ <a href=\"" ~ target_uri ~ "?to=")(this.getId)(AMP~"do=show"~AMP~"id=")(search.getId)("\">View</a> ]\n");
            if(search.getState == Search_.State.ACTIVE)
            {
                o(" [ <a href=\"" ~ target_uri ~ "?to=")(this.getId)(AMP~"do=stop"~AMP~"id=")(search.getId)("\">Stop</a> ]\n");
            }
            else
            {
                o(" [ <a href=\"" ~ target_uri ~ "?to=")(this.getId)(AMP~"do=resume"~AMP~"id=")(search.getId)("\">Resume</a> ]\n");
            }
            o(" [ <a href=\"" ~ target_uri ~ "?to=")(this.getId)(AMP~"do=cancel"~AMP~"id=")(search.getId)("\">Forget</a> ]\n");
            o("</td>\n");
            o("</tr>\n");
        }
        
        if(searches.length == 0)
        {
            o("<tr class=\"even\" ><td colspan=\"4\">");
            o(Phrase.No_Items_Found);
            o("</td></tr>\n");
        }
        
        o("</table>\n\n");
        
        o("<div style=\"clear: both;\">&nbsp;</div>\n\n");
        
        if(s) printResults(o, s);
    }
    
private:
    
    /*
    * Display a select list of searchable networks.
    */
    void insertNetworkSelection(HtmlOut o, Session session)
    {
        auto nodes = session.getGui!(PlexGui).getClient;
        
        Node[] networks;
        if(nodes) networks = nodes.getNodeArray(Node_.Type.NETWORK, Node_.State.CONNECTED, 0);
        
        o("<div class=\"label\">")(Phrase.Network)(":</div>\n");
        
        Node[] display_networks;
        foreach(network; networks)
        {
            if(network.getSearches) //support searches
            {
                display_networks ~= network;
            }
        }
        
        if(display_networks.length == 0)
        {
            o("-");
            return;
        }
        
        o("<select name=\"network_id\">\n");
        foreach(network; display_networks)
        {
            o("<option value=\"")(network.getId)("\">")(network.getName)("</option>\n");
        }
        o("</select>\n");
    }
    
    void printResults(HtmlOut o, Searches searches)
    {
        auto search = searches.getSearch(search_id);
        File[] results;
        
        if(search)
        {
            results = search.getResultArray(File_.State.ANYSTATE, 0);
        }
        else
        {
            search_id = 0;
        }
        
        void insertButtons()
        {
            o("<button type=\"submit\" name=\"do\" value=\"download\">");
            o(Phrase.Download);
            o("</button>\n");
            
            o("<button type=\"submit\" name=\"do\" value=\"remove\">");
            o(Phrase.Remove);
            o("</button>\n");
        }
        
        o("<form action=\"" ~ target_uri ~ "\" method=\"get\">\n");
        o("<input type=\"hidden\" name=\"to\" value=\"")(this.getId)("\">\n");
        o("<input type=\"hidden\" name=\"id\" value=\"")(search_id)("\">\n");
        
        insertButtons();
        o(BBN);
        
        o("<table class=\"max\">\n");
        
        //insert checkbox selectors
        o("<tr class=\"selectors\">\n");
        o("<td colspan=\"")(columns.length)("\">\n");
        insertJsSelectors(o);
        o("</td>\n");
        o("</tr>\n");
        
        //print header columns
        o("<tr>\n");
        foreach(i, col; columns)
        {
            o("<th><a href=\"" ~ target_uri ~ "?to=")(this.getId)(AMP~"do=sort")(AMP~"id=")(i)("\">");
            o(col.getName);
            o("</a></th>\n");
        }
        o("</tr>\n");
        
        sort(results, compare);
        if(invert_compare) results.reverse;
        
        auto mod_id = this.getId();
        foreach(c, result; results)
        {
            if(c%2) { o("<tr class=\"odd\">\n"); }
            else     { o("<tr class=\"even\">\n"); }
            
            foreach(col; columns)
            {
                col.getCell(o, result, mod_id);
            }
        }
        
        if(results.length == 0)
        {
            o("<tr class=\"even\" ><td colspan=\"5\">");
            o(Phrase.No_Items_Found);
            o("</td></tr>\n");
        }
        
        //insert checkbox selectors
        if(results.length > 15)
        {
            o("<tr class=\"selectors\">\n");
            o("<td colspan=\"")(columns.length)("\">\n");
            insertJsSelectors(o);
            o("</td>\n");
            o("</tr>\n");
        }
        
        o("</table>\n");
        
        o(BBN);
        insertButtons();
        
        o("</form>\n");
    }
}

interface Column
{
    public:
    Phrase getName();
    void getCell(HtmlOut o, File d, ushort mod_id);
    bool compare(File a, File b);
}

final class IdColumn : Column
{
    Phrase getName() { return Phrase.Id; }
    void getCell(HtmlOut o, File a, ushort mod_id)
    {
        o("<td class=\"id\">");
        o(a.getId);
        o("</td>\n");
    }
    
    bool compare(File a, File b)
    {
        return a.getId > b.getId;
    }
}

final class FormatColumn : public Column
{
    Phrase getName() { return Phrase.Format; }
    void getCell(HtmlOut o, File a, ushort mod_id)
    {
        o("<td class=\"format\">");
        o(a.getFormat);
        o("</td>\n");
    }
    
    bool compare(File a, File b)
    {
        return a.getFormat < b.getFormat;
    }
}

final class SourcesColumn : public Column
{
    Phrase getName() { return Phrase.Sources; }
    void getCell(HtmlOut o, File a, ushort mod_id)
    {
        o("<td class=\"sources\">");
        o(a.getFileCount(File_.Type.DOWNLOAD, File_.State.COMPLETE));
        o(" (")(a.getFileCount(File_.Type.DOWNLOAD, File_.State.ANYSTATE))(")</td>");
        o("</td>\n");
    }
    
    bool compare(File a, File b)
    {
        uint a_c = a.getFileCount(File_.Type.DOWNLOAD, File_.State.ANYSTATE);
        uint b_c = b.getFileCount(File_.Type.DOWNLOAD, File_.State.ANYSTATE);
        return a_c > b_c;
    }
}

final class SizeColumn : Column
{
    Phrase getName() { return Phrase.Size; }
    void getCell(HtmlOut o, File a, ushort mod_id)
    {
        o("<td class=\"size\">");
        o(formatSize(a.getSize));
        o("</td>\n");
    }
    
    bool compare(File a, File b)
    {
        return a.getSize > b.getSize;
    }
}

final class CheckBoxColumn : Column
{
    Phrase getName() { return Phrase.Check; }
    void getCell(HtmlOut o, File a, ushort mod_id)
    {
        o("<td class=\"check\">");
        o("<input type=\"checkbox\" name=\"ids\" value=\"")(a.getId)("\" />");
        o("</td>\n");
    }
    
    bool compare(File a, File b)
    {
        return false;
    }
}

final class NameColumn : Column
{
    Phrase getName() { return Phrase.Name; }
    void getCell(HtmlOut o, File a, ushort mod_id)
    {
        o("<td class=\"name\">");
        o(cropFileName(a.getName, 120));
        o("</td>\n");
    }
    
    bool compare(File a, File b)
    {
        return a.getName > b.getName;
    }
}
