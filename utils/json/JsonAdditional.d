/*******************************************************************************

        Copyright: Copyright (C) 2009 Moritz Warning
                   All rights reserved

        License:   BSD style: $(LICENSE)

        version:   January 2009: Initial release

        Authors:   mwarning

*******************************************************************************/

module utils.json.JsonAdditional;

private import tango.core.Memory;


struct GCAllocator
{
    static void collect()
    {
        GC.collect();
    }
    
    static T* malloc(T)()
    {
        return cast(T*) GC.malloc(T.sizeof);
    }
    
    static void* malloc()(uint size)
    {
        return GC.malloc(size);
    }
}


struct LinkedList(T, alias Allocator)
{
    private struct Attribute
    {
        Attribute* next;
        T value;
    }
    
    private Attribute* beg = null;
    private Attribute* end = null;
    private size_t count = 0;
    private Allocator stack;
    
    void opCatAssign(T value)
    {
        auto a = stack.malloc!(Attribute)();
        if(beg)
        {
            end.next = a;
        }
        else
        {
            beg = a;
        }
        a.next = null;
        a.value = value;
        end = a;
        ++count;
    }
    
    T opIndex(size_t index)
    {
        auto value = opIn_r(index);
        if(value) return *value;
        throw new Exception("key not present");
    }
    
    T* opIn_r(size_t index)
    {
        if(index >= count)
        {
            return null;
        }
        
        auto a = beg;
        while(index--)
        {
            a = a.next;
        }
        return &a.value;
    }
    
    int opApply(int delegate(ref T value) dg)
    {
        int result = 0;
        auto a = beg;
        while(a)
        {
            result = dg(a.value);
            if(result != 0)
            {
                break;
            }
            a = a.next;
        }
        return result;
    }
    
    int opApply(int delegate(ref size_t key, ref T value) dg)
    {
        int result = 0;
        size_t i = 0;
        auto a = beg;
        while(a)
        {
            result = dg(i, a.value);
            ++i;
            if(result != 0)
            {
                break;
            }
            a = a.next;
        }
        return result;
    }
    
    int opEquals(LinkedList!(T, Allocator) obj)
    {
        if(obj.length != this.length)
            return 0;
        
        auto a = this.beg;
        auto b = obj.beg;
        
        while(a && b)
        {
            if(a.value != b.value)
            {
                return 0;
            }
            a = a.next;
            b = b.next;
        }
        
        return 1;
    }
    
    size_t length()
    {
        return count;
    }
}

struct LinkedPairList(K, V, alias Allocator)
{
    private struct Attribute
    {
        Attribute* next = void;
        K name = void;
        V value = void;
    }
    
    private Attribute* beg = null;
    private Attribute* end = null;
    private size_t count = 0;
    private Allocator stack;
    
    void opIndexAssign(V value, K key)
    {
        auto a = stack.malloc!(Attribute)();
        if(beg)
        {
            end.next = a;
        }
        else
        {
            beg = a;
        }
        
        a.next = null;
        a.name = key;
        a.value = value;
        end = a;
        ++count;
    }
    
    V opIndex(K key)
    {
        auto ptr = opIn_r(key);
        if(ptr) return *ptr;
        throw new Exception("key not found");
    }
    
    V* opIn_r(K key)
    {
        auto a = beg;
        
        while(a)
        {
            if(a.name == key)
            {
                return &a.value;
            }
            a = a.next;
        }
        return null;
    }
    
    int opApply(int delegate(ref V value) dg)
    {
        int result = 0;
        auto a = beg;
        while(a)
        {
            result = dg(a.value);
            if(result != 0)
            {
                break;
            }
            a = a.next;
        }
        return result;
    }
    
    int opApply(int delegate(ref K key, ref V value) dg)
    {
        int result = 0;
        auto a = beg;
        while(a)
        {
            result = dg(a.name, a.value);
            if(result != 0)
            {
                break;
            }
            a = a.next;
        }
        return result;
    }
    
    int opEquals(LinkedPairList!(K, V, Allocator) obj)
    {
        if(obj.length != this.length)
            return 0;
        
        auto a = this.beg;
        auto b = obj.beg;
        
        while(a && b)
        {
            if(a.name != b.name || a.value != b.value)
            {
                return 0;
            }
            a = a.next;
            b = b.next;
        }
        
        return 1;
    }
    
    size_t length()
    {
        return count;
    }
}
