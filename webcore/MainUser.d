module webcore.MainUser;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import tango.io.device.Conduit;
import tango.io.device.File;
import Path = tango.io.Path;
import tango.io.model.IFile;
import tango.core.Array;
import tango.time.Clock;
import tango.util.container.more.Stack;
import tango.text.convert.Format;
import tango.io.Stdout;

import api.Client;
import api.Node;
import api.File;
import api.Setting;
import api.Meta;
import api.User;

import webcore.DiskFile;
import webcore.SettingsWrapper;
import webcore.Dictionary;
import webcore.Session;
import webcore.SessionManager;
import webcore.ClientManager;
import webcore.UserManager;
import webcore.Logger;
static import Main = webcore.Main;
static import Utils = utils.Utils;
import utils.Storage;
import utils.json.JsonBuilder;

/*
* Represents a user account.
*
* User is for login management
* Files for acessing the local file system
* Nodes for the client instances
* Metas for chatting between users, logging etc.
* Settings for controlling the behavior of this app
*/

class MainUser : User, Nodes, Metas, Settings
{
    uint id;
    bool is_admin;
    bool is_disabled; //disable account
    
    Main.Gui[] guis; //gui instances
    Utils.Set!(uint) client_ids;
    
    //login data for web interface
    char[] username;
    char[] password_hash;
    
    DiskFile files;
    Message[uint] logs;
    Setting[] settings;
    Setting[] hidden_settings;
    Language* language;
    
    public this(uint id, char[] username, char[] password = null, bool is_admin = false)
    {
        assert(username.length);
        assert(id);
        
        this.id = id;
        this.username = username;
        this.is_admin = is_admin;
        this.password_hash = Utils.md5_hex(password);
        
        this.language = &Dictionary.default_language;
        
        //default gui settings
        auto gui_settings = new JsonObject();
        gui_settings["Plex"] = new JsonObject();
        gui_settings["Clutch"] = new JsonObject();
        gui_settings["Jay"] = new JsonObject();
        
        this.guis = Main.getGuiInstances(new Storage(gui_settings));
        
        this();
    }
    
    public this(Storage s)
    {
        this.language = &Dictionary.default_language;
        
        load(s);
        
        this();
    }
    
    private this()
    {
        settings ~= createSetting(Phrase.language, &getLanguage, { return Dictionary.all_languages; }, &setLanguage);
        settings ~= createSetting(Phrase.default_interface, &getDefaultGuiName, &getAllGuiNames, &setDefaultGui);
        settings ~= createSetting(Phrase.password, { return cast(char[]) null; }, &setPassword);
        
        //only to see for admin
        hidden_settings ~= createSetting(Phrase.Home_Directory, &getDirectory, &setDirectory);
        hidden_settings ~= createSetting(Phrase.Disable_Account, &is_disabled);
        
        //global settings
        if(is_admin)
        {
            settings ~= createSetting(Phrase.auto_disconnect_clients, &ClientManager.max_client_age);
            settings ~= createSetting(Phrase.basic_auth, &Main.use_basic_auth);
            settings ~= createSetting(Phrase.enable_ssl, { return Main.isSSL(); }, (bool b) { Main.setSSL(b); });
            settings ~= createSetting(Phrase.Exit_Program, { return false; }, (bool exit) { if(exit) Main.shutdownApplication(); });
        }
    }
    
    private void load(Storage s)
    {
        s.load("id", &id);
        s.load("username", &username);
        s.load("password", &password_hash);
        s.load("is_admin", &is_admin);
        s.load("language", (char[] str)
            {
                auto lang = Dictionary.getLanguage(str);
                if(lang) language = lang;
            }
        );
        s.load("is_disabled", &is_disabled);
        s.load("directory", &setDirectory);
        s.load("default_gui", &setDefaultGui);
        s.load("clients", (uint[] ids) { client_ids.add(ids); });
        
        if(auto guis_storage = s["guis"])
        {
            this.guis = Main.getGuiInstances(guis_storage);
        }
    }
    
