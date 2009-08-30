module webguis.plex.HtmlDownloads;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/

import tango.io.Stdout;
import tango.text.Util;
import tango.core.Array;
import tango.math.Math;

import webcore.Dictionary;

import webserver.HttpRequest;
import webserver.HttpResponse;

import api.File;
import api.Node;
import api.User;
import api.Meta;

import webguis.plex.PlexGui;
import webguis.plex.HtmlUtils;
import webguis.plex.HtmlElement;
import utils.Utils;


Column delegate()[ushort] column_loaders;

void downloads_init()
{
    if(column_loaders.length) return;
    
    column_loaders = [
        Phrase.Id : { return cast(Column) new IdColumn; },
        Phrase.Check : { return cast(Column) new CheckBoxColumn; },
        Phrase.Name : { return cast(Column) new NameColumn; },
        Phrase.Percent : { return cast(Column) new PercentColumn; },
        Phrase.Size : { return cast(Column) new SizeColumn; },
        Phrase.Downloaded : { return cast(Column) new DownloadedColumn; },
        Phrase.Uploaded : { return cast(Column) new UploadedColumn; },
        Phrase.ETA : { return cast(Column) new ETAColumn; },
        Phrase.State : { return cast(Column) new StateColumn; },
        //Phrase.Speed : { return cast(Column) new SpeedColumn; },
        Phrase.UploadRate : { return cast(Column) new UploadRateColumn; },
        Phrase.DownloadRate : { return cast(Column) new DownloadRateColumn; },
        Phrase.Last_Seen : { return cast(Column) new LastSeenColumn; },
        Phrase.Sources : { return cast(Column) new SourcesColumn; },
        Phrase.Networks : { return cast(Column) new NetworksColumn; },
        Phrase.Chunks : { return cast(Column) new ChunksColumn; },
        Phrase.Priority : { return cast(Column) new PriorityColumn; }
    ];
}

final class HtmlDownloads : HtmlElement
{
private:

    Column[] columns;

    //show details for this download
    uint download_id = uint.max;

    bool delegate(File, File) compare;
    bool invert_compare;

    bool show_percent_bar = true;
    bool enable_row_colors = true;
    ubyte enable_rotx = false; //rot x file names
    bool enable_l33t = false; //if you don't know what is l33t, then you aren't l33t ;)

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
    
public:

    this()
    {
        super(Phrase.Downloads);
        downloads_init();
        
        setColumns ([
            Phrase.Check, Phrase.Networks, Phrase.Name, Phrase.ETA,
            Phrase.Percent, Phrase.Size, Phrase.Downloaded, Phrase.DownloadRate
        ]);
        compare = &columns[0].compare;
        
        addSetting(Phrase.column_order, &columns);
        addSetting(Phrase.show_columns, &getColumnIds, &getAllColumnIds, &setColumns);
        addSetting(Phrase.show_percent_bar, &show_percent_bar);
        addSetting(Phrase.enable_row_colors, &enable_row_colors);
        addSetting(Phrase.enable_rotX, &enable_rotx);
        addSetting(Phrase.enable_l33t, &enable_l33t);
    }
    
    void save(Storage s)
    {
        s.save("columns", {
            return Utils.map(columns, (Column col) { return Dictionary.toString(col.getName); });
        });
        
        s.save("show_percent_bar", &show_percent_bar);
        s.save("enable_row_colors", &enable_row_colors);
        s.save("enable_rotx", &enable_rotx);
        s.save("enable_l33t", &enable_l33t);
    }
    
