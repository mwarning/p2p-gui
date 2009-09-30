module utils.GeoIP;

/*
* Read a GeoIP-Lite database from maxmind.com.
* The code from the GeoIP class was ported from GeoIPJava-1.2.2
* (GNU Lesser General Public licencse).
*/

import tango.io.Stdout;
import tango.io.device.File;
import tango.io.FilePath;

static import Utils = utils.Utils;
import webcore.Logger;


/*
* Get country code by IP.
*/
char[] getCountryCode(uint ip)
{
    return getCountryCode(cast(ulong) ip);
}

char[] getCountryCode(ulong ip)
{
    if(shared) try
    {
        auto id = shared.getID(ip);
        return GeoIP.country_codes[id];
    }
    catch(Exception e)
    {
        Logger.addError("GeoIP: " ~ e.toString);
    }
    
    return GeoIP.country_codes[0];
}

/*
* Get country code by geo id.
*/
char[] getCountryCode(ubyte id)
{
    if(id >= GeoIP.country_codes.length)
    {
        id = 0;
    }
    return GeoIP.country_codes[id];
}

/*
* Get country code by ip string (such as "127.0.0.1").
*/
char[] getCountryCode(char[] ip_string)
{
    ulong ip = Utils.toIpNum(ip_string);
    return getCountryCode(ip);
}

private GeoIP shared;

/*
* Load a database file from maxmind.com (e.g. GeoIP.dat)
*/
void loadDatabase(char[] file_path)
{
    try
    {
        shared = new GeoIP(file_path);
    }
    catch(Exception e)
    {
        Logger.addWarning("GeoIP: Cannot open database. " ~ e.toString);
        return;
    }
    
    Logger.addInfo("GeoIP: Load database '{}'.", file_path);
}


private:

/*
* Changes from the original (GeoIPJava-1.2.2/source/maxmind/geoip/LookupService.java) version:
* - only getID(long), init(), seekCountry(long) and _check_mtime() were ported
* - variable called databaseFile was removed (needed?)
* - databaseSegments was changed from int[] to int;
*    only the first element was used anway
*/
class GeoIP
{
    enum DatabaseInfo : int
    {
        COUNTRY_EDITION = 1,
        REGION_EDITION_REV0 = 7,
        REGION_EDITION_REV1 = 3,
        CITY_EDITION_REV0 = 6,
        CITY_EDITION_REV1 = 2,
        ORG_EDITION = 5,
        ISP_EDITION = 4,
        PROXY_EDITION = 8,
        ASNUM_EDITION = 9,
        NETSPEED_EDITION = 10
    }
    
    enum : int
    {
        US_OFFSET = 1,
        CANADA_OFFSET = 677,
        WORLD_OFFSET = 1353,
        FIPS_RANGE = 360,
        COUNTRY_BEGIN = 16776960,
        STATE_BEGIN_REV0 = 16700000,
        STATE_BEGIN_REV1 = 16000000,
        STRUCTURE_INFO_MAX_SIZE = 20,
        DATABASE_INFO_MAX_SIZE = 100,
        GEOIP_STANDARD = 0,
        GEOIP_MEMORY_CACHE = 1,
        GEOIP_CHECK_CACHE = 2,
        GEOIP_INDEX_CACHE = 4,
        GEOIP_UNKNOWN_SPEED = 0,
        GEOIP_DIALUP_SPEED = 1,
        GEOIP_CABLEDSL_SPEED = 2,
        GEOIP_CORPORATE_SPEED = 3,

        SEGMENT_RECORD_LENGTH = 3,
        STANDARD_RECORD_LENGTH = 3,
        ORG_RECORD_LENGTH = 4,
        MAX_RECORD_LENGTH = 4,

        MAX_ORG_RECORD_LENGTH = 300,
        FULL_RECORD_LENGTH = 60
    }
    
