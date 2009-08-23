module webcore.UserManager;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import tango.time.Clock;
import tango.io.Stdout;
import api.User; //for hack
import api.Host;

import webcore.MainUser;
import utils.Storage;
static import Utils = utils.Utils;

/*
* Manage all account instances.
*/

struct UserManager
{
    private static const char[] webusers_file = "webusers.json";
    private static MainUser[char[]] users; //all users
    
    static void loadUsersSettings()
    {
        auto s = Storage.loadFile(webusers_file);

        foreach(char[] user_name, Storage user_settings; s)
        {
            if(user_name.length == 0)
            {
                throw new Exception("UserManger: Can't load user entry with empty name.");
            }
            users[user_name] = new MainUser(user_settings);
        }
    }

    static void saveUsersSettings()
    {
        auto storage = new Storage();
        
        foreach(user; users)
        {
            char[] name = user.getName();
            assert(name.length);
            auto value = new Storage();
            user.save(value);
            storage[name] = value;
        }
        
        storage.save("version", Host.main_version);
        
        Storage.saveFile(webusers_file, storage);
    }
    
    static MainUser getUser(char[] name)
    {
        auto ptr = (name in users);
        return ptr ? *ptr : null;
    }
    
    static MainUser getUser(uint id)
    {
        foreach(user; users)
        {
            if(user.getId == id)
            {
                return user;
            }
        }
        return null;
    }
    
    static MainUser addUser(char[] name)
    {
        if(name.length == 0 || name in users)
        {
            return null;
        }
        
        /*
        * Get an unused user id.
        */
        static uint getNewUserId()
        {
            uint id = 1;
            foreach(user; users)
            {
                auto uid = user.getId();
                if(uid >= id)
                {
                    id = uid + 1;
                }
            }
            return id;
        }
        
        uint id = getNewUserId();
        auto user = new MainUser(id, name);
        users[name] = user;
        return user;
    }
    
    
    static void remove(MainUser user)
    {
        users.remove(user.getName);
    }
    
    static void renameUser(char[] from_name, char[] to_name)
    {
        //TODO
        /*
        auto user = getUser(from_name);
        if(user)
        {
            removeUser(user);
            user.rename(to_name);
            addUser(user);
        }
        */
    }
    
    static void addUser(MainUser user)
    {
        users[user.getName] = user;
    }
    
    static uint getUserCount()
    {
        return users.length;
    }
    
    //for use in MainUser.d
    static User[] getUserArray()
    {
        return Utils.convert!(User)(users);
    }
    
    //get all users that use the client with id.
    static MainUser[] getByClientId(uint id)
    {
        MainUser[] ret;
        foreach(user; users)
        {
            if(user.client_ids.contains(id))
            {
                ret ~= user;
            }
        }
        return ret;
    }
}
