module clients.mldonkey.model.MLSearch;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import Convert = tango.util.Convert;
import tango.io.Stdout;

static import Utils = utils.Utils;
import api.File;
import api.Search;

import clients.mldonkey.model.MLResult;
import clients.mldonkey.MLDonkey;


class Query
{
    enum Type : ubyte
    {
        AND, OR, ANDNOT,
        MODULE, KEYWORD,
        MINSIZE, MAXSIZE,
        FORMAT, MEDIA,
        MP3ARTIST, MP3TITLE,
        MP3ALBUM, MP3BITRATE
    }

    this(Type type, char[] value = null, char[] comment = null)
    {
        this.type = type;
        this.value = value;
        this.comment = comment;
    }
    
    void addSubQuery(Search_.BoolType type, char[] query_string)
    {
        debug(MLSearch)
            Stdout("(D) MLSearch: Query.addSubQuery ")(Utils.toString(type))(" '")(query_string)("'").newline;
        
        Query query;
        switch(type)
        {
        case Search_.BoolType.AND:
            query = new Query(Type.AND); break;
        case Search_.BoolType.OR:
            query = new Query(Type.OR); break;
        case Search_.BoolType.NOT:
            query = new Query(Type.ANDNOT); break; //??
        default: return;
        }
        
        Utils.parseQuery(query_string, &query.addKey, &query.addSubQuery);
    }
    
    void addKey(Search_.ValueType type, char[] value)
    {
        debug(MLSearch)
            Stdout("(D) MLSearch: Query.addKey ")(Utils.toString(type))(" '")(value)("'").newline;
        
        switch(type)
        {
        case Search_.ValueType.KEYWORD:
            childs ~= new Query(Type.KEYWORD, value, "Keyword");
            break;
        case Search_.ValueType.MAXSIZE:
            childs ~= new Query(Type.MAXSIZE, value);
            break;
        case Search_.ValueType.MINSIZE:
            childs ~= new Query(Type.MINSIZE, value);
            break;
        case Search_.ValueType.ARTIST:
            childs ~= new Query(Type.MP3ARTIST, value);
            break;
        case Search_.ValueType.TITLE:
            childs ~= new Query(Type.MP3TITLE, value);
            break;
        case Search_.ValueType.MEDIA:
            char[] media;
            switch(value)
            {
                case "AUDIO": media = "Audio"; break;
                case "VIDEO": media = "Video"; break;
                case "IMAGE": media = "Image"; break;
                case "SOFTWARE": media = "Software"; break;
                case "DOCUMENT": media = "Document"; break;
                case "PROGRAM": media = "Program"; break;
                case "COPY":
                case "ARCHIVE": media = "Collection"; break; //TODO: need to clarify meaning
                default:
            }
            
            if(type)
            {
                childs ~= new Query(Type.MEDIA, media);
            }
            break;
        default:
        }
    }
    
    char[] comment;
    char[] value;
    Type type;
    Query[] childs;
}

final class MLSearch : Query, Search
{
    uint id;
    uint network_id;
    uint max_results;
    uint min_avail;
    char[] keywords;
    bool active = true;
    Search_.State state = Search_.State.ACTIVE;
    
    MLResult[uint] results;
    
    this(uint id, char[] query_string)
    {
        this.id = id;
        super(Query.Type.AND);
        debug(MLSearch)
            Stdout("(D) MLSearch: query_string: '")(query_string)("'").newline;
        
        Utils.parseQuery(query_string, &addKey, &addSubQuery);
    }
    
    void addKey(Search_.ValueType type, char[] value)
    {
        debug(MLSearch)
            Stdout("(D) MLSearch: addKey ")(Utils.toString(type))(" '")(value)("'").newline;
        
        //we catch some parameters that doesn't go into there query message
        switch(type)
        {
        case Search_.ValueType.MAXRESULTS:
            max_results = Convert.to!(uint)(value, 0);
            break;
        case Search_.ValueType.MINAVAIL:
            min_avail = Convert.to!(uint)(value, 0);
            break;
        case Search_.ValueType.NETWORKID:
            network_id = Convert.to!(uint)(value, 0);
            break;
        case Search_.ValueType.KEYWORD:
            if(keywords.length < 40) keywords ~= value ~ " ";
        //TODO: catch&pass keywords for name value?
        default:
            super.addKey(type, value);
        }
    }
    
    uint getId() { return id; }
    char[] getName() { return keywords; }
    Search_.State getState() { return state; }
    
    void addSearchResult(MLResult result, MLDonkey mld)
    {
        if(!active) return;
        
        //add filters for query parameters
        //not supported by the gui protocol
        if(max_results && results.length >= max_results)
        {
            //will set active to false
            mld.stopSearch(this.id);
            return;
        }
        
        //TODO: .getFileCount does not fit for this info
        if(min_avail && result.getFileCount(File_.Type.UNKNOWN, File_.State.ANYSTATE) <= min_avail)
        {
            return;
        }
        
        results[result.getId] = result;
    }
    
    void removeResults(uint[] ids)
    {
        foreach(id; ids)
        {
            results.remove(id);
        }
    }
    
    void stop()
    {
        active = false;
        state = Search_.State.STOPPED;
    }
    
    uint getResultCount(File_.State state)
    {
        return results.length;
    }
    
    File[] getResultArray(File_.State state, uint age)
    {
        return Utils.filter!(File)(results, state, age);
    }
}
