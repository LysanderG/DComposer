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
import docpop;
import docman;
import document;

import std.stdio;
import std.algorithm;
import std.ascii;



import gtk.TextIter;
import gdk.Rectangle;
import gsv.SourceBuffer;

class SYMBOL_COMPLETION : ELEMENT
{
    private:

    string      mName;
    string      mInfo;
    bool        mState;
    bool        mActive;

    int         mMinCompletionLength;

    DOCUMENT[]  mConnections;


    void WatchForNewDocument(string EventId, DOCUMENT_IF NuDoc)
    {
        DOCUMENT Doc = cast(DOCUMENT) NuDoc;

        mConnections ~= Doc;
        Doc.TextInserted.connect(&WatchDoc);
    }

    void WatchDoc(DOCUMENT doc, TextIter ti, string text, SourceBuffer buffer)
    {
        if(doc.IsPasting) return;

		
		if ((text == ".") || (text == "(") || (text == ")")) return;		
		
        if(text.length > 1) return; 
        
        TextIter WordStart = new TextIter;
        WordStart = GetCandidate(ti);
        string Candidate = WordStart.getText(ti);
        
        if(Candidate.length < mMinCompletionLength) return;
        
        int xpos, ypos;
        IterGetPostion(doc, WordStart, xpos, ypos);
               
        auto tmp = Symbols.Match(Candidate);
     
        string[] Possibles;
        
        foreach(item; tmp.uniq) Possibles ~= item;
        //if (Possibles.length < 1) return;

        dui.GetDocPop.Push(POP_TYPE_COMPLETION, Possibles, Possibles, xpos, ypos);
        mActive = true;
        
    }
    void WatchDoc_deprecated(DOCUMENT doc, TextIter ti, string text, SourceBuffer buffer)
    {
        if(doc.IsPasting) return;
        
        //if(active)
        //{
        //    active = false;
        //    //dui.GetDocPop.Pop();
        //}
		
		if ((text == ".") || (text == "(") || (text == ")")) return;
		
		
        if(text.length > 1) return;
        //if( !( (isAlphaNum(text[0])) || (text == "_"))) return;
        
        
        TextIter WordStart = ti.copy();
        WordStart.backwardWordStart();
       int CouldMoveback = WordStart.backwardChar();
               
       while('.' == WordStart.getChar())
       {
           WordStart.backwardWordStart();
           CouldMoveback = WordStart.backwardChar();
       }
       if(CouldMoveback)WordStart.forwardChar();
        
        int xpos, ypos;
        IterGetPostion(doc, WordStart, xpos, ypos);
        
        string Candidate = WordStart.getText(ti);
        if(Candidate.length < Config.getInteger("SYMBOLS", "minimum_completion_length", 4)) return;
        auto tmp = Symbols.Match(Candidate);
     
        string[] Possibles;
        
        foreach(item; tmp.uniq) Possibles ~= item;
        //if (Possibles.length < 1) return;

        dui.GetDocPop.Push(POP_TYPE_COMPLETION, Possibles, Possibles, xpos, ypos);
        mActive = true;
        
    }

    void IterGetPostion(DOCUMENT Doc, TextIter ti, out int xpos, out int ypos)
    {
        GdkRectangle gdkRect;
        int winX, winY, OrigX, OrigY;

        Rectangle LocationRect = new Rectangle(&gdkRect);
        Doc.getIterLocation(ti, LocationRect);
        Doc.bufferToWindowCoords(GtkTextWindowType.TEXT, gdkRect.x, gdkRect.y, winX, winY);
        Doc.getWindow(GtkTextWindowType.TEXT).getOrigin(OrigX, OrigY);
        xpos = winX + OrigX;
        ypos = winY + OrigY + gdkRect.height;
        return;        
    }
        

    TextIter GetCandidate(TextIter ti)
    {
        string growingtext;
        TextIter tstart = new TextIter;
        tstart = ti.copy();
        do
        {
            if(!tstart.backwardChar()) break;
            growingtext = tstart.getText(ti);
        }
        while( (isAlphaNum(growingtext[0])) || (growingtext[0] == '_'));

        return tstart;
        
    }
        
            
    
    
    public:

    this()
    {
        mName = "SYMBOL_COMPLETION";
        mInfo = "Retrieve any symbol for auto/code/symbol/tag completion (except for pesky local stuff)";
        mState = false;

        mMinCompletionLength =  Config.getInteger("SYMBOLS", "minimum_completion_length", 4);
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

        dui.GetDocMan.Event.connect(&WatchForNewDocument);

        Log.Entry("Engaged SYMBOL_COMPLETION element");
    }
        

    void Disengage()
    {
        mState = false;
        foreach (cnx; mConnections) cnx.TextInserted.disconnect(&WatchDoc);
        dui.GetDocMan.Event.disconnect(&WatchForNewDocument);
    }
   
}  
