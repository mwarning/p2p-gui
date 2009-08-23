module clients.amule.model.AClientInfo;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/

import api.Node;
import webcore.Logger;
static import Utils = utils.Utils;
static import GeoIP = utils.GeoIP;

import clients.amule.ECPacket;
import clients.amule.ECCodes;
import clients.amule.ECTag;
import clients.amule.aMule;

final class AClientInfo : NullNode//, Files
{
    //from updownclient.h
    enum ESourceFrom
    {
        SF_NONE,
        SF_LOCAL_SERVER,
        SF_REMOTE_SERVER,
        SF_KADEMLIA,
        SF_SOURCE_EXCHANGE,
        SF_PASSIVE,
        SF_LINK,
        SF_SOURCE_SEEDS
    };
    
    this(uint id, ECTag tag, aMule amule)
    {
        this.id = id;
        this.amule = amule;
        update(tag);
    }
    
    void update(ECTag t)
    {
        ECTag[] tags = t.getTags();
        
        foreach(ECTag tag; tags)
        {
            ECTagNames tag_code = tag.getCode();
            switch(tag_code)
            {
            case ECTagNames.EC_TAG_CLIENT_NAME:
                name = tag.getString();
                break;
            case ECTagNames.EC_TAG_CLIENT_SOFTWARE:
                software = tag.get8();
                break;
            case ECTagNames.EC_TAG_CLIENT_SCORE:
                //score = get.get16();
                break;
            case ECTagNames.EC_TAG_CLIENT_HASH:
                //tag.getRawValue();
                break;
            case ECTagNames.EC_TAG_CLIENT_FRIEND:
            case ECTagNames.EC_TAG_CLIENT_WAIT_TIME:
            case ECTagNames.EC_TAG_CLIENT_XFER_TIME:
            case ECTagNames.EC_TAG_CLIENT_QUEUE_TIME:
            case ECTagNames.EC_TAG_CLIENT_LAST_TIME:
                break;
            case ECTagNames.EC_TAG_CLIENT_UPLOAD_SESSION:
                uploaded = tag.get32();
                break;
            case ECTagNames.EC_TAG_CLIENT_UPLOAD_TOTAL:
                uploaded = tag.get32();
                break;
            case ECTagNames.EC_TAG_CLIENT_DOWNLOAD_TOTAL:
                downloaded = tag.get32();
                break;
            case ECTagNames.EC_TAG_CLIENT_STATE:
                /*valuemap.CreateTag(EC_TAG_CLIENT_STATE,
        uint64((uint16)client->GetDownloadState() | (((uint16)client->GetUploadState()) << 8) ), this);*/
                //ubyte status = tag.get16();
                break;
            case ECTagNames.EC_TAG_CLIENT_UP_SPEED:
                up_speed = tag.get32();
                break;
            case ECTagNames.EC_TAG_CLIENT_DOWN_SPEED:
                down_speed = tag.get32();
                break;
            case ECTagNames.EC_TAG_CLIENT_USER_IP:
                ip = Utils.swapBytes(tag.get32);
                break;
            case ECTagNames.EC_TAG_CLIENT_USER_PORT:
                port = tag.get16();
                break;
            /*
            case ECTagNames.EC_TAG_CLIENT_FROM:
                auto from = cast(ESourceFrom) tag.get8();
                break;
            case ECTagNames.EC_TAG_CLIENT_SERVER_IP:
                //tag.get32();
                break;
            case ECTagNames.EC_TAG_CLIENT_SERVER_PORT:
                //port = tag.get16();
                break;
            case ECTagNames.EC_TAG_CLIENT_SERVER_NAME:
                //tag.getString();
                break;
            case ECTagNames.EC_TAG_CLIENT_WAITING_POSITION:
                //tag.get16();
                break;
            */
            case ECTagNames.EC_TAG_CLIENT_SOFT_VER_STR:
                version_str = tag.getString();
                break;
            
            default:
            }
        }
    }
    
    char[] getSoftware()
    {
        switch(software)
        {
            case EClientSoftware.SO_EMULE: return "eMule";
            case EClientSoftware.SO_CDONKEY: return "cDonkey";
            case EClientSoftware.SO_LXMULE: return "LXMule";
            case EClientSoftware.SO_AMULE: return "aMule";
            case EClientSoftware.SO_SHAREAZA: return "Shareaza";
            case EClientSoftware.SO_EMULEPLUS: return "eMule+";
            case EClientSoftware.SO_HYDRANODE: return "Hydranode";
            case EClientSoftware.SO_NEW2_MLDONKEY: return "MLdonkey";
            case EClientSoftware.SO_LPHANT: return "LPhant";
            case EClientSoftware.SO_NEW2_SHAREAZA: return "Shareaza";
            case EClientSoftware.SO_EDONKEYHYBRID: return "eDonkey Hybrid";
            case EClientSoftware.SO_EDONKEY: return "eDonkey";
            case EClientSoftware.SO_MLDONKEY: return "MLDonkey";
            case EClientSoftware.SO_OLDEMULE: return "old eMule";
            case EClientSoftware.SO_UNKNOWN: return null;
            case EClientSoftware.SO_NEW_SHAREAZA: return "new Shareaza";
            case EClientSoftware.SO_NEW_MLDONKEY: return "new MLdonkey";
            case EClientSoftware.SO_COMPAT_UNK: return "Unknown"; //emule compatible
            default:
                Logger.addError("AClientInfo: Unknown software id {}.", software);
                return null;
        }
    }
    
    uint getId() { return id; }
    
    uint getLastChanged() { return 0; }
    
    char[] getHost() { return Utils.toIpString(ip); }
    ushort getPort() { return port; }
    char[] getLocation() { return GeoIP.getCountryCode(ip); }
    
    char[] getName() { return name; }
    char[] getVersion(){ return version_str; }
    char[] getProtocol() { return null; }
    
    Priority getPriority() { return Priority.NONE; }
    ushort getPing() { return 0; }
    
    uint getUploadRate() { return up_speed; }
    uint getDownloadRate() { return down_speed; }
    
    ulong getUploaded() { return uploaded; }
    ulong getDownloaded() { return downloaded; }
    
    uint getNodeCount(Node_.Type type, Node_.State state)
    {
        auto network = amule.edonkey;
        if(type == Node_.Type.NETWORK && network.getState == state) 
        {
            return 1; //edonkey
        }
        return 0;
    }
    
    Node[] getNodeArray(Node_.Type type, Node_.State state, uint age)
    {
        auto net = amule.edonkey;
        if(net && type == Node_.Type.NETWORK)
        {
            return Utils.filter!(Node)( [net] , state, age);
        }
        return null;
    }
    
    Node getNode(Node_.Type type, uint id)
    {
        auto net = amule.edonkey;
        if(type == Node_.Type.NETWORK && net && id == net.id)
        {
            return net;
        }
        return null;
    }
    
    /*
    Files getFiles() { return this; }
    
    uint getFileCount(File_.Type type, File_.State state)
    {
        return 0;
    }
    
    File getFile(File_.Type type, uint id)
    {
        return null;
    }
    
    File[] getFileArray(File_.Type type, File_.State state, uint age)
    {
        return null;
    }*/
    
    private:

    uint id;
    uint ip;
    ushort port;
    ubyte[] hash;
    char[] name;
    ubyte software;
    char[] version_str;
    uint downloaded, uploaded;
    uint down_speed, up_speed;
    aMule amule;
}
