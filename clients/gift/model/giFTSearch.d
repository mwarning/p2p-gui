module clients.gift.model.giFTSearch;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import clients.gift.giFTParser;
import clients.gift.model.giFTResult;


final class giFTSearch //: public Search
{
    public:
    this(uint id, char[]  keywords)
    {
        this.id = id;
        this.keywords = keywords;
    }
    
    void addResult(giFTParser msg)
    {
        if(msg.map.length == 1) active = false; //??
        if(!active) return;
        
        auto result = getResult(0); //TODO: get result id
        if(result)
        {
            result.update(msg); //TODO: strip msg
        }
        else
        {
            uint id = result_counter++;
            results[id] = new giFTResult(msg, id);
        }
    }
    
    uint getId() { return id; }
    bool isActive() { return active; }
    char[] getKeywords() { return keywords; }
    
    giFTResult getResult(uint id)
    {
        auto result = (id in results);
        return result ? *result : null;
    }
    
    giFTResult[uint] getResults()
    {
        return results;
    }
    
    
    bool active = true;
    uint id;
    uint result_counter = 1;
    char[] keywords;
    giFTResult[uint] results;
}