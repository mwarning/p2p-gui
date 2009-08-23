module clients.mldonkey.MLUtils;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/

import api.File;
import tango.io.Stdout;

File[] chunkString2FileArray(ulong file_size, char[] chunk_states, uint[] chunk_ages = null)
{
    if(chunk_states.length == 0 || file_size == 0)
    {
        return [];
    }
    
    class Part : NullFile
    {
        char state;
        uint size;
        uint last_seen;
        
        this(uint size, char state, uint last_seen)
        {
            this.state = state;
            this.size = size;
            this.last_seen = last_seen;
        }
        
        ulong getSize()
        {
            return size;
        }
        
        ulong getDownloaded()
        {
            if(state == '1') return size / 2; //partial, we assume 50%
            if(state == '3' || state == '2') return size; //complete, verified
            return 0; //missing
        }
        
        uint getNodeCount(Node_.Type type, Node_.State state)
        {
            return (type == Node_.Type.CLIENT) ? (last_seen < 100 * 24 * 60 * 60) : 0;
        }
        
        uint getLastSeen()
        {
            if(last_seen == 0)
            {
                return 1;
            }
            else if(last_seen < 100*24*60*60)
            {
                return last_seen;
            }
            else
            {
                return 0;
            }
        }
    }
    
    File[] chunks = new File[chunk_states.length];
    uint chunk_size = file_size / chunks.length;
    uint chunk_size_plus = chunk_size + 1;
    uint missing = file_size % chunks.length; //bytes that doesn't fit into equal sized chunks
    
    for(auto i= 0; i < chunks.length; i++)
    {
        auto size = (i < missing) ? chunk_size_plus : chunk_size;
        chunks[i] = new Part(size, chunk_states[i], chunk_ages[i]);
    }
    
    return chunks;
}
