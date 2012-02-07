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

import gdk.Rectangle;

import glib.SimpleXML;


class CALL_TIPS : ELEMENT
{    
    private:

    string      mName;
    string      mInfo;
    bool        mState;

    string[]    mStack; //y is this still here?

    DOCUMENT[] ConnectedDocs;

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

        dui.GetDocMan.Event.connect(&WatchForNewDocument);


        Log.Entry("Engaged CALL_TIPS element");
    }

    void Disengage()
    {
        mState = false;
        dui.GetDocMan.Event.disconnect(&WatchForNewDocument);
        foreach(Doc; ConnectedDocs) Doc.TextInserted.disconnect(&WatchDoc);
        mStack.length = 0;
        ConnectedDocs.length = 0;
        Log.Entry("Disengaged CALL_TIPS element");
                
    }

    void WatchForNewDocument(string EventId, DOCUMENT_IF docIF)
    {
        DOCUMENT DocX = cast(DOCUMENT) docIF;

        //DocX.addOnFocusOut (delegate bool (GdkEventFocus* ev, Widget w){dui.GetDocPop.Hide();return false;}); 

        
        DocX.TextInserted.connect(&WatchDoc);

        ConnectedDocs ~= DocX;
    }

    void WatchDoc(DOCUMENT sv , TextIter ti, string Text, SourceBuffer Buffer)
    {
        if(sv.IsPasting) return;
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

                string[] tmp = Symbols.GetCallTips(Candidate);
                string[] Possibles;

                //foreach(p; tmp.uniq()) Possibles ~= SimpleXML.escapeText(p, -1);
                foreach(p; tmp.uniq()) Possibles ~= p;
                
                if(Possibles.length == 0) break;

                int xpos, ypos;
                IterGetPostion(sv, ti, xpos, ypos);

                dui.GetDocPop.Push(docpop.POP_TYPE_TIP, Possibles, Possibles, xpos, ypos);
                break;
            }
            case ")" :
            {
                dui.GetDocPop.Pop();
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
