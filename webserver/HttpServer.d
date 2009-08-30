module webserver.HttpServer;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import tango.io.Stdout;
import tango.io.device.File;
import tango.core.Thread;
import tango.core.Array;
import tango.net.InternetAddress;
import tango.net.device.Socket;
import tango.net.device.SSLSocket;
import tango.net.util.PKI;
import tango.math.random.Kiss;
import tango.text.Ascii : toLower;
import tango.time.Time;
import tango.core.Exception;

import webserver.HttpRequest;
import webserver.HttpResponse;

static import Utils = utils.Utils;
static import Base64 = tango.io.encode.Base64;
import webcore.Logger;


final class HttpServer
{
    alias void function(HttpRequest, HttpResponse) Handler;
    alias void delegate(void delegate()) AddTask;
    alias void* function(Socket) SocketAuth;
    
    static char[] server_name = "SimpleHttpServer";
    
private:

    SocketAuth socket_auth;
    Handler handler;

    ushort port; //host port
    char[] mask; //host mask, e.g. "0.0.0.0"

    ServerSocket server_socket;
    Socket[] sockets;
    AddTask addTask;
    
    SSLCtx ssl_ctx;

    static void appendSlash(char[] path)
    {
        if(path.length && path[$-1] != '/')
        {
            path ~= "/";
        }
    }
    
    static final class TaskWrapper
    {
        Socket socket;
        
        HttpServer server;
        HttpRequest request;
        HttpResponse response;
        
        this(HttpServer server)
        {
            this.server = server;
            this.request = new HttpRequest();
            this.response = new HttpResponse();
        }
        
        void work()
        {
            try
            {
                request.reset();
                response.reset();
                
                server.process(request, socket, response);
                
                socket.shutdown();
                socket.close();
            }
            catch(Exception e)
            {
            }
            
            socket = null;
        }
    }
    
    TaskWrapper[] tasks;
    
    //wrap socket in task wrapper
    void delegate() wrap(Socket socket)
    {
        //search for unused task token
        for(auto i = 0; i < tasks.length; ++i)
        {
            if(tasks[i].socket is null)
            {
                tasks[i].socket = socket;
                return &tasks[i].work;
            }
        }
        
        //create new task token
        if(tasks.length < 16)
        {
            auto task = new TaskWrapper(this);
            task.socket = socket;
            tasks ~= task;
            return &task.work;
        }
        
        //all tokens in use => abort connection
        try
        {
            socket.shutdown();
            socket.close();
        }
        catch(Exception e)
        {
        }
        
        return null;
    }

public:

    this(Handler handler, char[] mask, ushort port, AddTask addTask)
    {
        this.handler = handler;
        this.mask = mask;
        this.port = port;
        this.addTask = addTask;
    }
    
    static void setTempDirectory(char[] dir)
    {
        appendSlash(dir);
        HttpRequest.temp_directory = dir;
    }
    
    static char[] getTempDirectory()
    {
        return HttpRequest.temp_directory;
    }

    synchronized void setSSL(bool enable)
    {
        //nothing changes
        if((enable && ssl_ctx) || (!enable && !ssl_ctx))
            return;
        
        if(!enable)
        {
            ssl_ctx = null;
            return;
        }
        
        const char[] public_pem_name = "public.pem";
        const char[] private_pem_name = "private.pem";
        
        void[] public_pem = null;
        void[] private_pem = null;
        
        try
        {
            public_pem = File.get(public_pem_name);
            private_pem = File.get(private_pem_name);
        }
        catch(Exception e)
        {
            Logger.addWarning("HttpServer: {}", e.toString);
        }
        
        PrivateKey pkey;
        Certificate cert;
        
        if(public_pem.length && private_pem.length)
        {
            Logger.addInfo("HttpServer: Load '{}' and '{}' for SSL.", public_pem_name, private_pem_name);
            pkey = new PrivateKey(cast(char[]) private_pem);
            cert = new Certificate(cast(char[]) public_pem);
        }
        else
        {
            Logger.addInfo("HttpServer: Create self-signed SSL certificate.");
            cert = new Certificate();
            pkey = new PrivateKey(2048);
            cert.privateKey = pkey;
            cert.serialNumber = Kiss.instance.natural();
            cert.dateBeforeOffset = TimeSpan.zero;
            cert.dateAfterOffset = TimeSpan.fromDays(365);
            cert.setSubject("CA", "Somewhere", "Place", "None", "SSL cert dummy", "no unit", "null@void.com");
            cert.sign(cert, pkey);
            
            try
            {
                Logger.addInfo("HttpServer: Write " ~ public_pem_name ~ " and " ~ private_pem_name ~ ".");
                File.set(public_pem_name, cert.pemFormat);
                File.set(private_pem_name, pkey.pemFormat);
            }
            catch(Exception e)
            {
                Logger.addWarning("HttpServer: {}", e.toString);
            }
        }
        
        auto sslCtx = new SSLCtx();
        sslCtx.certificate = cert;
        sslCtx.privateKey = pkey;
        sslCtx.checkKey();

        this.ssl_ctx = sslCtx;
    }
    
