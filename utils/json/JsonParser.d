/*******************************************************************************

        Copyright: Copyright (C) 2009 Moritz Warning
                   All rights reserved

        License:   BSD style: $(LICENSE)

        version:   January 2009: Initial release

        Authors:   mwarning

*******************************************************************************/

module utils.json.JsonParser;

private import utils.json.JsonBuilder;


/*******************************************************************************

        Parse JSON formatted text into a data structure.
    Typical usage is as follows:
        ---
        auto p = new JsonParser!();
        auto v = p.parseObject (`{"t": true, "n":null, "array":["world", [4, 5]]}`);    
        ---
    
    Converting back to text format employs a delegate:
        ---
        v.print ((char[] s) {Stdout(s);}); 
        ---

*******************************************************************************/

final class JsonParser(Builder = JsonBuilder!(), bool allow_comments = false, bool single_quotes = false, bool validate = true)
{
    alias Builder.JsonObject JsonObject;
    alias Builder.JsonArray JsonArray;
    alias Builder.JsonValue JsonValue;
    alias Builder.JsonNumber JsonNumber;
    alias Builder.JsonString JsonString;
    alias Builder.JsonBool JsonBool;
    alias Builder.JsonNull JsonNull;
    
    private
    {
        char* ptr;
        char* beg;
        char* end;
        Builder build;
        
        static const char string_delimiter = single_quotes ? '\'' : '"';
    }
    
    /*******************************************************************************

        Reset any references to given JSON text.

    *******************************************************************************/
    
    public void reset()
    {
        beg = null;
        ptr = null;
        end = null;
    }
    
    private R parse(R, char start_char, char end_char, alias func)(char[] json)
    {
        if(json.length == 0)
        {
            throw new Exception("JsonParser: Input is empty.");
        }
        
        beg = json.ptr;
        ptr = json.ptr;
        end = json.ptr + json.length - 1;
    
        while(ptr < end && *end <= 32) --end;
        
        /*
        * Check for object/array/comment end so we can omit
        * out of bounds checking for whitespaces, numbers, boolean and null values.
        */
        char c = *end;
        if(c != end_char && c != '/')
        {
            ptr = end;
            throw new Exception("JsonParser: Invalid JSON input. Unexpected non-white character at input end.");
        }
        
        skip();
        
        if(*ptr is start_char)
        {
            return func();
        }
        else
        {
            throw new Exception("JsonParser: '" ~ [start_char] ~ "' expected.");
        }
    }
    
        /***********************************************************************
        
                Parse the given text and return a resultant JsonObject type 

        ***********************************************************************/
    
    public JsonObject parseObject(char[] json)
    {
        return parse!(JsonObject, '{', '}', parseObject)(json);
    }
    
    /***********************************************************************
        
                Parse the given text and return a resultant JsonArray type 

        ***********************************************************************/
    
    public JsonArray parseArray(char[] json)
    {
        return parse!(JsonArray, '[', ']', parseArray)(json);
    }
    
    /***********************************************************************
    
        Get position of last consumed character.
    
        ***********************************************************************/
    
    public size_t pos()
    {
        return ptr - beg;
    }
    
    /***********************************************************************
    
        Skip whitespaces (and comments).
    
        ***********************************************************************/
    
    private void skip()
    {
        while(*ptr <= 32) ++ptr;

        static if(allow_comments)
        {
            while(*ptr == '/' && skipComment())
            {
                while(*ptr <= 32) ++ptr;
            }
        }
    }
    
    /***********************************************************************
    
        Skip single-line and multi-line comments.
    
        ***********************************************************************/
    
    private bool skipComment()
    {
        assert(*ptr == '/');
        ++ptr;
        
        //skip multi-line comment "/*" ... "*/"
        if(*ptr == '*')
        {
            ++ptr;
            while(ptr < end)
            {
                if(*ptr == '*' && *(ptr+1) == '/')
                {
                    ptr += 2;
                    return true;
                }
                ++ptr;
            }
            throw new Exception("JsonParser: '*/' expected at input end.");
        }
    
        //skip line comment "//" ... ["\n"]
        if(*ptr == '/')
        {
            ++ptr;
            while(ptr <= end)
            {
                if(*ptr == '\n')
                {
                    ++ptr;
                    return true;
                }
                ++ptr;
            }
            
            //line comment may end with input end
            return true;
        }
        
        throw new Exception("JsonParser: Comment begin expected.");
    }
    
    /***********************************************************************
    
        Parse a JSON value.
    
        ***********************************************************************/
    
