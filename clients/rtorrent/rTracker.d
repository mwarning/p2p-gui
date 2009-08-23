module clients.rtorrent.rTracker;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import tango.core.Exception;
import tango.core.Array;
import tango.io.Stdout;
static import Convert = tango.util.Convert;
import tango.time.Clock;
import tango.text.Ascii;

import api.File;
import api.Node;
import api.User;
import api.Meta;

static import Utils = utils.Utils;
static import GeoIP = utils.GeoIP;

import clients.rtorrent.XmlInput;
import clients.rtorrent.XmlOutput;
import clients.rtorrent.rTorrent;


final class rTracker : NullNode
{
    private static const char[][] full =
    [
        "0", "t.get_url=", "t.get_normal_interval=","t.get_scrape_time_last=",
        "t.get_scrape_complete=","t.get_scrape_incomplete=", "t.is_enabled=",
        "t.is_open=" //is the connection closed
    ];
    
    private static const char[][] update =
    [
        //"t.get_scrape_complete=","t.get_scrape_incomplete="
    ];
    
    static VariableRequest full_request;
    static VariableRequest update_request;
    
    static void construct()
    {
        auto tmp1 = new XmlOutput("t.multicall");
        tmp1.addArg(rTorrent.dummy_hash);
        tmp1.addArgs(full ~ update);
        full_request.ctor( tmp1.toString() );
        
        auto tmp2 = new XmlOutput("t.multicall");
        tmp2.addArg(rTorrent.dummy_hash);
        tmp2.addArgs(update);
        update_request.ctor( tmp2.toString() );
    }

    this(uint id, XmlInput res)
    {
        this.id = id;
        parseFull(res);
    }

    void parseFull(XmlInput res)
    {
        url = res.getString();
        normal_interval = res.getUInt();
        scrape_time_last = res.getUInt();
        scrape_completed = res.getUInt(); //number of seeders
        scrape_incomplete = res.getUInt(); //number of peers
        enabled = res.getBoolean();
        open = res.getBoolean();
    }

    uint getId() { return id; }
    char[] getName() { return url; }
    Node_.State getState()
    { 
        return open ? Node_.State.CONNECTED : Node_.State.DISCONNECTED;
    }
    
    uint id;
    char[] url;
    uint normal_interval;
    uint scrape_time_last;
    uint scrape_completed;
    uint scrape_incomplete;
    bool enabled;
    bool open;
}