    void load(Storage s)
    {
        s.load("columns", (char[][] cols) {
            setColumns(Utils.map(cols, &Dictionary.toId));
        });
        
        s.load("show_percent_bar", &show_percent_bar);
        s.load("enable_row_colors", &enable_row_colors);
        s.load("enable_rotx", &enable_rotx);
        s.load("enable_l33t", &enable_l33t);
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
        char[] action = req.getParameter("do");
        
        auto client = session.getGui!(PlexGui).getClient();
        if(client is null) return;
        
        if(action == "sort")
        {
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
        }
        else if(action == "show")
        {
            uint id = req.getParameter!(uint)("id", uint.max);
            if(download_id == id) { download_id = uint.max; } else { download_id = id; }
            return;
        }
        else if(action == "preview")
        {
            uint subfile_id = req.getParameter!(uint)("id", uint.max);
            auto files = client.getFiles();
            if(files is null) return;
            if(subfile_id != uint.max)
            {
                files = files.getFile(File_.Type.DOWNLOAD, download_id);
                if(files) files.previewFile(File_.Type.SUBFILE, subfile_id);
            }
            else
            {
                files.previewFile(File_.Type.DOWNLOAD, download_id);
            }
            return;
        }
        else if(action == "rename" || action == "commit")
        {
            uint id = req.getParameter!(uint)("id", uint.max);
            char[] new_name = trim( req.getParameter("new_name") );
            auto downloads = client.getFiles();
            if(id != uint.max && downloads && new_name.length)
            {
                downloads.renameFile(File_.Type.DOWNLOAD, id, new_name);
            }
            return;
        }
        
        uint[] ids = req.getParameter!(uint[])("ids");
        
        auto downloads = client.getFiles();
        
        if(ids.length && downloads)
        {
            switch(action)
            {
                case "pause": downloads.pauseFiles(File_.Type.DOWNLOAD, ids); break;
                case "resume": downloads.startFiles(File_.Type.DOWNLOAD, ids); break;
                case "cancel": downloads.removeFiles(File_.Type.DOWNLOAD, ids); break;
                case "stop": downloads.pauseFiles(File_.Type.DOWNLOAD, ids); break;
                case "prioritize":
                    auto priority = req.getParameter!(Priority)("priority");
                    downloads.prioritiseFiles(File_.Type.DOWNLOAD, ids, priority);
                default:
            }
        }
    }

    void handle(HttpResponse res, Session session)
    {
        HtmlOut o = { res.getWriter(), &session.getUser.translate};
        
        size_t counter = 0;
        //uint total_speed = 0;
        ulong total_size = 0;
        ulong total_completed = 0;
        File[] downloads = null;
        Files files = null;
        Node node = session.getGui!(PlexGui).getClient();
        if(node is null)
        {
            o("<b>")(Phrase.Not_Available)("</b>\n");
            return;
        }
        
        files = node.getFiles();
        
        if(files is null)
        {
            o("<b>")(Phrase.Not_Supported)("</b>\n");
            return;
        }
        
        downloads = files.getFileArray(File_.Type.DOWNLOAD, File_.State.ANYSTATE, 0);
        
        o("<form action=\"" ~ target_uri ~ "\" method=\"get\">\n");
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
        
        sort(downloads, compare);
        if(invert_compare) downloads.reverse;
        
        //auto mod_id = this.getId;
        size_t c;
        foreach(file; downloads)
        {
            if(c%2) o("<tr class=\"odd ");
            else o("<tr class=\"even ");
            
            if(enable_row_colors)
            {
                o( getColumnClass(file) );
            }
            
            o("\">\n");
            
            foreach(col; columns)
            {
                col.getCell(o, file, this);
            }
            
            o("</tr>\n");
            
            total_completed += file.getDownloaded();
            total_size += file.getSize();
            //total_speed += file.getDownloadRate();
            ++c;
        }
        
        bool odd = (c % 2 != 0);
        
        if(c == 0)
        {
            o("<tr class=\"even\" ><td colspan=\"")(columns.length)("\">");
            o(Phrase.No_Items_Found);
            o("</td></tr>\n");
            odd = true;
        }
        
        //print overall size and speed
        if(odd) o("<tr class=\"odd\">\n");
        else o("<tr class=\"even\">\n");
        
        o("<td align=\"right\"colspan=\"")(columns.length)("\"><b>");
        o(formatSize(total_completed))(" / ");
        o(formatSize(total_size))(" @ ");
        //o(formatSpeed(total_speed));
        o("&darr;");
        o(formatSpeed(node.getDownloadRate));
        o(" | ");
        o(formatSpeed(node.getUploadRate));
        o("&uarr;");
        o("</b></td>\n");
        o("</tr>\n");
        
        //insert checkbox selectors
        if(c > 15)
        {
            o("<tr class=\"selectors\">\n");
            o("<td colspan=\"")(columns.length)("\">\n");
            insertJsSelectors(o);
            o("</td>\n");
            o("</tr>\n");
        }
        
        o("</table>\n");
        
        insertMenu(o, session);
        
        o("</form>\n\n");
        
        if(files && download_id != uint.max)
        {
            insertDetails(res, o, files);
        }
    }
    
