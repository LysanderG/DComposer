module search;

//this is a basic built in search feature which maybe superceded by a 
//better element (plugin).  (okay I started calling them elements and it stuck in
//my head. So forget about plugins I've got elements baby!)jl

//how much faster would this be in parallel??
//oh well it is fast enough now.  How about working on completion first.


import core.memory;
import std.conv;
import std.file;
import std.path;
import std.regex;
import std.stdio;
import std.string;
import std.utf;
import std.encoding;



import qore;
import docman;

struct TREASURE
{
    string  mDocId;
    int     mLineNo;
    int     mOffsetBegin;
    int     mOffsetEnd;
    string  mLineText;
    this(string docName, int line, int startOffset, int endOffset, string text)
    {
        mDocId = docName;
        mLineNo = line;
        mOffsetBegin = startOffset;
        mOffsetEnd = startOffset + endOffset;
        mLineText = text;
    }
}

struct SEARCH_OPTIONS
{
    bool    mCaseSensitive;
    bool    mRecursion;
    bool    mRegEx;
    bool    mWordStart;
    bool    mWordEnd;
}
enum SEARCH_SCOPE
{
    CURRENT,
    OPEN,
    SOURCE,
    ALL,
    FOLDER,
}


//this damn function fails on large searches (or afew small ones)
//fails on a gc sweep and causes an assert from gobject ... something aint null
TREASURE[] Search(SEARCH_SCOPE sScope, string needle, SEARCH_OPTIONS sOpts)
{
    scope(exit)
    {
        GC.enable();
    }
    GC.disable();
        
    TREASURE[] rv;
    rv.reserve = 4_000_000;
    string haystack;
    string flags = "";
    SpanMode mode = SpanMode.shallow;
    
    if(!sOpts.mRegEx)needle = Escape(needle);
    if(sOpts.mWordStart) needle = '\b' ~ needle;
    if(sOpts.mWordEnd) needle ~= '\b';
    if(!sOpts.mCaseSensitive) flags = "i";
    if(sOpts.mRecursion) mode = SpanMode.depth;
    auto rgxNeedle = regex(needle, flags);
    
    final switch(sScope) with(SEARCH_SCOPE)
    {
        case ALL:
            foreach(string item; Project.List(LIST_KEYS.RELATED))
            {
                if(docman.Opened(item)) FindInDoc(item, rgxNeedle, rv);
                else FindInFile(item, rgxNeedle, rv);
            }
            goto case;
        case SOURCE:
            foreach(string item; Project.List(LIST_KEYS.SOURCE))
            {
                if(docman.Opened(item)) FindInDoc(item, rgxNeedle, rv);
                else FindInFile(item, rgxNeedle, rv);
            }
            break;
        case OPEN:
            {
                foreach(doc; docman.GetDocs()) FindInDoc(doc.FullName, rgxNeedle, rv);
            }
            break;
        case CURRENT:
            FindInDoc(CurrentDocName, rgxNeedle, rv);    
            break;
        case FOLDER:
            string searchPath = GetCurrentDoc().FullName();
            foreach( sfile; dirEntries(searchPath.dirName, mode, false))
            {
                scope(failure)continue;                
                if(sfile.isFile) 
                {
                    if(docman.Opened(sfile.name)) FindInDoc(sfile.name, rgxNeedle, rv);
                    else FindInFile(sfile.name,rgxNeedle, rv);
                }
            }
            break;
    }
    return rv;
    
}

void FindInDoc(string DocName, Regex!char needle, ref TREASURE[] rv)
{
    //TREASURE[] rv;
    auto curDoc = GetDoc(DocName);
    if(curDoc is null) return;
    int line = 0;
    foreach(string text; curDoc.Text.lineSplitter())
    {
        auto allMatches = matchAll(text, needle);
        foreach(item; allMatches) 
        {
            rv ~= TREASURE( DocName, 
                            cast(int)line,
                            cast(int)item.pre.length,
                            cast(int)item.hit.length,
                            text);
        }
        line++;
        
    }
    //return rv;
}

