//      calltips.d
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


module calltips;

import dcore;
import symbols;

import ui;
import docman;
import elements;
import document;

import std.stdio;
import std.algorithm;

import gsv.SourceView;
import gsv.SourceBuffer;

import gtk.TextIter;
import gtk.Widget;

import glib.SimpleXML;


class CALL_TIPS : ELEMENT
{    
    private:

    string      mName;
    string      mInfo;
    bool        mState;

    string[]    mStack; //y is this still here?

    DOCUMENT[] ConnectedDocs;  
        

    public:

    this()
    {
        mName = "CALL_TIPS";
        mInfo = "Displays function signatures, assisting user in choosing and applying the proper function";
    }
    
    @property string Name(){ return mName;}
    @property string Information(){return mInfo;}
    @property bool   State(){ return mState;}
    @property void   State(bool nuState)
    {
        mState = nuState;
        
        if(mState)  Engage();
        else        Disengage();
    }

    void Engage()
    {
        mState = true;

        dui.GetDocMan.Appended.connect(&WatchForNewDocument);

        //can read preopened docs from config ... they dont change til docman.disengage
        //or just flip thru centerpane?

        GetLog.Entry("Engaged CALL_TIPS element");
    }

    void Disengage()
    {
        mState = false;
        dui.GetDocMan.Appended.disconnect(&WatchForNewDocument);
        foreach(Doc; ConnectedDocs) Doc.TextInserted.disconnect(&WatchDoc);
        mStack.length = 0;
        ConnectedDocs.length = 0;
        GetLog.Entry("Disengaged CALL_TIPS element");
                
    }

    void WatchForNewDocument(DOCUMENT_IF docIF)
    {
        DOCUMENT DocX = cast(DOCUMENT) docIF;

        DocX.addOnFocusOut (delegate bool (GdkEventFocus* ev, Widget w){dui.GetDocPop.Hide();return false;}); 

        
        DocX.TextInserted.connect(&WatchDoc);

        ConnectedDocs ~= DocX;
    }

    void WatchDoc(DOCUMENT sv , TextIter ti, string Text, SourceBuffer Buffer)
    {
        switch(Text)
        {
            case "(" :
            {
                //pull out candidate
                ti.backwardChar();
                ti.backwardWordStart();
                TextIter tiEnd = ti.copy();
                tiEnd.forwardWordEnd();

                int CouldMoveback = ti.backwardChar();
                
                while('.' == ti.getChar())
                {
                    ti.backwardWordStart();
                    CouldMoveback = ti.backwardChar();
                }
                if(CouldMoveback)ti.forwardChar();

                string Candidate = ti.getText(tiEnd);

                string[] tmp = GetSymbols.GetCallTips(Candidate);
                string[] Possibles;

                //foreach(p; tmp.uniq()) Possibles ~= SimpleXML.escapeText(p, -1);
                foreach(p; tmp.uniq()) Possibles ~= p;
                
                if(Possibles.length == 0) break;

                dui.GetDocPop.Push(sv, ti, Possibles, TYPE_CALLTIP);
                break;
            }
            case ")" :
            {
                dui.GetDocPop.Close(TYPE_CALLTIP);
                break;
            }
            default : break;
        }

    }
    
    
}  
/*
*
* Ok.. I was going to do a stack of candidates push one when ( was inserted and pop on )
* that would allow the call tips to be inside call tips and when an inner finished the outter
* would just pop back up.
*
* but... that does not take in to account user deletions and moving around in the document
* so now I see that was rather naive. even if I look at a line, that's not perfect
* functions with many params often span lines...
* hmm.. but not semi colons-- any way...
* oh and in my ignorance I totally forgot about how insert text just ignores esc and cursor keys
* well like everything in this project I'm learning ... really it doesn't work half bad for what I'm
* doing. I've actually surprised myself.
* just need to see if I can make it useful for someone else.



*/