    void save(Storage s)
    {
        assert(username.length);
        assert(id);
        
        s.save("id", &id);
        s.save("username", &username);
        s.save("password", &password_hash);
        s.save("is_admin", &is_admin);
        s.save("language", &language.code);
        s.save("is_disabled", &is_disabled);
        s.save("directory", &getDirectory);
        if(this.guis.length)
            s.save("default_gui", &guis[0].getGuiName);
        
        s.save("clients", &client_ids.slice);
    
        auto gui_settings = new Storage();
        foreach(gui; guis)
        {
            auto storage = new Storage();
            gui.save(storage);
            
            gui_settings[gui.getGuiName] = storage;
        }
        s["guis"] = gui_settings;
    }
    
private:

    public Main.Gui[] getGuis()
    {
        return guis;
    }

    char[] getDefaultGuiName()
    {
        return guis.length ? guis[0].getGuiName() : null;
    }
    
    char[][] getAllGuiNames()
    {
        char[][] names = new char[][](guis.length);
        
        foreach(i, gui; guis)
        {
            names[i] = gui.getGuiName();
        }
        
        return names;
    }
    
    void setDefaultGui(char[] name)
    {
        auto pos = findIf(guis, (Main.Gui gui)
            {
                return gui.getGuiName() == name;
            }
        );
        
        //move selected gui to front
        if(pos && pos < guis.length)
        {
            Utils.swapValues(guis, cast(size_t) 0, cast(size_t) pos);
        }
    }
    
    void setPassword(char[] password)
    {
        if(password.length)
        {
            this.password_hash = Utils.md5_hex(password);
            Logger.addInfo("MainUser: Password was set.");
        }
    }
    
    Phrase getLanguage()
    {
        return language.id;
    }
    
    void setLanguage(Phrase phrase)
    {
        auto lang = Dictionary.getLanguage(phrase);
        if(lang)
        {
            language = lang;
        }
        else
        {
            Logger.addError("MainUser: Unknown language identifier {}.", cast(uint) phrase);
        }
    }
    
    public char[] getDirectory()
    {
        return files ? files.toString() : null;
    }
    
    /*
    * Set directory for file browser.
    */
    void setDirectory(char[] path)
    {
        if(path.length == 0)
        {
            this.files = null;
            return;
        }
        
        path = Path.standard(path);
        
        if(path[$-1] != '/')
        {
            path ~= '/';
        }
        
        if(Path.exists(path) && Path.isFolder(path))
        {
            this.files = new DiskFile(path);
        }
        else
        {
            Logger.addWarning("MainUser: Directory \"" ~ path ~ "\" does not exist!");
        }
    }

public:

    /*
    * Tells if this user account is disabled.
    */
    bool isDisabled()
    {
        return is_disabled;
    }

    char[] translate(Phrase phrase)
    {
        char[] text = language.dictionary[phrase];
        if(text.ptr) return text;
        
        //use english dictionary as fallback
        text = Dictionary.default_language.dictionary[phrase];
        if(text.ptr) return text;
        
        //if everything fails
        return Format("[{}]", phrase);
    }
    
    static char[] tr(Phrase phrase)
    {
        auto user = cast(MainUser) Main.getThreadOwner();
        if(user)
        {
            char[] text = user.language.dictionary[phrase];
            if(text.ptr) return text;
        }
        
        //use english dictionary as fallback
        char[] text = Dictionary.default_language.dictionary[phrase];
        if(text.ptr) return text;
        
        //if everything fails
        return Format("[{}]", phrase);
    }
    
    Phrase getLanguageId()
    {
        return language.id;
    }
    
    final class Message : Meta
    {
        uint id;
        char[] text;
        Meta_.Type type;
        uint last_changed;
        
        this(char[] text, Meta_.Type type)
        {
            static uint id_counter;
            this.id = ++id_counter;
            this.type = type;
            this.text = text;
            this.last_changed = (Clock.now - Time.epoch1970).seconds;
        }

