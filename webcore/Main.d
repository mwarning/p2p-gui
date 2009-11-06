module webcore.Main;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import tango.core.Array;
import tango.io.Stdout;
import tango.io.FilePath;
import tango.io.Path;
import tango.sys.Environment;
import tango.core.Thread;
import tango.core.ThreadPool;
import tango.text.Util;
import tango.time.Clock;
import tango.sys.Environment;
import tango.math.random.Kiss;
static import Convert = tango.util.Convert;
static import Base64 = tango.io.encode.Base64;
static import PathUtil = tango.util.PathUtil;

version(Posix)
{
    import tango.stdc.posix.stdio;
    import tango.stdc.posix.signal;
    import tango.stdc.posix.sys.stat;
    import tango.stdc.posix.unistd;
}

version(Windows)
{
    import tango.sys.win32.UserGdi;
    
    extern(Windows) HWND GetConsoleWindow();
}

import webserver.HttpServer;
import webserver.HttpResponse;
import webserver.HttpRequest;

version (JAY_GUI) import webguis.jay.JayGui;
version (PLEX_GUI) import webguis.plex.PlexGui;
version (CLUTCH_GUI) import webguis.clutch.ClutchGui;

import api.Client;
import api.Node;
import api.File;
import api.Setting;
import api.Meta;
import api.User;
import api.Host;

static import Utils = utils.Utils;
static import GeoIP = utils.GeoIP;
static import Timer = utils.Timer;
static import Selector = utils.Selector;
import webcore.Webroot;
import webcore.ClientManager;
import webcore.DiskFile;
import webcore.MainUser;
import webcore.UserManager;
import webcore.Dictionary;
import webcore.SessionManager;
import webcore.Session;
import webcore.Logger;
import utils.Storage;


public static void setThreadOwner(Object object = null)
{
    Thread.setLocal(1, cast(void*) object);
}

public static Object getThreadOwner()
{
    return cast(Object) Thread.getLocal(1);
}


/*
* Shutdown this application.
*/
public void shutdownApplication()
{
    auto user = cast(MainUser) getThreadOwner();
    if(user && user.isAdmin)
    {
        Logger.addInfo("Main: Manual shutdown by '{}'.", user.getName);
        server.stop();
    }
}


interface Gui
{
    char[] getGuiName();
    
    void save(Storage);
    void load(Storage);
    
    /*
    * Try to process request.
    * Return true if request was accepted.
    */
    bool process(HttpRequest req, Session session, HttpResponse res);
}

/*
* Get a fresh instance for every gui.
*/
public Gui[] getGuiInstances(Storage s)
{
    Gui[] guis;
    foreach(char[] gui_name, Storage settings; s)
    {
        switch(gui_name)
        {
            version(PLEX_GUI)
            {
                case "Plex":
                    guis ~= new PlexGui(settings);
                    break;
            }
            
            version(CLUTCH_GUI)
            {
                case "Clutch":
                    guis ~= new ClutchGui(settings);
                    break;
            }
            
            version(JAY_GUI)
            {
                case "Jay":
                    if(disable_json == false)
                    {
                        guis ~= new JayGui(settings);
                    }
                    else
                    {
                        Logger.addWarning("Main: Cannot load Jay gui; JSON interface is disabled");
                    }
                    break;
            }
            
            default:
                Logger.addWarning("Main: Unsupported gui name found '{}'.", gui_name);
        }
    }
    
    return guis;
}

bool isSSL()
{
    return server.isSSL();
}

void setSSL(bool b)
{
    server.setSSL(b);
}

public
{
    bool use_basic_auth = false;
    char[] base_dir;
}

ThreadPool!() pool;

private
{
    HttpServer server;

    Gui function()[] gui_loaders;
    
    const char[] webgui_file = "webgui.json";
    
    //web server defaults
    ushort server_port = 8080;
    char[] server_mask = "0.0.0.0";
    bool ssl_enabled = false;
    bool disable_json = false;
    char[] basic_realm = "Authentication required"; //realm for basic access authentication
}

