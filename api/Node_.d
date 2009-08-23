module api.Node_;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/

//this file is needed because of http://d.puremagic.com/issues/show_bug.cgi?id=102

//add UNKNOWN / ANY
interface Node_
{
    enum State : ubyte
    {
        CONNECTED, //what about firewalled
        CONNECTING, //same as initiating??
        DISCONNECTED,
        //INITIATING, FIREWALLED
        BLOCKED,
        REMOVED,
        ANYSTATE
    };
    
    enum Type : ubyte
    {
        UNKNOWN,
        SERVER,
        CLIENT,
        NETWORK,
        CORE
        //ANYTYPE,
    };
}