    static const char[2][253] country_codes =
    [
        "--","AP","EU","AD","AE","AF","AG","AI","AL","AM","AN","AO","AQ","AR",
        "AS","AT","AU","AW","AZ","BA","BB","BD","BE","BF","BG","BH","BI","BJ",
        "BM","BN","BO","BR","BS","BT","BV","BW","BY","BZ","CA","CC","CD","CF",
        "CG","CH","CI","CK","CL","CM","CN","CO","CR","CU","CV","CX","CY","CZ",
        "DE","DJ","DK","DM","DO","DZ","EC","EE","EG","EH","ER","ES","ET","FI",
        "FJ","FK","FM","FO","FR","FX","GA","GB","GD","GE","GF","GH","GI","GL",
        "GM","GN","GP","GQ","GR","GS","GT","GU","GW","GY","HK","HM","HN","HR",
        "HT","HU","ID","IE","IL","IN","IO","IQ","IR","IS","IT","JM","JO","JP",
        "KE","KG","KH","KI","KM","KN","KP","KR","KW","KY","KZ","LA","LB","LC",
        "LI","LK","LR","LS","LT","LU","LV","LY","MA","MC","MD","MG","MH","MK",
        "ML","MM","MN","MO","MP","MQ","MR","MS","MT","MU","MV","MW","MX","MY",
        "MZ","NA","NC","NE","NF","NG","NI","NL","NO","NP","NR","NU","NZ","OM",
        "PA","PE","PF","PG","PH","PK","PL","PM","PN","PR","PS","PT","PW","PY",
        "QA","RE","RO","RU","RW","SA","SB","SC","SD","SE","SG","SH","SI","SJ",
        "SK","SL","SM","SN","SO","SR","ST","SV","SY","SZ","TC","TD","TF","TG",
        "TH","TJ","TK","TM","TN","TO","TL","TR","TT","TV","TW","TZ","UA","UG",
        "UM","US","UY","UZ","VA","VC","VE","VG","VI","VN","VU","WF","WS","YE",
        "YT","RS","ZA","ZM","ME","ZW","A1","A2","O1","AX","GG","IM","JE","BL",
        "MF"
    ];

    private
    {
        /**
        * The database type. Default is the country edition.
        */
        byte databaseType = DatabaseInfo.COUNTRY_EDITION;

        int databaseSegments;
        int recordLength;

        int dboptions = GEOIP_MEMORY_CACHE;
        byte dbbuffer[];
        byte index_cache[];
        long mtime;

        File file;
        char[] path;
    }
    
    this(char[] db_path = "GeoIP.dat")
    {
        path = db_path;
        file = new File(db_path);
        init();
    }
    
    ~this()
    {
        close();
    }

    uint getID(long ipAddress)
    {
        if (file is null && (dboptions & GEOIP_MEMORY_CACHE) == 0)
        {
            throw new Exception("Database has been closed.");
        }
        return seekCountry(ipAddress) - databaseSegments;
    }
    
private:
    
    /*
    * Closes the lookup service.
    */
    void close()
    {
        try
        {
            if (file)
            {
                file.close();
            }
            file = null;
        }
        catch (Exception e) { }
    }

