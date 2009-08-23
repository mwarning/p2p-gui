module api.Search;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/

import tango.io.model.IConduit;
import tango.io.Stdout;

public import api.Node_;
public import api.File_;
public import api.Search_;
public import api.File;

//TODO: how do we search for Nodes, Comments, etc.?
interface Search
{
    uint getId();
    char[] getName();
    
    Search_.State getState();
/*
    Search andKeywords(char[][] keywords);
    Search orKeywords(char[][] keywords);
    Search andNotKeyword(char[][] keywords);

    //void addKeyword(char[] value);
    void setMedia(File_.Media media);
    void setNetwork(uint id);
    void setMaxResults(uint max);
    void setMinSize(ulong size);
    void setMaxSize(ulong size);
    
    //uint getNetworkId
    File_.Media getMedia();
    ulong getMaxSize();
    ulong getMinSize();
*/
    
    uint getResultCount(File_.State state);
    File[] getResultArray(File_.State state, uint age);
}

interface Searches
{
    /*
    * It is tedious to build up an arbitrary query structure
    * so we submit a query string
    * TODO: add EBNF
    */
    Search addSearch(char[] query);
    void stopSearch(uint id);
    void removeSearch(uint id);
    
    void startSearchResults(uint search_id, uint[] result_ids);
    void removeSearchResults(uint search_id, uint[] result_ids);
    /*
    void mergeSearch(uint[] ids); //OR searches
    void intersectSearch(uint[] ids); //AND searches
    void excludeSearch(uint id, uint id); //ANDNOT searches
    */
    Search getSearch(uint id);
    Search[] getSearchArray();
}
