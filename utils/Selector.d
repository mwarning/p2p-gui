module utils.Selector;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import tango.io.Stdout;
import tango.io.selector.model.ISelector;
import tango.io.selector.SelectSelector;
import tango.core.Thread;
import tango.net.device.Socket;

import webcore.Logger;


/*
* Watch for socket for events and call handlers.
*/

private class SWrapper
{
    private void delegate() caller;
    
    this(void delegate() caller)
    {
        this.caller = caller;
    }
    
    void run()
    {
        caller();
    }
}

private
{
    Socket[] sc_to_register;
    void delegate()[] dl_to_register;
    Socket[] sc_to_unregister;
    bool run = false;
    Object token;
}

static this()
{
    token = new Object();
}

public void register(Socket sc, void delegate() dl)
{
    debug(Selector)
        Logger.addDebug("Selector: register called");
    
    //workaound for Tango trunk bug
    sc.timeout = 0;
    
    assert(sc.socket.blocking == false, "Socket must be non-blocking");
    assert(sc.timeout == false, "Socket timout must be 0");
    
    synchronized(token)
    {
        sc_to_register ~= sc;
        dl_to_register ~= dl;
    }
}

public void shutdown()
{
    run = false;
}

public void unregister(Socket sc)
{
    debug(Selector)
        Logger.addDebug("Selector: unregister called");
    
    sc.shutdown(); //.close(); we close later! We need the file descriptor!
    synchronized(token)
    {
        sc_to_unregister ~= sc;
    }
}

/*
* Watch sockets for incoming data
*/
void selector_loop(void delegate(void delegate()) add_task)
{
    if(run)
    {
        Logger.addWarning("Selector: Selector loop is already running!");
        return;
    }
    
    run = true;
    Logger.addInfo("Selector: Start selector loop.");
    
    scope selector = new SelectSelector();
    
    selector.open(10, 5);
    
    // Register to read from socket
    while(run)
    {
        while(sc_to_unregister.length)
        {
            debug(Selector)
                Logger.addDebug("Selector: remove socket");
            
            Socket sc;
            synchronized(token)
            {
                sc = sc_to_unregister[0];
                sc_to_unregister = sc_to_unregister[1..$].dup;
            }
            selector.unregister(sc);
            sc.close();
        }
        
        while(sc_to_register.length)
        {
            debug(Selector)
                Logger.addDebug("Selector: add socket");
            
            Socket sc;
            void delegate() dl;
            synchronized(token)
            {
                sc = sc_to_register[0];
                dl = dl_to_register[0];
                sc_to_register = sc_to_register[1..$].dup;
                dl_to_register = dl_to_register[1..$].dup;
            }
            auto wrapper = new SWrapper(dl);
            selector.register(sc, Event.Read, wrapper);
        }
        
        int eventCount = selector.select(0.5);
    
        if(eventCount > 0)
        {
            foreach(SelectionKey key; selector.selectedSet)
            {
                if(key.isReadable)
                {
                    auto task = cast(SWrapper) key.attachment;
                    
                    add_task(&task.run);
                }
                if(key.isError || key.isHangup || key.isInvalidHandle)
                {
                    selector.unregister(key.conduit);
                    auto conduit = cast(Socket) key.conduit;
                    conduit.close();
                }
            }
        }
        else if(eventCount == -1)
        {
            Logger.addFatal("Selector: Selector was disturbed and is angry.");
            break;
        }
    }

    selector.close();
}