    /*
    * Get css class for file state.
    */
    static char[] getColumnClass(File file)
    {
        if(file.getDownloadRate > 256)
        {
            return "progress";
        }
        
        switch(file.getState)
        {
            case File_.State.COMPLETE: return "complete";
            case File_.State.STOPPED: return "stopped";
            case File_.State.PAUSED: return "paused";
            case File_.State.ACTIVE: return "active";
            default: return null;
        }
    }
    
    void insertMenu(HtmlOut o, Session session)
    {
        o("<input type=\"hidden\" name=\"to\" value=\"")(this.getId)("\" />\n");

        auto client = session.getGui!(PlexGui).getClient;
        
        Users users;
        if(client) users = client.getUsers;
        
        User[] iter;
        if(users) iter = users.getUserArray;
        
        if(iter)
        {
            o("<button type=\"submit\" name=\"do\" value=\"addOwner\">");
            o(Phrase.Add_Owner);
            o("</button>\n");
            
            o("<select name=\"user\" size=\"1\">\n");
            foreach(user; iter)
            {
                o("<option value=\"")(user.getName)("\">");
                o(user.getName);
                o("</option>\n");
            }
            o("</select>\n");
        }
        
        o("<button type=\"submit\" name=\"do\" value=\"cancel\">");
        o(Phrase.Cancel);
        o("</button>\n");
        
        o(SP4);
        
        o("<button type=\"submit\" name=\"do\" value=\"pause\">");
        o(Phrase.Pause);
        o("</button>\n");
        
        o("<button type=\"submit\" name=\"do\" value=\"stop\">");
        o(Phrase.Stop);
        o("</button>\n");
        
        o("<button type=\"submit\" name=\"do\" value=\"resume\">");
        o(Phrase.Resume);
        o("</button>\n");
        
        //Priority selection
        o("<select name=\"priority\" size=\"1\">\n");
        o("<option value=\"VERY_LOW\">")(Phrase.Very_Low)("</option>\n");
        o("<option value=\"LOW\">")(Phrase.Low)("</option>\n");
        o("<option value=\"NORMAL\" selected=\"selected\">")(Phrase.Normal)("</option>\n");
        o("<option value=\"HIGH\">")(Phrase.High)("</option>\n");
        o("<option value=\"VERY_HIGH\">")(Phrase.Very_High)("</option>\n");
        o("</select>\n");
        
        o("<button type=\"submit\" name=\"do\" value=\"prioritize\">");
        o(Phrase.Prioritize);
        o("</button>\n");
    }

