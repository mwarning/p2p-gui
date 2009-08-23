module webcore.Session;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import tango.io.Stdout;
import tango.io.model.IConduit;
import tango.time.Clock;

import webserver.HttpRequest;
import webserver.HttpResponse;

import webcore.Main;
import webcore.MainUser;
import webcore.SessionManager;
import webcore.Logger;

/*
* HTTP session class.
*/
class Session
{
private:
    
    char[] sid;
    MainUser user;
    ulong last_accessed;

    //source info for a file that is going to be uploaded to the user.
    InputStream source;
    ulong source_size;
    char[] source_name;

public:

    this(char[] sid, MainUser user)
    {
        this.sid = sid;
        this.user = user;
    }
    
    Gui[] getGuis()
    {
        last_accessed =  (Clock.now - Time.epoch1970).seconds;
        return user.getGuis();
    }
    
    /*
    * Get the session identifier.
    */
    char[] getSid()
    {
        return sid;
    }
    
    MainUser getUser()
    {
        return user;
    }
    
    T getGui(T)()
    {
        foreach(gui; user.getGuis)
        {
            auto core = cast(T) gui;
            if(core) return core;
        }
        
        throw new Exception("(E) Session: Can't find gui instance of type " ~ T.stringof ~ "!");
    }
    
    /*
    * Send file to browser and trigger download dialog
    */
    void sendFile(HttpResponse res)
    {
        if(source && source_name.length)
        {
            res.addHeader("Content-Disposition: attachment; filename=\"" ~ source_name ~ "\"");
            res.setContentType("application/octet-stream");
            res.setBodySource(source, source_size);
        }
        else
        {
            res.setCode(HttpResponse.Code.NOT_FOUND);
        }
        
        source = null;
        source_size = 0;
        source_name = null;
    }
    
    /*
    * Set file source to be put into the http response body.
    */
    static void saveFile(InputStream source, char[] name, ulong size)
    {
        auto s = SessionManager.getThreadSession();
        if(s is null)
        {
            Logger.addError("Session: Can't find session to set download source!");
        }
        s.source = source;
        s.source_size = size;
        s.source_name = name;
    }
    
    /*
    * Check if this session has a file attached.
    */
    bool hasFile()
    {
        return (source && source_name.length);
    }

    /*
    * When was this session used the last time?
    * Used for auto-logout.
    */
    ulong getLastAccessed()
    {
        return last_accessed;
    }
}
