module clients.amule.model.APreference;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/

import api.Setting;
import api.Node;
import webcore.Logger;
static import Utils = utils.Utils;

import clients.amule.aMule;
import clients.amule.ECPacket;
import clients.amule.ECCodes;
import clients.amule.ECTag;


private static char[][ECTagNames] names;

static this()
{
    names = [
    /*
    ECTagNames.EC_TAG_PREFS_CATEGORIES
    ECTagNames.EC_TAG_CATEGORY
    ECTagNames.EC_TAG_CATEGORY_TITLE
    ECTagNames.EC_TAG_CATEGORY_PATH
    ECTagNames.EC_TAG_CATEGORY_COMMENT
    ECTagNames.EC_TAG_CATEGORY_COLOR
    ECTagNames.EC_TAG_CATEGORY_PRIO*/
    
    ECTagNames.EC_TAG_PREFS_GENERAL : cast(char[]) "General",
    ECTagNames.EC_TAG_USER_NICK : "User Nick",
    ECTagNames.EC_TAG_USER_HASH : "User Hash",
    ECTagNames.EC_TAG_USER_HOST : "User Host",
    
    ECTagNames.EC_TAG_PREFS_CONNECTIONS : "Connections",
    ECTagNames.EC_TAG_CONN_DL_CAP : "Download Cap",
    ECTagNames.EC_TAG_CONN_UL_CAP : "Upload Cap",
    ECTagNames.EC_TAG_CONN_MAX_DL : "Max Download",
    ECTagNames.EC_TAG_CONN_MAX_UL : "Max Upload",
    ECTagNames.EC_TAG_CONN_SLOT_ALLOCATION : "Slot Allocation",
    ECTagNames.EC_TAG_CONN_TCP_PORT : "TCP Port",
    ECTagNames.EC_TAG_CONN_UDP_PORT : "UDP Port",
    ECTagNames.EC_TAG_CONN_UDP_DISABLE : "UDP disable",
    ECTagNames.EC_TAG_CONN_MAX_FILE_SOURCES : "Max file Sources",
    ECTagNames.EC_TAG_CONN_MAX_CONN : "Max Connections",
    ECTagNames.EC_TAG_CONN_AUTOCONNECT : "Auto Connect",
    ECTagNames.EC_TAG_CONN_RECONNECT : "Reconnect",
    ECTagNames.EC_TAG_NETWORK_ED2K : "eDonkey2000",
    ECTagNames.EC_TAG_NETWORK_KADEMLIA : "Kademila",
    
    ECTagNames.EC_TAG_PREFS_MESSAGEFILTER : "Message Filter",
    ECTagNames.EC_TAG_MSGFILTER_ENABLED : "Enabled",
    ECTagNames.EC_TAG_MSGFILTER_ALL : "All",
    ECTagNames.EC_TAG_MSGFILTER_FRIENDS : "Friends",
    ECTagNames.EC_TAG_MSGFILTER_SECURE : "Secure",
    ECTagNames.EC_TAG_MSGFILTER_BY_KEYWORD : "By Keyword",
    ECTagNames.EC_TAG_MSGFILTER_KEYWORDS : "Keywords",
    
    ECTagNames.EC_TAG_PREFS_REMOTECTRL : "Remote Control",
    ECTagNames.EC_TAG_WEBSERVER_AUTORUN : "Webserver Autorun",
    ECTagNames.EC_TAG_WEBSERVER_PORT : "Webserver Port",
    ECTagNames.EC_TAG_WEBSERVER_GUEST : "Webserver Guest",
    ECTagNames.EC_TAG_WEBSERVER_USEGZIP : "Webserver Use GZIP",
    ECTagNames.EC_TAG_WEBSERVER_REFRESH : "Webserver Refresh",
    ECTagNames.EC_TAG_WEBSERVER_TEMPLATE : "Webserver Template",
    
    ECTagNames.EC_TAG_PREFS_ONLINESIG : "Online Signature",
    ECTagNames.EC_TAG_ONLINESIG_ENABLED  : "Enabled",
    
    ECTagNames.EC_TAG_PREFS_SERVERS : "Servers",
    ECTagNames.EC_TAG_SERVERS_REMOVE_DEAD : "Remove Dead",
    ECTagNames.EC_TAG_SERVERS_DEAD_SERVER_RETRIES : "Server Retries",
    ECTagNames.EC_TAG_SERVERS_AUTO_UPDATE : "Auto Update",
    ECTagNames.EC_TAG_SERVERS_URL_LIST : "URL List",
    ECTagNames.EC_TAG_SERVERS_ADD_FROM_SERVER : "Add From Server",
    ECTagNames.EC_TAG_SERVERS_ADD_FROM_CLIENT : "Add From Client",
    ECTagNames.EC_TAG_SERVERS_USE_SCORE_SYSTEM : "Use Score System",
    ECTagNames.EC_TAG_SERVERS_SMART_ID_CHECK : "Smart ID Check",
    ECTagNames.EC_TAG_SERVERS_SAFE_SERVER_CONNECT : "Safe Server Connect",
    ECTagNames.EC_TAG_SERVERS_AUTOCONN_STATIC_ONLY : "Auto Connect Static Only",
    ECTagNames.EC_TAG_SERVERS_MANUAL_HIGH_PRIO : "Manual High Server Priority",
    ECTagNames.EC_TAG_SERVERS_UPDATE_URL : "Update By URL",
    
    ECTagNames.EC_TAG_PREFS_FILES : "Files",
    ECTagNames.EC_TAG_FILES_ICH_ENABLED : "ICH Enabled",
    ECTagNames.EC_TAG_FILES_AICH_TRUST : "AICH Trust",
    ECTagNames.EC_TAG_FILES_NEW_PAUSED : "New Paused",
    ECTagNames.EC_TAG_FILES_NEW_AUTO_DL_PRIO : "Auto Download Priority",
    ECTagNames.EC_TAG_FILES_PREVIEW_PRIO : "Preview Priority",
    ECTagNames.EC_TAG_FILES_NEW_AUTO_UL_PRIO : "New Auto Upload Priority",
    ECTagNames.EC_TAG_FILES_UL_FULL_CHUNKS : "Upload Full Chunk",
    ECTagNames.EC_TAG_FILES_START_NEXT_PAUSED : "Start Next Paused",
    ECTagNames.EC_TAG_FILES_RESUME_SAME_CAT : "Resume same Category",
    ECTagNames.EC_TAG_FILES_SAVE_SOURCES  : "Save Sources",
    ECTagNames.EC_TAG_FILES_EXTRACT_METADATA : "Extract Metadata",
    //ECTagNames.EC_TAG_FILES_ALLOC_FULL_CHUNKS : "Allocate Full Chunks",
    ECTagNames.EC_TAG_FILES_ALLOC_FULL_SIZE : "Allocate Full Size",
    ECTagNames.EC_TAG_FILES_CHECK_FREE_SPACE : "Check Free Space",
    ECTagNames.EC_TAG_FILES_MIN_FREE_SPACE : "Min Free Space",
    
    ECTagNames.EC_TAG_PREFS_SRCDROP : "Source Drop",
    ECTagNames.EC_TAG_SRCDROP_NONEEDED : "Drop Noneeded",
    ECTagNames.EC_TAG_SRCDROP_DROP_FQS : "Drop FQS",
    ECTagNames.EC_TAG_SRCDROP_DROP_HQRS : "Drop HQRS",
    ECTagNames.EC_TAG_SRCDROP_HQRS_VALUE : "HQRS Value",
    ECTagNames.EC_TAG_SRCDROP_AUTODROP_TIMER : "AutoDrop Timer",
    
    ECTagNames.EC_TAG_PREFS_DIRECTORIES : "Directories",
    
    ECTagNames.EC_TAG_PREFS_STATISTICS : "Statistics",
    ECTagNames.EC_TAG_STATSGRAPH_WIDTH : "Graph Wide",
    ECTagNames.EC_TAG_STATSGRAPH_SCALE : "Graph Scale",
    ECTagNames.EC_TAG_STATSGRAPH_LAST : "Graph Last",
    ECTagNames.EC_TAG_STATSGRAPH_DATA : "Graph Data",
    ECTagNames.EC_TAG_STATTREE_CAPPING : "Capping",
    ECTagNames.EC_TAG_STATTREE_NODE : "Tree Node",
    ECTagNames.EC_TAG_STAT_NODE_VALUE : "Node Value",
    ECTagNames.EC_TAG_STAT_VALUE_TYPE : "Value Type",
    ECTagNames.EC_TAG_STATTREE_NODEID : "Stattree Node Id",
    
    ECTagNames.EC_TAG_PREFS_SECURITY : "Security",
    ECTagNames.EC_TAG_SECURITY_CAN_SEE_SHARES : "Can See Shares",
    ECTagNames.EC_TAG_IPFILTER_CLIENTS : "Clients",
    ECTagNames.EC_TAG_IPFILTER_SERVERS : "Servers",
    ECTagNames.EC_TAG_IPFILTER_AUTO_UPDATE : "Auto Update",
    ECTagNames.EC_TAG_IPFILTER_UPDATE_URL : "Update URL",
    ECTagNames.EC_TAG_IPFILTER_LEVEL : "Level",
    ECTagNames.EC_TAG_IPFILTER_FILTER_LAN : "Filter LAN",
    ECTagNames.EC_TAG_SECURITY_USE_SECIDENT : "Use Secure Ident",
    ECTagNames.EC_TAG_SECURITY_OBFUSCATION_SUPPORTED : "Obfuscation Supported",
    ECTagNames.EC_TAG_SECURITY_OBFUSCATION_REQUESTED : "Obfuscation Requested",
    ECTagNames.EC_TAG_SECURITY_OBFUSCATION_REQUIRED : "Obfuscation Required",
    
    ECTagNames.EC_TAG_PREFS_CORETWEAKS : "Core Tweaks",
    ECTagNames.EC_TAG_CORETW_MAX_CONN_PER_FIVE : "Max Connection per Five",
    ECTagNames.EC_TAG_CORETW_VERBOSE : "Verbose",
    ECTagNames.EC_TAG_CORETW_FILEBUFFER : "File Buffer",
    ECTagNames.EC_TAG_CORETW_UL_QUEUE : "Upload Queue",
    ECTagNames.EC_TAG_CORETW_SRV_KEEPALIVE_TIMEOUT : "Server KeepAlive TimeOut",
    
    ECTagNames.EC_TAG_PREFS_KADEMLIA : "Kademlia",
    ECTagNames.EC_TAG_KADEMLIA_UPDATE_URL : "Update By URL"
    ];
}

