module webcore.JsonRPC;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/


import tango.core.Traits;
import tango.io.Stdout;
static import Integer = tango.text.convert.Integer;
static import Float = tango.text.convert.Float;
import JsonEscape = tango.text.json.JsonEscape;

import Utils = utils.Utils;
import utils.json.JsonParser;
import utils.json.JsonBuilder;
import webcore.Logger;
import webcore.MainUser;
import webcore.Main;

import api.Node;
import api.File;
import api.Meta;
import api.Setting;
import api.Search;
import api.User;
import api.Host;
import api.Client;

private static JsonBuilder!() builder;

alias builder.JsonString JsonString;
alias builder.JsonObject JsonObject;
alias builder.JsonValue JsonValue;
alias builder.JsonArray JsonArray;


/*
* JSON RPC interface

Request Syntax example for
.foo(12, "ab").bar.[getInteger(), getObject.getName(), getBoolean()]:
{
    "id" : "123", //optional
    "query" : {
        "method" : "foo",
        "params" : [12, "ab"],
        "chain" : {
            "method" : "bar",
            "chain" : [
                "getInteger", 
                { "method" : "getObject", "chain" : ["getName"], "retalias" : "name"},
                "getBoolean"
        }
    }
}

Response example:
{
    "id" : "123",
    "result" : {
        "foo" :  {
            "bar" : {
                "getInteger" : 42,
                "name" : "xyz",
                "getBoolean" : true
            }
        }
    }
}

*/


class JsonRPC
{
    static JsonParser!() pa;
    
    this()
    {
        add!("getAppName", "main_name");
        add!("getAppVersion", "main_version");
        add!("getAppWebLink", "main_weblink");
        
        add!("invalidateSession", "logout");
        add!("addLink", "add_link");
        add!("shutdownClient", "shutdown_client");
        
        //class User
        add!("User.getId","id");
        add!("User.getName", "name");
        add!("User.getUserCount", "usercount");
        add!("User.getFiles", "files");
        add!("User.getNodes", "nodes");
        add!("User.getSettings", "settings");
        add!("User.getMetas", "metas");
        
        add!("Users.addUser", "add");
        add!("Users.renameUser", "rename");
        add!("Users.removeUser", "remove");
        add!("Users.setUserPassword", "setpassword");
        add!("Users.getUser", "get");
        add!("Users.getUserArray", "getusers");
        
        //class Node
        add!("Node.getId", "id");
        add!("Node.getHost", "host");
        add!("Node.getPort", "port");
        add!("Node.getLocation", "location");
        add!("Node.getName", "name");
        add!("Node.getSoftware", "software");
        add!("Node.getVersion", "version");
        add!("Node.getProtocol", "protocol");
        add!("Node.getDescription", "description");
        add!("Node.getState", "state");
        add!("Node.getAge", "age");
        add!("Node.getType", "type");
        add!("Node.getFileCount", "filecount");
        add!("Node.getNodeCount", "nodecount");
        add!("Node.getUserCount", "usercount");
        add!("Node.getPriority", "priority");
        add!("Node.getPing", "ping");
        add!("Node.getUploadRate", "uploadrate");
        add!("Node.getDownloadRate", "downloadrate");
        add!("Node.getUploaded", "uploaded");
        add!("Node.getDownloaded", "downloaded");
        add!("Node.getSearches", "searches");
        add!("Node.getNodes", "nodes");
        add!("Node.getFiles", "files");
        add!("Node.getSettings", "settings");
        add!("Node.getUsers", "users");
        add!("Node.getMetas", "metas");
        
        //class Nodes
        add!("Nodes.addNode", "add");
        add!("Nodes.getNode", "get");
        add!("Nodes.connect");
        add!("Nodes.disconnect");
        add!("Nodes.removeNode", "remove");
        add!("Nodes.getNodeCount", "nodecount");
        add!("Nodes.getNodeArray", "getnodes");

        //class Searches
        add!("Searches.addSearch", "add");
        add!("Searches.getSearch", "get");
        add!("Searches.removeSearch", "remove");
        add!("Searches.stopSearch", "stop");
        add!("Searches.startSearchResults", "startresults");
        add!("Searches.removeSearchResults", "removeresults");
        add!("Searches.getSearchArray", "getsearches");

        //class Search
        add!("Search.getId", "id");
        add!("Search.getName", "name");
        add!("Search.getState", "state");
        add!("Search.getResultCount", "resultcount");
        add!("Search.getResultArray", "getresults");

        //class File
        add!("File.getId", "id");
        add!("File.getName", "name");
        add!("File.getSize", "size");
        add!("File.getState", "state");
        add!("File.getType", "type");
        add!("File.getHash", "hash");
        add!("File.getLastSeen", "lastseen");
        add!("File.getRequests", "requests");
        add!("File.getAge", "age");
        add!("File.getFormat", "format");
        add!("File.getFileCount", "filecount");
        add!("File.getNodeCount", "nodecount");
        add!("File.getFiles", "files");
        add!("File.getNodes", "nodes");
        add!("File.getUsers", "users");
        add!("File.getMetas", "metas");
        add!("File.getPriority", "priority");
        add!("File.getPing", "ping");
        add!("File.getUploadRate", "uploadrate");
        add!("File.getDownloadRate", "downloadrate");
        add!("File.getUploaded", "uploaded");
        add!("File.getDownloaded", "downloaded");
        add!("File.getLastChanged", "changed");
        
        //class Files
        add!("Files.getFileCount", "filecount");
        add!("Files.getFile", "get");
        add!("Files.getFileArray", "getfiles");
        add!("Files.removeFiles", "remove");
        add!("Files.renameFile", "rename");
        add!("Files.startFiles", "start");
        add!("Files.pauseFiles", "pause");
        add!("Files.prioritiseFiles", "prioritise");
        add!("Files.previewFile", "download");
        
        //class Meta
        add!("Meta.getId", "id");
        add!("Meta.getMeta", "text");
        add!("Meta.getRating", "rating");
        add!("Meta.getSource", "source");
        add!("Meta.getType", "type");
        add!("Meta.getState", "state");
        add!("Meta.getLastChanged", "changed");
        
        //class Metas
        add!("Metas.addMeta", "add");
        add!("Metas.removeMeta", "del");
        add!("Metas.getMetaCount", "metacount");
        add!("Metas.getMetaArray", "getmetas");
        
        //class Setting
        add!("Setting.getId", "id");
        add!("Setting.getType", "type");
        add!("Setting.getName", "name");
        add!("Setting.getValue", "value");
        add!("Setting.getDescription", "description");
        add!("Setting.getSettings", "settings");
        
        //class Settings
        add!("Settings.getSetting", "get");
        add!("Settings.setSetting", "set");
        add!("Settings.getSettingCount", "settingcount");
        add!("Settings.getSettingArray", "getsettings");
        
        pa = new JsonParser!();
    }
    
