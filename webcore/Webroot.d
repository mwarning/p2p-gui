module webcore.Webroot;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

/*
* This file may contain an alternative file system
* in variable "files" to be included into the binary.
*
* Use helper program ./utils/Includer.d to fill variable included_files in this file.
*
* Start using "./Includer ../webcore/Webroot.d *"
*/

import tango.core.Array;
import tango.io.device.File;
import tango.io.FilePath;
private import Path = tango.io.Path;
import tango.io.model.IFile;
import tango.io.FileSystem;
import tango.io.Stdout;
import TimeStamp = tango.text.convert.TimeStamp;

import webserver.HttpResponse;
import webserver.HttpRequest;

static import Utils = utils.Utils;

/*
* This module manages access to the files in the web root.
* The web root can be the located in the binary or on harddisk.
*/


struct Webroot
{
    //file-path -> file-data
    static ubyte[][char[]] included_files;
    static char[] webroot_dir;

    static this()
    {
        included_files = included_files.init;
    }

    /*
    * Get a list of file names in a directory (path), filtered by extension (ext).
    * Usefull to get list of CSS files for style selection.
    */
    public static char[][] getFileNames(char[] path, char[] ext)
    {
        //extension includes .
        static char[] getExt(char[] name)
        {
            auto i = rfind(name, '.');
            if(i == name.length) return null;
            return name[i..$];
        }
        
        static char[] getName(char[] path)
        {
            auto i = rfind(path, '/');
            if(i == path.length) return path;
            return path[i+1..$];
        }
        
        //a valid path ends with '/'
        static char[] getPath(char[] path)
        {
            auto i = rfind(path, '/');
            if(i == path.length) return path;
            return path[0..i+1];
        }
        
        char[][] matches = null;
        
        //get files from hard disk
        if(webroot_dir.length)
        {
            foreach(file; Path.children(webroot_dir ~ path))
            {
                if(file.folder)
                    continue;
		
                if(getExt(file.name) == ext)
                {
                    char[] name = file.name[0..$-ext.length].dup;
                    if(name.length)
                    {
                        matches ~= name;
                    }
                }
            }
        }
        else //get files from binary
        {
            foreach(file, data; included_files)
            {
                if(getPath(file) == path && getExt(file) == ext)
                {
                    char[] name = file[path.length..$-ext.length].dup;
                    if(name.length)
                    {
                        matches ~= name;
                    }
                }
            }
        }
        
        return matches;
    }

    /*
    * Access files on harddisk inside webroot
    * or in the binary.
    */
    public static void getFile(HttpResponse res, char[] sub_path)
    {
        if(sub_path.length == 0)
        {
            sub_path = "index.html";
        }
        else if(sub_path[$-1] == '/')
        {
            sub_path ~= "index.html";
        }
        
        if(sub_path[0] == '/')
        {
            sub_path = sub_path[1..$];
        }
        
        void setMime(FilePath path)
        {
            char[] mime;
            switch(path.ext)
            {
                case "htm":
                case "html": mime = "text/html"; break;
                case "css": mime = "text/css"; break;
                case "js":  mime = "text/javascript"; break;
                case "jpg":
                case "jpeg":  mime = "image/jpeg"; break;
                case "gif":  mime = "image/gif"; break;
                case "png":  mime = "image/png"; break;
                case "txt":  mime = "text/plain"; break;
                default: mime = "application/octet-stream";
            }
            res.setContentType(mime);
        }
        
        if(webroot_dir) //get files from hard disk
        {
            if(sub_path.find("..") != sub_path.length)
            {
                Stdout("(E) Webroot: Path '")(sub_path)("' contains \"..\" and will be rejected!").newline;
                res.setCode(HttpResponse.Code.NOT_FOUND);
                return;
            }
            
            char[] full_path = webroot_dir ~ sub_path;
            
            auto file_path = new FilePath(full_path);
            
            if(!file_path.exists)
            {
                Stdout("(W) Webroot: Path '")(full_path)("' does not exist!").newline;
                res.setCode(HttpResponse.Code.NOT_FOUND);
                return;
            }
            
            if(file_path.isFolder)
            {
                Stdout("(E) Webroot: Folder '")(full_path)("' cannot be transfered!").newline;
                res.setCode(HttpResponse.Code.NOT_FOUND);
                return;
            }
            
            setMime(file_path);
            res.addHeader("Last-Modified: " ~ TimeStamp.toString(file_path.modified)); //GMT
            
            auto fc = new File(full_path);
            res.setBodySource(fc, fc.length);
        }
        else //get files from binary
        {
            auto file_data_ptr = (sub_path in included_files);
            if(file_data_ptr)
            {
                //res.setCode(HttpResponse.Code.NOT_MODIFIED);
                setMime(FilePath(sub_path));
                //res.addHeader("Date: "); //current time in GMT
                res.addHeader("Last-Modified: Mon, 01 Jan 2008 00:00:00 GMT");
                //res.addHeader("Cache-Control: max-age=86400, must-revalidate"); //one day
                auto writer = res.getWriter();
                writer(cast(char[]) *file_data_ptr);
            }
            else
            {
                Stdout("(W) Webroot: File '")(sub_path)("' does not exist in memory!").newline;
                res.setCode(HttpResponse.Code.NOT_FOUND);
                return;
            }
        }
    }

    /*
    * Writes files included into the binary to disk.
    * For developing purposes.
    */
    public static void writeToDisk(char[] base_dir)
    {
        if(included_files.length == 0)
        {
            Stdout("(I) Webroot: No files included in this binary.").newline;
            return;
        }
        
        if(base_dir.length == 0)
        {
            base_dir = "./";
        }
        else
        {
            Utils.appendSlash(base_dir);
        }

        scope path = new FilePath(base_dir);
        if(path.exists)
        {
            Stdout("(E) Webroot: Target directory '")(base_dir)("' does already exist. => Abort.").newline;
            return;
        }
        else
        {
            path.create();
        }
        
        try
        {
            Stdout("Write Files to Disk:").newline;
            foreach(file_path, content; included_files)
            {
                auto path = base_dir ~ file_path;
                Stdout("Write: '")(path)("'").newline;
                
                //make sure the path exists
                uint pos = rfind(path, '/');
                if(pos < path.length) 
                    FilePath(path[0..pos]).create();
                
                File.set(path, content);
            }
            Stdout("Done.").newline;
        }
        catch(Exception e)
        {
            Stdout("(E) Webroot: '")(e.toString)("'\n");
            Stdout("                            => Abort!").newline;
            return;
        }
    }
}
