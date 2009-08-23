module api.Meta;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/

public import api.Meta_;
import api.Node;

/*
* For meta information that doesn't fit elsewhere (chat, log..)
* Values of a Meta can't be modified,
* but Metas can be added/removed.
*/

interface Metas
{
    public:
    void addMeta(Meta_.Type type, char[] value, int rating);
    void removeMeta(Meta_.Type type, uint id);
    uint getMetaCount(Meta_.Type type, Meta_.State state);
    Meta[] getMetaArray(Meta_.Type type, Meta_.State state, uint age);
}

interface Meta : Metas
{
    public:
    uint getId();
    char[] getMeta();
    uint getLastChanged();
    short getRating(); //for settings this could rate the order
    Meta_.Type getType();
    Meta_.State getState();
    Node getSource();
    Metas getMetas();
}

class NullMeta : Meta
{
    uint getId() { return 0; }
    uint getLastChanged() { return 0; }
    char[] getMeta() { return null; }
    short getRating() { return 0; }
    Meta_.Type getType() { return Meta_.Type.UNKNOWN; }
    Meta_.State getState() { return Meta_.State.ANYSTATE; }
    Node getSource() { return null; }
    Metas getMetas() { return null; }
//from Metas;
    void addMeta(Meta_.Type type, char[] value, int rating) {}
    void removeMeta(Meta_.Type type, uint id) {}
    uint getMetaCount(Meta_.Type type, Meta_.State state) { return 0; }
    Meta[] getMetaArray(Meta_.Type type, Meta_.State state, uint age) { return null; }
}
