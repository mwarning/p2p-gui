module clients.hydranode.opcodes;

/*
 *  Copyright (C) 2005-2006 Alo Sarv <madcat_@users.sourceforge.net>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

/**
 * Packet structure:
 * \code
 * +--------+--------+--------+--------+--------
 * | subsys |   packet length | opcode | data payload
 * +--------+--------+--------+--------+--------
 * \endcode
 *
 * Subsys is one of SubSystems enumeration values; packet length is unsigned
 * 16-bit integer, that is the sum of data layload size + 1 (opcode), in bytes.
 * Opcode is subsystem-specific, generally used opcodes are listed in OpCodes
 * enumeration value. Data payload is subsystem-specific.
 */

/**
 * Opcodes are used inside subsystems for determining the type of operation
 * being performed. Generally, opcodes are only sent from UI to Engine, however
 * the engine uses a few of them (mainly OC_LIST and OC_DATA) in response
 * packets as well.
 */
enum OpCodes : ubyte
{
    OC_LIST     = 0x01,  //!< Request / Send list
    OC_MONITOR  = 0x02,  //!< Request automatic updates
    OC_CANCEL   = 0x03,  //!< Cancel (a download, search or similar)
    OC_PAUSE    = 0x04,  //!< Pause operation (download, hashing, etc)
    OC_STOP     = 0x05,  //!< Stop operation (download)
    OC_RESUME   = 0x06,  //!< Resume operation (download, hashing, etc)
    OC_ADD      = 0x07,  //!< Add item (download, server, etc)
    OC_REMOVE   = 0x08,  //!< Remove item (download, server, etc)
    OC_SET      = 0x09,  //!< Set data / element
    OC_GET      = 0x10,  //!< Get data / element
    OC_DATA     = 0x11,  //!< Sending data
    OC_UPDATE   = 0x12,  //!< Response to OC_MONITOR, sends (partial) data
    OC_IMPORT   = 0x13,  //!< Import partial downloads
    OC_NAMES    = 0x14,  //!< Get/Send known file names
    OC_COMMENTS = 0x15,  //!< Get/Send found comments/ratings
    OC_SETNAME  = 0x16,  //!< Set file name
    OC_SETDEST  = 0x17,  //!< Set file destination
    OC_LINKS    = 0x18,  //!< Get/Send human-readable links (http, ed2k etc)
    OC_GETLINK  = 0x19,  //!< Start a download from a link
    OC_GETFILE  = 0x1a,  //!< Start a download from file contents
    OC_DOOPER   = 0x1b,  //!< Do an operation (on an object)
    OC_NOTFOUND = 0x1c,  //!< The refered object was not found
    OC_CADDED   = 0x1d,  //!< Child was added to an object
    OC_CREMOVED = 0x1e,  //!< Child was removed from an object
    OC_DESTROY  = 0x1f,  //!< Object was destroyed
    OC_CHANGEID = 0x20   //!< Object ID was changed
};

/**
 * Used by Search subsystem, marks SearchResults packet
 */
enum SearchPackets : ubyte
{
    OP_SEARCHRESULTS = 0x01
};

/**
 * Tags used in SearchResults packet
 */
enum SearchTags : ubyte
{
    TAG_FILENAME   = 0x01, //!< string
    TAG_FILESIZE   = 0x02, //!< uint64_t
    TAG_SRCCNT     = 0x03, //!< uint32_t
    TAG_KEYWORDS   = 0x04, //!< space-separated string
    TAG_MINSIZE    = 0x05, //!< uint64_t (used for search query)
    TAG_MAXSIZE    = 0x06, //!< uint64_t (used for search query)
    TAG_FILETYPE   = 0x07, //!< FileType enumeration value
    TAG_BITRATE    = 0x08, //!< Bitrate (uint32_t)
    TAG_CODEC      = 0x09, //!< Codec (string)
    TAG_LENGTH     = 0x0a, //!< Media length (uint32_t)
    OC_DOWNLOAD    = 0x0f  //!< Custom opcodes used only by search subsys
};

