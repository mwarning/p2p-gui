module webguis.plex.HtmlContainer;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/

import tango.io.Stdout;
import Tango = tango.io.device.File;
import tango.io.FilePath;

import webserver.HttpRequest;
import webserver.HttpResponse;

import api.User;
static import Main = webcore.Main;
static import Utils = utils.Utils;
import webcore.Logger;

import webguis.plex.PlexGui;
import webguis.plex.HtmlElement;
import webguis.plex.HtmlUtils;


final class HtmlContainer : HtmlElement
{
    char[] file_path;
    char[] content;
    
    bool reload_content;
    
    this()
    {
        super(Phrase.Container);
        addSetting(Phrase.content_source, &file_path, &setContentSource);
        addSetting(Phrase.reload_content, &reload_content);
    }
    
    void save(Storage s)
    {
        s.save("container_content", &content);
        s.save("container_reload_content", &reload_content);
    }
    
    void load(Storage s)
    {
        s.load("container_content", &setContentSource);
        s.load("container_reload_content", &reload_content);
    }
    
    private void setContentSource(char[] source)
    {
        if(source.length == 0)
        {
            file_path = null;
            content = null;
            return;
        }
        
        scope path = new FilePath(source);
        if(!path.exists || path.isFolder)
        {
            Logger.addWarning("HtmlContainer: File doesn't exists!");
            return;
        }
        
        if(path.fileSize > 100*1024)
        {
            Logger.addWarning("HtmlContainer: Can't use files bigger 100Kb.");
            return;
        }
        
        if(reload_content)
        {
            file_path = source;
            content = null;
        }
        else try
        {
            content = cast(char[]) Tango.File.get(source);
            file_path = source;
        }
        catch(Object e)
        {
            Logger.addWarning("HtmlContainer: Can't read file!");
        }
    }
    
    void handle(HttpRequest req, Session session) {}
    
    void handle(HttpResponse res, Session session)
    {
        HtmlOut o = { res.getWriter(), &session.getUser.translate};
        
        if(reload_content && file_path.length)
        {
            try
            {
                content = cast(char[]) Tango.File.get(file_path);
                o(content);
            }
            catch(Object e)
            {
                reload_content = false;
            }
        }
        else if(content.length)
        {
            o(content);
        }
        else
        {
            o("<h3>")(Phrase.Nothing_Selected)("</h3>\n");
        }
    }
}
