module webguis.plex.HtmlFileBrowser;

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
import tango.io.FilePath;
static import tango.io.device.File;
import tango.core.Array;

static import Main = webcore.Main;
import webcore.MainUser;
import webcore.Dictionary;
import webcore.Logger;

import api.Client;
import api.User;
import api.Node;
import api.File;

import webguis.plex.PlexGui;
import webguis.plex.HtmlElement;
import webguis.plex.HtmlUtils;


Column delegate()[ushort] column_loaders;

void file_browser_init()
{
    if(column_loaders.length) return;
    
    column_loaders = [
        Phrase.Id : { return cast(Column) new IdColumn; },
        Phrase.Check : { return cast(Column) new CheckBoxColumn; },
        Phrase.Name : { return cast(Column) new NameColumn; },
        Phrase.Size : { return cast(Column) new SizeColumn; },
        Phrase.Type : { return cast(Column) new TypeColumn; }
    ];
}

final class HtmlFileBrowser : HtmlElement
{
private:
    
    Column[] columns;
    
    bool show_disk_stats;
    bool show_directories = true;
    bool allow_file_upload = true;
    bool allow_file_download = true;
    bool allow_file_remove = true;
    bool show_hidden_files = true;
    
    uint directory_id;
    
    bool delegate(File, File) compare;
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
        super(Phrase.FileBrowser);
        file_browser_init();
        
        setColumns ([Phrase.Check, Phrase.Type, Phrase.Name, Phrase.Size]);
        compare = &columns[0].compare;
        
        addSetting(Phrase.allow_file_upload, &allow_file_upload);
        addSetting(Phrase.show_directories, &show_directories);
        addSetting(Phrase.show_hidden_files, &show_hidden_files);
    }
    
    void save(Storage s)
    {
        s.save("show_directories", &show_directories);
        s.save("show_hidden_files", &show_hidden_files);
        s.save("allow_file_remove", &allow_file_remove);
    }
    
    void load(Storage s)
    {
        s.load("show_directories", &show_directories);
        s.load("show_hidden_files", &show_hidden_files);
        s.load("allow_file_remove", &allow_file_remove);
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
        auto user = session.getUser;
        char[] action = req.getParameter("do");
        uint id = req.getParameter!(uint)("id", uint.max);
        
        if(action == "sort")
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
        else if(show_directories && action == "open")
        {
            directory_id = id;
        }
        else if(allow_file_download && action == "download")
        {
            auto files = user.getFiles();
            if(files)
            {
                files.previewFile(File_.Type.FILE, id);
            }
        }
        else if(allow_file_remove && action == "remove")
        {
            auto ids = req.getParameter!(uint[])("ids");
            auto files = user.getFiles();
            if(ids.length && files)
            {
                files.removeFiles(File_.Type.FILE, ids);
            }
        }
        else if(allow_file_upload && action == "upload")
        {
            char[] dir = user.getDirectory();
            char[][] files = req.getFiles();
            
            //move files
            foreach(file; files)
            {
                try
                {
                    uint i = 0;
                    auto src = FilePath(file);
                    auto dst = FilePath(src.file).prepend(dir);
                    //when file already exists
                    while(dst.exists)
                    {
                        i++;
                        dst = FilePath(src.name ~ "(" ~ Convert.to!(char[])(i) ~ ")" ~ src.suffix).prepend(dir);
                    }
                    src.rename(dst);
                }
                catch(Object o)
                {
                    Logger.addError("HtmlFileBrowser: " ~ o.toString);
                }
            }
        }
        else if(action == "start_local_torrents")
        {
            //start selected files
            Files directory = user.getFiles();
            uint[] ids = req.getParameter!(uint[])("ids");
            auto client = cast(Client) session.getGui!(PlexGui).getClient();
            
            if(directory is null || client is null || ids.length == 0)
            {
                return;
            }
            
            foreach(id_; ids) try
            {
                directory.previewFile(File_.Type.FILE, id_);
               
                auto stream = session.getSourceStream();
                auto name = session.getSourceName();
                auto size = session.getSourceSize();
                
                session.resetSource();
                
                if(stream is null)
                {
                    Logger.addError("HtmlFileBrowser: File not found: '{}'", name);
                    continue;
                }

                if(!Utils.is_suffix(name, ".torrent"))
                {
                    Logger.addWarning("HtmlFileBrowser: File is no torrent file: '{}'", name);
                    continue;
                }
                
                if(size > 200 * 1024 || size == 0)
                {
                    Logger.addWarning("HtmlFileBrowser: Torrent file is too big or zero: '{}'", name);
                    continue;
                }
                
                auto data = new void[](size);
                stream.read(data);
                client.addLink(cast(char[]) data);
            }
            catch(Exception e)
            {
                Logger.addError("HtmlFileBrowser: {}", e.toString);
            }
        }
    }
    
    void handle(HttpResponse res, Session session)
    {
        HtmlOut o;
        o.init(res.getWriter(), &session.getUser.translate);
        
        auto user = session.getUser();
        
        bool client_available = (session.getGui!(PlexGui).getClient !is null);
        Files dir = user.getFiles();
        if(dir is null)
        {
            o("<b>")(Phrase.Not_Available)("</b>\n");
            return;
        }
        File base_file;
        
        if(directory_id)
        {
            base_file = dir.getFile(File_.Type.DIRECTORY, directory_id);
            dir = base_file;
            if(dir is null)
                Logger.addWarning(user, "HtmlFileBrowser: File not found.");
            
            directory_id = 0;
        }

        if(show_disk_stats)
        {
            ulong size;
            ulong avail;
            float used; //(1 - avail / size) * 100;
            o("<div class=\"smalltext\"><b>");
            o(Phrase.Size)(": ")(formatSize(size))(" | ");
            o("Used: ")(formatSize(size - avail))(" (")(used)("%) | ");
            o(Phrase.Availability)(": ")(formatSize(avail))("<br>");
            o("</b></div>\n");
        }
        
        ulong dir_size;
        uint col_count = columns.length;
        
        o("<b>")(Phrase.Directory)(": &quot;")(base_file ? base_file.getName : "")("&quot;</b>");
        
        o("<form name=\"incoming\" action=\"" ~ target_uri ~ "\" method=\"get\">");
        
        o("<table class=\"mid\">\n");
        
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
        
        File[] files;
        if(dir) files = dir.getFileArray(File_.Type.UNKNOWN, File_.State.ANYSTATE, 0);
        
        if(files is null)
        {
            //o("<b>")(Phrase.Not_Supported)("</b>\n");
            o("<b>")(Phrase.No_Home_Directory)("</b>\n");
            return;
        }
        
        sort(files, compare);
        if(invert_compare) files.reverse;
        
        auto mod_id = this.getId();
        size_t c;
        foreach(file; files)
        {
            if(!show_directories && file.getType == File_.Type.DIRECTORY) continue;
            if(!show_hidden_files && file.getName[0] == '.') continue;
            
            if(c%2) o("<tr class=\"odd\">\n");
            else  o("<tr class=\"even\">\n");
            
            foreach(col; columns)
            {
                col.getCell(o, file, mod_id);
            }
            
            o("</tr>\n");
            
            dir_size += file.getSize;
            c++;
        }
        
        if(c == 0)
        {
            o("<tr class=\"even\" ><td colspan=\"")(col_count)("\">");
            o(Phrase.No_Items_Found);
            o("</td></tr>\n");
        }
        
        if(dir_size)
        {
            o("<tr>");
            o("<td align=\"right\" colspan=\"")(col_count)("\">");
            o("<strong>")(formatSize(dir_size))("</strong>");
            o("</td>");
            o("</tr>\n");
        }
        
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
        
        o("<input type=\"hidden\" name=\"to\" value=\"")(this.getId)("\" />\n");
        
        if(allow_file_remove)
        {
            o("<button type=\"submit\" name=\"do\" value=\"remove\">");
            o(Phrase.Delete);
            o("</button>\n");
        }
        
        if( session.getGui!(PlexGui).getClient() )
        {
            o("<button type=\"submit\" name=\"do\" value=\"start_local_torrents\">");
            o(Phrase.Load_Torrent);
            o("</button>\n");
        }
        
        o("</form>");
        
        if(allow_file_upload)
        {
            o(BN);
            o("<form enctype=\"multipart/form-data\" action=\"" ~ target_uri  ~ "\" method=\"post\">\n\n");
            o("<b>")(Phrase.Upload_File)(":</b>")(SP2)("<input name=\"userfile\" type=\"file\">\n");
            o("<button type=\"submit\" name=\"do\" value=\"upload\">");
            o(Phrase.Upload);
            o("</button>\n");
            o("<input type=\"hidden\" name=\"to\" value=\"")(this.getId)("\" />\n");
            o("</form>\n");
        }
    }
}