/**
 * Tags used when sending download list
 */
enum DownloadTags : ubyte
{
    TAG_FULLSRCCNT      = 0x10, //!< uint32_t
    TAG_COMPLETED       = 0x11, //!< uint64_t (bytes completed)
    TAG_COMPLETEDCHUNKS = 0x12, //!< RangeList64
    TAG_LOCATION        = 0x13, //!< string, full path to temp file
    TAG_DESTDIR         = 0x14, //!< string, incoming/destination folder
    TAG_STATE           = 0x15, //!< uint32_t, state change
    TAG_CHILD           = 0x16, //!< uint32_t ID of child object
    TAG_AVAIL           = 0x17  //!< float, availability percentage
};

/**
 * Tags dealing with network-related values. These are all either 32bit or
 * 64bit integers.
 */
enum NetworkTags : ubyte
{
    TAG_UPSPEED       = 0x20,
    TAG_DOWNSPEED     = 0x21,
    TAG_CONNCNT       = 0x22, 
    TAG_CONNECTINGCNT = 0x23,
    TAG_TOTALUP       = 0x24,
    TAG_TOTALDOWN     = 0x25,
    TAG_SESSUP        = 0x26,
    TAG_SESSDOWN      = 0x27,
    TAG_DOWNPACKETS   = 0x28,
    TAG_UPPACKETS     = 0x29,
    TAG_UPLIMIT       = 0x2a,
    TAG_DOWNLIMIT     = 0x2b,
    TAG_RUNTIMESESS   = 0x2c,
    TAG_RUNTIMETOTAL  = 0x2d
};

enum SharedFileTags : ubyte
{
    TAG_UPLOADED        = 0x30, //!< Amount uploaded
    TAG_PDPOINTER       = 0x31  //!< ID of corresponding PartData object
};

/**
 * General file state
 */
enum FileState : byte
{
    DSTATE_KEEP    = -1,   //!< Needed by implementation
    DSTATE_RUNNING = 0,    //!< The download is ok and running
    DSTATE_VERIFYING,      //!< The download is being hashed
    DSTATE_MOVING,         //!< The download is being moved
    DSTATE_COMPLETE,       //!< The download is complete
    DSTATE_CANCELED,       //!< The download is canceled
    DSTATE_PAUSED,         //!< The download is paused
    DSTATE_STOPPED         //!< The download is stopped
};

// Tags specific to modules
enum ModuleTags : ubyte
{
    OC_MODULE = 0x40,
    TAG_NAME  = 0x41,
    TAG_DESC  = 0x42
};

/**
 * Available subsystems
 */
enum SubSystems : ubyte
{
    SUB_AUTH     = 0x01,
    SUB_SEARCH   = 0x02,
    SUB_DOWNLOAD = 0x03,
    SUB_SHARED   = 0x04,
    SUB_CONFIG   = 0x05,
    SUB_HASHER   = 0x06,
    SUB_MODULES  = 0x07,
    SUB_LOG      = 0x08,
    SUB_NETWORK  = 0x09,
    SUB_EXT      = 0xff
};

enum : ubyte
{
    OP_SHAREDFILE = 0x90,
    OC_OBJECT     = 0x91,
    OC_OBJLIST    = 0x92
};

//added from fwd.h
enum FileType : ubyte
{
    FT_UNKNOWN = 0,                         //!< Unknown/any
    FT_ARCHIVE = 1,                         //!< zip/arj/rar/gz/bz2
    FT_VIDEO,                               //!< avi/mpeg/mpg/wmv
    FT_AUDIO,                               //!< mp3/mpc/ogg
    FT_IMAGE,                               //!< png/gif/jpg/bmp
    FT_DOC,                                 //!< txt/doc/kwd/sxw/rtf
    FT_PROG,                                //!< exe/com/bat/sh
    FT_CDDVD                                //!< iso/bin/cue/nrg
};


