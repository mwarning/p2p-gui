module clients.mldonkey.model.MLConsoleLine;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import tango.time.Clock;

import api.Meta;


final class MLConsoleLine : public NullMeta
{
    char[] lines;
    uint id;
    uint lastChanged;
    
    public:
    
    this(char[] lines, uint id)
    {
        this.lines = lines;
        this.id = id;
        this.lastChanged = (Clock.now - Time.epoch1970).seconds;
    }
    
    uint getId()
    {
        return id;
    }
    
    uint getLastChanged()
    {
        return lastChanged;
    }

    char[] getMeta()
    {
        return lines;
    }
}
