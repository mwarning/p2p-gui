module HNTag;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import Utils = Utils;

//namespace Engine {

struct Tag(T)
{
    Tag(ubyte opcode, const T &data) : m_opcode(opcode), m_data(data) {}

    template<typename Type>
    friend std.ostream& operator<<(ubyte[] o, inout Tag<Type> t);

    ubyte m_opcode;
    T m_data;
}
/*
ubyte[] operator<<(ubyte[] o, inout Tag<T> t)
{
    putVal!(ubyte)(o, t.m_opcode);
    putVal!(ushort)(o, sizeof(t.m_data));
    putVal<T>(o, t.m_data);
    return o;
}

std.ostream& operator<<(ubyte[] o, inout Tag!(char[]) t)
{
    putVal!(ubyte)(o, t.m_opcode);
    putVal!(ushort)(o, t.m_data.size());
    putVal(o, t.m_data.data(), t.m_data.size());
    return o;
}*/

Tag!(T) makeTag(ubyte opcode, const T data)
{
    return Tag!(T)(opcode, data);
}