    void insertDetails(HttpResponse res, HtmlOut o, Files files)
    {
        auto file = files.getFile(File_.Type.DOWNLOAD, download_id);
        
        if(file is null)
        {
            o("<b>")(Phrase.Not_Found)("</b>\n");
            download_id = uint.max;
            return;
        }
        
        uint comment_count;
        char[] file_format = file.getFormat;
        char[] hash = file.getHash;
        File[] subfiles = file.getFileArray(File_.Type.SUBFILE, File_.State.ANYSTATE, 0);
        Nodes nodes = file.getNodes;
        
        o("<div class=\"details\">\n");
        
        o("<b>[<a href=\"" ~ target_uri ~ "?to=")(this.getId)(AMP~"do=show"~AMP~"id=_\">");
        o(Phrase.Hide);
        o("</a>]</b>")(BN);
        
        //print file details
        o("<b>")(Phrase.Id)(":</b> ")(file.getId)(BN);
        
        o("<b>")(Phrase.Name)(":</b>\n");
        o("<form action=\"" ~ target_uri ~ "\" method=\"get\">\n");
        o("<input type=\"hidden\" name=\"to\" value=\"")(this.getId)("\" />\n");
        o("<input type=\"hidden\" name=\"id\" value=\"")(file.getId)("\" />\n");
        o("<input type=\"text\" name=\"new_name\" size=\"70\" value=\"")(file.getName)("\" />\n");
        if(subfiles.length == 0)
        {
            o(" [<a href=\"" ~ target_uri ~ "?to=")(this.getId)(AMP~"do=preview\">");
            o(Phrase.Preview);
            o("</a>]")(BN);
        }
        
        o("<button type=\"submit\" name=\"do\" ");
        if(file.getState == File_.State.COMPLETE)
        {
            o("value=\"commit\">")(Phrase.Commit);
        }
        else
        {
            o("value=\"rename\">")(Phrase.Rename);
        }
        o("</button>\n");
        
        o("</form>")(BN);
        
        //display networks
        o("<b>")(Phrase.Network)(":</b> ");
        Node[] networks;
        if(nodes)
        {
            networks = nodes.getNodeArray(Node_.Type.NETWORK, Node_.State.ANYSTATE, 0);
        }
        if(networks)
        {
            foreach(network; networks)
            {
                char[] name = network.getName();
                bool connected = (network.getState == Node_.State.CONNECTED);
                if(connected) o(name);
                else o("[")(name)("]");
                o(" ");
            }
        }
        o(BN);
        
        //print alternative file names
        auto source_files = file.getFileArray(File_.Type.SOURCE, File_.State.ANYSTATE, 0);
        if(source_files.length)
        {
            o("<b>")(Phrase.FileNames)(":</b>")(BN);
            o("<div class=\"scrollable\">\n");
            o("<ul>\n");
            foreach(source_file; source_files)
            {
                o("<li>");
                o(cropFileName(source_file.getName, 120));
                auto sources = source_file.getNodeCount(Node_.Type.UNKNOWN,  Node_.State.ANYSTATE);
                if(sources)
                {
                    o(" (")(Phrase.Sources)(": ")(sources)(")");
                }
                o("</li>\n");
            }
            o("</ul>\n");
            o("</div>\n");
            o(BN);
        }
        
        o("<b>")(Phrase.Size)(":</b> ")(formatSize(file.getSize))(" (")(file.getSize)(" Bytes)")(BN);
        o("<b>")(Phrase.Downloaded)(":</b> ")(formatSize(file.getDownloaded))(BN);
        o("<b>")(Phrase.Uploaded)(":</b> ")(formatSize(file.getUploaded))(BN);
        o("<b>")(Phrase.State)(":</b> ")(formatFileState(file.getState))(BN);
        
        if(nodes)
        {
            o("<b>")(Phrase.Sources)(":</b> ");
            uint connected = nodes.getNodeCount(Node_.Type.CLIENT, Node_.State.CONNECTED);
            uint disconnected = nodes.getNodeCount(Node_.Type.CLIENT, Node_.State.DISCONNECTED);
            o(Phrase.Connected)(": ")(connected)(", ");
            o(Phrase.Disconnected)(": ")(disconnected)(BN);
        }
        
        if(file_format.length) o("<b>")(Phrase.Format)(":</b> ")(file_format)(BN);
        o("<b>")(Phrase.Priority)(":</b> ")(file.getPriority)(BN);
        o("<b>")(Phrase.DownloadRate)(":</b> ")(formatSpeed(file.getDownloadRate))(BN);
        o("<b>")(Phrase.UploadRate)(":</b> ")(formatSpeed(file.getUploadRate))(BN);
        if(hash.length) o("<b>")(Phrase.Hash)(":</b> ")(hash)(BN);
        o("<b>")(Phrase.Last_Seen)(":</b> ")(formatTime(file.getLastSeen))(BN);
        
        //print users
        auto users = file.getUsers;
        User[] users_array;
        if(users) users_array = users.getUserArray();
        if(users_array)
        {
            o("<b>")(Phrase.Users)(":</b> ");
            size_t i;
            foreach(user; users_array)
            {
                if(i) o(", ");
                o(user.getName);
                i++;
            }
        }
        o(BN);
    
        auto chunks = file.getFileArray(File_.Type.CHUNK, File_.State.ANYSTATE, 0);
        if(chunks.length)
        {
            o("<b>")(Phrase.Chunks)(":</b>\n");
            insertChunkBar(o, file, 120);
            o(BN);
        }
        
        //print comments
        Meta[] comments;
        if(auto metas = file.getMetas)
        {
            comments = metas.getMetaArray(Meta_.Type.COMMENT, Meta_.State.ANYSTATE, 0);
        }
        
        if(comments.length)
        {
            o("<b>")(Phrase.Comments)(" (")(comments.length)("):</b> ")(BN);
            o("<div class=\"scrollable\">\n");
            o("<ul>\n");
            foreach(comment; comments)
            {
                o("<li>");
                if(auto source = comment.getSource)
                {
                    o("<img src=\"/flag_img/")(source.getLocation)(".gif\" />");
                    o(source.getName);
                    o("(")(source.getHost)("): ");
                }
                o("\"")(comment.getMeta)("\"  ");
                o("(")(comment.getRating)(")");
                o("</li>\n");
            }
            o("</ul>\n");
            o("</div>\n");
        }
        
        //print subfiles
        if(subfiles.length)
        {
            o("<b>")(Phrase.SubFiles)(" (")(subfiles.length)("):</b> ")(BN);
            o("<div class=\"scrollable\">\n");
            o("<ul>\n");
            foreach(subfile; subfiles)
            {
                auto size = subfile.getSize();
                auto percent = 100.0;
                if(size != 0)
                {
                    percent = (percent * subfile.getDownloaded) / size;
                }
                o("<li>");
                o(subfile.getName);
                o(" [<a href=\"" ~ target_uri ~ "?to=")(this.getId)(AMP~"do=preview"~AMP~"id=")(subfile.getId)("\">");
                o(Phrase.Preview);
                o("</a>]");
                o(" (")(formatSize(size))(", ")(percent)("%");
                
                auto format = subfile.getFormat();
                if(format.length)
                {
                    o(", ")(Phrase.Format)(": \"")(format)("\"");
                }
                o(")");
                o("</li>\n");
            }
            o("</ul>\n");
            o("</div>\n");
        }
        o(BBN);
    }
}

