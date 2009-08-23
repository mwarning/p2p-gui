module api.Meta_;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/

interface Meta_
{
    enum State : ubyte
    {
        ANYSTATE
    };
    
    enum Type : ubyte
    {
        UNKNOWN,
        LOG,
        CHAT,
        CONSOLE,
        COMMENT,
        INFO,
        STATUS,
        WARNING,
        ERROR,
        FATAL,
        DEBUG
    };
}