    private JsonValue parseValue()
    {
        if(ptr > end)
        {
            throw new Exception("JsonParser: Value expected.");
        }
        
        char c = *ptr;
        
        if(c == string_delimiter)
            return cast(JsonValue) parseString();
        
        if(c == '{')
            return cast(JsonValue) parseObject();
        
        if(c == '[')
            return cast(JsonValue) parseArray();
        
        if((c >= '0' && c <= '9') || c == '-')
            return cast(JsonValue) parseNumber();
        
        if(c == 'f')
            return matchFalse();
        
        if(c == 't')
            return matchTrue();
        
        if(c == 'n')
            return matchNull();
        
        throw new Exception("JsonParser: JSON element expected.");
    }
    
    /***********************************************************************
    
        Parse a JSON null.
    
        ***********************************************************************/
    
    private JsonValue matchNull()
        {
        assert(*ptr == 'n');
        static if(validate)
            if(*(cast(char[4]*) ptr) != "null")
        {
            throw new Exception("JsonParser: 'null' expected.");
        }
        ptr += 4;
        
        return cast(JsonValue) new JsonNull();
        }
    
    /***********************************************************************
    
        Parse a JSON true.
    
        ***********************************************************************/
    
    private JsonValue matchTrue()
        {
        assert(*ptr == 't');
        
        static if(validate)
            if(*(cast(char[4]*) ptr) != "true")
        {
            throw new Exception("JsonParser: 'true' expected.");
        }
        ptr += 4;
        
        return cast(JsonValue) new JsonBool(true);
        }
    
    /***********************************************************************
    
        Parse a JSON false.
    
        ***********************************************************************/
    
    private JsonValue matchFalse()
        {
        assert(*ptr == 'f');
        ++ptr;
        
        static if(validate)
            if(*(cast(char[4]*) ptr) != "alse") // without leading 'f'!
        {
            throw new Exception("JsonParser: 'false' expected.");
        }
        ptr += 4;
        
        return cast(JsonValue) new JsonBool(false);
        }
    
    /***********************************************************************
    
        Parse a JSON number.
    
        ***********************************************************************/
    
    private JsonNumber parseNumber()
    {
        assert((*ptr >= '0' && *ptr <= '9') || *ptr == '-');
        
        auto p = ptr;
        ptr = consumeNumber(ptr);

        return new JsonNumber( p[0..ptr-p] );
    }
    
    /***********************************************************************
    
        Consume a JSON formatted number.
        The sequence must end with a char that is not in JSON number.
        Validation is computational cheap.
    
        ***********************************************************************/
    
    private static char* consumeNumber(char* p)
    {
        assert((*p >= '0' && *p <= '9') || *p == '-');
        
        static char* digitsPlus(char* p)
        {
            if(*p < '0' || *p > '9')
            {
                throw new Exception("JsonParser: At least one digit in number expected.");
            }
            
            ++p;
            
            while(true)
            {
                if(*p < '0' || *p > '9')
                {
                    return p;
                }
                ++p;
            }
        }
        
        if(*p == '-')
        {
            ++p;
        }
        
        if(*p == '0')
        {
            ++p;
        }
        else
        {
            p = digitsPlus(p);
        }
        
        if(*p == '.')
        {
            ++p;
            p = digitsPlus(p);
        }
        
        if(*p == 'e' || *p == 'E')
        {
            ++p;
        }
        else
        {
            return p;
        }
        
        if(*p == '+' || *p == '-')
        {
            ++p;
        }
        
        p = digitsPlus(p);
        
        return p;
    }
    
    /***********************************************************************
    
        Parse a JSON string.
    
        ***********************************************************************/
    
    private JsonString parseString()
    {
        assert(*ptr == string_delimiter);
    
        auto p = ptr + 1;
        ptr = consumeString!(string_delimiter)(ptr, end);
        if(ptr >= end)
        {
            throw new Exception("JsonParser: String expected.");
        }
        
        return new JsonString( p[0..(ptr++) - p] );
    }
    
    /***********************************************************************
    
        Consume a string that begins and ends with delimiter m.
        Escaped delimeters are allowed.
        No validation is done.
    
        ***********************************************************************/
    
    private static char* consumeString(char m)(char* p, char* end)
    {
        assert(*p == m);
        assert(p <= end);
        
        static int isEscaped(char* ptr)
        {
            size_t i = 0; 
            while (*--ptr == '\\')
            {
                   ++i;
            }
            return i & 1;
        }
        
        ///fast linear search
        static char* next(char* p, char* end, char m)
        {
            auto len = end - p;
        
            //partially unrolled loop
            while(len >= 8)
            {
                if(*++p == m) return p;
                if(*++p == m) return p;
                if(*++p == m) return p;
                if(*++p == m) return p;
                if(*++p == m) return p;
                if(*++p == m) return p;
                if(*++p == m) return p;
                if(*++p == m) return p;
                
                len -= 8;
            }
            
            while(p < end)
            {
                if(*++p == m) return p;
            }
            
            assert(p == end);
            return p;
        }
        
        do
        {
            p = next(p, end, m);
        }
        while(isEscaped(p))
        
        assert(*p == m || p == end);
        return p;
    }
    
