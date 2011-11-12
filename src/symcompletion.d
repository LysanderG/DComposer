//      symcompletion.d
//      
//      Copyright 2011 Anthony Goins <anthony@LinuxGen11>
//      
//      This program is free software; you can redistribute it and/or modify
//      it under the terms of the GNU General Public License as published by
//      the Free Software Foundation; either version 2 of the License, or
//      (at your option) any later version.
//      
//      This program is distributed in the hope that it will be useful,
//      but WITHOUT ANY WARRANTY; without even the implied warranty of
//      MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//      GNU General Public License for more details.
//      
//      You should have received a copy of the GNU General Public License
//      along with this program; if not, write to the Free Software
//      Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
//      MA 02110-1301, USA.


module symcompletion;

import dcore;
import ui;
import elements;
import docman;
import document;

import std.stdio;
import std.algorithm;
import std.ascii;



import gtk.TextIter;
import gsv.SourceBuffer;

class SYMBOL_COMPLETION : ELEMENT
{
    private:

    string      mName;
    string      mInfo;
    bool        mState;
    bool        active;

    DOCUMENT[]  mConnections;


    void WatchForNewDocument(DOCUMENT_IF NuDoc)
    {
        DOCUMENT Doc = cast(DOCUMENT) NuDoc;

        mConnections ~= Doc;
        Doc.TextInserted.connect(&WatchDoc);
    }

    void WatchDoc(DOCUMENT doc, TextIter ti, string text, SourceBuffer buffer)
    {
        if ((text == ".") || (text == "(") || text == ")") return;
        if(active)
        {
            active = false;
            dui.GetDocPop.Close(TYPE_SYMCOM);
        }

        if(text.length > 1) return;
        if( !( (isAlphaNum(text[0])) || (text == "_"))) return;
        
        
        TextIter WordStart = ti.copy();
        WordStart.backwardWordStart();
        int CouldMoveback = WordStart.backwardChar();
                
        while('.' == WordStart.getChar())
        {
            WordStart.backwardWordStart();
            CouldMoveback = WordStart.backwardChar();
        }
        if(CouldMoveback)WordStart.forwardChar();

        string Candidate = WordStart.getText(ti);

        auto tmp = Symbols.Match(Candidate);
     
        string[] Possibles;
        
        foreach(item; tmp.uniq) Possibles ~= item;
        if (Possibles.length < 1) return;

        dui.GetDocPop.Push(doc, WordStart, Possibles, TYPE_SYMCOM);
        active = true;
        
    }
    
    public:

    this()
    {
        mName = "SYMBOL_COMPLETION";
        mInfo = "Retrieve any symbol for auto/code/symbol/tag completion (except for pesky local stuff)";
        mState = false;
    }
    
    @property string Name() {return mName;}
    @property string Information(){return mInfo;}
    @property bool   State() {return mState;}
    @property void   State(bool nuState)
    {
        if(mState == nuState) return;
        mState = nuState;

        (mState) ? Engage() : Disengage();
    }

    void Engage()
    {
        mState = true;

        dui.GetDocMan.Appended.connect(&WatchForNewDocument);

        Log.Entry("Engaged SYMBOL_COMPLETION element");
    }
        

    void Disengage()
    {
        mState = false;
        foreach (cnx; mConnections) cnx.TextInserted.disconnect(&WatchDoc);
        dui.GetDocMan.Appended.disconnect(&WatchForNewDocument);
    }
   
}  