/*
* Display a chunk bar.
*/
void insertChunkBar(HtmlOut o, File file, uint max_ranges)
{
    const uint steps = 9; //color steps
    
    auto chunks = file.getFileArray(File_.Type.CHUNK, File_.State.ANYSTATE, 0);
    uint file_sources = file.getNodeCount(Node_.Type.CLIENT, Node_.State.ANYSTATE);
    ulong file_size = file.getSize();
    
    if(file_size == 0 || chunks.length == 0) return;
    
    o("<table class=\"chunks\">\n");
    o("<tr>\n");

    ulong pre_size;
    ulong pre_down;
    uint pre_sources;
    ubyte pre_step;

    void printCell(ubyte step)
    {
        if(pre_size == 0) return;
        float width = 100.0 * pre_size / file_size;
        o("<td class=\"c")(step)("\" width=\"")(width)("%\">")("</td>\n");
    }
    
    uint merge = 1 + (chunks.length / max_ranges);
    
    uint i;
    while(i < chunks.length)
    {
        ulong size;
        ulong down;
        uint sources;
        
        for(uint j; j < merge && i < chunks.length; j++, i++)
        {
            auto chunk = chunks[i];
            size += chunk.getSize();
            down += chunk.getDownloaded();
            sources += chunk.getNodeCount(Node_.Type.CLIENT, Node_.State.ANYSTATE);
        }
        
        if(size ==  0) continue;
        
        ubyte step = cast(ubyte) round(steps * down / size);
        
        //nothing downloaded but sources
        if(step == 0 && sources) step = 1;
        
        if(step == pre_step)
        {
            pre_size += size;
            pre_down += down;
            pre_sources += sources;
        }
        else
        {
            printCell(pre_step);
            pre_size = size;
            pre_down = down;
            pre_sources = sources;
            pre_step = step;
        }
    }
    
    if(pre_size)
    {
        printCell(pre_step);
    }
    
    o("</tr>\n");
    o("</table>\n");
}

/*
* Table cell generators for File interface.
*/

interface Column
{
    public:
    Phrase getName(); //column title
    void getCell(HtmlOut o, File d, HtmlDownloads mod); //<td></td> cell
    bool compare(File a, File b);
}

final class SizeColumn : Column
{
    Phrase getName() { return Phrase.Size; }
    void getCell(HtmlOut o, File d, HtmlDownloads mod)
    {
        o("<td class=\"size\">");
        o(formatSize(d.getSize));
        o("</td>\n");
    }
    
