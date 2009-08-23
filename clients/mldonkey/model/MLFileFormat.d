module clients.mldonkey.model.MLFileFormat;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import tango.io.Stdout;

import clients.mldonkey.InBuffer;

import webcore.Logger;

class MLFileFormat
{
public:
    /*
    enum FileType {
        UNKNOWN,
        AUDIO,
        VIDEO,
        BINARY
    };*/

    void readMLFileFormat(InBuffer msg)
    {
        ubyte type = msg.read8();
        
        switch(type)
        {
        case 0: //unknown format
            break;
        case 1:
            formatExtension = msg.readString();
            formatKind = msg.readString();
            break;
        case 2: //AVI
            videoCodec = msg.readString();
            videoWidth = msg.read32();
            videoHeight = msg.read32();
            videoFPS = msg.read32();
            videoRate = msg.read32();
            break;
        case 3: //MP3
            mp3Title = msg.readString();
            mp3Artist = msg.readString();
            mp3Album = msg.readString();
            mp3Year = msg.readString();
            mp3Comment = msg.readString();
            mp3TrackNumber = msg.read32();
            mp3Genre = msg.read32();
            break;
        case 4: //OGG
            ushort streams = msg.read16; //list of stream infos
            for(ushort i = 0; i < streams; i++)
            {
                msg.read32(); //stream number
                
                ubyte stream_type = msg.read8();
                /*
                0  OGG_VIDEO_STREAM
                1 OGG_AUDIO_STREAM
                2 OGG_INDEX_STREAM
                3 OGG_TEXT_STREAM
                4 OGG_VORBIS_STREAM
                5 OGG_THEORA_STREAM
                */
                ushort tags = msg.read16; //list of stream tags
                for(ushort k = 0; k < tags; k++)
                {
                    switch(msg.read8)
                    {
                    case 0: msg.readString(); break; //Ogg_codec
                    case 1: msg.read32(); break;  //Ogg_bits_per_samples
                    case 2: msg.read32(); break;  //Ogg_duration
                    case 3:  break; //Ogg_has_subtitle
                    case 4:  break; //Ogg_has_index
                    case 5: msg.read32(); break; //Ogg_audio_channels
                    case 6: msg.readFloat(); break; // Ogg_audio_sample_rate
                    case 7: msg.read32(); break; //Ogg_audio_blockalign
                    case 8: msg.readFloat(); break; //Ogg_audio_avgbytespersec
                    case 9: msg.readFloat(); break; //Ogg_vorbis_version
                    case 10: msg.readFloat(); break; //Ogg_vorbis_sample_rate
                    case 11: //Ogg_vorbis_bitrates
                        ushort bitrates = msg.read16();
                        for(ushort j = 0; j < bitrates; j++)
                        {
                            msg.read8(); //0 Maximum_br, 1 Nominal_br, 2 Minimum_br
                            msg.readFloat();
                        }
                        break;
                    case 12: msg.read32(); break; //Ogg_vorbis_blocksize_0
                    case 13: msg.read32(); break;//Ogg_vorbis_blocksize_1
                    case 14: msg.readFloat(); break; //Ogg_video_width
                    case 15: msg.readFloat(); break; //Ogg_video_height
                    case 16: msg.readFloat(); break; //Ogg_video_sample_rate
                    case 17: msg.readFloat(); break; //Ogg_aspect_ratio
                    case 18: //Ogg_theora_cs
                        msg.read8(); //0 CSUndefined, 1 CSRec470M, 2 CSRec470BG
                        break;
                    case 19: msg.read32(); break; //Ogg_theora_quality
                    case 20: msg.read32(); break; //Ogg_theora_avgbytespersec
                    }
                }
            }
            break;
        default:
            Logger.addWarning("MLFileFormat: Unknown Format!");
        }
    }
    
    private:
    char[] formatExtension, formatKind, videoCodec, mp3Title, mp3Artist, mp3Album, mp3Year, mp3Comment;
    uint videoWidth, videoHeight, videoFPS, videoRate, mp3TrackNumber, mp3Genre;

}

