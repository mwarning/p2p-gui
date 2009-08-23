module clients.transmission.TPeer;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/

import tango.text.Util : jhash;
import tango.io.Stdout;
import tango.core.Array;

import api.Node;
import utils.json.JsonBuilder;
static import GeoIP = utils.GeoIP;
static import Utils = utils.Utils;

import clients.transmission.Transmission;

class TPeer : NullNode
{
    alias JsonBuilder!().JsonValue JsonValue;
    alias JsonBuilder!().JsonString JsonString;
    alias JsonBuilder!().JsonNumber JsonNumber;
    alias JsonBuilder!().JsonNull JsonNull;
    alias JsonBuilder!().JsonBool JsonBool;
    alias JsonBuilder!().JsonArray JsonArray;
    alias JsonBuilder!().JsonObject JsonObject;
    
    uint id;
    char[] name;
    char[] software;
    char[] version_str;
    char[] address_str;
    ulong address_ip;
    uint rate_to_client;
    uint rate_to_peer;
    ushort port;
    //bool client_is_hoked;
    //bool client_is_interested;
    //bool is_downloading_from;
    //bool is_encrypted;
    //bool is_incoming;
    //bool is_uploading_to;
    //bool peer_is_choked;
    //bool peer_is_interested;
    double progress;
    Transmission tc;
    //ulong size; //size of the download when finished
    
    this(JsonObject obj, Transmission tc)
    {
        this.tc = tc;
        update(obj);
    }
    
    uint getId()
    {
        return id;
    }
    
    char[] getName()
    {
        return name.length ? name : address_str;
    }
    
    char[] getSoftware()
    {
        return software;
    }
    
    char[] getVersion()
    {
        return version_str;
    }
    
    char[] getHost()
    {
        return address_str;
    }
    
    ushort getPort()
    {
        return port;
    }
    
    char[] getLocation()
    {
        return GeoIP.getCountryCode(address_ip);
    }
    
    uint getUploadRate()
    {
        return rate_to_peer;
    }
    
    uint getDownloadRate()
    {
        return rate_to_client;
    }
    
    Node_.State getState()
    {
        return Node_.State.CONNECTED;
    }
    
    Node_.Type getType()
    {
        return Node_.Type.CLIENT;
    }
    
    uint getNodeCount(Node_.Type type, Node_.State state)
    {
        if(type == Node_.Type.NETWORK)
        {
            return 1;
        }
    }
    
    Node getNode(Node_.Type type, uint id)
    {
        if(type == Node_.Type.NETWORK && id == Transmission.bittorrent_net_id)
        {
            return tc.network;
        }
        return null;
    }
    
    Node[] getNodeArray(Node_.Type type, Node_.State state, uint age)
    {
        if(type == Node_.Type.NETWORK)
        {
            return Utils.filter!(Node)([tc.network], state, age);
        }
        return null;
    }
    
    void update(JsonObject obj)
    {
        foreach(char[] key, JsonValue value; obj)
        {
            switch(key)
            {
            case "address":
                if(address_str.length == 0)
                {
                    address_str = value.toString();
                    address_ip = Utils.toIpNum(address_str);
                }
                break;
            case "clientName":
                if(name.length == 0)
                {
                    name = value.toString();
                    auto pos = rfind(name, ' ');
                    if(pos < name.length)
                    {
                        version_str = name[pos+1..$];
                        software = name[0..pos];
                    }
                    else
                    {
                        software = name;
                    }
                    
                    if(id == 0) id = jhash(name);
                }
                break;
            case "clientIsChoked":
                //client_is_hoked = value.toBool();
                break;
            case "clientIsInterested":
                //client_is_interested = value.toBool();
                break;
            case "isDownloadingFrom":
                //is_downloading_from = value.toBool();
                break;
            case "isEncrypted":
                //is_encrypted = value.toBool();
                break;
            case "isIncoming":
                //is_incoming = value.toBool();
                break;
            case "isUploadingTo":
                //is_uploading_to = value.toBool();
                break;
            case "peerIsChoked":
                //peer_is_choked = value.toBool();
                break;
            case "peerIsInterested":
                //peer_is_interested = value.toBool();
                break;
            case "port":
                port = value.toInteger();
                break;
            case "progress": // <= 1
                progress = value.toFloat();
                break;
            case "rateToClient": // B/s
                rate_to_client = value.toInteger();
                break;
            case "rateToPeer": // B/s
                rate_to_peer = value.toInteger();
                break;
            case "flagStr":
                char[] str = value.toString();
                foreach(c; str) switch(c)
                {
                    case 'O': //Optimistic unchoke
                    case 'D': //Downloading from this peer
                    case 'd': //We would download from this peer if they would let us
                    case 'U': //Uploading to peer
                    case 'u': //We would upload to this peer if they asked
                    case 'K': //Peer has unchoked us, but we're not interested
                    case '?': //We unchoked this peer, but they're not interested
                    case 'E': //Encrypted connection
                    case 'X': //Peer was discovered through Peer Exchange (PEX)
                    case 'I': //Peer is an incoming connection
                    default:
                }
                break;
            default:
            }
        }
    }
}