    bool compare(File a, File b)
    {
        return a.getSize > b.getSize;
    }
}

final class NameColumn : Column
{
    Phrase getName() { return Phrase.Name; }
    void getCell(HtmlOut o, File d, HtmlDownloads mod)
    {
        char[] name = d.getName();
        if(mod.enable_rotx)
        {
            name = Utils.rotX(name.dup, mod.enable_rotx);
        }
        
        if(mod.enable_l33t)
        {
            name = Utils.l33t(name);
        }
        
        o("<td class=\"name\">\n");
        o("<a href=\"" ~ target_uri ~ "?to=")(mod.getId)(AMP~"do=show"~AMP~"id=")(d.getId)("\">")(name)("</a>\n");
        
        if(mod.show_percent_bar)
        {
            auto size = d.getSize;
            auto downloaded = d.getDownloaded;
            if(size == 0) size = 1; //avoid nan for percent
            auto percent = (cast(float) downloaded / size) * 100.0;
            //o.format("{0:0.1} %", percent);
            o("<div class=\"prog-border\">");
            o("<div class=\"prog-bar\" style=\"width: ")(percent)("%;\">");
            o("</div></div>\n");
            
        }
        
        o("</td>\n");
    }
    
    bool compare(File a, File b)
    {
        return a.getName < b.getName;
    }
}

/*
final class NamePercentColumn : Column
{
    Phrase getName() { return Phrase.Name; }
    void getCell(HtmlOut o, File d, HtmlDownloads mod)
    {
        auto size = d.getSize;
        auto downloaded = d.getDownloaded;
        if(size == 0) size = 1; //avoid nan for percent
        auto percent = (cast(float) downloaded / size) * 100.0;
        o("<td class=\"name\">");
        o("<a href=\"" ~ target_uri ~ "?to=")(mod.getId)(AMP~"do=show"~AMP~"id=")(d.getId)("\">")(d.getName)("</a>\n");
        o("<div class=\"prog-border\">");
        o("<div class=\"prog-bar\" style=\"width: ")(percent)("%;\"></div>");
        o("</div>\n");
        o("</td>\n");
    }
    
    bool compare(File a, File b)
    {
        return a.getName > b.getName;
    }
}
*/

final class StateColumn : Column
{
    Phrase getName() { return Phrase.State; }
    void getCell(HtmlOut o, File d, HtmlDownloads mod)
    {
        o("<td class=\"state\">");
        o( formatFileState(d.getState) );
        o("</td>\n");
    }
    
    bool compare(File a, File b)
    {
        return a.getState < b.getState;
    }
}

void putSpeedCell(HtmlOut o, uint speed, File_.State state)
{
    o("<td class=\"");
    if(state == File_.State.ACTIVE)
    {
        if (speed <= 1 * 1024)  { o("speed_slowest"); }
        else if (speed <= 3 * 1024)  { o("speed_slow"); }
        else if (speed <= 5 * 1024)  { o("speed_medium"); }
        else if (speed <= 10 * 1024) { o("speed_fast"); }
        else if (speed <= 20 * 1024) { o("speed_faster"); }
        else { o("speed_fastest"); }
        o("\">");
        o(formatSpeed(speed));
    }
    else if(state == File_.State.PAUSED || state == File_.State.STOPPED)
    {
        o("speed_paused");
        o("\">-");
    }
    else if(state == File_.State.COMPLETE)
    {
        o("speed_complete");
        o("\">-");
    }
    else
    {
        o("speed_unknown");
        o("\">?");
    }
    o("</td>\n");
}

final class UploadRateColumn : Column
{
    Phrase getName() { return Phrase.UploadRate; }
    void getCell(HtmlOut o, File d, HtmlDownloads mod)
    {
        putSpeedCell(o, d.getUploadRate(), d.getState());
    }
    
    bool compare(File a, File b)
    {
        return a.getUploadRate > b.getUploadRate;
    }
}

final class DownloadRateColumn : Column
{
    Phrase getName() { return Phrase.DownloadRate; }
    void getCell(HtmlOut o, File d, HtmlDownloads mod)
    {
        putSpeedCell(o, d.getDownloadRate(), d.getState());
    }
    
