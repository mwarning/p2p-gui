module api.Search_;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/

interface Search_
{
    enum State : ubyte
    {
        ACTIVE,
        STOPPED,
        PAUSED,
        REMOVED,
        ANYSTATE
    };
    
    enum BoolType : ubyte
    {
        AND, OR, NOT
    };
    
    enum ValueType : ushort
    {
        KEYWORD,
        MAXSIZE,
        MINSIZE,
        MEDIA,
        ARTIST,
        TITLE,
        MAXRESULTS,
        MINAVAIL,
        NETWORKID
    };
    
    enum MediaType : ubyte
    {
        UNKNOWN,
        PROGRAM,    // exe/com/bat/sh
        DOCUMENT,    // txt/doc/kwd/sxw/rtf
        IMAGE,        // png/gif/jpg/bmp
        AUDIO,        // mp3/mpc/ogg
        VIDEO,        // avi/mpeg/mpg/wmv
        ARCHIVE,        // zip/arj/rar/gz/bz2
        COPY        // iso/bin/cue/nrg
    };
}