        uint getId() { return id; }
        char[] getMeta() { return text; }
        uint getLastChanged() { return last_changed; }
        short getRating() { return 0; }
        Meta_.Type getType() { return type; }
        Meta_.State getState() { return Meta_.State.ANYSTATE; }
        Node getSource() { return null; }
        Metas getMetas() { return this; }
        //from Metas:
        void addMeta(Meta_.Type type, char[] value, int rating) {}
        void removeMeta(Meta_.Type type, uint id) {}
        uint getMetaCount(Meta_.Type type, Meta_.State state) { return 0; }
        Meta[] getMetaArray(Meta_.Type type, Meta_.State state, uint age) { return null; }
    }
    
    uint getId() { return id; }
    char[] getName() { return username; }
    char[] getPassword() { return password_hash; }
    
    bool isAdmin()
    {
        return is_admin;
    }
    
    User_.Type getType()
    {
        return is_admin ? User_.Type.ADMIN : User_.Type.USER;
    }
    
    User_.State getState()
    {
        return User_.State.ENABLED;
    }
    
    private Client getClient(uint id)
    {
        auto user = cast(MainUser) Main.getThreadOwner();
        if(!user.is_admin && !client_ids.contains(id))
            return null;
        
        return ClientManager.getClient(id);
    }
    
    void connect(uint id)
    {
        connect(Node_.Type.CORE, id);
    }
    
    void disconnect(uint id)
    {
        disconnect(Node_.Type.CORE, id);
    }
    
    Files getFiles() { return files ? (files.exists() ? files : null) : null; } //access disk files
    Nodes getNodes() { return this; } //access clients
    Settings getSettings() { return this; } //access local user settings
    Metas getMetas() { return this; } //access local user to local user chat

/* from Users interface */
    
    uint addUser(User_.Type type, char[] name)
    {
        if(!is_admin)
        {
            Logger.addWarning("MainUser: Only admins can add users!");
            return 0;
        }
        
        auto user = UserManager.addUser(name);
        return user ? user.getId : 0;
    }
    
    void renameUser(uint id, char[] new_name)
    {
        if(!is_admin)
        {
            Logger.addWarning("MainUser: Only admins can rename users!");
            return;
        }
        
        auto user = UserManager.getUser(id);
        if(user && new_name.length)
        {
            UserManager.renameUser(user.username, new_name);
        }
    }
    
    void removeUser(uint id)
    {
        if(!is_admin)
        {
            Logger.addWarning("MainUser: Only admins can remove users!");
            return;
        }
        
        if(auto user = UserManager.getUser(id))
        {
            UserManager.remove(user);
            SessionManager.remove(user);
        }
    }
    
    void setUserPassword(uint id, char[] password)
    {
        if(!is_admin)
        {
            Logger.addWarning("MainUser: Only admins can set password for other users!");
            return;
        }
        
        auto user = UserManager.getUser(id);
        if(user)
        {
            user.password_hash = Utils.md5_hex(password);
        }
    }
    
    uint getUserCount()
    {
        return is_admin ? UserManager.getUserCount : 0;
    }
    
    User getUser(uint id)
    {
        if(this.id == id) return this;
        
        if(!is_admin)
        {
            Logger.addWarning("MainUser: Only admins can access another user!");
            return null;
        }
        
        return UserManager.getUser(id); 
    }
    
    User[] getUserArray()
    {
        if(is_admin)
        {
            return UserManager.getUserArray();
        }
        else
        {
            return [this];
        }
    }
    
/* from Nodes interface */

    void connect(Node_.Type type, uint id)
    {
        if(type != Node_.Type.CORE)
            return;
        
        auto client = getClient(id);
        if(client) client.connect();
    }
    
    void disconnect(Node_.Type type, uint id)
    {
        if(type != Node_.Type.CORE)
            return;
        
        auto client = getClient(id);
        if(client) client.disconnect();
    }

