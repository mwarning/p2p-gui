/*******************************************************************************

        Copyright: Copyright (C) 2009 Moritz Warning
                   All rights reserved

        License:   BSD style: $(LICENSE)

        version:   January 2009: Initial release

        Authors:   mwarning

*******************************************************************************/

module utils.json.JsonBuilder;

private import JsonEscape = tango.text.json.JsonEscape;

private import Float = tango.text.convert.Float;

private import Integer = tango.text.convert.Integer;

private import tango.core.Traits;

public import utils.json.JsonAdditional;


/*******************************************************************************

    Build and print JSON structures.
    Typical usage is as follows:
        ---
    alias JsonBuilder!().JsonObject JsonObject;

    auto obj = new JsonObject();
    obj["value"] = "abc";
    obj["number"] = 12.3;
    
    obj.print((char[] s){ Stdout(s); });
        ---

*******************************************************************************/

enum JsonType { Null, Bool, Number, String, Array, Object }

struct JsonBuilder(C = char, alias Allocator = GCAllocator, alias ArrayContainer = LinkedList, alias ObjectContainer = LinkedPairList)
{
    Allocator allocator;
    
    struct JsonValue
    {
        private Object inst = null;
        
        /*******************************************************************************

            Access wrapped instance.
            For null checks or casting.

        *******************************************************************************/
        
        Object ptr()
        {
            return inst;
        }
        
        JsonObject toJsonObject()
        {
            return cast(JsonObject) inst;
        }
        
        JsonArray toJsonArray()
        {
            return cast(JsonArray) inst;
        }
        
        JsonString toJsonString()
        {
            return cast(JsonString) inst;
        }
        
        JsonNumber toJsonNumber()
        {
            return cast(JsonNumber) inst;
        }
        
        JsonBool toJsonBool()
        {
            return cast(JsonBool) inst;
        }
        
        JsonNull toJsonNull()
        {
            return cast(JsonNull) inst;
        }
        
        JsonType type()
        {
            if(cast(JsonObject) inst)
                return JsonType.Object;
            
            if(cast(JsonArray) inst)
                return JsonType.Array;
            
            if(cast(JsonString) inst)
                return JsonType.String;
            
            if(cast(JsonNumber) inst)
                return JsonType.Number;
            
            if(cast(JsonBool) inst)
                return JsonType.Bool;
            
            if(cast(JsonNull) inst)
                return JsonType.Null;
            
            assert(0);
        }
        
        /*******************************************************************************

            Add a single element by index if wrapped instance is a JsonArray.
            Does nothing otherwise.

        *******************************************************************************/
        
        void opIndexAssign(T)(T value, int index)
        {
            if(auto array = cast(JsonArray) inst)
            {
                array[index] = value;
            }
        }
        
        /*******************************************************************************

            Retrieve a single element by index if wrapped instance is a JsonArray.
            Returns an empty element otherwise or if index doesn't exist.

        *******************************************************************************/
        
        JsonValue opIndex(size_t index)
        {
            auto array = cast(JsonArray) inst;
            return array ? array.opIndex(index) : JsonValue.init;
        }
        
        /*******************************************************************************

            Add a single element if wrapped instance is a JsonArray.
            Does nothing otherwise.

        *******************************************************************************/
        
        void opCatAssign(T)(T value)
        {
            auto array = cast(JsonArray) inst;
            if(array) array.opCatAssign(value);
        }

        /*******************************************************************************

            Iterate over this if it is JsonObject.
            Does nothing otherwise.

        *******************************************************************************/
        
        int opApply(int delegate(ref char[] key, ref JsonValue value) dg)
        {
            auto object = cast(JsonObject) inst;
            return object ? object.opApply(dg) : 0;
        }
        
        /*******************************************************************************

            Iterate over this if it is JsonArray.
            Does nothing otherwise.

        *******************************************************************************/
        
        int opApply(int delegate(ref size_t key, ref JsonValue value) dg)
        {
            auto array = cast(JsonArray) inst;
            return array ? array.opApply(dg) : 0;
        }

        /*******************************************************************************

            Iterate over this if it is a JsonObject or JsonArray.
            Does nothing otherwise.

        *******************************************************************************/
        
        int opApply(int delegate(ref JsonValue value) dg)
        {
            if(auto object = cast(JsonObject) inst)
                return object.opApply(dg);
            if(auto array = cast(JsonArray) inst)
                return array.opApply(dg);
            return 0;
        }
        
