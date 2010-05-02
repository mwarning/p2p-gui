module webguis.plex.HtmlTitlebar;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/

import webserver.HttpRequest;
import webserver.HttpResponse;

import api.File;
import api.Node;
import api.Meta;
import api.User;

import tango.io.Stdout;
import tango.core.Array;

import webguis.plex.PlexGui;
import webguis.plex.HtmlElement;
import webguis.plex.HtmlUtils;


final class HtmlTitlebar : HtmlElement
{
private:
    
    uint num_lines = 1;
    
    static Phrase[] designs = [Phrase.Default_Titlebar, Phrase.Icon_Titlebar, Phrase.Plain_Titlebar];
    Phrase design = Phrase.Default_Titlebar;
    void delegate(HtmlOut) insert_navigation;

    HtmlElement page_refresh;
    HtmlElement[] elements; //visible modules in the navigation bar
    HtmlElement selected = null;

    public this()
    {
        super(Phrase.Titlebar, "");
        insert_navigation = &insertTableTitlebar;
        
        visible = true;
        display_in_titlebar = false;
        
        addSetting(Phrase.design, &designs, &design, &setTitlebar);
        addSetting(Phrase.elements, &elements);
        addSetting(Phrase.Number_of_Lines, &num_lines);
    }
    
    public void resetSelected()
    {
        if(selected)
        {
            selected.visible = false;
            selected = null;
        }
    }
    
    void save(Storage s)
    {
        s.save("num_lines", &num_lines);
    }
    
    void load(Storage s)
    {
        s.load("num_lines", &num_lines);
    }
    
    private void setTitlebar(Phrase phrase)
    {
        switch(phrase)
        {
            case Phrase.Icon_Titlebar:
                design = phrase;
                insert_navigation = &insertIconTitlebar;
                break;
            case Phrase.Plain_Titlebar:
                design = phrase;
                insert_navigation = &insertPlainTitlebar;
                break;
            default:
                design = Phrase.Default_Titlebar;
                insert_navigation = &insertTableTitlebar;
        }
    }
    
    override public void changed(HtmlElement[] items)
    {
        foreach(item; items)
        {
            if(item.name == Phrase.PageRefresh)
            {
                if(item.remove) page_refresh = null;
                else page_refresh = item;
                continue;
            }
            
            uint pos = find(elements, item);
            
            if(pos == elements.length) //add
            {
                if(item.display_in_titlebar && !item.remove)
                {
                    elements ~= item;
                }
            }
            else if(!item.display_in_titlebar || item.remove) //remove
            {
                HtmlElement[] elems;
                elems ~= elements[0..pos];
                elems ~= elements[pos+1..$];
                elements = elems;
            }
        }
    }
    
    override public void handle(HttpRequest req, Session session)
    {
        //show module
        uint module_id = req.getParameter!(uint)("show");
        if(module_id)
        {
            auto select = session.getGui!(PlexGui).getModule(module_id);
            if(select)
            {
                if(!select.display_in_titlebar) return;
                if(selected) { selected.visible = false; }
                select.visible = true;
                selected = select;
            }
        }
        else
        {
            auto metas = session.getUser.getMetas();
            if(metas is null) return;
            
            //remove messages
            uint[] ids = req.getParameter!(uint[])("remove");
            foreach(id; ids)
            {
                metas.removeMeta(Meta_.Type.LOG, id);
            }
        }
    }
    
    override public void handle(HttpResponse res, Session session)
    {
        //create output wrapper
        HtmlOut o;
        o.init(res.getWriter(), &session.getUser.translate);
        
        //insert navigation bar
        insert_navigation(o);
        
        //insert three-element info bar
        insertInfoBar(res, session);
    }
    
    void insertTableTitlebar(HtmlOut o)
    {
        auto partition = getPartition(elements, num_lines);
        
        foreach(i, line; partition)
        {
            o("<table class=\"tablepanel\">\n");
            
            o("<tr>\n");
            
            foreach(item; line)
            {
                if(!item.display_in_titlebar) continue;
                
                if(item == selected && !item.exec_only)
                {
                    o("<td class=\"selected\">");
                }
                else
                {
                    o("<td>");
                }
                
                if(item.exec_only)
                {
                    o("<a href=\"" ~ target_uri ~ "?to=")(item.getId)("\">");
                }
                else
                {
                    o("<a href=\"" ~ target_uri ~ "?to=")(this.getId)(AMP~"show=")(item.getId)("\">");
                }
                
                o(item.getName);
                o("</a>");
                
                o("</td>\n");
            }
            
            o("</tr>\n");
            o("</table>\n");
        }
    }
    