private char[] getTagName(ECTagNames tag_code)
{
    char[]* name_ptr = (tag_code in names);
    char[] name = name_ptr ? *name_ptr : "???";
    
    if(name_ptr is null) 
    {
        Logger.addWarning("APreference: Name for preference code not found {}.", tag_code);
    }
    
    return name;
}

class APreference : Setting
{
public:
    
    ECTagNames category_code;
    ECTagNames code;
    ECTagTypes type;

    char[] name;
    char[] value;
    
    this(ECTagNames category_code, ECTag tag)
    {
        this.category_code = category_code;
        
        this.code = tag.getCode();
        this.type = tag.getType();
        
        this.name = getTagName(this.code);
//ECTagNames.EC_TAG_CONN_AUTOCONNECT
        switch(this.type)
        {
        case ECTagTypes.EC_TAGTYPE_UINT8:
            this.value = Utils.toString(tag.get8);
            break;
        case ECTagTypes.EC_TAGTYPE_UINT16:
            this.value = Utils.toString(tag.get16);
            break;
        case ECTagTypes.EC_TAGTYPE_UINT32:
            this.value = Utils.toString(tag.get32);
            break;
        case ECTagTypes.EC_TAGTYPE_UINT64:
            this.value = Utils.toString(tag.get64);
            break;
        case ECTagTypes.EC_TAGTYPE_STRING:
            this.value = tag.getString();
            break;
        //TODO: implement
        case ECTagTypes.EC_TAGTYPE_DOUBLE:
            break;
        case ECTagTypes.EC_TAGTYPE_IPV4:
            break;
        case ECTagTypes.EC_TAGTYPE_HASH16:
            this.value = tag.getHash();
            break;
        case ECTagTypes.EC_TAGTYPE_CUSTOM:
            /*
            Logger.addDebug("got custom {}", Utils.toHexString(code));
            Logger.addDebug("subtags {}", tag.getTags.length);
            ubyte[] dta = tag.getRawValue();
            Debug.hexDump(dta);
            */
            break;
        case ECTagTypes.EC_TAGTYPE_UNKNOWN:
            //never received before
        default:
            Logger.addError("APreference: Unknown setting type {}", this.type);
        }
    }
    
