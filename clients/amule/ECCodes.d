﻿module clients.amule.ECCodes;

// 
//  This file is part of the aMule Project.
// 
//  Copyright (c) 2004-2008 aMule Team ( admin@amule.org / http://www.amule.org )
// 
//  Any parts of this program derived from the xMule, lMule or eMule project,
//  or contributed by third-party developers are copyrighted by their
//  respective authors.
// 
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
// 
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//  
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301, USA

// Purpose:
// EC codes and type definition.

typedef ubyte ec_opcode_t;
typedef ushort ec_tagname_t;
typedef ubyte ec_tagtype_t;
typedef uint ec_taglen_t;

const final ushort EC_CURRENT_PROTOCOL_VERSION = 0x0203;


enum ECFlags : uint
{
    EC_FLAG_ZLIB     = 0x00000001,
    EC_FLAG_UTF8_NUMBERS = 0x00000002,
    EC_FLAG_HAS_ID     = 0x00000004,
    EC_FLAG_ACCEPTS     = 0x00000010,
    EC_FLAG_NOTIFY     = 0x00008000,
    EC_FLAG_UNKNOWN_MASK = 0xff7f7f08
};

enum ECOpCodes : ubyte
{
    EC_OP_NOOP                          = 0x01,
    EC_OP_AUTH_REQ                      = 0x02,
    EC_OP_AUTH_FAIL                     = 0x03,
    EC_OP_AUTH_OK                       = 0x04,
    EC_OP_FAILED                        = 0x05,
    EC_OP_STRINGS                       = 0x06,
    EC_OP_MISC_DATA                     = 0x07,
    EC_OP_SHUTDOWN                      = 0x08,
    EC_OP_ADD_LINK                      = 0x09,
    EC_OP_STAT_REQ                      = 0x0A,
    EC_OP_GET_CONNSTATE                 = 0x0B,
    EC_OP_STATS                         = 0x0C,
    EC_OP_GET_DLOAD_QUEUE               = 0x0D,
    EC_OP_GET_ULOAD_QUEUE               = 0x0E,
    EC_OP_GET_WAIT_QUEUE                = 0x0F,
    EC_OP_GET_SHARED_FILES              = 0x10,
    EC_OP_SHARED_SET_PRIO               = 0x11,
    EC_OP_PARTFILE_REMOVE_NO_NEEDED     = 0x12,
    EC_OP_PARTFILE_REMOVE_FULL_QUEUE    = 0x13,
    EC_OP_PARTFILE_REMOVE_HIGH_QUEUE    = 0x14,
    EC_OP_PARTFILE_CLEANUP_SOURCES      = 0x15,
    EC_OP_PARTFILE_SWAP_A4AF_THIS       = 0x16,
    EC_OP_PARTFILE_SWAP_A4AF_THIS_AUTO  = 0x17,
    EC_OP_PARTFILE_SWAP_A4AF_OTHERS     = 0x18,
    EC_OP_PARTFILE_PAUSE                = 0x19,
    EC_OP_PARTFILE_RESUME               = 0x1A,
    EC_OP_PARTFILE_STOP                 = 0x1B,
    EC_OP_PARTFILE_PRIO_SET             = 0x1C,
    EC_OP_PARTFILE_DELETE               = 0x1D,
    EC_OP_PARTFILE_SET_CAT              = 0x1E,
    EC_OP_DLOAD_QUEUE                   = 0x1F,
    EC_OP_ULOAD_QUEUE                   = 0x20,
    EC_OP_WAIT_QUEUE                    = 0x21,
    EC_OP_SHARED_FILES                  = 0x22,
    EC_OP_SHAREDFILES_RELOAD            = 0x23,
    EC_OP_SHAREDFILES_ADD_DIRECTORY     = 0x24,
    EC_OP_RENAME_FILE                   = 0x25,
    EC_OP_SEARCH_START                  = 0x26,
    EC_OP_SEARCH_STOP                   = 0x27,
    EC_OP_SEARCH_RESULTS                = 0x28,
    EC_OP_SEARCH_PROGRESS               = 0x29,
    EC_OP_DOWNLOAD_SEARCH_RESULT        = 0x2A,
    EC_OP_IPFILTER_RELOAD               = 0x2B,
    EC_OP_GET_SERVER_LIST               = 0x2C,
    EC_OP_SERVER_LIST                   = 0x2D,
    EC_OP_SERVER_DISCONNECT             = 0x2E,
    EC_OP_SERVER_CONNECT                = 0x2F,
    EC_OP_SERVER_REMOVE                 = 0x30,
    EC_OP_SERVER_ADD                    = 0x31,
    EC_OP_SERVER_UPDATE_FROM_URL        = 0x32,
    EC_OP_ADDLOGLINE                    = 0x33,
    EC_OP_ADDDEBUGLOGLINE               = 0x34,
    EC_OP_GET_LOG                       = 0x35,
    EC_OP_GET_DEBUGLOG                  = 0x36,
    EC_OP_GET_SERVERINFO                = 0x37,
    EC_OP_LOG                           = 0x38,
    EC_OP_DEBUGLOG                      = 0x39,
    EC_OP_SERVERINFO                    = 0x3A,
    EC_OP_RESET_LOG                     = 0x3B,
    EC_OP_RESET_DEBUGLOG                = 0x3C,
    EC_OP_CLEAR_SERVERINFO              = 0x3D,
    EC_OP_GET_LAST_LOG_ENTRY            = 0x3E,
    EC_OP_GET_PREFERENCES               = 0x3F,
    EC_OP_SET_PREFERENCES               = 0x40,
    EC_OP_CREATE_CATEGORY               = 0x41,
    EC_OP_UPDATE_CATEGORY               = 0x42,
    EC_OP_DELETE_CATEGORY               = 0x43,
    EC_OP_GET_STATSGRAPHS               = 0x44,
    EC_OP_STATSGRAPHS                   = 0x45,
    EC_OP_GET_STATSTREE                 = 0x46,
    EC_OP_STATSTREE                     = 0x47,
    EC_OP_KAD_START                     = 0x48,
    EC_OP_KAD_STOP                      = 0x49,
    EC_OP_CONNECT                       = 0x4A,
    EC_OP_DISCONNECT                    = 0x4B,
    EC_OP_GET_DLOAD_QUEUE_DETAIL        = 0x4C,
    EC_OP_KAD_UPDATE_FROM_URL           = 0x4D,
    EC_OP_KAD_BOOTSTRAP_FROM_IP         = 0x4E,
    EC_OP_AUTH_SALT                     = 0x4F,
    EC_OP_AUTH_PASSWD                   = 0x50
};