    bool isSSL()
    {
        return (ssl_ctx !is null);
    }
    
    void setSocketAuth(SocketAuth socket_auth)
    {
        this.socket_auth = socket_auth;
    }
    
    void start()
    {
        Logger.addInfo("HttpServer: Temp directory is '{}'.", getTempDirectory);
        Logger.addInfo("HttpServer: Start listening socket on port '{}', subnet mask '{}'.", port, mask);
        
        server_socket = new ServerSocket(new IPv4Address(mask, port), 32, true);
        Socket socket = null;
        
        try while(true)
        {
            auto server = server_socket;
            if(server is null) break;
            
            if(auto ctx = ssl_ctx)
            {
                auto ssl_socket = new SSLSocket(false);
                socket = server.accept(ssl_socket);
                ssl_socket.setCtx(ctx, false);
            }
            else
            {
                socket = new Socket();
                socket = server.accept(socket);
            }
            
            if(socket is null) break;
            auto task = wrap(socket);
            if(task) addTask(task);
        }
        catch(Exception e)
        {
            Logger.addError("HttpServer: {}", e.toString);
        }
    }

    void stop()
    {
        server_socket.socket.shutdown( SocketShutdown.BOTH );
        server_socket = null;
        
        version(Windows)
        {
            //we must interrupt server.accept() manually on windows :/
            auto sock = new Socket();
            sock.connect(new InternetAddress("127.0.0.1", port));
        }
    }
    
private:
    
    void process(HttpRequest req, Socket socket, HttpResponse res)
    {
        uint keep_alive = uint.max;
        const uint default_keep_alive = 1_000;
        const uint max_keep_alive = 1_000;
        bool ssl_enabled = (cast(SSLSocket) socket) !is null;
        
        debug(HttpServer)
        {
            uint ip = (cast(IPv4Address) socket.socket.remoteAddress).addr;
            Logger.addDebug("HttpServer: Connection from IP {}.", Utils.toIpString(ip));
        }
        
        //set initial timeout
        if(ssl_enabled)
        {
            socket.timeout = 30_000;
        }
        else
        {
            socket.timeout = 500;
        }
        
        if(socket_auth)
        {
            auto token = socket_auth(socket);
            
            if(token is null)
                return;
        }
        
        //did the request passed before?
        bool passed = false;
        
        while(server_socket)
        {
            req.init(socket);
            res.init(socket);
            
            try //socket throws on timeout!?
            {
                req.receive();
            }
            catch(Exception e) {}
            
            //check if connection was closed or the header was invalid
            if(req.getHttpMethod() == HttpMethod.UNKNOWN)
            {
                if(!passed)
                {
                    res.setCode(HttpResponse.Code.BAD_REQUEST);
                    res.send();
                }
                
                return;
            }
            
            passed = true;
            
            char[] connection = toLower (
                req.getHeader("Connection")
            );
            
            //we disable non blocking io for SSL
            if(!ssl_enabled)
            {
                //set keep alive
                if(find(connection, "keep-alive") != connection.length)
                {
                    keep_alive = req.getHeader!(uint)("Keep-Alive", 0);
                    if(keep_alive > max_keep_alive)
                    {
                        keep_alive = max_keep_alive;
                    }
                }
                else
                {
                    keep_alive = default_keep_alive;
                }
                
                if(keep_alive == 0)
                {
                    //na, we don't want to allow no timeout, this is the max we give
                    socket.timeout = 1_000;
                }
                else
                {
                    socket.timeout = keep_alive;
                }
            }
        
            if(find(connection, "close") != connection.length)
            {
                keep_alive = 0;
            }
            
            handler(req, res);
            
            try //just in case
            {
                res.send();
            }
            catch(Exception e) {}
           
            if(keep_alive == 0)
            {
                break;
            }
            
            req.reset();
            res.reset();
        }
    }
}
