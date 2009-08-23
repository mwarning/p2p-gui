module clients.hydranode.model.HNSearch;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import clients.hydranode.Hydranode;
import clients.hydranode.opcodes;
import clients.hydranode.model.HNResult;
import api.Search;

class HNSearch // : Search
{
    public:
    
    this(uint id,  char[] keywords, ulong minSize, ulong maxSize) 
    {
        this.id = id;
        this.keywords = keywords;
        this.minSize = minSize;
        this.maxSize = maxSize;
    }

    void addSearchResult(HNResult result)
    {
        if(!active) return;
        
        uint id = result.getId();
        if (id in results)
        {
            results[id] = result;
        }
        else
        {
            auto res = results[id];
            res.update(result);
        }
    }

    uint getId() { return id; }
    char[] getKeywords() { return keywords; }
    ulong getMinSize() { return minSize; }
    ulong getMaxSize() { return maxSize; }
    bool isActive() { return active; }
    
    HNResult[uint] getResults()
    {
        return results;
    }
    
    private:
    
    uint id;
    char[] keywords;
    ulong minSize, maxSize;
    HNResult[uint] results;
    bool active = true;
}

