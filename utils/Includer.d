module Includer;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

/*
* A helper program to include entire directory
* structures into an associative array of a source file.
*
* The program can substitue a variable in a file or create a new file;
* Default behaviour is substitution.
*
* Hidden files and hidden directories are omitted.
* (That is, when the name begins with a point) 
*/

import tango.io.Stdout;
import tango.core.Array;
import tango.io.device.File;
import Path = tango.io.Path;
import tango.io.FilePath;
import tango.io.device.Array;
import tango.io.model.IFile;

version(USE_COMPRESSION)
{
    import tango.io.compress.ZlibStream;
}

uint i; //file counter
char[] content; //output file content
char[2] hex; //tmp

void toHex(ubyte x)
{
    static const char char_array[16]  = "0123456789abcdef";
    hex[0] = char_array[x >> 4];
    hex[1] = char_array[x & 0xF];
}

void addFolder(char[] path, char[] name)
{
    if(name[0] == '.')
        return;
        
    foreach(file; Path.children(path ~ name))
    {
        if(file.folder)
        {
            addFolder(file.path, file.name);
        }
        else
        {
            addFile(file.path, file.name);
        }
    }
}

void addFile(char[] path, char[] name)
{
    if(name[0] == '.')
        return;
    
    char[] full_path = path.dup ~ name.dup;
    Stdout("Read: ")(full_path).newline;
    
    if(i) content ~= ",";
    content ~= "\n        \"" ~ full_path ~ "\" : cast(ubyte[]) x\"";
    
    //read file and compress with zlib
    auto data = cast(ubyte[]) File.get(full_path);
    
    version(USE_COMPRESSION)
    {
        //data = Zlib.compress(data); //Phobos code
        
        scope buf = new Array(1024, 1024);
        scope comp = new ZlibOutput(buf);
        comp.write(data);
        comp.close();
        data = cast(ubyte[]) buf.slice();
    }
    
    //for each ubyte
    foreach(x; data)
    {
        content ~= " ";
        toHex(x);
        content ~= hex;
    }
    
    content ~= "\"";
    i++;
}

/*
* Creates a module name from a file path.
* Used when a new file need to be written.
*
* e.g.: "./foo/Bar.d" -> "foo.Bar"
*/
char[] getModuleName(char[] target_path)
{
    char[] base;
    char[] name;
    
    //split into path and file name
    uint pos = rfind(target_path, FileConst.PathSeparatorChar);
    if(pos == target_path.length)
    {
        name = target_path;
    }
    else
    {
        base = target_path[0..pos];
        name = target_path[pos+1..$];
    }
    
    //strip extension
    pos = rfind(name, '.');
    if(pos != name.length) name = name[0..pos];
    
    //only use path part after last ".." if present
    pos = rfind(base, "..");
    if(pos != base.length) base = base[pos+2..$];
    
    replace(base, FileConst.PathSeparatorChar, '.');
    
    if(base.length && base[0] == '.') base = base[1..$];
    
    return base ~ "." ~ name;
}

void main(char[][] args)
{
    char[] token = "included_files ="; //replace data between this token and ';'
    bool write_new_file = false; //default: replace value after token
    
    if(args.length < 3)
    {
        Stdout("Missing arguments!\n");
        Stdout("Use: " ~ args[0] ~ " output_file [file/directory]*\n\n");
        Stdout("This program includes all files under given directories in a D source file.\n");
        Stdout("Within the file everything is in an associative array \"ubyte[][char[]] files\".\n");
        Stdout("It maps the file path and name to its content.\n");
        return;
    }
    
    char[] own_file_name = (new FilePath(args[0])).file;
    char[] out_file_name = args[1];
    
    if(write_new_file)
    {
        char[] module_name = getModuleName(args[1].dup);
        content =
        "module " ~ module_name ~";\n"
        "\n"
        "/*\n"
        "* This file includes binary files in an associative array.\n"
        "*/\n"
        "\n"
        "const ubyte[][char[]] files;\n"
        "\n"
        "static this()\n"
        "{\n"
        "    files = [\n cast(char[]) ";
    }
    else
    {
        content = " [\n cast(char[]) ";
    }
    
    //for each provided file/directory
    foreach(arg; args[2..$])
    {
        if(arg[0] == '.')
        {
            Stdout("Skip: ")(arg).newline;
            continue;
        }
        
        auto file = new FilePath(arg);
        if(file.isFolder)
        {
            addFolder(file.path, file.name);
        }
        else
        {
            if(arg == own_file_name)
            {
                //don't include this program
                Stdout("Skip: ")(arg).newline;
            }
            else
            {
                addFile(file.path, file.file);
            }
        }
    }
    
    if(write_new_file)
    {
        content ~= "\n    ];\n}\n";
        Stdout("Write file: ")(out_file_name).newline;
        File.set(out_file_name, content);
    }
    else
    {
        content ~= "\n    ]";
        
        char[] data = cast(char[]) File.get(out_file_name);
        
        uint begin = data.find(token) + token.length;
        if(begin >= data.length)
        {
            Stdout("Token '")(token)("' not found.").newline;
            return;
        }
        
        uint end = begin + data[begin..$].find(';');
        if(end >= data.length)
        {
            Stdout("';' not found after token '")(token)("'.").newline;
            return;
        }
        
        char[] pre_data = data[0..begin];
        char[] post_data = data[end..$];
        
        Stdout("Write file: ")(out_file_name).newline;
        auto out_file = new File(out_file_name, File.WriteExisting);
        out_file.write(pre_data);
        out_file.write(content);
        out_file.write(post_data);
    }
    
    Stdout(i)(" files included into '")(out_file_name)("'.").newline;
}
