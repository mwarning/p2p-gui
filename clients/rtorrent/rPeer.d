module clients.rtorrent.rPeer;

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

import clients.rtorrent.XmlOutput;
import clients.rtorrent.XmlInput;
import clients.rtorrent.rTorrent;
import clients.rtorrent.rDownload;


final class rPeer : NullNode, Files
{
    private static const char[][] base =
    [
        "p.get_address=", "p.get_port=", "p.is_incoming=",
        "p.is_encrypted=", "p.get_client_version="
        //"p_is_encrypted="
        //"p.is_incoming" //who started the connection
        //"p.get_id" 20char peer id, "p.get_id_html" with escaped html special chars
        //p.get_peer_rate //how fast the peers appears to download, judged from the rate of HAVE messages it sends
    ];
    
    private static const char[][] update =
    [
        "p.get_down_rate=", "p.get_up_rate=", "p.get_peer_rate=",
        "p.get_completed_percent=", "p.get_down_total=", "p.get_up_total="
    ];
    
    static VariableRequest full_request;
    static VariableRequest update_request;
    
    static void construct()
    {
        auto tmp1 = new XmlOutput("p.multicall");
        tmp1.addArg(rTorrent.dummy_hash);
        tmp1.addArgs(["0"] ~ base ~ update);
        full_request.ctor( tmp1.toString() );
        
        auto tmp2 = new XmlOutput("p.multicall");
        tmp2.addArg(rTorrent.dummy_hash);
        tmp2.addArgs(["0"] ~ update);
        update_request.ctor( tmp2.toString() );
    }
    
    this(uint id, XmlInput res, rDownload rdownload)
    {
        this.id = id;
        this.rdownload = rdownload;
        parseFull(res);
    }

    void parseFull(XmlInput res)
    {
        address = res.getString();
        ip = Utils.toIpNum(address);
        port = res.getUInt();
        is_incoming = res.getBoolean();
          is_encrypted = res.getBoolean();
        char[] client_version = res.getString();
        
        if(software_str.length == 0) //not yet set
        {
            auto pos = rfind(client_version, ' ');
            if(pos != client_version.length)
            {
                software_str = client_version[0..pos];
                if(software_str == "DelugeTorrent") //common name
                {
                    software_str = "Deluge";
                }
                else if(software_str == "XeiLun") //typo in rTorrent
                {
                    software_str = "XunLei";
                }
                else if(software_str == "Enhanced CTorrent") //shorter name
                {
                    software_str = "eCTorrent";
                }
                
                version_str = client_version[pos+1..$];
            }
            else
            {
                software_str = client_version;
            }
        }
        
        
        parseUpdate(res);
    }
    
    void parseUpdate(XmlInput res)
    {
        down_rate = res.getUInt();
        up_rate = res.getUInt();
        peer_rate = res.getUInt();
        completed_percent = res.getUInt();
        down_total = res.getULong();
        up_total = res.getULong();
    }

    uint getId() { return id; }
    char[] getHost() { return address; }
    ushort getPort() { return port; }
    char[] getLocation() { return GeoIP.getCountryCode(ip); }
    char[] getName() { return address; }
    char[] getSoftware() { return software_str; }
    char[] getVersion() { return version_str; }
    
    Node_.State getState() { return Node_.State.CONNECTED; }
    uint getDownloadRate() { return down_rate; }
    uint getUploadRate() { return up_rate; }
    ulong getDownloaded() { return down_total; }
    ulong getUploaded() { return up_total; }
    
    Nodes getNodes() { return this; }
    Files getFiles() { return this; }
    
    Node[] getNodeArray(Node_.Type type, Node_.State state, uint age)
    {
        if(type == Node_.Type.NETWORK)
        {
            return rdownload.getNodeArray(type, state, age);
        }
        return null;
    }
    
    uint getFileCount(File_.Type type, File_.State state)
    {
        return 0;
    }
    
    File getFile(File_.Type type, uint id)
    {
        if(type == File_.Type.DOWNLOAD)
        {
            return rdownload;
        }
        return null;
    }
    
    File[] getFileArray(File_.Type type, File_.State state, uint age)
    {
        if(type == File_.Type.DOWNLOAD)
        {
            return [rdownload];
        }
        return null;
    }

    void previewFile(File_.Type type, uint id) {}

    void removeFiles(File_.Type type, uint[] ids) {}
    void copyFiles(File_.Type type, uint[] source, uint target) {}
    void moveFiles(File_.Type type, uint[] source, uint target) {}
    void renameFile(File_.Type type, uint id, char[] new_name) {}
    //for download resume and search result start
    void startFiles(File_.Type type, uint[] ids) {}
    void pauseFiles(File_.Type type, uint[] ids) {}
    void stopFiles(File_.Type type, uint[] ids) {}
    void prioritiseFiles(File_.Type type, uint[] ids, Priority priority) {}
    
    rDownload rdownload;
    uint id;
    uint ip;
    ushort port;
    char[] address;
    uint down_rate, up_rate;
    ulong down_total, up_total;
    bool is_incoming;
    uint completed_percent;
    bool is_encrypted;
    uint peer_rate;
    char[] software_str;
    char[] version_str;
}