    //we use a small hack to add different clients that are
    //not part of Node_.Type
    Node addNode(Node_.Type type, char[] host, ushort  port, char[] user, char[] pass)
    {
        Node node = null;
        if(type > Node_.Type.max && is_admin)
        {
            node = ClientManager.addClient(cast(Client.Type) type, host, port, user, pass);
            if(node)
            {
                client_ids.add(node.getId);
            }
        }
        return node;
    }
    
    void addLink(char[] link) {}
    
    void removeNode(Node_.Type type, uint id)
    {
        if(type != Node_.Type.CORE) return;
        
        if(!client_ids.contains(id))
        {
            return;
        }
        
        ClientManager.removeClient(id);
        client_ids.remove(id);
    }

    uint getNodeCount(Node_.Type type, Node_.State state)
    {
        if(type != Node_.Type.CORE) return 0;
        
        return client_ids.length;
    }
    
    Node getNode(Node_.Type type, uint id)
    {
        if(type == Node_.Type.CORE) 
        {
            return getClient(id);
        }
        return null;
    }
    
    Node[] getNodeArray(Node_.Type type, Node_.State state, uint age)
    {
        if(type != Node_.Type.CORE) return null;
        
        Client[] clients = ClientManager.getClients(client_ids.slice);
        return Utils.filter!(Node)(clients, state, age);
    }

/* from Metas interface */
    
    void addMeta(Meta_.Type type, char[] text, int rating)
    {
        static Message overflow;
        if(overflow is null)
            overflow = new Message("Cannot accept more messages. New messages will be dropped.", Meta_.Type.ERROR);
        
        auto msg = new Message(text, type);
        
        //cleanup old messages every 20 messages, TODO: delete oldest
        if(logs.length > 20)
        {
            uint now = (Clock.now - Time.epoch1970).seconds;
            foreach(msg ; logs)
            {
                if(now - msg.getLastChanged > 60*10)
                {
                    logs.remove(msg.getId);
                }
            }
            
            if(logs.length > 20)
            {
                logs[overflow.getId] = overflow;
                return;
            }
            else
            {
                logs.remove(overflow.getId);
            }
        }
        
        logs[msg.getId] = msg;
    }
    
    void removeMeta(Meta_.Type type, uint id)
    {
        if(type == Meta_.Type.LOG)
        {
            logs.remove(id);
        }
    }
    
    uint getMetaCount(Meta_.Type type, Meta_.State state)
    {
        if(type == Meta_.Type.LOG) return logs.length;
        return logs.length; //to check for for any messages 
    }
    
    Meta[] getMetaArray(Meta_.Type type, Meta_.State state, uint age)
    {
        if(type == Meta_.Type.LOG) return Utils.filter!(Meta)(logs, state, age);
        return null;
    }
    
/* from Settings interface */

    Setting getSetting(uint id)
    {
        foreach(setting; settings)
        {
            if(setting.getId == id)
                return setting;
        }
        
        if(accessByAdmin())
        {
            foreach(setting; hidden_settings)
            {
                if(setting.getId == id)
                    return setting;
            }
        }
        return null;
    }
    
    private static bool accessByAdmin()
    {
        auto session = SessionManager.getThreadSession();
        auto user = session ? session.getUser() : null;
        return user ? user.is_admin : false;
    }
    
    void setSetting(uint id, char[] value)
    {
        foreach(setting; settings)
        {
            if(setting.getId == id)
            {
                setting.setSetting(id, value);
            }
        }
        
        if(accessByAdmin())
        {
            foreach(setting; hidden_settings)
            {
                if(setting.getId == id)
                {
                    setting.setSetting(id, value);
                }
            }
        }
    }
    
    uint getSettingCount()
    {
        if(accessByAdmin())
        {
            return settings.length + hidden_settings.length;
        }
        return settings.length;
    }
    
    Setting[] getSettingArray()
    {
        if(accessByAdmin())
        {
            return Utils.convert!(Setting)(settings ~ hidden_settings);
        }
        return Utils.convert!(Setting)(settings);
    }
}
