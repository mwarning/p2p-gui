module webcore.DiskFile;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import tango.util.PathUtil;
import tango.core.Exception;
import tango.time.Clock;
import tango.io.FilePath;
import tango.io.Stdout;
static import Tango = tango.io.device.File;
import tango.io.FileSystem;

import api.Host;
import api.Search;
import api.Node;
import api.File;
import api.Setting;
import api.Meta;
import api.User;

static import Main = webcore.Main;
static import Utils = utils.Utils;
import webcore.Logger;

/*
*  Allow access to the local file system using the Files api.
*/
class DiskFile : NullFile, Files
{
    uint id;
    DiskFile[uint] files;
    FilePath path;
    File_.Type type;
    
    this(char[] path, uint id_offset = 0)
    {
        this(new FilePath(path), id_offset);
    }
    
    this(FilePath path, uint id_offset = 0)
    {
        this.path = path;
        
        if(path.exists)
        {
            type = path.isFolder ? File_.Type.DIRECTORY : File_.Type.FILE;
        }
        else
        {
            type = File_.Type.DIRECTORY;
        }
        
        id = getFileHash(path.toString) + id_offset;
    }
    
    bool exists()
    {
        return path.exists();
    }
    
    char[] toString()
    {
        return path.toString();
    }
    
    static uint getFileHash(char[] str)
    {
        uint i = 1;
        foreach(c; str)
        {
            i = i * c;
            if(i == 0) i++;
        }
        return i;
    }
    
    private void readFiles()
    {
        if(!path.exists)
            return;
        
        DiskFile[uint] files;
        
        foreach (file; path.toList)
        {
            auto tmp = new DiskFile(file, this.id);
            files[tmp.getId] = tmp;
        }
        
        this.files = files; //replace, no update
    }
    
    uint getId() { return id; }
    ulong getSize() { return path.fileSize; }
    File_.State getState() { return File_.State.COMPLETE; }
    File_.Type getType() { return type; }
    char[] getName() { return path.file; }
    
    Files getFiles()
    {
        if(type == File_.Type.DIRECTORY)
        {
            return this;
        }
        return null;
    }
    
    //TODO: files will be filled only when Files accessed
    uint getFileCount(File_.Type type, File_.State state)
    {
        return files.length;
    }
    
    File getFile(File_.Type type, uint id)
    {
        return getDiskFile(type, id);
    }
    
    DiskFile getDiskFile(File_.Type type, uint id)
    {
        if(this.type != File_.Type.DIRECTORY)
        {
            return null;
        }
        
        if(auto file = (id in files))
        {
            return *file;
        }
        
        foreach(item; files)
        {
            auto file = item.getDiskFile(type, id);
            if(file)
            {
                return file;
            }
        }
        
        return null;
    }
    
    File[] getFileArray(File_.Type type, File_.State state, uint age)
    {
        if(this.type != File_.Type.DIRECTORY)
        {
            return null;
        }
        
        readFiles();
        
        return Utils.filter!(File)(files, state, age);
    }
    
    void previewFile(File_.Type type, uint id)
    {
        auto file = getDiskFile(type, id);
        if(file && type == File_.Type.FILE)
        {
            auto fc = new Tango.File(file.path.toString);
            Host.saveFile(fc, file.path.file, file.path.fileSize);
        }
    }
    
    //not used yet
    void removeFiles(File_.Type type, uint[] ids)
    {
        foreach(id; ids)
        {
            auto file = getDiskFile(type, id);
            try
            {
                if(file) file.path.remove();
            }
            catch(Object o) {}
        }
    }
    
    void copyFiles(File_.Type type, uint[] source_ids, uint target_id) {}
    void moveFiles(File_.Type type, uint[] source_ids, uint target_id)
    {
        auto target = getDiskFile(type, target_id);
        if(target is null) return;
        foreach(source_id; source_ids)
        {
            auto source = getDiskFile(type, source_id);
            if(source is null) continue;
            try
            {
                source.path.rename(target.path.toString ~ source.getName);
            }
            catch(Exception e)
            {
                Logger.addError(e.toString);
            }
        }
    }
    
    void renameFile(File_.Type type, uint id, char[] new_name)
    {
        auto file = getDiskFile(type, id);
        if(file is null) return;
        try
        {
            file.path.rename(new_name);
        }
        catch(Exception e)
        {
            Logger.addError(e.toString);
        }
    }
    
    void startFiles(File_.Type type, uint[] ids) {}
    void pauseFiles(File_.Type type, uint[] ids) {}
    void stopFiles(File_.Type type, uint[] ids) {}
    void prioritiseFiles(File_.Type type, uint[] ids, Priority priority) {}

    uint getlastChanged()
    {
        if(!path.exists)
            return 0;
        return (path.modified - Time.epoch1970).seconds;
    }
}
