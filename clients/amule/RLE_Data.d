module clients.amule.RLE_Data;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/

import tango.io.Stdout;

/*
* Data decoder ported from aMule source code.
*/
final class RLE_Data
{
    bool m_use_diff;
    int m_len;
    ubyte[] m_enc_buff;
    ubyte[] m_buff;

    this(int len, bool use_diff)
        {
        m_len = len;
        m_use_diff = use_diff;
        // in worst case 2-byte sequence encoded as 3. So, data can grow at 1/3
        m_enc_buff = new ubyte[m_len * 4 / 3 + 1];
        m_buff = new ubyte[m_len];
        }

        public void Realloc(int size)
        {
        if ( size == m_len )
        {
            return;
        }

        if ( (size > m_len) && (size > m_buff.length) )
        {
            m_buff.length = size;
            m_enc_buff.length = size * 4 / 3 + 1;
        }
        m_len = size;
        }

    public void Decode(ubyte [] buff, int start_offset = 0)
    {
        int len = buff.length;

        int i = start_offset, j = 0;
        while ( j != m_len )
        {
            if ( i < (len -1) )
            {
                if (buff[i+1] == buff[i])
                {
                    // this is sequence
                    for(int k = 0; k < buff[i + 2]; k++)
                    {
                        m_enc_buff[j + k] = buff[i];
                    }
                    j += buff[i + 2];
                    i += 3;
                }
                else
                {
                    // this is single byte
                    m_enc_buff[j++] = buff[i++];
                }
            }
            else
            {
                // only 1 byte left in encoded data - it can't be sequence
                m_enc_buff[j++] = buff[i++];
                // if there's no more data, but buffer end is not reached,
                // it must be error in some point
                if ( j != m_len )
                {
                    Stdout.format("(E) AFileInfo: RLE_Data: decoding error. {0} bytes decoded to {1} instead of {2}\n", len, j, m_len);
                    throw new Exception("(E) AFileInfo: RLE_Data: decoding error");
                }
            }
        }
        
        if ( m_use_diff )
        {
            for (int k = 0; k < m_len; k++)
            {
                m_buff[k] ^= m_enc_buff[k];
            }
        }
    }
}
