module clients.gift.giFTParser;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI and is 
* licensed under GNU General Public License.
*/

import tango.core.Array;
import tango.io.Console;

final class giFTParser
{
private:
    
    char[] str;

public:
    
    char[] first_key;
    char[][char[]] map;
    uint consumed;

    /**
    * Parse a gift command of 0.11.x syntax with a few restrictions:
    * - "subcommand (argument) {group}",
    *     argument will be overwritten by group
    * - other whitespaces except " " and "\n" will
    *    not be considered for speed reasons
    * @param str    String to parse
    */
    this(char[] str)
    {
        this.str = str;
        
        uint begin;
        uint end;
        char[] key;
        
        bool first = true;
        
        char c;
        while(true)
        {
            //search for next token begin
            while(begin < str.length)
            {
                c = str[begin];
                if(c != ' ' && c != '\n' && c != '\t') break;
                begin++;
            }
            
            if(begin >= str.length) break;
            
            if(c == '(') //get argument
            {
                end = argumentEnd(begin);
                map[key] = str[begin + 1..end].dup;
                end++;
            }
            else if(c == '{') //get group
            {
                end = groupEnd(begin);
                map[key] = str[begin + 1..end].dup;
                end++;
            }
            else if(c == ';')
            {
                consumed = begin;
                break;
            }
            else //get command, subcommand or key
            {
                end = commandEnd(begin);
                key = str[begin..end].dup;
                if(first)
                {
                    first_key = key;
                    first = false;
                }
            }
            begin = end;
        }
        
        //we didn't reached the ';', then the message is invalid
        consumed = 0;
    }
    
    //get number of char that were succesfully parsed
    uint getConsumed()
    {
        return consumed;
    }
    
    char[] opIndex(char[] key) 
    {
        char[]* value = (key in map);
        return value ? (*value) : "";
    }
    
    /**
    * Check if the char is escaped by '\'
    * also handles "\\x" etc.
    *
    * @param str    String
    * @param pos    Char position
    */
    static bool isEscaped(char[] str, uint pos)
    {
        bool escaped = false;
        while(pos)
        {
            --pos;
            if(str[pos] == '\\') { escaped = !escaped; }
            else return escaped;
        }
        return escaped;
    }
    
    //bool unEscape(uint pos);
    
    public void print()
    {
        Cout("Command: \"")(first_key)("\"\n");
        foreach(key, value; map)
        {
            Cout("\"")(key)("\" : \"")(value)("\"\n");
        }
        Cout();
    }
    
private:

    /**
    * Get the end position of sub- commands and keys
    *
    * @param str    String
    * @param start    Position of the command
    */
    uint commandEnd(uint start)
    {
        for(uint i = start; i < str.length; i++)
        {
            char c = str[i];
            if(c == ' ' || c == '\n' || c == '(' || c == '{')
            {
                return i;
            }
        }
        return str.length;
    }

    /**
    * Get the end position of an argument
    *
    * @param str    String
    * @param start    Position of '(' in str, not for nested arguments
    */
    uint argumentEnd(uint start)
    {
        for(uint i = start; i < str.length; i++)
        {
            if(str[i] == ')' && !isEscaped(str, i))
            {
                return i;
            }
        }
        return str.length;
    }

    /**
    * Get the end position of a {} pair
    * works for nested pairs and escaped chars
    *
    * @param str    String
    * @param start    Position of '{'
    */
    uint groupEnd(uint start)
    {
        //number of visited '{'
        uint opens = 0;
        
        //+1 because we don't want to 
        //find the '{' at the beginning
        uint next = start + 1; 
        
        while(true)
        {
            char c;
            //find first of
            while(next < str.length)
            {
                c = str[next];
                if(c == '{' || c == '}') break;
                next++;
            }
            
            if(next == str.length) return next;
            
            if(!isEscaped(str, next))
            {
                if(c == '}')
                {
                    if(opens == 0) return next;
                    --opens;
                }
                else
                {
                    ++opens;
                }
            }
            ++next;
        }
    }
}
