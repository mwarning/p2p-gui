module webcore.Logger;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/


import tango.io.Console;
import tango.text.convert.Layout;
import tango.core.Thread;

import api.User;
import api.Meta;
import api.Client;

import webcore.UserManager;
import Main = webcore.Main;


struct Logger
{
    static void addInfo(char[] fmt, ...) { add(null, _arguments, _argptr, fmt, Meta_.Type.INFO); }
    static void addStatus(char[] fmt, ...) { add(null, _arguments, _argptr, fmt, Meta_.Type.STATUS); }
    static void addWarning(char[] fmt, ...) { add(null, _arguments, _argptr, fmt, Meta_.Type.WARNING); }
    static void addError(char[] fmt, ...) { add(null, _arguments, _argptr, fmt, Meta_.Type.ERROR); }
    static void addFatal(char[] fmt, ...) { add(null, _arguments, _argptr, fmt, Meta_.Type.FATAL); }
    static void addDebug(char[] fmt, ...) { add(null, _arguments, _argptr, fmt, Meta_.Type.DEBUG); }
    
    static void addInfo(Object source, char[] fmt, ...) { add(source, _arguments, _argptr, fmt, Meta_.Type.INFO); }
    static void addStatus(Object source, char[] fmt, ...) { add(source, _arguments, _argptr, fmt, Meta_.Type.STATUS); }
    static void addWarning(Object source, char[] fmt, ...) { add(source, _arguments, _argptr, fmt, Meta_.Type.WARNING); }
    static void addError(Object source, char[] fmt, ...) { add(source, _arguments, _argptr, fmt, Meta_.Type.ERROR); }
    static void addFatal(Object source, char[] fmt, ...) { add(source, _arguments, _argptr, fmt, Meta_.Type.FATAL); }
    
    /*
    * Forward message to respomsible source.
    */
    private static void add(Object source, TypeInfo[] arguments, ArgList args, char[] formatStr, Meta_.Type type)
    {
        static Layout!(char) layout;
        
        if(layout is null)
            layout = new Layout!(char);

        synchronized(layout)
        {
            char[] msg = layout.convert(arguments, args, formatStr);
            
            if(type == Meta_.Type.DEBUG)
            {
                Cout("(D) ")(msg).newline;
                return;
            }
            
            if(type == Meta_.Type.FATAL)
                Cout("(F) ")(msg).newline;
            
            if(type == Meta_.Type.ERROR)
                Cout("(E) ")(msg).newline;
        
            if(source is null)
                source = Main.getThreadOwner(); //may be null as well
            
            if(auto user = cast(Metas) cast(User) source)
            {
                user.addMeta(type, msg, 0);
                return;
            }
            
            if(auto client = cast(Client) source)
            {
                auto id = client.getId();
                auto users = UserManager.getByClientId(id);
                
                foreach(user; users)
                {
                    if(auto metas = cast(Metas) user)
                    {
                        metas.addMeta(type, msg, 0);
                    }
                }
                return;
            }
            
            if(source)
                Cout("(W) Logger: Unexpected thread source: ")(source.toString).newline;
            
            switch(type) //print to console;
            {
                case Meta_.Type.FATAL:
                case Meta_.Type.ERROR:
                    //already printed to console
                    break;
                case Meta_.Type.WARNING:
                    Cout("(W) ")(msg).newline;
                    break;
                case Meta_.Type.STATUS:
                    Cout("(S) ")(msg).newline;
                    break;
                case Meta_.Type.INFO:
                    Cout("(I) ")(msg).newline;
                    break;
                default:
                    Cout("(?) ")(msg).newline;
            }
        }
    }
}