    void parse(void delegate(char[]) o, User base, char[] json)
    {
        JsonObject rpc;
        
        o("{\n");
        try
        {
            rpc = pa.parseObject(json);
            char[] id = rpc["id"].toString;
            if(id)
            {
                o("\"id\" : \"");
                o(id);
                o("\",\n");
            }
            
            o("\"result\" : ");
            auto query = rpc["query"];
            
            if(query.ptr is null)
                throw new Exception("\"query\" attribute is required.");
            
            auto q_array = query.toJsonArray();
            
            if(q_array is null)
            {
                auto q_object = query.toJsonObject();
                if(q_object is null)
                {
                    throw new Exception("\"query\" attribute must be an array or object.");
                }
                
                q_array = new JsonArray();
                q_array ~= q_object;
            }
            
            Parse!(User).parse(o, base, q_array);
        }
        catch(Exception e)
        {
            char[] error = e.toString();
            if(rpc) o(",\n");
            o("\"error\" :  \"");
            JsonEscape.escape(error, o);
            o("\"");
        }
        
        o("\n}");
    }
}

private:
    
//some workarounds

char[] getAppName() { return Host.main_name; }
char[] getAppVersion() { return Host.main_version; }
char[] getAppWebLink() { return Host.main_weblink; }

private void shutdownClient(uint id)
{
    auto user = cast(MainUser) getThreadOwner();
    if(user is null) return;
    auto client = cast(Client) user.getNode(Node_.Type.CLIENT, id);
    if(client) client.shutdown();
}