    bool compare(File a, File b)
    {
        return a.getDownloadRate > b.getDownloadRate;
    }
}

/*
final class SpeedColumn : Column
{
    Phrase getName() { return Phrase.Speed; }
    void getCell(HtmlOut o, File d, HtmlDownloads mod)
    {
        o("<td class=\"speed\">&darr;");
        o(formatSpeed(d.getDownloadRate));
        o("/");
        o(formatSpeed(d.getUploadRate));
        o("&uarr;</td>\n");
    }
    
    bool compare(File a, File b)
    {
        return (a.getDownloadRate + a.getUploadRate) > (b.getDownloadRate + b.getUploadRate);
    }
}
*/

final class DownloadedColumn : Column
{
    Phrase getName() { return Phrase.Downloaded; }
    void getCell(HtmlOut o, File d, HtmlDownloads mod)
    {
        o("<td class=\"completed\">");
        o(formatSize(d.getDownloaded));
        o("</td>\n");
    }
    
    bool compare(File a, File b)
    {
        return a.getDownloaded > b.getDownloaded;
    }
}

final class UploadedColumn : Column
{
    Phrase getName() { return Phrase.Uploaded; }
    void getCell(HtmlOut o, File d, HtmlDownloads mod)
    {
        o("<td class=\"uploaded\">");
        o(formatSize(d.getUploaded));
        o("</td>\n");
    }
    
    bool compare(File a, File b)
    {
        return a.getUploaded > b.getUploaded;
    }
}

final class IdColumn : Column
{
    Phrase getName() { return Phrase.Id; }
    void getCell(HtmlOut o, File d, HtmlDownloads mod)
    {
        o("<td class=\"id\">");
        o(d.getId);
        o("</td>\n");
    }
    
    bool compare(File a, File b)
    {
        return a.getId > b.getId;
    }
}

final class PriorityColumn : Column
{
    Phrase getName() { return Phrase.Priority; }
    void getCell(HtmlOut o, File d, HtmlDownloads mod)
    {
        o("<td class=\"priority\">");
        o(formatPriority(d.getPriority));
        o("</td>\n");
    }
    
    bool compare(File a, File b)
    {
        return a.getPriority > b.getPriority;
    }
}

final class UserColumn : Column
{
    Phrase getName() { return Phrase.Users; }
    void getCell(HtmlOut o, File d, HtmlDownloads mod)
    {
        auto users = d.getUsers;
        User[] all;
        if(users) all = users.getUserArray;
        o("<td class=\"users\">");
        if(all)
        {
            foreach(user; all)
            {
                o(user.getName)(", ");
            }
        }
        o("</td>\n");
    }
    
    bool compare(File a, File b)
    {
        auto a_users = a.getUsers;
        auto b_users = b.getUsers;
        if(a_users is null || b_users is null) return false;
        auto a_array = a_users.getUserArray;
        auto b_array = b_users.getUserArray;
        if(a_array.length == 0 || b_array.length == 0) return false;
        return a_array[0].getName < a_array[0].getName;
    }
}

final class CheckBoxColumn : Column
{
    Phrase getName() { return Phrase.Check; }
    void getCell(HtmlOut o, File d, HtmlDownloads mod)
    {
        o("<td class=\"check\">");
        o("<input type=\"checkbox\" name=\"ids\" value=\"")(d.getId)("\" />");
        o("</td>\n");
    }
    
    bool compare(File a, File b)
    {
        return false;
    }
}

final class ETAColumn : Column
{
    Phrase getName() { return Phrase.ETA; }
    void getCell(HtmlOut o, File d, HtmlDownloads mod)
    {
        o("<td class=\"eta\">");
        ulong speed = d.getDownloadRate;
        ulong bytes = d.getSize - d.getDownloaded;
        if(speed)
        {
            o(formatTime(bytes / speed));
        }
        else
        {
            o("&infin;");
        }
        o("</td>\n");
    }
    
    bool compare(File a, File b)
    {
        ulong a_speed = a.getDownloadRate;
        ulong a_bytes = a.getSize - a.getDownloaded;
        if(a_speed == 0) a_speed = 1;
        
        ulong b_speed = b.getDownloadRate;
        ulong b_bytes = b.getSize - b.getDownloaded;
        if(b_speed == 0) b_speed = 1;
        
        return (a_bytes / a_speed) < (b_bytes / b_speed);
    }
}