enum ECTagNames : ushort
{
    EC_TAG_STRING                             = 0x0000,
    EC_TAG_PASSWD_HASH                        = 0x0001,
    EC_TAG_PROTOCOL_VERSION                   = 0x0002,
    EC_TAG_VERSION_ID                         = 0x0003,
    EC_TAG_DETAIL_LEVEL                       = 0x0004,
    EC_TAG_CONNSTATE                          = 0x0005,
    EC_TAG_ED2K_ID                            = 0x0006,
    EC_TAG_LOG_TO_STATUS                      = 0x0007,
    EC_TAG_BOOTSTRAP_IP                       = 0x0008,
    EC_TAG_BOOTSTRAP_PORT                     = 0x0009,
    EC_TAG_CLIENT_ID                          = 0x000A,
    EC_TAG_PASSWD_SALT                        = 0x000B,
    EC_TAG_CLIENT_NAME                        = 0x0100,
        EC_TAG_CLIENT_VERSION                     = 0x0101,
        EC_TAG_CLIENT_MOD                         = 0x0102,
    EC_TAG_STATS_UL_SPEED                     = 0x0200,
        EC_TAG_STATS_DL_SPEED                      = 0x0201,
        EC_TAG_STATS_UL_SPEED_LIMIT               = 0x0202,
        EC_TAG_STATS_DL_SPEED_LIMIT               = 0x0203,
        EC_TAG_STATS_UP_OVERHEAD                  = 0x0204,
        EC_TAG_STATS_DOWN_OVERHEAD                = 0x0205,
        EC_TAG_STATS_TOTAL_SRC_COUNT              = 0x0206,
        EC_TAG_STATS_BANNED_COUNT                 = 0x0207,
        EC_TAG_STATS_UL_QUEUE_LEN                 = 0x0208,
        EC_TAG_STATS_ED2K_USERS                   = 0x0209,
        EC_TAG_STATS_KAD_USERS                    = 0x020A,
        EC_TAG_STATS_ED2K_FILES                   = 0x020B,
        EC_TAG_STATS_KAD_FILES                    = 0x020C,
        EC_TAG_STATS_LOGGER_MESSAGE               = 0x020D,
        EC_TAG_STATS_KAD_FIREWALLED_UDP           = 0x020E,
        EC_TAG_STATS_KAD_INDEXED_SOURCES          = 0x020F,
        EC_TAG_STATS_KAD_INDEXED_KEYWORDS         = 0x0210,
        EC_TAG_STATS_KAD_INDEXED_NOTES            = 0x0211,
        EC_TAG_STATS_KAD_INDEXED_LOAD             = 0x0212,
        EC_TAG_STATS_KAD_IP_ADRESS                = 0x0213,
        EC_TAG_STATS_BUDDY_STATUS                 = 0x0214,
        EC_TAG_STATS_BUDDY_IP                     = 0x0215,
        EC_TAG_STATS_BUDDY_PORT                   = 0x0216,
    EC_TAG_PARTFILE                           = 0x0300,
        EC_TAG_PARTFILE_NAME                      = 0x0301,
        EC_TAG_PARTFILE_PARTMETID                 = 0x0302,
        EC_TAG_PARTFILE_SIZE_FULL                 = 0x0303,
        EC_TAG_PARTFILE_SIZE_XFER                 = 0x0304,
        EC_TAG_PARTFILE_SIZE_XFER_UP              = 0x0305,
        EC_TAG_PARTFILE_SIZE_DONE                 = 0x0306,
        EC_TAG_PARTFILE_SPEED                     = 0x0307,
        EC_TAG_PARTFILE_STATUS                    = 0x0308,
        EC_TAG_PARTFILE_PRIO                      = 0x0309,
        EC_TAG_PARTFILE_SOURCE_COUNT              = 0x030A,
        EC_TAG_PARTFILE_SOURCE_COUNT_A4AF         = 0x030B,
        EC_TAG_PARTFILE_SOURCE_COUNT_NOT_CURRENT  = 0x030C,
        EC_TAG_PARTFILE_SOURCE_COUNT_XFER         = 0x030D,
        EC_TAG_PARTFILE_ED2K_LINK                 = 0x030E,
        EC_TAG_PARTFILE_CAT                       = 0x030F,
        EC_TAG_PARTFILE_LAST_RECV                 = 0x0310,
        EC_TAG_PARTFILE_LAST_SEEN_COMP            = 0x0311,
        EC_TAG_PARTFILE_PART_STATUS               = 0x0312,
        EC_TAG_PARTFILE_GAP_STATUS                = 0x0313,
        EC_TAG_PARTFILE_REQ_STATUS                = 0x0314,
        EC_TAG_PARTFILE_SOURCE_NAMES              = 0x0315,
        EC_TAG_PARTFILE_COMMENTS                  = 0x0316,
    EC_TAG_KNOWNFILE                          = 0x0400,
        EC_TAG_KNOWNFILE_XFERRED                  = 0x0401,
        EC_TAG_KNOWNFILE_XFERRED_ALL              = 0x0402,
        EC_TAG_KNOWNFILE_REQ_COUNT                = 0x0403,
        EC_TAG_KNOWNFILE_REQ_COUNT_ALL            = 0x0404,
        EC_TAG_KNOWNFILE_ACCEPT_COUNT             = 0x0405,
        EC_TAG_KNOWNFILE_ACCEPT_COUNT_ALL         = 0x0406,
        EC_TAG_KNOWNFILE_AICH_MASTERHASH          = 0x0407,
    EC_TAG_SERVER                             = 0x0500,
        EC_TAG_SERVER_NAME                        = 0x0501,
        EC_TAG_SERVER_DESC                        = 0x0502,
        EC_TAG_SERVER_ADDRESS                     = 0x0503,
        EC_TAG_SERVER_PING                        = 0x0504,
        EC_TAG_SERVER_USERS                       = 0x0505,
        EC_TAG_SERVER_USERS_MAX                   = 0x0506,
        EC_TAG_SERVER_FILES                  = 0x0507,
        EC_TAG_SERVER_PRIO                      = 0x0508,
        EC_TAG_SERVER_FAILED                      = 0x0509,
        EC_TAG_SERVER_STATIC                      = 0x050A,
        EC_TAG_SERVER_VERSION                     = 0x050B,
    EC_TAG_CLIENT                             = 0x0600,
        EC_TAG_CLIENT_SOFTWARE                    = 0x0601,
        EC_TAG_CLIENT_SCORE                       = 0x0602,
        EC_TAG_CLIENT_HASH                        = 0x0603,
        EC_TAG_CLIENT_FRIEND                      = 0x0604,
        EC_TAG_CLIENT_WAIT_TIME                   = 0x0605,
        EC_TAG_CLIENT_XFER_TIME                   = 0x0606,
        EC_TAG_CLIENT_QUEUE_TIME                  = 0x0607,
        EC_TAG_CLIENT_LAST_TIME                   = 0x0608,
        EC_TAG_CLIENT_UPLOAD_SESSION              = 0x0609,
        EC_TAG_CLIENT_UPLOAD_TOTAL                = 0x060A,
        EC_TAG_CLIENT_DOWNLOAD_TOTAL              = 0x060B,
        EC_TAG_CLIENT_STATE                       = 0x060C,
        EC_TAG_CLIENT_UP_SPEED                    = 0x060D,
        EC_TAG_CLIENT_DOWN_SPEED                  = 0x060E,
        EC_TAG_CLIENT_FROM                        = 0x060F,
        EC_TAG_CLIENT_USER_IP                     = 0x0610,
        EC_TAG_CLIENT_USER_PORT                   = 0x0611,
        EC_TAG_CLIENT_SERVER_IP                   = 0x0612,
        EC_TAG_CLIENT_SERVER_PORT                 = 0x0613,
        EC_TAG_CLIENT_SERVER_NAME                 = 0x0614,
        EC_TAG_CLIENT_SOFT_VER_STR                = 0x0615,
        EC_TAG_CLIENT_WAITING_POSITION            = 0x0616,
    EC_TAG_SEARCHFILE                         = 0x0700,
        EC_TAG_SEARCH_TYPE                        = 0x0701,
        EC_TAG_SEARCH_NAME                        = 0x0702,
        EC_TAG_SEARCH_MIN_SIZE                    = 0x0703,
        EC_TAG_SEARCH_MAX_SIZE                    = 0x0704,
        EC_TAG_SEARCH_FILE_TYPE                   = 0x0705,
        EC_TAG_SEARCH_EXTENSION                   = 0x0706,
        EC_TAG_SEARCH_AVAILABILITY                = 0x0707,
        EC_TAG_SEARCH_STATUS                      = 0x0708,
    EC_TAG_SELECT_PREFS                       = 0x1000,
        EC_TAG_PREFS_CATEGORIES                   = 0x1100,
            EC_TAG_CATEGORY                           = 0x1101,
            EC_TAG_CATEGORY_TITLE                     = 0x1102,
            EC_TAG_CATEGORY_PATH                      = 0x1103,
            EC_TAG_CATEGORY_COMMENT                   = 0x1104,
            EC_TAG_CATEGORY_COLOR                     = 0x1105,
            EC_TAG_CATEGORY_PRIO                      = 0x1106,
        EC_TAG_PREFS_GENERAL                      = 0x1200,
            EC_TAG_USER_NICK                          = 0x1201,
            EC_TAG_USER_HASH                          = 0x1202,
            EC_TAG_USER_HOST                          = 0x1203,
        EC_TAG_PREFS_CONNECTIONS                  = 0x1300,
            EC_TAG_CONN_DL_CAP                        = 0x1301,
            EC_TAG_CONN_UL_CAP                      = 0x1302,
            EC_TAG_CONN_MAX_DL                      = 0x1303,
            EC_TAG_CONN_MAX_UL                      = 0x1304,
            EC_TAG_CONN_SLOT_ALLOCATION               = 0x1305,
            EC_TAG_CONN_TCP_PORT                      = 0x1306,
            EC_TAG_CONN_UDP_PORT                      = 0x1307,
            EC_TAG_CONN_UDP_DISABLE                   = 0x1308,
            EC_TAG_CONN_MAX_FILE_SOURCES              = 0x1309,
            EC_TAG_CONN_MAX_CONN                      = 0x130A,
            EC_TAG_CONN_AUTOCONNECT                   = 0x130B,
            EC_TAG_CONN_RECONNECT                      = 0x130C,
            EC_TAG_NETWORK_ED2K                  = 0x130D,
            EC_TAG_NETWORK_KADEMLIA                   = 0x130E,
        EC_TAG_PREFS_MESSAGEFILTER                = 0x1400,
            EC_TAG_MSGFILTER_ENABLED                  = 0x1401,
            EC_TAG_MSGFILTER_ALL                      = 0x1402,
            EC_TAG_MSGFILTER_FRIENDS                  = 0x1403,
            EC_TAG_MSGFILTER_SECURE                   = 0x1404,
            EC_TAG_MSGFILTER_BY_KEYWORD               = 0x1405,
            EC_TAG_MSGFILTER_KEYWORDS                 = 0x1406,
        EC_TAG_PREFS_REMOTECTRL                   = 0x1500,
            EC_TAG_WEBSERVER_AUTORUN                  = 0x1501,
            EC_TAG_WEBSERVER_PORT                     = 0x1502,
            EC_TAG_WEBSERVER_GUEST                    = 0x1503,
            EC_TAG_WEBSERVER_USEGZIP                  = 0x1504,
            EC_TAG_WEBSERVER_REFRESH                  = 0x1505,
            EC_TAG_WEBSERVER_TEMPLATE                 = 0x1506,
        EC_TAG_PREFS_ONLINESIG                    = 0x1600,
            EC_TAG_ONLINESIG_ENABLED                  = 0x1601,
        EC_TAG_PREFS_SERVERS                      = 0x1700,
            EC_TAG_SERVERS_REMOVE_DEAD                = 0x1701,
            EC_TAG_SERVERS_DEAD_SERVER_RETRIES        = 0x1702,
            EC_TAG_SERVERS_AUTO_UPDATE                = 0x1703,
            EC_TAG_SERVERS_URL_LIST                   = 0x1704,
            EC_TAG_SERVERS_ADD_FROM_SERVER            = 0x1705,
            EC_TAG_SERVERS_ADD_FROM_CLIENT            = 0x1706,
            EC_TAG_SERVERS_USE_SCORE_SYSTEM           = 0x1707,
            EC_TAG_SERVERS_SMART_ID_CHECK             = 0x1708,
            EC_TAG_SERVERS_SAFE_SERVER_CONNECT        = 0x1709,
            EC_TAG_SERVERS_AUTOCONN_STATIC_ONLY       = 0x170A,
            EC_TAG_SERVERS_MANUAL_HIGH_PRIO           = 0x170B,
            EC_TAG_SERVERS_UPDATE_URL                 = 0x170C,
        EC_TAG_PREFS_FILES                        = 0x1800,
            EC_TAG_FILES_ICH_ENABLED                  = 0x1801,
            EC_TAG_FILES_AICH_TRUST                   = 0x1802,
            EC_TAG_FILES_NEW_PAUSED                   = 0x1803,
            EC_TAG_FILES_NEW_AUTO_DL_PRIO             = 0x1804,
            EC_TAG_FILES_PREVIEW_PRIO                 = 0x1805,
            EC_TAG_FILES_NEW_AUTO_UL_PRIO             = 0x1806,
            EC_TAG_FILES_UL_FULL_CHUNKS               = 0x1807,
            EC_TAG_FILES_START_NEXT_PAUSED            = 0x1808,
            EC_TAG_FILES_RESUME_SAME_CAT              = 0x1809,
            EC_TAG_FILES_SAVE_SOURCES                 = 0x180A,
            EC_TAG_FILES_EXTRACT_METADATA             = 0x180B,
            //EC_TAG_FILES_ALLOC_FULL_CHUNKS
            EC_TAG_FILES_ALLOC_FULL_SIZE              = 0x180C,
            EC_TAG_FILES_CHECK_FREE_SPACE             = 0x180D,
            EC_TAG_FILES_MIN_FREE_SPACE              = 0x180E,
        EC_TAG_PREFS_SRCDROP                      = 0x1900,
            EC_TAG_SRCDROP_NONEEDED                   = 0x1901,
            EC_TAG_SRCDROP_DROP_FQS                   = 0x1902,
            EC_TAG_SRCDROP_DROP_HQRS                  = 0x1903,
            EC_TAG_SRCDROP_HQRS_VALUE                 = 0x1904,
            EC_TAG_SRCDROP_AUTODROP_TIMER             = 0x1905,
        EC_TAG_PREFS_DIRECTORIES                  = 0x1A00,
        EC_TAG_PREFS_STATISTICS                   = 0x1B00,
            EC_TAG_STATSGRAPH_WIDTH                   = 0x1B01,
            EC_TAG_STATSGRAPH_SCALE                   = 0x1B02,
            EC_TAG_STATSGRAPH_LAST                    = 0x1B03,
            EC_TAG_STATSGRAPH_DATA                    = 0x1B04,
            EC_TAG_STATTREE_CAPPING                   = 0x1B05,
            EC_TAG_STATTREE_NODE                      = 0x1B06,
            EC_TAG_STAT_NODE_VALUE                    = 0x1B07,
            EC_TAG_STAT_VALUE_TYPE                    = 0x1B08,
            EC_TAG_STATTREE_NODEID                    = 0x1B09,
        EC_TAG_PREFS_SECURITY                     = 0x1C00,
            EC_TAG_SECURITY_CAN_SEE_SHARES            = 0x1C01,
            EC_TAG_IPFILTER_CLIENTS                   = 0x1C02,
            EC_TAG_IPFILTER_SERVERS                   = 0x1C03,
            EC_TAG_IPFILTER_AUTO_UPDATE               = 0x1C04,
            EC_TAG_IPFILTER_UPDATE_URL                = 0x1C05,
            EC_TAG_IPFILTER_LEVEL                     = 0x1C06,
            EC_TAG_IPFILTER_FILTER_LAN                = 0x1C07,
            EC_TAG_SECURITY_USE_SECIDENT              = 0x1C08,
            EC_TAG_SECURITY_OBFUSCATION_SUPPORTED     = 0x1C09,
            EC_TAG_SECURITY_OBFUSCATION_REQUESTED     = 0x1C0A,
            EC_TAG_SECURITY_OBFUSCATION_REQUIRED      = 0x1C0B,
        EC_TAG_PREFS_CORETWEAKS                   = 0x1D00,
            EC_TAG_CORETW_MAX_CONN_PER_FIVE           = 0x1D01,
            EC_TAG_CORETW_VERBOSE                     = 0x1D02,
            EC_TAG_CORETW_FILEBUFFER                  = 0x1D03,
            EC_TAG_CORETW_UL_QUEUE                    = 0x1D04,
            EC_TAG_CORETW_SRV_KEEPALIVE_TIMEOUT       = 0x1D05,
        EC_TAG_PREFS_KADEMLIA                     = 0x1E00,
            EC_TAG_KADEMLIA_UPDATE_URL                = 0x1E01
};