void FindInFile(string fileName, Regex!char needle, ref TREASURE[] rv)
{
    fileName = buildPath(getcwd(), fileName);
    auto sfile = File(fileName);
    auto lineRange = sfile.byLine();
    //auto haystack = readText(fileName).splitLines();
    
    int lineNo = 0;
    foreach(stringLineText; lineRange)
    {
        if(lineNo == 0)
        { 
            if(!isValid(stringLineText))continue;
        }
        auto allMatches = matchAll(stringLineText, needle);
        foreach(item; allMatches)
        {
            rv ~= TREASURE( fileName,
                            cast(int)lineNo,
                            cast(int)item.pre.length,
                            cast(int)item.hit.length,
                            stringLineText.to!string);
        }   
        lineNo++;
    } 
    //return rv;
}

void QuickSearchFore(string needle, SEARCH_OPTIONS sOpts)
{
    string flags = "";
    if(!sOpts.mRegEx)needle = Escape(needle);
    if(sOpts.mWordStart) needle = '\b' ~ needle;
    if(sOpts.mWordEnd) needle ~= '\b';
    if(!sOpts.mCaseSensitive) flags = "i";
       
    GetCurrentDoc().FindForward(needle);    
}
void QuickSearchBack(string needle, SEARCH_OPTIONS sOpts)
{
    string flags = "";
    if(!sOpts.mRegEx)needle = Escape(needle);
    if(sOpts.mWordStart) needle = '\b' ~ needle;
    if(sOpts.mWordEnd) needle ~= '\b';
    if(!sOpts.mCaseSensitive) flags = "i";
       
    GetCurrentDoc().FindBackward(needle);    
}
string Escape(string OldNeedle)
{
    import std.array;
    string rv = OldNeedle;
    string specials = "[]-{}()*+?.,^$|#";

    rv = rv.replace(`\`, `\\`);//`back tick screws up highlights
    foreach(specChar; specials) rv = rv.replace([specChar], ['\\'] ~specChar);

    return rv;

}


//HEY I STOLE THIS DIRECTLY FROM PHOBOS XML
//IT IS IN THE UNDEAD LIBRARY BUT THOUGHT IT WOULD BE BETTER
//TO GRAB THIS ONE FUNCTION.... 
/*
-------------------------------------------------------------------------------
Copyright: Copyright Janice Caron 2008 - 2009.
License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors:   Janice Caron
Source:    $(PHOBOSSRC std/xml.d)
*/
/*
         Copyright Janice Caron 2008 - 2009.
Distributed under the Boost Software License, Version 1.0.
   (See accompanying file LICENSE_1_0.txt or copy at
         http://www.boost.org/LICENSE_1_0.txt)
*/
/**
 * Encodes a string by replacing all characters which need to be escaped with
 * appropriate predefined XML entities.
 *
 * encode() escapes certain characters (ampersand, quote, apostrophe, less-than
 * and greater-than), and similarly, decode() unescapes them. These functions
 * are provided for convenience only. You do not need to use them when using
 * the undead.xml classes, because then all the encoding and decoding will be done
 * for you automatically.
 *
 * If the string is not modified, the original will be returned.
 *
 * Standards: $(LINK2 http://www.w3.org/TR/1998/REC-xml-19980210, XML 1.0)
 *
 * Params:
 *      s = The string to be encoded
 *
 * Returns: The encoded string
 *
 * Example:
 * --------------
 * writefln(encode("a > b")); // writes "a &gt; b"
 * --------------
 */
S encode(S)(S s)
{
    import std.array : appender;

    string r;
    size_t lastI;
    auto result = appender!S();

    foreach (i, c; s)
    {
        switch (c)
        {
        case '&':  r = "&amp;"; break;
        case '"':  r = "&quot;"; break;
        case '\'': r = "&apos;"; break;
        case '<':  r = "&lt;"; break;
        case '>':  r = "&gt;"; break;
        default: continue;
        }
        // Replace with r
        result.put(s[lastI .. i]);
        result.put(r);
        lastI = i + 1;
    }

    if (!result.data.ptr) return s;
    result.put(s[lastI .. $]);
    return result.data;
}

@safe pure unittest
{
    auto s = "hello";
    assert(encode(s) is s);
    assert(encode("a > b") == "a &gt; b", encode("a > b"));
    assert(encode("a < b") == "a &lt; b");
    assert(encode("don't") == "don&apos;t");
    assert(encode("\"hi\"") == "&quot;hi&quot;", encode("\"hi\""));
    assert(encode("cat & dog") == "cat &amp; dog");
}
