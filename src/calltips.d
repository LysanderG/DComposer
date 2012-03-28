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
import autopopups;
import elements;
import document;

import std.stdio;
import std.algorithm;
import std.ascii;

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

    TextIter GetCandidate(TextIter ti)
    {
        bool GoForward = true;
        
        string growingtext;
        TextIter tstart = new TextIter;
        tstart = ti.copy();
        do
        {
            if(!tstart.backwardChar())
            {
                GoForward = false;
                break;
            }
            growingtext = tstart.getText(ti);
        }
        while( (isAlphaNum(growingtext[0])) || (growingtext[0] == '_') || (growingtext[0] == '.'));
        if(GoForward)tstart.forwardChar();
        
        return tstart;
        
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
        if (DocX.GetType != DOC_TYPE.D_SOURCE)
        {
            writeln(cast(long)DocX.GetType);
            return;
        }        
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
                ti.backwardChar();
                auto TStart = GetCandidate(ti);
                

                string Candidate = TStart.getText(ti);

                
                if(Candidate.length < 1) return;
                auto Possibles = Symbols.MatchCallTips(Candidate);

                DSYMBOL[] FuncPossibles;

                foreach (dsym; Possibles)
                {
                    if(dsym.Kind != "function") continue;
                    if( !endsWith(Candidate, dsym.Scope[$-1])) continue;
                    FuncPossibles ~= dsym;
                }
                
                if(FuncPossibles.length < 1) break;


                int xpos, ypos;
                IterGetPostion(sv, TStart, xpos, ypos);

                dui.GetAutoPopUps.TipPush(FuncPossibles, xpos, ypos);
                break;
            }
            case ")" :
            {
                dui.GetAutoPopUps.TipPop();
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