    void init()
    {
        int i, j;
        byte[3] delim;
        byte[SEGMENT_RECORD_LENGTH] buf;
        
        /*
        if (file == null) {
            // distributed service only
            for (i = 0; i < 233;i++){
            hashmapcountryCodetoindex.put(countryCode[i],new Integer(i));
            hashmapcountryNametoindex.put(countryName[i],new Integer(i));
            }
            return;
        }*/
        
        if ((dboptions & GEOIP_CHECK_CACHE) != 0)
        {
            mtime = FilePath(path).modified.ticks;
        }
        
        file.seek(file.length() - 3);
        for (i = 0; i < STRUCTURE_INFO_MAX_SIZE; i++)
        {
            file.read(delim);
            
            if (delim[0] == -1 && delim[1] == -1 && delim[2] == -1) 
            {
                file.read(delim[0..1]);
                databaseType = delim[0];
                
                if (databaseType >= 106)
                {
                    // Backward compatibility with databases from April 2003 and earlier
                    databaseType -= 105;
                }
                // Determine the database type.
                if (databaseType == DatabaseInfo.REGION_EDITION_REV0)
                {
                    databaseSegments = STATE_BEGIN_REV0;
                    recordLength = STANDARD_RECORD_LENGTH;
                }
                else if (databaseType == DatabaseInfo.REGION_EDITION_REV1)
                {
                    databaseSegments = STATE_BEGIN_REV1;
                    recordLength = STANDARD_RECORD_LENGTH;
                }
                else if (databaseType == DatabaseInfo.CITY_EDITION_REV0 ||
                    databaseType == DatabaseInfo.CITY_EDITION_REV1 ||
                    databaseType == DatabaseInfo.ORG_EDITION ||
                    databaseType == DatabaseInfo.ISP_EDITION ||
                    databaseType == DatabaseInfo.ASNUM_EDITION)
                {
                    databaseSegments = 0;
                    if (databaseType == DatabaseInfo.CITY_EDITION_REV0 ||
                        databaseType == DatabaseInfo.CITY_EDITION_REV1 ||
                        databaseType == DatabaseInfo.ASNUM_EDITION)
                    {
                        recordLength = STANDARD_RECORD_LENGTH;
                    }
                    else
                    {
                        recordLength = ORG_RECORD_LENGTH;
                    }
                    file.read(buf);
                    for (j = 0; j < SEGMENT_RECORD_LENGTH; j++)
                    {
                        databaseSegments += (unsignedByteToInt( buf[j]) << (j * 8));
                    }
                }
                break;
            }
            else
            {
                file.seek(file.position - 4);
            }
        }
        
        if ((databaseType == DatabaseInfo.COUNTRY_EDITION) |
            (databaseType == DatabaseInfo.PROXY_EDITION) |
            (databaseType == DatabaseInfo.NETSPEED_EDITION))
        {
            databaseSegments = COUNTRY_BEGIN;
            recordLength = STANDARD_RECORD_LENGTH;
        }
        
        if ((dboptions & GEOIP_MEMORY_CACHE) == 1)
        {
            int l = cast(int) file.length();
            dbbuffer = new byte[l];
            file.seek(0);
            file.read(dbbuffer);
            file.close();
        }
        
        if ((dboptions & GEOIP_INDEX_CACHE) != 0)
        {
            int l = databaseSegments * recordLength * 2;
            index_cache = new byte[l];
            if (index_cache != null)
            {
                file.seek(0);
                file.read(index_cache);   
            }
        }
        else
        {
            index_cache = null;
        }
    }

    synchronized void _check_mtime()
    {
        if ((dboptions & GEOIP_CHECK_CACHE) != 0)
        {
            long t = FilePath(path).modified.ticks;
            if (t != mtime)
            {
                /* GeoIP Database file updated */
                /* refresh filehandle */
                try
                {
                    file.close();
                    file = new File(path);
                    init();
                }
                catch (Exception e)
                {
                    Logger.addError("GeoIP: " ~ e.toString);
                }
            }
        }
    }

    synchronized int seekCountry(long ipAddress)
    {
        byte[] buf = new byte[2 * MAX_RECORD_LENGTH];
        int[] x = new int[2];
        int offset = 0;
        _check_mtime();
        for (int depth = 31; depth >= 0; depth--)
        {
            if ((dboptions & GEOIP_MEMORY_CACHE) == 1)
            {
                //read from memory
                for (int i = 0; i < 2 * MAX_RECORD_LENGTH; i++)
                {
                    buf[i] = dbbuffer[(2 * recordLength * offset) + i];
                }
            }
            else if ((dboptions & GEOIP_INDEX_CACHE) != 0)
            {
                //read from index cache
                for (int i = 0; i < 2 * MAX_RECORD_LENGTH; i++)
                {
                    buf[i] = index_cache[(2 * recordLength * offset) + i];
                }
            }
            else
            {
                //read from disk 
                try
                {
                    file.seek(2 * recordLength * offset);
                    file.read(buf);
                }
                catch (Exception e)
                {
                    Logger.addError("GeoIP: " ~ e.toString);
                    file = null;
                }
            }
            
            for (int i = 0; i < 2; i++) 
            {
                x[i] = 0;
                for (int j = 0; j < recordLength; j++)
                {
                    int y = buf[i * recordLength + j];
                    if (y < 0)
                    {
                        y += 256;
                    }
                    x[i] += (y << (j * 8));
                }
            }

            if ((ipAddress & (1 << depth)) > 0)
            {
                if (x[1] >= databaseSegments)
                {
                    return x[1];
                }
                offset = x[1];
            }
            else
            {
                if (x[0] >= databaseSegments)
                {
                    return x[0];
                }
                offset = x[0];
            }
        }

        // shouldn't reach here
        Logger.addError("GeoIP: seeking country while seeking: {}", Utils.toIpString(cast(uint) ipAddress));
        return 0;
    }
    
    static int unsignedByteToInt(byte b)
    {
        return cast(int) b & 0xFF;
    }
}