        /*******************************************************************************

            Add a value if wrapped instance is a JsonObject
            Does nothing otherwise.

        *******************************************************************************/

        void opIndexAssign(T)(T value, char[] key)
        {
            auto object = cast(JsonObject) inst;
            if(object) object.opIndexAssign(value, key);
        }
        
        /*******************************************************************************

            Retrieve an element by key if wrapped instance is a JsonObject.
            Returns an empty element otherwise or if key doesn't exists.

        *******************************************************************************/
        
        JsonValue opIndex(char[] key)
        {
            auto object = cast(JsonObject) inst;
            return object ? object.opIndex(key) : JsonValue.init;
        }

        /*******************************************************************************

            Iterate over this if it is JsonObject.
            Does nothing otherwise.

        *******************************************************************************/
        
        int opApply(int delegate(ref JsonString key, ref JsonValue value) dg)
        {
            auto object = cast(JsonObject) inst;
            return object ? object.opApply(dg) : 0;
        }
        
        /*******************************************************************************

            Convert a value to a JSON type an assign it.

        *******************************************************************************/

        void opAssign(T)(T value)
        {
            inst = toJson(value).inst;
        }

        /*******************************************************************************

            Get a string if this is JsonString.
            Otherwise return null.

        *******************************************************************************/
        
        char[] toString()
        {
            auto string = cast(JsonString) inst;
            return string ? string.toString() : null;
        }
        
        /*******************************************************************************

            Get a long if this is JsonNumber.
            Otherwise return 0.

        *******************************************************************************/
        
        long toInteger()
        {
            auto number = cast(JsonNumber) inst;
            return number ? number.toInteger() : 0;
        }
        
        /*******************************************************************************

            Get a float if this is JsonNumber.
            Otherwise return 0.0.

        *******************************************************************************/
        
        double toFloat()
        {
            auto number = cast(JsonNumber) inst;
            return number ? number.toFloat() : 0.0;
        }
        
        /*******************************************************************************

            Get a bool if this is JsonBool.
            Otherwise return false.

        *******************************************************************************/
        
        bool toBool()
        {
            auto b = cast(JsonBool) inst;
            return b ? b.toBool() : false;
        }
        
        int opEquals(char[] value)
        {
            auto string = cast(JsonString) inst;
            return string ? string.opEquals(value) : 0;
        }
        
        int opEquals(double value)
        {
            auto number = cast(JsonNumber) inst;
            return number ? number.opEquals(value) : 0;
        }
        
        int opEquals(bool value)
        {
            auto b = cast(JsonBool) inst;
            return b ? b.opEquals(value) : 0;
        }
        
        int opEquals(JsonValue e)
        {
            if(auto object = cast(JsonObject) inst)
                return object.opEquals(e);
            
            if(auto array = cast(JsonArray) inst)
                return array.opEquals(e);
            
            if(auto string = cast(JsonString) inst)
                return string.opEquals(e);
            
            if(auto number = cast(JsonNumber) inst)
                return number.opEquals(e);
            
            if(auto bool_ = cast(JsonBool) inst)
                return bool_.opEquals(e);
            
            if(auto null_ = cast(JsonNull) inst)
                return null_.opEquals(e);
            
            assert(0);
        }
        
        /*******************************************************************************

            Convert instance to given value type.
            Throws exception if not possible.

        *******************************************************************************/
        
        T to(T)()
        {
            return fromJson!(T)(*this);
        }
    }

    final class JsonNull
    {
        new(size_t size)
        {
            return allocator.malloc(size);
        }
        
        this()
        {
        }
        
        JsonValue opCast()
        {
            return JsonValue(this);
        }

        JsonType type() { return JsonType.Null; }
        
        int opEquals(JsonNull e)
        {
            return 1;
        }
        
        int opEquals(JsonValue e)
        {
            auto v = cast(JsonNull) e.inst;
            return v ? opEquals(v) : 0;
        }
        
        char[] toString()
        {
            return "null";
        }
    }

    final class JsonBool
    {
        private bool value;
        
        this(bool value)
        {
            this.value = value;
        }
        
        /*******************************************************************************

            Create an instance with "true" or "false".

        *******************************************************************************/
        