    //to fit in local preferences
    this(uint id, char[] name, char[] value)
    {
        //check lower bound for preference ids used by aMule
        //to prevent id collisions
        assert(id < ECTagNames.EC_TAG_SELECT_PREFS);
        
        this.code = cast(ECTagNames) id;
        this.name = name;
        this.value = value;
        this.type = ECTagTypes.EC_TAGTYPE_STRING;
    }
    
    private this(ECTagNames code, char[] name)
    {
        this.code = code;
        this.name = name;
    }
    
    uint getId() { return code; }
    
    Setting.Type getType() { return Setting.Type.STRING; }
    
    char[] getName() { return name; }
    char[] getValue() { return value; }
    char[] getDescription() { return ""; }
    
    Settings getSettings() { return null; }
    
    Setting getSetting(uint id) { return null; }
    void setSetting(uint id, char[] value) { }
    uint getSettingCount() { return 0; }
    Setting[] getSettingArray() { return null; }
}

final class APreferences : APreference, Settings
{
    APreference[] prefs;
    
    this(ECTagNames tag_code)
    {
        char[] name = getTagName(tag_code);
        super(tag_code, name);
    }
    
    void add(APreference pref) { prefs ~= pref; }
    
    Setting.Type getType() { return Setting.Type.MULTIPLE; }
    
    Settings getSettings() { return this; }
    
    Setting getSetting(uint id) { return null; }
    void setSetting(uint id, char[] value) {}
    uint getSettingCount() { return prefs.length; }
    Setting[] getSettingArray()
    {
        return Utils.convert!(Setting)(prefs);
    }
}
