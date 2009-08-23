module utils.Storage;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import tango.io.device.File;
import tango.io.Stdout;
import tango.core.Traits;

import utils.json.JsonParser;
import utils.json.JsonBuilder;
import Debug = utils.Debug;

/*
* Load JSON formated files and allow easy (but limited) manipulation
* without using the Json* data structures directly.
*/

private static JsonBuilder!() builder;
alias builder.JsonValue JsonValue;
alias builder.JsonString JsonString;
alias builder.JsonArray JsonArray;
alias builder.JsonObject JsonObject;
alias builder.JsonNumber JsonNumber;
alias builder.JsonBool JsonBool;
alias builder.JsonNull JsonNull;


class Storage
{
    private JsonObject root;
    
    this()
    {
        root = new JsonObject();
    }
    
    /*private*/ this(JsonObject root)
    {
        this.root = root;
    }
    
    /*
    * Load a text file and parse JSON content as object.
    */
    static Storage loadFile(char[] file_path)
    {
        auto file = new File(file_path, File.ReadWriteOpen);
        
        auto pa = new JsonParser!();
        JsonObject obj;
        
        if(file.length)
        {
            char[] content = new char[file.length];
            file.input.read(content);

            try
            {
                obj = pa.parseObject(content);
            }
            catch(Exception e)
            {
                Stdout("(E) While loading ")(file_path)(": ")(e.toString).newline;
                Debug.getErrorMessage(content, pa.pos);
                file.close();
                throw e;
            }
        }
        else
        {
            obj = new JsonObject();
        }
        
        file.close();
        return new Storage(obj);
    }

    /*
    * Store JSON data to text file.
    */
    static void saveFile(char[] file_path, Storage storage)
    {
        scope file = new File(file_path, File.ReadWriteCreate);
        scope(exit) file.close();
        storage.root.print (
            cast(void delegate(char[])) &file.output.write
        );
    }
    
    void save(D : char[] function(T), T)(char[] name, T* target, D toString)
    {
        char[] tmp = toString(*target);
        save(name, &tmp);
    }
    
    void save(D : T delegate(), T)(char[] name, D getter)
    {
        T tmp = getter();
        save(name, &tmp);
    }
    
    void save(T)(char[] name, T* target)
    {
        root[name] = *target;
    }
    
    void save(T, Dummy = void)(char[] name, T target)
    {
        static if(is(T == Storage))
        {
            root[name] = target.root;
        }
        else
        {
            root[name] = target;
        }
    }
    
    /*
    * Set target to stored value, target is left untouched if value not present.
    */
    void load(D : T function(char[]), T)(char[] name, T* target, D fromString)
    {
        char[] tmp;
        load(name, &tmp);
        *target = fromString(tmp);
    }
    
    void load(D : void delegate(T), T)(char[] name, D setter)
    {
        T tmp;
        load(name, &tmp);
        setter(tmp);
    }
    
    void load(T)(char[] name, T* target)
    {
        auto value = root[name];
        if(value.ptr)
        {
            //may throw an exception
            *target = builder.fromJson!(T)(value);
        }
    }
    
    void load()(char[] name, Storage target)
    {
        auto object = cast(JsonObject) root[name].ptr;
        if(object)
        {
            target.root = object;
        }
    }
    
    public int opApply(int delegate(ref Storage value) dg)
    {
        int result = 0;
        foreach(JsonValue value; root)
        {
            auto obj = cast(JsonObject) value.ptr;
            if(obj is null) continue;
            auto storage = new Storage(obj);
            result = dg(storage);
            
            if (result != 0)
            {
                break;
            }
        }
        return result;
    }
    
    public int opApply(int delegate(ref char[] key, ref Storage value) dg)
    {
        int result = 0;
        foreach(char[] key, JsonValue value; root)
        {
            auto obj = cast(JsonObject) value.ptr;
            if(obj is null) continue;
            auto storage = new Storage(obj);
            result = dg(key, storage);
            
            if (result != 0)
            {
                break;
            }
        }
        return result;
    }
    
    Storage opIndex(char[] name)
    {
        auto obj = cast(JsonObject) root[name].ptr;
        return obj ? new Storage(obj) : null;
    }
    
    void opIndexAssign(Storage s, char[] name)
    {
        if(s) root[name] = s.root;
    }
}