    void insertPlainTitlebar(HtmlOut o)
    {
        auto partition = getPartition(elements, num_lines);
        
        o("<div class=\"plainpanel\">\n");
        o("<hr/>\n");
        
        foreach(line; partition)
        {
            o("<span class=\"nobr\">\n");
            size_t c;
            foreach(item; line)
            {
                if(!item.display_in_titlebar) continue;
                
                if(c != 0) o(" | ");
                
                if(item == selected) o("<b>");
                
                o("<a href=\"" ~ target_uri ~ "?to=")(this.getId)(AMP~"show=")(item.getId)("\">");
                o(item.getName);
                o("</a>");
                
                if(item == selected) o("</b>");
                o("\n");
                
                c++;
            }
            o("</span>\n");
        }
        
        o("<hr/>\n");
        o("</div>\n");
    }
    
    void insertIconTitlebar(HtmlOut o)
    {
        auto partition = getPartition(elements, num_lines);
        
        foreach(line; partition)
        {
            o("<table class=\"iconpanel\">\n");
            o("<tr>\n");
            
            foreach(item; line)
            {
                if(!item.display_in_titlebar) continue;
                
                o("<td id=\"")(item.getCssIdString)("_bg\">");
                o("<a href=\"" ~ target_uri ~ "?to=")(this.getId)(AMP~"show=")(item.getId)("\">");
                o(item.getName);
                o("</a>");
                o("</td>\n");
            }
            
            o("</tr>\n");
            o("</table>\n");
        }
    }
    
    void insertInfoBar(HttpResponse res, Session session)
    {
        HtmlOut o;
        o.init(res.getWriter(), &session.getUser.translate);
        
        o("<table>\n");
        o("<tr align=\"center\">\n");
        o("<td align=\"left\" width=\"33%\">\n");
        
        insertMessages(o, session.getUser);
        
        o("</td>\n");
        o("<td align=\"center\" width=\"33%\">");
        if(selected) o("<h2>")(selected.getName)("</h2>");
        o("</td>\n");
        o("<td align=\"right\" width=\"33%\">\n");
        
        if(page_refresh)
        {
            page_refresh.handle(res, session);
        }
        
        o("</td>\n");
        o("</tr>\n");
        o("</table>\n");
    }
    
    void insertMessages(HtmlOut o, User user)
    {
        auto msgs = user.getMetas.getMetaArray(Meta_.Type.LOG, Meta_.State.ANYSTATE, 30);

        if(msgs.length == 0)
            return;
        
        sort(msgs, delegate bool (Meta x, Meta y) { return x.getLastChanged < y.getLastChanged; });
        
        uint[] ids;
        
        foreach(msg; msgs)
        {
            auto type = msg.getType();
            char[] text = msg.getMeta();
            
            switch(type)
            {
                case Meta_.Type.INFO:
                    o("<span class=\"nobr info\">")(text)("</span>\n");
                    break;
                case Meta_.Type.STATUS:
                    o("<span class=\"nobr status\">")(text)("</span>\n");
                    break;
                case Meta_.Type.WARNING:
                    o("<span class=\"nobr warning\">")(text)("</span>\n");
                    break;
                case Meta_.Type.ERROR:
                    o("<span class=\"nobr error\">")(text)("</span>\n");
                    break;
                case Meta_.Type.FATAL:
                    o("<span class=\"nobr fatal\">")(text)("</span>\n");
                    break;
                default:
                    continue;
            }
            
            ids ~= msg.getId();
            
            o(BN);
        }
        
        if(ids.length)
        {
            o("<a href=\"" ~ target_uri ~ "?to=")(this.getId)(AMP~"remove=");
            foreach(i, id; ids)
            {
                if(i) o(",");
                o(id);
            }
            o("\">[drop]</a>")(BN);
        }
    }
}
