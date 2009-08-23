module clients.mldonkey.model.MLPartFile;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import tango.io.Stdout;

import api.Node;
import api.File;
import api.Meta;
import api.User;

import clients.mldonkey.model.MLFileInfo;
import clients.mldonkey.InBuffer;
import clients.mldonkey.MLUtils;
import clients.mldonkey.MLDonkey;


final class MLPartFile : NullFile
{
public:
    
    this(uint id, char[] name, ulong size, char[] format, ulong offset, MLFileInfo file)
    {
        this.id = id;
        this.file = file;
        this.size = size;
        this.name = name;
        
        auto states = file.getChunkStates();
        if(states.length)
        {
            auto chunk_size = file.getSize() / states.length;
            chunk_start = offset / chunk_size;
            chunk_end = (offset + size) / chunk_size;
        }
    }
    
    File_.Type getType() { return File_.Type.SUBFILE; }
    uint getId() { return id; }
    char[] getName() { return name; }
    char[] getFormat() { return format; }
    ulong getSize() { return size; }
    
    //get an estimated download size
    ulong getDownloaded()
    {
        auto states = file.getChunkStates();
        
        if(states.length == 0)
        {
            return size;
        }
        
        if(chunk_end > states.length || chunk_start > chunk_end)
        {
            return 0;
        }
        
        if(chunk_start == chunk_end)
        {
            return (states[chunk_start] == '0') ? 0 : size;
        }
        
        auto chunk_size = file.getSize() / states.length;
        
        uint complete_chunks;
        foreach(c; states[chunk_start..chunk_end])
        {
            if(c == '3' || c== '2')
            {
                complete_chunks++;
            }
        }
        
        uint all_chunks = chunk_end - chunk_start;
        uint incomplete_chunks = all_chunks - complete_chunks;
        auto factor = (complete_chunks * 1.0) / all_chunks;
        return cast(ulong) (factor * size);
    }
    
    File[] getFileArray(File_.Type type, File_.State state, uint age)
    {
        if(type != File_.Type.CHUNK) return null;
        
        auto states = file.getChunkStates();
        auto ages =  file.getChunkAges();
        
        if ( states.length == ages.length
            && chunk_end <= states.length
            && chunk_start <= chunk_end
        )
        {
            return chunkString2FileArray(file.getSize(), states[chunk_start..chunk_end], ages[chunk_start..chunk_end]);
        }
        return null;
    }
    
private:
    
    MLFileInfo file;
    uint id;
    char[] name, format;
    ulong size;
    ushort chunk_start;
    ushort chunk_end;
}
