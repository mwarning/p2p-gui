module api.File_;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/

//this file is needed because of http://d.puremagic.com/issues/show_bug.cgi?id=102

interface File_
{
    enum Type : ubyte
    {
        UNKNOWN,
        DOWNLOAD,
        DIRECTORY, //a file system directory / emule collection?
        CHUNK, //download
        FILE,  //filesystem
        SUBFILE, //torrent, merge meaning of subfile with file?
        SOURCE //search results, file names
    };
    
    enum State : ubyte
    {
        ACTIVE,
        PAUSED,
        STOPPED,
        COMPLETE, //seeding
        PROCESS,
        CANCELED, //for internal use?
        SHARED, //for internal use?
        ANYSTATE
    };
}