        this(char[] value)
        {
            if(value == "true")
            {
                this.value = true;
            }
            else if(value == "false")
            {
                this.value = false;
            }
            else throw new Exception("JsonBool: 'true' or 'false' expected for constructor.");
        }
        
        new(size_t size)
        {
            return allocator.malloc(size);
        }
        
        JsonValue opCast()
        {
            return JsonValue(this);
        }
        
        JsonType type() { return JsonType.Bool; }
        
        int opEquals(bool value)
        {
            return cast(int) (this.value == value);
        }
        
        int opEquals(JsonBool e)
        {
            return cast(int) (this.value == e.value);
        }
        
        int opEquals(JsonValue e)
        {
            auto v = cast(JsonBool) e.inst;
            return v ? opEquals(v) : 0;
        }
        
        bool toBool()
        {
            return value;
        }
        
        char[] toString()
        {
            return value ? "true" : "false";
        }
    }

    final class JsonNumber
    {
        private char[] value;
        
        this(double value)
        {
            opAssign(value);
        }
        
        /*******************************************************************************

            Create an instance with an value JSON formated numeral string.

        *******************************************************************************/
        
        this(char[] value)
        {
            //assert(isNumber(value));
            this.value = value;
        }
        
        new(size_t size)
        {
            return allocator.malloc(size);
        }
        
        JsonValue opCast()
        {
            return JsonValue(this);
        }
        
        JsonType type() { return JsonType.Number; }
        
        void opAssign(double value)
        {
            this.value = Float.truncate (
                Float.toString(value)
            );
        }
        
        long toInteger()
        {
            return Integer.parse(value);
        }
        
        double toFloat()
        {
            return cast(double) Float.parse(value);
        }
        
        char[] toString()
        {
            return value.dup;
        }
        
        char[] slice()
        {
            return value;
        }
        
        int opEquals(char[] value)
        {
            return cast(int) (Float.truncate(value) == this.value);
        }
        
        int opEquals(long value)
        {
            return cast(int) (value == this.toInteger);
        }
    
        int opEquals(double value)
        {
            return cast(int) (value == this.toFloat);
        }
        
        int opEquals(JsonValue e)
        {
            auto v = cast(JsonNumber) e.inst;
            return v ? opEquals(v) : 0;
        }
        
        int opEquals(JsonNumber e)
        {
            return opEquals(e.value);
        }
    }

    final class JsonString 
    {
        private char[] value;
        
        /*******************************************************************************

            Create an instance with an JSON formatted (=escaped) string.

        *******************************************************************************/
        
        this(char[] value)
        {
            this.value = value;
        }
        
        //value is assumed to be escaped
        this(char[] value, bool escaped)
        {
            if(escaped)
            {
                this.value = value;
            }
            else
            {
                this.value = JsonEscape.escape(value);
            }
        }
        
        new(size_t size)
        {
            return allocator.malloc(size);
        }
        
        JsonValue opCast()
        {
            return JsonValue(this);
        }
        
        JsonType type() { return JsonType.String; }
        
        /*******************************************************************************

            Assign an escaped string.

        *******************************************************************************/
    
        void opAssign(char[] value)
        {
            //assert(isValidUtf8String(value));
            this.value = value;
        }

        char[] slice()
        {
            return value;
        }
        
        char[] toString(bool unescape = true)
        {
            if(unescape)
            {
                char[] str = JsonEscape.unescape(value);
                return (str.ptr == value.ptr) ? str.dup : str;
            }
            else
            {
                return value.dup;
            }
        }
        
        /*******************************************************************************

            Compare to an unescaped string.
            No heap usage.

        *******************************************************************************/
        
        int opEquals(char[] value)
        {
            bool eq = true;
            auto chunk_cmp = (char[] str)
            {
                auto min = str.length > value.length ? value.length : str.length;

                if(value[0..min] == str)
                {
                    value = value[min..$];
                }
                else
                {
                    eq = false;
                }
            };
            
            JsonEscape.unescape(this.value, chunk_cmp);
            return cast(int) eq;
        }
        
        int opEquals(JsonValue e)
        {
            auto v = cast(JsonString) e.inst;
            return v ? opEquals(v) : 0;
        }
        
        int opEquals(JsonString e)
        {
            return opEquals(e.value);
        }
    }

    final class JsonArray
    {
        private ArrayContainer!(JsonValue, Allocator) items;
        
        new(size_t size)
        {
            return allocator.malloc(size);
        }
        