private MainUser checkBasicAuth(HttpRequest req)
{
    char[] auth = req.getHeader("Authorization");
    if(!auth.length)
    {
        //common case to trigger auth request
        debug(HttpServer)
            Logger.addDebug("HttpServer: No authorization provided!");
        
        return null;
    }
    
    uint pos = find(auth, "Basic ");
    if(pos == auth.length)
    {
        debug(HttpServer)
            Logger.addDebug("HttpServer: No Basic authorization provided!");
        
        return null;
    }
    
    char[256] buf;
    char[] token = auth[pos+6..$];
    
    if(buf.length < Base64.allocateEncodeSize(token.length))
    {
        return null;
    }
    
    try
    {
        token = cast(char[]) Base64.decode(token, cast(ubyte[]) buf);
    }
    catch(Object o)
    {
        return null;
    }
    
    pos = find(token, ':');
    if(pos == token.length)
    {
        debug(HttpServer)
            Logger.addDebug("HttpServer: Invalid Basic authorization format!");
        return null;
    }
    char[] user_login = token[0..pos];
    char[] user_pass = token[pos+1..$];
    
    auto user = UserManager.getUser(user_login);
    
    if(user && user.getPassword() == Utils.md5_hex(user_pass))
    {
        return user;
    }
    else
    {
        return null;
    }
}

private void sendBasicAuthRequest(HttpResponse res)
{
    /*
    static const char[] unauthorized_page =
        "<!DOCTYPE HTML>"
        "<html>"
        "<head><title>401 Unauthorized</title></head>"
        "<h1>401 Unauthorized</h1>"
        "<p>Please login using a valid username and password.</p>"
        "</html>";
    */
    res.setContentType("text/html");
    res.setCode(HttpResponse.Code.UNAUTHORIZED);
    res.addHeader("WWW-Authenticate: Basic realm=\"" ~ basic_realm ~ "\"");
    res.addHeader("Connection: close");
    //auto o = res.getWriter();
    //o(unauthorized_page);
}

private void sendLoginPage(HttpResponse res, char[] uri)
{
    /*
    if(uri == "/index.html")
    {
        res.setCode(HttpResponse.Code.OK);
        Webroot.getFile(res, "/index.html");
    }
    else //redirect
    {
        res.setCode(HttpResponse.Code.FOUND);
        res.addHeader("Location: /index.html");
    }*/
    
    //We use this to preserve the URI in the browser line to act a referrer (for login.html).
    //A redirect would reset it.
    res.setCode(HttpResponse.Code.OK);
    res.addHeader("Cache-Control: no-store");
    Webroot.getFile(res, "/index.html");
}

private MainUser checkLoginAuth(HttpRequest req)
{
    char[] user_login = req.getParameter("user_login");
    char[] user_pass = req.getParameter("user_pass");
    
    auto user = UserManager.getUser(user_login);
    
    if(user && user.getPassword() == Utils.md5_hex(user_pass))
    {
        return user;
    }
    else
    {
        return null;
    }
}

/*
* Set Cookie containing a session id.
*/
private char[] setSessionId(HttpResponse res)
{
    ulong id = Kiss.instance.natural();
    id = id << 32;
    
    //inlcude ip in session id when SSL is disabled,
    //for enhanced authorization
    if(server.isSSL() == false)
    {
        id += res.getRemoteIP();
    }
    else
    {
        id += Kiss.instance.natural();
    }
    
    char[] sid = Utils.toHexString(id);
    char[] max_age = Utils.toString(SessionManager.max_session_age);
    
    res.addHeader (
        "Set-Cookie: sid=\"" ~ sid ~ "\";"
        "Path=\"/\";"
        "Max-Age=" ~ max_age ~ ";"
    );
    
    return sid;
}

/*
* Extract session id from cookie or generate a new (random) session id.
*/
private char[] getSessionId(HttpRequest req)
{
    char[] cookie = req.getHeader("Cookie");
    
    uint start = 5 + find(cookie, "sid=\"");
    if(start >= cookie.length)
    {
        return null;
    }
    
    uint end = locate(cookie, '"', start);
    if(end >= cookie.length)
    {
        return null;
    }
    
    char[] sid = cookie[start..end];
    
    if(sid.length != 16)
    {
        return null;
    }
    
    //check ip part in session id when SSL is disabled,
    //for enhanced authorization
    if(server.isSSL() == false)
    {
        uint ip = req.getRemoteIP();
        if(sid[8..16] != Utils.toHexString(ip))
        {
            return null;
        }
    }
    
    return sid;
}

