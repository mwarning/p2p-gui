module webguis.plex.HtmlTranslator;

/*
* Copyright 2007-2009 Moritz Warning
*
* This file is part of P2P-GUI  and is 
* licensed under GNU General Public License.
*/

import webserver.HttpRequest;
import webserver.HttpResponse;

import api.File;
import api.User;
import api.Host;

import tango.io.Stdout;
import tango.core.Array;

import webguis.plex.PlexGui;
import webguis.plex.HtmlElement;
import webguis.plex.HtmlUtils;
import webcore.Dictionary;
static import Utils = utils.Utils;
static import Main = webcore.Main;
import webcore.Logger;
import webcore.MainUser;

/*
* This module enables a user to alter the internal translation tables.
* It is meant to easy improving translations.
*
* The language to translate/modify is a setting
* but admins can choose the language freely.
*/
final class HtmlTranslator : HtmlElement
{
    Phrase language_id;
    bool show_export;
    
    this()
    {
        super(Phrase.Translator);
        
        addSetting(Phrase.language, &language_id, &Dictionary.all_languages, &setLanguage);
    }
    
    void setLanguage(Phrase phrase)
    {
        char[][] tmp = Dictionary.getDictionary(phrase);
        if(tmp)
        {
            language_id = phrase;
        }
        else
        {
            Logger.addError("HtmlTranslator: Unknown language identifier {}.", cast(uint) phrase);
        }
    }
    
    void handle(HttpRequest req, Session session)
    {
        auto user = cast(MainUser) session.getUser();
        
        if(language_id == 0)
            language_id = user.getLanguageId();
        
        char[] do_str = req.getParameter("do");
        
        if(do_str == "show" && user.getType == User_.Type.ADMIN)
        {
            auto lang = req.getParameter!(ushort)("id", language_id);
            setLanguage(cast(Phrase) lang);
        }
        else if(do_str == "export")
        {
            show_export = true;
        }
        else if(do_str == "apply")
        {
            char[][] dictionary = Dictionary.getDictionary(language_id);
            char[][char[]] params = req.getAllParameters();
            foreach(phrase_id_str, phrase_str; params)
            {
                auto phrase = Convert.to!(ushort)(phrase_id_str, ushort.max);
                if(phrase < dictionary.length)
                {
                    dictionary[phrase] = phrase_str.dup;
                }
            }
        }
    }
    
    void handle(HttpResponse res, Session session)
    {
        HtmlOut o = { res.getWriter(), &session.getUser.translate};
        
        auto user = cast(MainUser) session.getUser();
        
        if(language_id == 0)
            language_id = user.getLanguageId();
        
        o("<form action=\"" ~ target_uri ~ "\" method=\"get\">");
        o("<input type=\"hidden\" name=\"to\" value=\"")(this.getId)("\" />\n");
        
        if(user.getType == User_.Type.ADMIN)
        {
            o("<select name=\"id\" size=\"1\">\n");
            foreach(lang; Dictionary.all_languages)
            {
                o("<option value=\"")(cast(ushort) lang);
                if(lang == language_id)
                {
                    o("\" selected=\"selected\">");
                }
                else
                {
                    o("\">");
                }
                o(lang);
                o("</option>\n");
            }
            o("</select>\n");
            
            o("<button type=\"submit\" name=\"do\" value=\"show\">");
            o(Phrase.Show);
            o("</button>\n");
        }
        
        o("<button type=\"submit\" name=\"do\" value=\"export\">");
        o("Export");
        o("</button>\n");
        
        o("</form>");
        
        o("<h3>")(language_id)("</h3>\n");
        
        char[][] dictionary = Dictionary.getDictionary(language_id);
        
        //display pecentage of completion
        uint c, percentage;
        foreach(word; dictionary)
        {
            if(word.length) ++c;
        }
        
        if(c)
        {
            percentage = 100 * c / dictionary.length;
        }
        
        o("(Completed: ")(percentage)("%)\n");
        
        //export for inclusion into source code
        if(show_export)
        {
            o("<pre>\n");
            o(Host.main_name)(" ")(Host.main_version)(":\n");
            uint i = 0;
            foreach(key, val; dictionary)
            {
                //only display translated phrases
                if(val.length)
                {
                    if(i++) o(",\n");
                    
                    char[] word = Dictionary.string_dict[key];
                    o("Phrase.")(word)(" : \"")(val)("\"");
                }
            }
            o("\n</pre>\n");
            
            show_export = false;
        }
        else
        {
            //display dictionary,
            //split into multiple tables
            uint max_per_col = 15;
            uint from = 1; //we skip Phrase.NIL;
            uint to = max_per_col;
            
            while(true)
            {
                //new table
                if(to > dictionary.length) to = dictionary.length;
                
                displayTable(o, from, to, dictionary);
                
                if(to == dictionary.length) break;
                from = to;
                to += max_per_col;
            }
        }
    }
    
    private void displayTable(HtmlOut o, uint i, uint max, char[][] dictionary)
    {
        assert(i <= dictionary.length && max <= dictionary.length);
        
        o("<form name=\"translator\" action=\"" ~ target_uri ~ "\" method=\"post\">\n");
        o("<input type=\"hidden\" name=\"to\" value=\"")(this.getId)("\" />\n");
        
        o("<table>\n");
        while(i < max)
        {
            o("<tr>\n");
            
            //own language
            o("<td>");
            o(cast(Phrase) i)(" [")(i)("]");
            o("</td>\n");
            
            //selected language
            o("<td>");
            o("<input type=\"text\" name=\"")(i)("\" value=\"")(dictionary[i])("\" />");
            o("</td>\n");
            
            o("</tr>\n");
            i++;
        }
        o("</table>\n");
        
        o("<button type=\"submit\" name=\"do\" value=\"apply\">");
        o(Phrase.Apply);
        o("</button>\n");
        
        o("</form>\n\n");
    }
}