enum EC_DETAIL_LEVEL : ubyte
{
    EC_DETAIL_CMD           = 0x00,
    EC_DETAIL_WEB           = 0x01,
    EC_DETAIL_FULL          = 0x02,
    EC_DETAIL_UPDATE        = 0x03,
    EC_DETAIL_INC_UPDATE    = 0x04
};

enum EC_SEARCH_TYPE : ubyte
{
    EC_SEARCH_LOCAL         = 0x00,
    EC_SEARCH_GLOBAL        = 0x01,
    EC_SEARCH_KAD           = 0x02,
    EC_SEARCH_WEB           = 0x03
};

enum EC_STATTREE_NODE_VALUE_TYPE : ubyte
{
    EC_VALUE_INTEGER        = 0x00,
    EC_VALUE_ISTRING        = 0x01,
    EC_VALUE_BYTES          = 0x02,
    EC_VALUE_ISHORT         = 0x03,
    EC_VALUE_TIME           = 0x04,
    EC_VALUE_SPEED          = 0x05,
    EC_VALUE_STRING         = 0x06,
    EC_VALUE_DOUBLE         = 0x07
};

enum EcPrefs : uint
{
    EC_PREFS_CATEGORIES     = 0x00000001,
    EC_PREFS_GENERAL        = 0x00000002,
    EC_PREFS_CONNECTIONS    = 0x00000004,
    EC_PREFS_MESSAGEFILTER  = 0x00000008,
    EC_PREFS_REMOTECONTROLS = 0x00000010,
    EC_PREFS_ONLINESIG      = 0x00000020,
    EC_PREFS_SERVERS        = 0x00000040,
    EC_PREFS_FILES          = 0x00000080,
    EC_PREFS_SRCDROP        = 0x00000100,
    EC_PREFS_DIRECTORIES    = 0x00000200,
    EC_PREFS_STATISTICS     = 0x00000400,
    EC_PREFS_SECURITY       = 0x00000800,
    EC_PREFS_CORETWEAKS     = 0x00001000,
    EC_PREFS_KADEMLIA       = 0x00002000
};