final class PercentColumn : Column
{
    Phrase getName() { return Phrase.Percent; }
    void getCell(HtmlOut o, File d, HtmlDownloads mod)
    {
        o("<td class=\"percent\">");
        ulong size = d.getSize;
        ulong downloaded = d.getDownloaded;
        if(size == 0) size = 1; //avoid nan for percent
        float percent = (cast(float) downloaded / size) * 100.0;
        o.format("{0:0.1} %", percent);
        o("</td>\n");
    }
    
    bool compare(File a, File b)
    {
        return a.getDownloaded > b.getDownloaded;
    }
}

final class LastSeenColumn : Column
{
    Phrase getName() { return Phrase.Last_Seen; }
    void getCell(HtmlOut o, File d, HtmlDownloads mod)
    {
        o("<td class=\"lastseen\">");
        o(formatTime(d.getLastSeen));
        o("</td>\n");
    }
    
    bool compare(File a, File b)
    {
        return a.getLastSeen < b.getLastSeen;
    }
}

final class SourcesColumn : Column
{
    Phrase getName() { return Phrase.Sources; }
    void getCell(HtmlOut o, File d, HtmlDownloads mod)
    {
        auto nodes = d.getNodes();
        o("<td class=\"sources\">");
        if(nodes)
        {
            uint connected = nodes.getNodeCount(Node_.Type.CLIENT, Node_.State.CONNECTED);
            uint disconnected = nodes.getNodeCount(Node_.Type.CLIENT, Node_.State.DISCONNECTED);
            o(disconnected)(" (")(connected)(")");
        }
        o("</td>\n");
    }
    
    bool compare(File a, File b)
    {
        uint a_nodes, b_nodes;
        if(auto nodes = a.getNodes)
        {
            a_nodes = nodes.getNodeCount(Node_.Type.CLIENT, Node_.State.ANYSTATE);
        }
        if(auto nodes = b.getNodes)
        {
            b_nodes = nodes.getNodeCount(Node_.Type.CLIENT, Node_.State.ANYSTATE);
        }
        return a_nodes > b_nodes;
    }
}

final class NetworksColumn : public Column
{
    Phrase getName() { return Phrase.Networks; }
    void getCell(HtmlOut o, File d, HtmlDownloads mod)
    {
        Node[] networks;
        if(auto nodes = d.getNodes)
        {
            networks = nodes.getNodeArray(Node_.Type.NETWORK, Node_.State.ANYSTATE, 0);
        }
        o("<td class=\"networks\">");
        if(networks)
        {
            foreach(network; networks)
            {
                char[] name = network.getName();
                if(name.length == 0) name = "Unknown";
                bool connected = (network.getState == Node_.State.CONNECTED);
                o("<img src=\"/net_img/")(name)(connected ? "_connected.gif\" />" : "_disabled.gif\" />");
            }
        }
        else
        {
            o("<img src=\"/net_img/Unknown_connected.gif\" />");
        }
        o("</td>\n");
    }
    
    bool compare(File a, File b)
    {
        auto a_nodes = a.getNodes;
        auto b_nodes = b.getNodes;
        if(a_nodes is null || b_nodes is null) return false;
        auto a_nets = a_nodes.getNodeArray(Node_.Type.NETWORK, Node_.State.ANYSTATE, 0);
        auto b_nets = b_nodes.getNodeArray(Node_.Type.NETWORK, Node_.State.ANYSTATE, 0);
        if(a_nets.length == 0 || b_nets.length == 0) return false;
        return a_nets[0].getId < b_nets[0].getId;
    }
}

final class ChunksColumn : public Column
{
    Phrase getName() { return Phrase.Chunks; }
    void getCell(HtmlOut o, File d, HtmlDownloads mod)
    {
        o("<td>\n"); //class=\"chunks\"
        insertChunkBar(o, d, 15);
        o("</td>\n");
    }
    
    bool compare(File a, File b)
    {
        auto a_cc = a.getFileCount(File_.Type.CHUNK, File_.State.COMPLETE);
        auto b_cc = a.getFileCount(File_.Type.CHUNK, File_.State.COMPLETE);
        return a_cc < b_cc;
    }
}