private void addLink(uint client_id, char[] link)
{
    auto user = cast(MainUser) getThreadOwner();
    if(user && link.length)
    {
        auto client = cast(Client) user.getNode(Node_.Type.CORE, client_id);
        if(client) client.addLink(link);
    }
}

//end workarounds


//split string at compile time
class Split(char[] a)
{
    private template find(char[] str, char c, int i = 0)
    {
        static if (i >= str.length) const int pos = str.length;
        else static if (str[i] == c) const int pos = i;
        else const int pos = find!(str, c, i + 1).pos;
    }
    
    static if(find!(a, '.').pos == a.length)
    {
        const char[] base_name = "void";
        const char[] func_name = a;
        //alias typeof(mixin(base_name)) base_type;
        alias Object base_type; //void?
        mixin("alias typeof(" ~ func_name ~ ") func_type;");
    }
    else
    {
        const char[] base_name = a[0..find!(a, '.').pos];
        const char[] func_name = a[find!(a, '.').pos + 1..$];
        mixin("alias " ~ base_name ~ " base_type;");
        mixin("alias typeof(" ~ a ~ ") func_type;");
    }
}

/*
* Helper function to have a function
* to access a variable from scope.
*/
T getVariable_(char[] value_name, T)()
{
    mixin("return " ~ value_name ~ ";");
}

void add(char[] token_name, char[] alt_name = "")()
{
    static if(isCallableType!(typeof(mixin(token_name))))
    {
        const char[] full_method_name = token_name;
        const bool use_token_name = false;
    }
    else //make a function from value type
    {
        alias typeof(mixin(token_name)) Type; //can't move this into template of getVariable, dmd bug
        const char[] full_method_name = "getVariable_!(\"" ~ token_name ~ "\"," ~ Type.stringof ~ ")";
        const bool use_token_name = true;
    }
    
    alias Split!(full_method_name).base_type B;
    alias Split!(full_method_name).func_type F;
    
    const char[] func_name = Split!(full_method_name).func_name;
    const char[] base_name = Split!(full_method_name).base_name;
    
    alias ReturnTypeOf!(F) R;
    alias ParameterTupleOf!(F) Params;
    
    static if(alt_name.length)
    {
        const char[] name = alt_name;
    }
    else static if(use_token_name)
    {
        const char[] name = token_name;
    }
    else
    {
        const char[] name = func_name;
    }
    
    debug
    {
        if(name in Parse!(B).methods)
        {
            Logger.addError("JsonPRC: Reject adding duplicate parser with name {} for {}.", name, full_method_name);
            return;
        }
    }
    
    Parse!(B).methods[name] = &Parser!(full_method_name).call;
}

