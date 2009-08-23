module webcore.ClientManager;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import tango.time.Clock;
import tango.io.Stdout;
import Integer = tango.text.convert.Integer;

import api.Client;
import api.Node;
import api.Host;

static import Main = webcore.Main;
static import Utils = utils.Utils;
import webcore.Logger;
import utils.Storage;

version(MLDONKEY) import clients.mldonkey.MLDonkey;
version(AMULE) import clients.amule.aMule;
version(GIFT) import clients.gift.giFT;
version(RTORRENT) import clients.rtorrent.rTorrent;
version(TRANSMISSION) import clients.transmission.Transmission;


struct ClientManager
{
    static uint max_client_age = 60 * 10; //ten minutes
    private static ClientWrapper[uint] client_wrappers_all;
    const char[] webclients_file = "webclients.json";

    private struct ClientWrapper
    {
        Client client;
        
        uint last_accessed;

        void touch()
        {
            last_accessed =  (Clock.now - Time.epoch1970).seconds;
        }
    }

    /*
    * Get an unused client id.
    */
    public static uint getUnusedId()
    {
        uint id = 1;
        foreach(cid, ref cw; client_wrappers_all)
        {
            if(cid >= id)
            {
                id = cid + 1;
            }
        }
        return id;
    }

    public static Client getClient(uint id)
    {
        auto ptr = (id in client_wrappers_all);
        return ptr ? ptr.client : null;
    }

    public static Client[] getClients(uint[] ids)
    {
        auto clients = new Client[](ids.length);
        uint i = 0;
        foreach(id; ids)
        {
            auto cw = (id in client_wrappers_all);
            if(cw)
            {
                cw.touch();
                clients[i] = cw.client;
                ++i;
            }
        }
        
        return clients[0..i];
    }

    public static Client[] getAllClients()
    {
        return getClients(client_wrappers_all.keys);
    }

    public static void loadClientsSettings()
    {
        auto storage = Storage.loadFile(webclients_file);
        
        foreach(Storage s; storage)
        {
            uint id;
            char[] software;
            char[] host;
            ushort port;
            char[] user;
            char[] pass;
        
            s.load("software", &software);
            s.load("id", &id);
            
            auto type = Utils.fromString!(Client.Type)(software);
            if(type == Client.Type.UNKNOWN)
            {
                if(software)
                {
                    Stdout("(W) Clients: Software identifier '")(software)("' is not supported.").newline;
                }
                else
                {
                    Stdout("(W) Clients: Software identifier is missing for id ")(id)(".").newline;
                }
                continue;
            }
            
            if(id == 0)
            {
                Stdout("(W) Clients: Client id is missing or invalid (0).").newline;
                continue;
            }
            
            s.load("host", &host);
            s.load("port", &port);
            s.load("username", &user);
            s.load("password", &pass);
        
            auto client = createClient(type, id);
            
            if(host) client.setHost(host);
            if(port) client.setPort(port);
            if(user) client.setUsername(user);
            if(pass) client.setPassword(pass);
            
            if(id in client_wrappers_all)
            {
                Stdout("(W) Clients: Client id is already in use.").newline;
                continue;
            }
            
            client_wrappers_all[id] = ClientWrapper(client);
        }
    }

    static void saveClientsSettings()
    {
        auto storage = new Storage();
        
        foreach(w; client_wrappers_all)
        {
            auto client = w.client;
            auto s = new Storage();
            
            s.save("id", client.getId);
            s.save("software", client.getSoftware);
            s.save("host", client.getHost);
            s.save("port", client.getPort);
            s.save("username", client.getUsername);
            s.save("password", client.getPassword);
            char[] id_str = Integer.toString(client.getId);
            storage[id_str] = s;
        }
        
        storage.save("version", Host.main_version);
        
        Storage.saveFile(webclients_file, storage);
    }

    static uint getClientCount()
    {
        return client_wrappers_all.length;
    }
    
    static void removeClient(uint id)
    {
        auto client = getClient(id);
        if(client)
        {
            client_wrappers_all.remove(id);
            client.disconnect();
        }
    }
    
    static Client addClient(Client.Type type, char[] host, ushort port, char[] user, char[] pass)
    {
        uint id = getUnusedId();
        auto client = createClient(type, id);
        if(client)
        {
            if(host.length) client.setHost(host);
            if(port) client.setPort(port);
            if(user.length) client.setUsername(user);
            if(pass.length) client.setPassword(pass);
            
            client_wrappers_all[id] = ClientWrapper(client);
        }
        return client;
    }
    
    private static Client createClient(Client.Type type, uint id)
    {
        switch(type)
        {
            version(MLDONKEY)
            {
                case Client.Type.MLDONKEY:
                    return new MLDonkey(id);
            }
            
            version(AMULE)
            {
                case Client.Type.AMULE:
                    return new aMule(id);
            }
            
            version(GIFT)
            {
                case Client.Type.GIFT:
                    return new giFT(id);
            }
            
            version(RTORRENT)
            {
                case Client.Type.RTORRENT:
                    return new rTorrent(id);
            }
            
            version(TRANSMISSION)
            {
                case Client.Type.TRANSMISSION:
                    return new Transmission(id);
            }
            
            default:
                Logger.addError("ClientManager: Cannot load unknown client with id {} and type id {}.", id , cast(size_t) type);
                return null;
        }
    }
    
    /*
    * Disconnect client when unused
    * for max_client_age sconds.
    */
    public static void disconnectOld()
    {
        if(max_client_age == 0)
            return;
        
        auto now = (Clock.now - Time.epoch1970).seconds;
        foreach(cw; client_wrappers_all)
        {
            if(now - cw.last_accessed >= max_client_age)
            {
                cw.client.disconnect();
            }
        }
    }
}
