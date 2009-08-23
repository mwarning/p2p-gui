module clients.amule.model.ASearchInfo;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import tango.io.model.IConduit;
import tango.io.Stdout;

import api.File;
import api.Search;
static import Utils = utils.Utils;

import clients.amule.aMule;
import clients.amule.ECTag;
import clients.amule.model.AResultInfo;


final class ASearchInfo : Search
{
    uint id;
    char[] name;
    bool active = true;
    Search_.State state = Search_.State.ACTIVE;
    AResultInfo[ubyte[]] results;
    uint max_results;
    aMule amule;
    
    this(uint id, char[] query_string, aMule amule, uint max_results = 0)
    {
        this.id = id;
        this.name = query_string;
        this.max_results = max_results;
        this.amule = amule;
    }
    
    uint getId() { return id; }
    char[] getName() { return name; }
    Search_.State getState() { return state; }
    
    void addResult(ECTag tag)
    {
        if(!active)
        {
            return;
        }
        else if(max_results && results.length >= max_results)
        {
            amule.stopSearch(id); //stops this search
            return;
        }
        
        ubyte[] hash = tag.getRawValue();
        assert(hash.length == 16);
        
        if(auto result = (hash in results))
        {
            result.update(tag);
        }
        else
        {
            uint id = results.length + 1;
            results[hash] = new AResultInfo(id, hash, tag);
        }
    }
    
    void removeResults(uint[] ids)
    {
        foreach(id; ids)
        {
            ubyte[] hash = getResultHashById(id);
            results.remove(hash);
        }
    }
    
    void stop()
    {
        active = false;
        state = Search_.State.STOPPED;
    }
    
    ubyte[] getResultHashById(uint id)
    {
        foreach(result; results)
        {
            if(result.getId == id)
                return result.getRawHash();
        }
        return null;
    }
    
    AResultInfo getResultById(uint id)
    {
        foreach(result; results)
        {
            if(result.getId == id)
                return result;
        }
        return null;
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