        JsonValue opCast()
        {
            return JsonValue(this);
        }
        
        JsonType type() { return JsonType.Array; }
        
        void opAssign(JsonValue e)
        {
            auto array = cast(JsonArray) e.inst;
            if(array) this.items = array.items;
        }
        
        void opIndexAssign(T)(T value, int index)
        {
            JsonValue* v = (index in items);
            if(v) *v = toJson(value);
        }
        
        JsonValue opIndex(size_t index)
        {
            JsonValue* v = (index in items);
            return v ? *v : JsonValue.init;
        }
        
        void opCatAssign(T)(T value)
        {
            items.opCatAssign( toJson(value) );
        }
    
        int opApply(int delegate(ref size_t key, ref JsonValue value) dg)
        {
            return items.opApply(dg);
        }

        int opApply(int delegate(ref JsonValue value) dg)
        {
            return items.opApply(dg);
        }
    
        int opEquals(JsonValue e)
        {
            auto v = cast(JsonArray) e.inst;
            return v ? opEquals(v) : 0;
        }
        
        int opEquals(JsonArray array)
        {
            return array.items == array.items;
        }
        
        size_t length()
        {
            return items.length;
        }
        
        void print(void delegate(char[]) emit, bool formatted = true)
        {
            if(formatted)
                printFormatted(cast(JsonValue) this, emit);
            else
                printCompact(cast(JsonValue) this, emit);
        }
    }

    final class JsonObject
    {
        private ObjectContainer!(JsonString, JsonValue, Allocator) items;
        
        JsonValue opCast()
        {
            return JsonValue(this);
        }
        
        new(size_t size)
        {
            return allocator.malloc(size);
        }
        
        JsonType type() { return JsonType.Object; }
        
        void opAssign(JsonValue value)
        {
            auto object = cast(JsonObject) value.inst;
            if(object) this.items = object.items;
        }
        
        void opIndexAssign(T)(T value, char[] string_key)
        {
            auto key = new JsonString(string_key);
            opIndexAssign(value, key);
        }
        
        void opIndexAssign(T)(T value, JsonString key)
        {
            items.opIndexAssign(toJson(value), key);
        }
        
        JsonValue opIndex(char[] string_key)
        {
            scope key = new JsonString(string_key);
            return opIndex(key);
        }
        
        JsonValue opIndex(JsonString key)
        {
            auto p = (key in items);
            return p ? *p : JsonValue.init;
        }

        int opApply(int delegate(ref JsonValue value) dg)
        {
            return items.opApply(dg);
        }
        
        int opApply(int delegate(ref JsonString key, ref JsonValue value) dg)
        {
            return items.opApply(dg);
        }
        
        int opApply(int delegate(ref char[] key, ref JsonValue value) dg)
        {
            return items.opApply
            (
                (ref JsonString key, ref JsonValue value)
                {
                    char[] str = key.toString();
                    return dg(str, value);
                }
            );
        }
        
        int opEquals(JsonValue e)
        {
            auto v = cast(JsonObject) e.inst;
            return v ? opEquals(v) : 0;
        }
        
        int opEquals(JsonObject object)
        {
            return items == object.items;
        }
        
        size_t length()
        {
            return items.length;
        }
        
        void print(void delegate(char[]) emit, bool formatted = true)
        {
            if(formatted)
                printFormatted(cast(JsonValue) this, emit);
            else
                printCompact(cast(JsonValue) this, emit);
        }
    }
    
    static JsonValue toJson(T)(T value_)
    {
        //cast static arrays to dynamic arrays
        static if(isStaticArrayType!(T))
        {
            alias typeof(T.init) E;
            alias E[] S;
            auto value = cast(E[]) value_;
        }
        else
        {
            alias T S;
            auto value = value_;
        }
        
        static if(is(T == JsonValue))
        {
            auto v = value.ptr;
        }
        else static if( is(T == JsonNull) || is(T == JsonBool) || is(T == JsonNumber) ||
                is(T == JsonString) || is(T == JsonArray) || is(T == JsonObject) 
            )
        {
            auto v = value;
        }
        else static if(is(S == char[]))
        {
            auto v =  new JsonString(value);
        }
        else static if(is(S == bool))
        {
            auto v =  new JsonBool(value);
        }
        else static if(isIntegerType!(S))
        {
            auto v = new JsonNumber(cast(long) value);
        }
        else static if(isRealType!(S))
        {
            auto v = new JsonNumber(cast(double) value);
        }
        else static if(isDynamicArrayType!(S))
        {
            auto v = new JsonArray();
            for(auto i = 0; i < value.length; ++i)
            {
                auto e = toJson(value[i]);
                v.opCatAssign(e);
            }
        }
        else static if(isAssocArrayType!(S))
        {
            alias typeof(S.init.keys[0]) K;
            static assert(is(K == char[]), "toJson: Hash map key must be char[], not " ~ K.stringof);
            
            auto v = new JsonObject();
            foreach(key, val; value)
            {
                v.opIndexAssign(toJson(val), key);
            }
        }
        else
        {
            static assert(0, "toJson: Cannot convert " ~ T.stringof ~ " to any JsonValue data type.");
        }
        
        return JsonValue(*(cast(Object*) &v));
    }

