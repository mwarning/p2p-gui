module clients.amule.model.AServerInfo;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import tango.io.Stdout;

import api.Node;
import webcore.Logger;
static import Utils = utils.Utils;
static import GeoIP = utils.GeoIP;

import clients.amule.ECPacket;
import clients.amule.ECCodes;
import clients.amule.ECTag;

final class AServerInfo : NullNode
{
public:
    
    enum SRV_PR : ubyte
    {
        LOW = 2,
        NORMAL = 0,
        HIGH = 1,
        MAX = 2,
        MID = 1,
        MIN = 0
    }
    
    this(uint id)
    {
        this.id = id;
    }
    
    this(uint id, ECTag tag)
    {
        update(tag);
        this.id = id;
    }
    
    void setState(Node_.State state)
    {
        this.state = state;
    }
    
    void update(ECTag t)
    {
        ip = t.getIp();
        port = t.getPort();
        
        ECTag[] tags = t.getTags();
        
        foreach(ECTag tag; tags)
        {
            ECTagNames tag_code = tag.getCode();
        
            switch(tag_code)
            {
            case ECTagNames.EC_TAG_SERVER_NAME:
                name = tag.getString();
                break;
            case ECTagNames.EC_TAG_SERVER_DESC:
                description = tag.getString();
                break;
            case ECTagNames.EC_TAG_SERVER_PING:
                ping = tag.get32();
                break;
            case ECTagNames.EC_TAG_SERVER_USERS:
                user_count = tag.get32();
                break;
            case ECTagNames.EC_TAG_SERVER_USERS_MAX:
                user_max = tag.get32();
                break;
            case ECTagNames.EC_TAG_SERVER_FILES:
                file_count = tag.get32();
                break;
            case ECTagNames.EC_TAG_SERVER_PRIO:
                ubyte tmp = tag.get8();
                switch(tmp)
                {
                    case SRV_PR.LOW: priority = Priority.LOW; break;
                    case SRV_PR.NORMAL: priority = Priority.NORMAL; break;
                    case SRV_PR.HIGH: priority = Priority.HIGH; break;
                    default:
                        Logger.addDebug("AServerInfo: Unkown priority {}", tmp);
                }
                break;
            case ECTagNames.EC_TAG_SERVER_FAILED:
                failed = tag.getBool();
                break;
            case ECTagNames.EC_TAG_SERVER_STATIC:
                stat = tag.getBool();
                break;
            case ECTagNames.EC_TAG_SERVER_VERSION:
                version_str = tag.getString();
                break;
            default:
                break;
            }
        }
    }
    
    uint getId() { return id; }
    char[] getName() { return name; }
    char[] getVersion() { return version_str; }
    char[] getDescription() { return description; }
    Node_.State getState() { return state; }
    Node_.Type getType() { return Node_.Type.SERVER; }
    uint getUserCount() { return user_count; }
    uint getFileCount(File_.Type type, File_.State state) { return file_count; }
    char[] getHost() { return Utils.toIpString(ip); }
    ushort getPort() { return port; }
    char[] getLocation() { return GeoIP.getCountryCode(ip); }
    ushort getPing() { return ping; }
    Priority getPriority() { return priority; }
    
    uint getIp() { return ip; }
    
    private:

    Node_.State state = Node_.State.DISCONNECTED;
    char[] name, description, version_str;
    ushort ping;
    uint user_count, file_count, user_max;
    uint ip;
    ushort port;
    Priority priority;
    uint id;
    bool preferred;
    bool failed;
    bool stat;
}

