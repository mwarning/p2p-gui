module api.User_;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/

interface User_
{
    enum Type : ubyte
    {
        USER,
        GROUP,
        ADMIN,
        UNKNOWN
    };
    
    
    enum State : ubyte
    {
        ENABLED,
        DISABLED,
        ANYSTATE
    };
}