    static T fromJson(T)(JsonValue value)
    {
        static if(is(T == JsonNull) || is(T == JsonBool) || is(T == JsonNumber) ||
            is(T == JsonString) || is(T == JsonArray) || is(T == JsonObject))
        {
            return cast(T) value.ptr;
        }
        else static if(is(T == char[]))
        {
            auto json_string = cast(JsonString) value.ptr;
            if(json_string is null)
                throw new Exception("JsonString expected");
            return json_string.toString();
        }
        else static if(is(T == bool))
        {
            auto json_bool = cast(JsonBool) value.ptr;
            if(json_bool is null)
                throw new Exception("JsonBool expected");
            return json_bool.toBool();
        }
        else static if(isIntegerType!(T))
        {
            auto json_number = cast(JsonNumber) value.ptr;
            if(json_number is null)
                throw new Exception("JsonNumber expected");
            return json_number.toInteger();
        }
        else static if(isRealType!(T))
        {
            auto json_number = cast(JsonNumber) value.ptr;
            if(json_number is null)
                throw new Exception("JsonNumber expected");
            return json_number.toFloat();
        }
        else static if(isAssocArrayType!(T))
        {
            alias typeof(T.init.keys[0]) K;
            alias typeof(T.init.values[0]) V;
            
            auto json_object = cast(JsonObject) value.ptr;
            if(json_object is null)
                throw new Exception("JsonObject expected.");
            
            V[K] aa;
            foreach(char[] key, JsonValue val; json_object)
            {
                aa[key] = fromJson!(V)(val);
            }
            return aa;
        }
        else static if(isDynamicArrayType!(T) || isStaticArrayType!(T))
        {
            alias typeof(T.init[0]) K;
            
            auto json_array = cast(JsonArray) value.ptr;
            if(json_array is null)
            {
                throw new Exception("JsonArray expected.");
            }
            
            T array;
            array.length = json_array.length;
            foreach(size_t i, JsonValue item; json_array)
            {
                array[i] = fromJson!(K)(item);
            }
            return array;
        }
        else
        {
            static assert(0 , "fromJson: Cannot convert from JsonValue to " ~ T.stringof ~ ".");
        }
    }
    
    
    /*
    * Write JSON data in a compact format with no white spaces.
    * Speed is everything.
    */
    private static void printCompact(JsonValue e, void delegate(char[]) emit)
    {
        assert(e.ptr !is null, "JsonBuilder: JsonValue contains null pointer.");

        if(auto string = e.toJsonString)
        {
            emit("\"");
            emit(string.slice);
            emit("\"");
        }
        else if(auto number = e.toJsonNumber)
        {
            emit(number.slice);
        }
        else if(auto array = e.toJsonArray)
        {
            emit("[");
            foreach(size_t i, JsonValue item; array)
            {
                if(i) emit(",");
                printCompact(item, emit);
            }
            emit("]");
        }
        else if(auto object = e.toJsonObject)
        {
            emit("{");
            auto i = 0;
            foreach(JsonString key, JsonValue val; object)
            {
                if(i) emit(",");
                emit("\"");
                emit(key.slice);
                emit("\":");
                printCompact(val, emit);
                ++i;
            }
            emit("}");
        }
        else if(auto b = e.toJsonBool)
        {
            emit(b.toString());
        }
        else if(e.toJsonNull)
        {
            emit("null");
        }
        else
        {
            assert(0, "JsonBuilder: Invalid JSON type.");
        }
    }