template Parser(char[] full_method_name)
{
    alias Split!(full_method_name).base_type B;
    alias Split!(full_method_name).func_type F;
    
    const char[] func_name = Split!(full_method_name).func_name;
    const char[] base_name = Split!(full_method_name).base_name;
    
    alias ReturnTypeOf!(F) R;
    alias ParameterTupleOf!(F) Params;
    
    void call(void delegate(char[]) o, B obj, JsonArray params, JsonArray chain_array)
    {
        try
        {
        auto params_len = params ? params.length : 0;
        if(params_len != Params.length)
        {
            Logger.addError("JsonPRC: Wrong number of arguments supplied for {}. Found {}, need {}.", full_method_name, params_len, Params.length);
            o("null");
            return;
        }
        
        //build up an argument tuple,
        Params t;
        foreach (i, arg; t)
        {
            alias typeof(arg) T;
            try
            {
                static if(is(T == enum))
                {
                    t[i] = Utils.fromString!(T)(params[i].toString);
                }
                else static if(is(T == char[]))
                {
                    t[i] = params[i].toString;
                }
                else static if(is(T == uint[]))
                {
                    JsonArray array = params[i].toJsonArray;
                    uint[] values = new uint[](array.length);
                    for(auto j = 0; j < values.length; j++)
                    {
                        values[j] = array[j].toInteger;
                    }
                    t[i] = values;
                }
                else static if(is(T : ulong))
                {
                    t[i] = params[i].toInteger;
                }
                else static if(is(T : double))
                {
                    t[i] = params[i].toFloat;
                }
                else
                {
                    t[i] = Utils.fromString!(T)(params[i].toString);
                }
            }
            catch(Exception e)
            {
                t[i] = T.init;
            }
        }
        
        static if(is(B == void) || is(B == Object)) //global function
        {
            const char[] func = func_name ~ "(t);";
        }
        else //member function
        {
            const char[] func = "obj." ~ func_name ~ "(t);";
        }

        static if(is(R == void))
        {
            mixin(func);
            o("null");
        }
        else static if(is(R == enum)) //is enumeration
        {
            mixin("R ret = " ~ func);
            o("\"");
            o( Utils.toString(ret) );
            o("\""); 
        }
        else static if(is(R : ulong)) //is number
        {
            char[66] tmp;
            mixin("R ret = " ~ func);
            o(Integer.format(tmp, ret));
        }
        else static if(is(R : double)) //is float
        {
            char[66] tmp;
            mixin("R ret = " ~ func);
            o(Float.format(tmp, ret));
        }
        else static if(is(R == char[]) || is(R == dchar[]) || is(R == wchar[])) //is string
        {
            mixin("R ret = " ~ func);
            o("\"");
            JsonEscape.escape(ret, o);
            o("\""); 
        }
        else static if(isDynamicArrayType!(R) || is(typeof(R.opApply)))
        {
            static if(isDynamicArrayType!(R))
            {
                alias typeof((R.init)[0]) V;
            }
            else
            {
                alias ParameterTupleOf!(ParameterTupleOf!(typeof(R.opApply))[0])[0] V;
            }
            
            mixin("R ret = " ~ func);
            
            if(ret is null)
            {
                o("null");
                return;
            }
            
            o("{");
            
            size_t c;
            char[66] tmp;
            foreach(V item; ret)
            {
                //V item = ret.get;
                if(c++) o(", ");
                o("\"");
                static if(is(typeof(V.getId)))
                {
                    auto id = item.getId();
                }
                else
                {
                    auto id = c;
                }
                o(Integer.format(tmp, id));
                o("\" : ");
                
                Parse!(V).parse(o, item, chain_array);
                c++;
            }
            
            o("}");
        }
        else
        {
            //global function
            mixin("R ret = " ~ func);
            Parse!(R).parse(o, ret, chain_array);
        }
        
        }
        catch(Object obj)
        {
            Logger.addError("JsonPRC: Exception occured calling {}:\n    {}", full_method_name, obj.toString);
            o("null");
        }
    }
}

template Parse(B)
{
    alias void function(void delegate(char[]) o, B obj, JsonArray params, JsonArray chain_array) Method;
    
    Method[char[]] methods;
    
    void parse(void delegate(char[]) o, B obj, JsonArray rpcs)
    {
        if(obj is null || rpcs is null)
        {
            o("null");
            return;
        }
        
        bool encase = (rpcs.length > 1);
        
        size_t d;
        if(encase) o("{");
        
        foreach(rpc; rpcs)
        {
            char[] method = rpc.toString();
            char[] method_alias;
            JsonArray param_array;
            JsonArray chain_array;
            
            if(method is null)
            {
                method = rpc["method"].toString; //required

                if(method.length == 0)
                {
                    if(encase) o("}");
                    throw new Exception("missing \"method\" name");
                }
                
                method_alias = rpc["retname"].toString; //optional
                param_array = rpc["params"].toJsonArray; //optional
                auto chain_value = rpc["chain"]; //optional
                if(chain_value.ptr)
                {
                    chain_array = chain_value.toJsonArray; 
                    if(chain_array is null)
                    {
                        auto chain_object = chain_value.toJsonObject;
                        if(chain_object)
                        {
                            chain_array = new JsonArray();
                            chain_array ~= chain_object;
                        }
                    }
                }
            }
            
            if(encase)
            {
                if(d++) o(", ");
                
                o("\"");
                o(method_alias.length ? method_alias : method);
                o("\" : ");
            }
            
            if(auto ptr = (method in methods))
            {
                (*ptr)(o, obj, param_array, chain_array);
            }
            else
            {
                //is it a global function
                if(auto global_method_ptr = (method in Parse!(Object).methods))
                {
                    (*global_method_ptr)(o, cast(Object) obj, param_array, chain_array);
                }
                else
                {
                    if(encase) o("null }");
                    throw new Exception("unknown method name " ~ method);
                }
            }
        }
        if(encase) o("}");
    }
}
