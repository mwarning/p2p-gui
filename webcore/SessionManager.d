module webcore.SessionManager;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import tango.io.Stdout;
import tango.time.Clock;
import tango.core.Thread;
import tango.util.container.more.Stack;

import webserver.HttpRequest;
import webserver.HttpResponse;

import webcore.Main;
import webcore.MainUser;
import webcore.Session;
import utils.Utils;


/*
* Manage all session instances.
*/
struct SessionManager
{
    private static Session[char[]] sessions; //all sessions
    const ulong max_session_age = 60 * 60 * 24; //one day
    
    public static Session getThreadSession()
    {
        return cast(Session) Thread.getLocal(0);
    }

    public static void setThreadSession(Session session = null)
    {
        Thread.setLocal(0, cast(void*) session);
    }
    
    /*
    * Invalidate own session / logout
    */
    static void invalidateSession()
    {
        auto session = getThreadSession();
        if(session) remove(session);
    }
    
    static void remove(Session session)
    {
        assert(session);
        remove(session.getSid);
    }
    
    static void remove(char[] sid)
    {
        sessions.remove(sid);
    }
    
    /*
    * Remove all session of this user (forced logout).
    */
    static void remove(MainUser user)
    {
        foreach(session; sessions)
        {
            if(session.getUser is user)
            {
                SessionManager.remove(session);
            }
        }
    }
    
    static Session get(char[] sid)
    {
        if(sid.length == 0) return null;
        auto ptr = (sid in sessions);
        return ptr ? *ptr : null;
    }
    
    //hack to get a session for saving settings
    static Session getByUserName(char[] username)
    {
        foreach(session; sessions)
        {
            if(session.getUser.getName == username)
            {
                return session;
            }
        }
        return null;
    }
    
    static void add(Session session)
    {
        sessions[session.getSid] = session;
    }
    
    /*
    * Remove old sessions.
    */
    static void removeOld()
    {
        Stack!(char[], 32) sids; //session ids
        ulong now = (Clock.now - Time.epoch1970).seconds;
        
        do
        {
            sids.clear();
            
            //find
            foreach(session; sessions)
            {
                if(now - session.getLastAccessed >= max_session_age)
                {
                    if(sids.unused == 0) break;
                    sids.push(session.getSid);
                }
            }
            
            //remove
            foreach(sid; sids.slice)
            {
                sessions.remove(sid);
            }
        }
        while(sids.unused == 0) //full?
    }
}