/*
* This function is called by the webserver for every request.
*/
private void service(HttpRequest req, HttpResponse res)
{
    auto method = req.getHttpMethod();
    if(method != HttpMethod.GET && method != HttpMethod.POST)
    {
        res.setCode(HttpResponse.Code.NOT_IMPLEMENTED);
        return;
    }
    
    char[] uri = req.getUri();
    char[] sid = getSessionId(req);
    
    debug
    {
        Logger.addDebug("Main: sid '{}' uri '{}'", sid, uri);
    }
    
    Session session = SessionManager.get(sid);
    MainUser user = null;
    
    if(session)
    {
        user = session.getUser();
        
        //user shouldn't be null at this point
        if(user is null || user.isDisabled)
        {
            SessionManager.remove(sid);
            session = null;
        }
    }
    
    if(session is null)
    {
        sid = setSessionId(res);
        
        if(use_basic_auth)
        {
            user = checkBasicAuth(req);
            
            if(user && user.isDisabled)
            {
                user = null;
            }
            
            if(user is null)
            {
                sendBasicAuthRequest(res);
                return;
            }
        }
        else
        {
            user = checkLoginAuth(req);
            
            if(user && user.isDisabled)
            {
                user = null;
            }
            
            if(user is null)
            {
                sendLoginPage(res, uri);
                return;
            }
        }
        
        session = new Session(sid, user);
        SessionManager.add(session);
    }
    
    assert(session);
    assert(user);
    
    scope(exit)
    {
        SessionManager.setThreadSession(null);
        setThreadOwner(null);
    }
    
    //attach session&user to thread local storage
    SessionManager.setThreadSession(session);
    setThreadOwner(user);
    
    foreach(gui; session.getGuis)
    {
        //the first accepting gui processes the request
        bool ok = gui.process(req, session, res);
        if(ok)
        {
            return;
        }
    }
    
    Webroot.getFile(res, uri);
}

/*
* Get base_dir and set Webroot.use_disk.
* Called once at program startup.
*/
private char[] setupBaseDir(char[] preset_dir)
{
    const char[] settings_sub_dir = ".p2p-gui/";
    const char[] webroot_sub_dir = "webroot/";
    
    char[] working_dir = Environment.cwd();
    char[] base_dir;
    
    if(preset_dir.length)
    {
        preset_dir = standard(preset_dir); //replace '\' on Windows
        preset_dir = PathUtil.normalize(preset_dir ~ "/");
    }
    
    //set base directory
    if(preset_dir.length)
    {
        if(!FilePath(preset_dir).exists)
        {
            throw new Exception("Directory '" ~ preset_dir ~ "' doesn't exist!");
        }
        
        base_dir = preset_dir;
    }
    else if(FilePath(working_dir ~ webgui_file).exists)
    {
        base_dir = working_dir;
    }
    else
    {
        version(Windows)
        {
            char[] home = Environment.get("USERPROFILE");
            if(home.length == 0)
                home = Environment.get("HOMEPATH");
        }
        else
        {
            char[] home = Environment.get("HOME");
        }
        
        if(home.length == 0)
        {
            throw new Exception("Can't get users home directory!");
        }
        
        Utils.appendSlash(home);
        base_dir = home ~ settings_sub_dir;
    }
    
    //create base directory if it doesn't exist
    scope path = new FilePath(base_dir);
    if(!path.exists)
    {
        Logger.addInfo("Main: Create settings directory '{}'.", base_dir);
        path.create();
    }
    
    return base_dir;
}

/*
Detect the directory were the webroot is located.
*/
private char[] getWebrootDir(char[] base_dir)
{
    assert(base_dir.length && base_dir[$-1] == '/');
    
    const char[] webroot_sub_dir = "webroot/";
    
    //is webroot in the base_dir directory?
    if(FilePath(base_dir ~ webroot_sub_dir).exists)
    {
        return base_dir ~ webroot_sub_dir;
    }
    
    char[] working_dir = Environment.cwd();
    
    //is webroot in the working directory?
    if(FilePath(working_dir ~ webroot_sub_dir).exists)
    {
        return working_dir ~ webroot_sub_dir;
    }
    //no webroot found, use included webroot
    else if(Webroot.included_files.length) 
    {
        return null;
    }
    else
    {
        throw new Exception("Directory '" ~ base_dir ~  webroot_sub_dir ~ "' not found.");
    }
}


private void loadGlobalSettings()
{
    auto s = Storage.loadFile(webgui_file);
    
    s.load("server_port", &server_port);
    s.load("server_netmask", &server_mask);
    s.load("server_name", &HttpServer.server_name);
    s.load("server_ssl_enabled", &ssl_enabled);
    s.load("use_basic_auth", &use_basic_auth);
    s.load("auto_disconnect_clients", &ClientManager.max_client_age);
    s.load("basic_realm", &basic_realm);
}