enum ECTagTypes : ubyte
{
    EC_TAGTYPE_UNKNOWN = 0,
    EC_TAGTYPE_CUSTOM = 1,
    EC_TAGTYPE_UINT8 = 2,
    EC_TAGTYPE_UINT16 = 3,
    EC_TAGTYPE_UINT32 = 4,
    EC_TAGTYPE_UINT64 = 5,
    EC_TAGTYPE_STRING = 6,
    EC_TAGTYPE_DOUBLE = 7,
    EC_TAGTYPE_IPV4 = 8,
    EC_TAGTYPE_HASH16 = 9
};

//from KnownFile.h
enum PS : ubyte
{
    READY,
    EMPTY,
    WAITINGFORHASH,
    HASHING,
    ERROR, //Erroneous
    INSUFFICIENT, //Insufficient Diskspace
    UNKNOWN,
    PAUSED,
    COMPLETING,
    COMPLETE, //Stopped
    ALLOCATING
};

//from KnownFile.h
enum PR : ubyte
{
    LOW,
    NORMAL, // Don't change this - needed for edonkey clients and server!
    HIGH,
    VERYHIGH,
    /* PR_VERYLOW:
    I Had to change this because
    it didn't save negative number
    correctly.. Had to modify the
    sort function for this change..
    */
    VERYLOW,
    AUTO,
    POWERSHARE //added for powershare (deltaHF)
};

//from ClientSoftware.h
enum EClientSoftware : ubyte
{
    SO_EMULE            = 0,
    SO_CDONKEY            = 1,
    SO_LXMULE            = 2,
    SO_AMULE            = 3,
    SO_SHAREAZA            = 4,
    SO_EMULEPLUS        = 5,
    SO_HYDRANODE        = 6,
    SO_NEW2_MLDONKEY    = 0x0a,
    SO_LPHANT            = 0x14,
    SO_NEW2_SHAREAZA    = 0x28,
    SO_EDONKEYHYBRID    = 0x32,
    SO_EDONKEY            = 0x33,
    SO_MLDONKEY            = 0x34,
    SO_OLDEMULE            = 0x35,
    SO_UNKNOWN            = 0x36,
    SO_NEW_SHAREAZA        = 0x44,
    SO_NEW_MLDONKEY        = 0x98,
    SO_COMPAT_UNK        = 0xFF
};