    /*
    * Write formatted JSON data with indentations.
    * Speed is no prior concern.
    */
    private static void printFormatted(JsonValue e, void delegate(char[]) emit, uint indents = 0)
    {
        assert(e.ptr !is null, "JsonBuilder: JsonValue contains null pointer.");
        
        //Very crude estimation of the string representation length.
        uint estimateArrayLength(JsonArray a)
        {
            uint peek_length;
            void peek(char[] str) { peek_length = str.length; }
            uint length;

            foreach(JsonValue item; a)
            {
                if(auto object = cast(JsonObject) item.ptr)
                {
                    if(object.length == 0)
                        continue;
                    else return uint.max;
                }
                
                if(auto array = cast(JsonArray) item.ptr)
                {
                    if(array.length == 0)
                        continue;
                    else return uint.max;
                }
                
                printFormatted(item, &peek);
                length += peek_length + 3;
            }
            return length;
        }
        
        //insert a padding of length i
        void pad(uint i)
        {
            static char[16] pads = ' ';
            while(i)
            {
                size_t min = i > pads.length ? pads.length : i;
                emit(pads[0..min]);
                i -= min;
            }
        }
        
        if(auto string = e.toJsonString)
        {
            emit("\"");
            emit(string.slice);
            emit("\"");
        }
        else if(auto number = e.toJsonNumber)
        {
            emit(number.slice);
        }
        else if(auto array = e.toJsonArray)
        {
            if(array.length == 0)
            {
                emit("[ ]");
                return;
            }
            
            //without newlines
            if(estimateArrayLength(array) <= 80)
            {
                emit("[ ");
                foreach(size_t i, JsonValue item; array)
                {
                    if(i) emit(", ");
                    
                    printFormatted(item, emit, indents);
                }
                emit(" ]");
                return;
            }
            
            ++indents;
            emit("[\n");
            foreach(size_t i, JsonValue item; array)
            {
                if(i) emit(",\n");
                pad(indents);
                
                printFormatted(item, emit, indents);
            }
            emit("\n");
            pad(indents);
            emit("]");
        }
        else if(auto object = e.toJsonObject)
        {
            if(object.length == 0)
            {
                emit("{ }");
                return;
            }
            
            ++indents;
            emit("{\n");
            auto i = 0;
            foreach(JsonString key, JsonValue val; object)
            {
                if(i) emit(",\n");
                
                pad(indents);
                
                emit("\"");
                emit(key.slice);
                emit("\" : ");
                
                printFormatted(val, emit, indents);
                ++i;
            }
            emit("\n");
            pad(indents);
            emit("}");
        }
        else if(auto b = e.toJsonBool)
        {
            emit(b.toString());
        }
        else if(e.toJsonNull)
        {
            emit("null");
        }
        else
        {
            assert(0, "JsonBuilder: Invalid JSON type.");
        }
    }
}

debug(UnitTest)
{
    unittest
    {
        alias JsonBuilder!().JsonValue JsonValue;
        alias JsonBuilder!().JsonObject JsonObject;
        alias JsonBuilder!().JsonString JsonString;

        auto obj = new JsonObject();
        
        obj["floats"] = [1.1, 2.2, 3.3, 4.4];
        obj["array"] = [cast(char[]) "a" : cast(uint[]) [1,2,3], "b" : [42]];
        obj["string"] = "abc";
        obj["bools"] = [true, false];
        obj["numbers"] = [3, 1234567890];
        obj["numbers"] ~= [42, 128];
        obj["one bool"] = true;
        obj["empty object"] = new JsonObject();
        obj["number"] = 42.1234;
        
        obj.print((char[] str){ /* Stdout(str); */ }, true); //formatted ouput
        obj.print((char[] str){ /* Stdout(str); */ }, false); //compact output
        
        assert(obj["array"]["b"][0] == 42);
        assert(obj["string"] == "abc");
        assert(obj["number"] == 42.1234);
        assert(obj["string"].toString == "abc");
        assert(obj["number"].toFloat == 42.1234);

        if(obj["array"]["b"][0].ptr) { /* item exists */ } else { assert(0); }
        if(obj["array"]["21"][42][0].ptr) { assert(0); } else { /* item does not exist */ }
        
        foreach(JsonString key, JsonValue val; obj)
        {
            if(key == "floats")
            {
                float[] floats = val.to!(float[])(val);
                assert(floats == [1.1, 2.2, 3.3, 4.4]);
            }
        }
    }
}