private void saveGlobalSettings()
{
    auto s = new Storage();
    
    s.save("server_port", &server_port);
    s.save("server_netmask", &server_mask);
    s.save("server_name", &HttpServer.server_name);
    s.save("server_ssl_enabled", &ssl_enabled);
    s.save("use_basic_auth", &use_basic_auth);
    s.save("auto_disconnect_clients", &ClientManager.max_client_age);
    s.save("version", Host.main_version); //for diagnostics
    s.save("basic_realm", &basic_realm);
    
    Storage.saveFile(webgui_file, s);
}

private void main(char[][] args)
{
    version(Posix)
    {
        //prevent exit on file upload
        sigaction_t sa;
        sa.sa_handler = SIG_IGN;
        sigaction(SIGPIPE, &sa, null);
        
        //allow clean shutdown on signal
        static extern(C) void shutdown(int sig)
        {
            if(server) server.stop();
        }
        
        signal(SIGINT, &shutdown);
        signal(SIGTERM, &shutdown);
    }
    
    version(Windows)
    {
        //allow clean shutdown on signal
        static extern(Windows) WINBOOL shutdown(uint sig)
        {
            if(server) server.stop();
            return true;
        }
        
        SetConsoleCtrlHandler(&shutdown, true);
    }
    
    //global hook :(
    Host.saveFile = &Session.setSource;
    
    Host.main_version = "0.2.0";
    Host.main_name = "P2P-GUI";
    Host.main_weblink = "http://p2p-gui.sourceforge.net";
    
    bool run_as_daemon = false;
    char[] preset_dir = null;
    
    //parse arguments
    for(auto i = 1; i < args.length; i++)
    {
        char[] getArg()
        {
            if(i + 1 < args.length && args[i+1][0] != '-')
            {
                i++;
                return args[i];
            }
            return null;
        }
        
        switch(args[i])
        {
        case "-b":
            //use/set base directory
            preset_dir = getArg();
            if(preset_dir.length == 0)
            {
                Stdout("(E) Need argument for -b!").newline;
                return;
            }
            break;
        case "-d":
            run_as_daemon = true;
            break;    
        version(JAY_GUI) //uses JsonRPC interface (Clutch doesn't)
        {
        case "-no-json":
            disable_json = true;
            break;
        }
        case "-p":
            //set web server port
            server_port = Convert.to!(ushort)(getArg, 0);
            if(server_port == 0)
            {
                Stdout("(E) Invalid value for -p!").newline;
                return;
            }
            break;
        case "-m":
            //set web server subnet mask
            server_mask = getArg();
            break;
        case "-t":
            //set temp directory for webserver
            char[] tmp = getArg();
            if(tmp.length == 0)
            {
                Stdout("(E) Invalid value for -t!").newline;
                return;
            }
            server.setTempDirectory(tmp);
            break;
        case "-v":
            //print out version
            Stdout(Host.main_name)(" (")(Host.main_version)(")\n");
            return;
        case "--write-out-files":
            //write files included in the binary to disk
            char[] dir = getArg();
            if(dir.length == 0)
                dir = "webroot/";
            Webroot.writeToDisk(dir);
            return;
        case "--help":
        case "-h":
            //print out help
            Stdout(Host.main_name)(" ")(Host.main_version)(" - Multi P2P Client Web UI. [");
        
            //print list of supported client interfaces
            foreach(k, ref info; Host.client_infos)
            {
                if(k) Stdout(", ");
                Stdout(info.name);
            }
            Stdout("]\n");
            
            Stdout("Copyright (c) 2007-2009 Moritz Warning\n\n");
            Stdout("Usage: ")(args[0])(" [options]\n");
            Stdout("Options:\n");
            Stdout("-b\t\t\tSet base directory (for settings, webroot etc). ('")(base_dir)("')\n");
            version(Posix)
            {
                Stdout("-d\t\t\tRun as daemon.\n");
            }
            Stdout("-h\t\t\tDisplay this help; also --help.\n");
            version(JAY_GUI)
            {
                Stdout("-no-json\t\tDisable JSON interface.\n");
            }
            Stdout("-m\t\t\tSet the subnet mask for the web server. ('")(server_mask)("')\n");
            Stdout("-p\t\t\tSet the port for the web server. (")(server_port)(")\n");
            Stdout("-t\t\t\tSet the temp directory for the web server. ('")(HttpServer.getTempDirectory)("')\n");
            Stdout("-v\t\t\tPrint out version.\n");
            Stdout("--write-out-files\tWrite files included into the binary to disk '--write-out-files [<directory>]'.\n");
            Stdout("--copyright\t\tPrints the programs license.\n");
            return;
        case "--copyright":
            Stdout(copyright_terms).newline;
            return;
        default:
            Stdout("Unknown parameter '")(args[i])("'.\n");
            return;
        }
    }
    
    Logger.addInfo("Main: Starting up.");
    
    base_dir = setupBaseDir(preset_dir);
    Webroot.webroot_dir = getWebrootDir(base_dir);
    
    //change working directory to 
    Logger.addInfo("Main: Set working directory '{}'.", base_dir);
    Environment.cwd(base_dir);
    
    Logger.addInfo("Main: JSON interface is " ~ (disable_json ? "disabled." : "enabled."));
    
    //load settings
    Logger.addInfo("Main: Load globals from '{}'.", webgui_file);
    loadGlobalSettings();
    
    Logger.addInfo("Main: Load clients from '{}'.", ClientManager.webclients_file);
    ClientManager.loadClientsSettings();
    
    Logger.addInfo("Main: Load users from '{}'.", UserManager.webusers_file);
    UserManager.loadUsersSettings();
    
    if(Webroot.webroot_dir)
    {
        Logger.addInfo("Main: Serve files from '{}'.", Webroot.webroot_dir);
    }
    else
    {
        Logger.addInfo("Main: Serve files from [binary].");
    }
    
    //try to load the database
    GeoIP.loadDatabase("GeoIP.dat");
    
    if(run_as_daemon)
    {
        Logger.addInfo("Main: Going into daemon/background mode.");
        daemonize(false);
    }
    
    pool = new ThreadPool!()(6);
    
    //TODO: make non-blocking?
    pool.assign( {Selector.selector_loop(&pool.append);} );
    pool.assign( {Timer.timer_loop(&pool.append);} );
    
    //add default user
    if(UserManager.getUserCount == 0)
    {
        Logger.addInfo("Main: Create default user 'admin' with no password.");
        UserManager.addUser( new MainUser(1, "admin", null, true) ); //empty password
    }
    
    Timer.add(&ClientManager.disconnectOld, 1, 60); //check every minute
    Timer.add(&SessionManager.removeOld, 2, 60); //check every minute
    
    //start main loop
    server = new HttpServer(&service, server_mask, server_port, &pool.append);
    server.setSSL(ssl_enabled);
    
    //enter listener loop
    server.start();
    
    Logger.addInfo("Main: Shutting down.");
    ssl_enabled = server.isSSL();
    Timer.shutdown();
    Selector.shutdown();
    pool.shutdown();
    
    //save settings
    Logger.addInfo("Main: Save user settings.");
    UserManager.saveUsersSettings();
    
    Logger.addInfo("Main: Save client settings.");
    ClientManager.saveClientsSettings();
    
    Logger.addInfo("Main: Save global settings.");
    saveGlobalSettings();
}