    /***********************************************************************
    
        Parse a JSON Array.
    
        ***********************************************************************/
    
    private JsonArray parseArray()
    {
        assert(*ptr == '[');
        ++ptr;
        
        auto array = new JsonArray();
        JsonValue value = void;
        
        skip();
        
        if(*ptr == ']')
        {
            ++ptr;
            return array;
        }
        
        while(true)
        {
            value = parseValue();
            array.opCatAssign(value);
            
            if(ptr > end)
            {
                throw new Exception("JsonParser: Unexpected end of input in array.");
            }
            
            skip();
            
            if(*ptr == ']')
            {
                ++ptr;
                return array;
            }
            
            if(*ptr == ',')
            {
                ++ptr;
                skip();
            }
            else
            {
                throw new Exception("JsonParser: ',' expected in array. ");
            }
        }
    }
    
    /***********************************************************************
    
        Parse a JSON Object.
    
        ***********************************************************************/
    
    private JsonObject parseObject()
    {
        assert(*ptr == '{');
        ++ptr;
        
        skip();
    
        auto object = new JsonObject();
        
        JsonString key = void;
        JsonValue value = void;
        
        if(*ptr == '}')
        {
            ++ptr;
            return object;
        }
        
        while(true)
        {
            if(*ptr == string_delimiter)
            {
                key = parseString();
            }
            else
            {
                throw new Exception("JsonParser: String expected in object.");
            }
            
            skip();
            
            if(*ptr == ':')
            {
                ++ptr;
                skip();
            }
            else
            {
                throw new Exception("JsonParser: ':' expected in object.");
            }
            
            value = parseValue();
            
            if(ptr > end)
            {
                throw new Exception("JsonParser: Unexpected end of input in object.");
            }
            
            object.opIndexAssign(value, key);
            
            skip();
            
            if(*ptr == '}')
            {
                ++ptr;
                return object;
            }
            
            if(*ptr == ',')
            {
                ++ptr;
                skip();
            }
            else
            {
                throw new Exception("JsonParser: ',' expected in object. ");
            }
        }
    }
}


debug(JsonParser)
{
    import tango.io.Stdout;
    import tango.io.device.File;
    import tango.time.StopWatch;
    
    import utils.json.JsonBuilder;
    
    struct StaticAllocator
    {
        private static
        {
            size_t index;
            ubyte[1024] array;
        }

        static void reset()
        {
            index = 0;
        }

        static T* malloc(T)()
        {
            return cast(T*) GC.malloc(T.sizeof);
        }
        
        static void* malloc()(size_t size)
        {
            auto ptr = cast(void*) &array[index];
            index += size;

            if(index > array.length)
            {
                index -= size;
                throw new Exception("StaticAllocator: Fixed memory exhausted.");
            }
            
            return ptr;
        }
    }
    
    void main()
    {
        auto pa = new JsonParser!(JsonBuilder!(StaticAllocator));
        
        char[] txt = `{"t": true, "f":false, "n":null, "hi":["world", "big", 123, [4, 5, ["foo", "bar"]]]}`;
        
        uint n = 1_000_000;
        
        StopWatch watch;
        watch.start();
        
        for(auto i = 0; i < n; ++i)
        {
            pa.parse(txt);
            StaticAllocator.reset();
        }
        
        auto t = watch.stop();
        auto mb = (txt.length * n) / (1024 * 1024);
        Stdout.formatln("{} iterations, {} seconds: {} MB/s", n, t, mb / t);
    }

    unittest
    {
        auto pa = new JsonParser!(JsonBuilder!(GCAllocator));
        
        char[][] must_raise = [null, ``, ` `, `  `, `{"`, `{ "\`, `{ "a" : 12`, `{"`, `{ "\`, `{ "a" : "\"}`, `{ "a" : `];
        
        char[][] must_pass = [`{}`, `{ }`, `{ "a":{"a" : 0.1e23, "b" : [true, false, null]}}`];

        foreach(i, txt; must_raise)
        {
            try
            {
                auto root = pa.parseObject(txt);
                Stdout("JsonParser: Test ")(i)(" should not have been accepted: ")(txt).newline;
                assert(0);
            }
            catch(Exception e)
            {
            }
        }

        foreach(i, txt; must_pass)
        {
            try
            {
                auto root = pa.parseObject(txt);
            }
            catch(Exception e)
            {
                Stdout("JsonParser: Test ")(i)(" should have been accepted: ")(txt)("\n")(e.toString).newline;
                assert(0);
            }
        }
    }
}