interface Column
{
    public:
    Phrase getName();
    void getCell(HtmlOut o, File a, ushort mod_id);
    bool compare(File a, File b);
}

class IdColumn : Column
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

class SizeColumn : Column
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

class NameColumn : Column
{
    Phrase getName() { return Phrase.Name; }
    void getCell(HtmlOut o, File a, ushort mod_id)
    {
        if(a.getType == File_.Type.DIRECTORY)
        {
            o("<td class=\"name\"><a href='" ~ target_uri ~ "?to=")(mod_id)(AMP~"do=open"~AMP~"id=")(a.getId)("' >");
            o(cropFileName(a.getName, 120));
            o("</a></td>");
        }
        else
        {
            o("<td class=\"name\">");
            o("<a href='" ~ target_uri ~ "?to=")(mod_id)(AMP~"do=download"~AMP~"id=")(a.getId)("' >[D]</a>  ");
            o(cropFileName(a.getName, 120));
            o("</td>");
        }
    }
    
    bool compare(File a, File b)
    {
        return a.getName > b.getName;
    }
}

class CheckBoxColumn : Column
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


class TypeColumn : public Column
{
    Phrase getName() { return Phrase.Type; }
    void getCell(HtmlOut o, File a, ushort mod_id)
    {
        o("<td class=\"type\">");
        if(a.getType == File_.Type.DIRECTORY)
        {
            o("<img src=\"/" ~ resource_dir ~ "images/directory.png\" />");
        }
        else
        {
            o("<img src=\"/" ~ resource_dir ~ "images/file.png\" />");
        }
        o("</td>\n");
    }
    
    bool compare(File a, File b)
    {
        return a.getType() > b.getType();
    }
}