/*
* Run current program as daemon (posix)
* or hide the window (windows)
*/
void daemonize(bool change_path = true)
{
    version(Posix)
    {
        //already a daemon
        if (getppid() == 1)
            return;

        auto pid = fork();
        if(pid < 0)
        {
            throw new Exception("Could not fork.");
        }
        
        if(pid > 0)
        {
            //exit parent
            _exit(0);
            return;
        }
        
        //reset file mask
        umask(0);
        
        //detach from shell
        if(setsid() < 0)
        {
            throw new Exception("Could not create new SID for child process.");
        }
        
        if(change_path && chdir("/") < 0)
        {
            throw new Exception("Could not change directory.");
        }

        //redirect to /dev/null
        freopen( "/dev/null", "r", stdin);
        freopen( "/dev/null", "w", stdout);
        freopen( "/dev/null", "w", stderr);
    }
    else version(Windows)
    {
        auto window = GetConsoleWindow();
        
        if(IsWindow(window))
        {
            //just hide the console window
            ShowWindow(window, SW_HIDE);
        }
        else
        {
            throw new Exception("Could not get Window");
        }
    }
    else
    {
        throw new Exception("Main: No daemonization supported for this platform.");
    }
}

const char[] copyright_terms =
"P2P-GUI Web Frontend\n"
"Copyright (C) 2007-2009 Moritz Warning\n"
"\n"
"This program is free software: you can redistribute it and/or modify\n"
"it under the terms of the GNU General Public License as published by\n"
"the Free Software Foundation, either version 3 of the License, or\n"
"(at your option) any later version.\n"
"\n"
"This program is distributed in the hope that it will be useful,\n"
"but WITHOUT ANY WARRANTY; without even the implied warranty of\n"
"MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the\n"
"GNU General Public License for more details.\n"
"\n"
"For a copy of the GNU General Public License\n"
"see <http://www.gnu.org/licenses/>.\n";
