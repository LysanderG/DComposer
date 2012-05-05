//      scopelist.d
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


module scopelist;

import ui;
import dcore;
import symbols;
import elements;

import autopopups;
import docman;
import document;


import std.stdio;
import std.ascii;
import std.string;
import std.conv;




import gsv.SourceView;
import gsv.SourceBuffer;

import gtk.TextIter;
import gtk.Widget;

import gdk.Rectangle;



class SCOPE_LIST : ELEMENT
{
    private:

    string      mName;
    string      mInfo;
    bool        mState;


    void WatchForNewDocument(string EventId, DOCUMENT_IF DocIF)
    {
        DOCUMENT DocX = cast (DOCUMENT) DocIF;
        if (DocX.GetType != DOC_TYPE.D_SOURCE) return;
        DocX.TextInserted.connect(&WatchDoc);
    }

    void WatchDoc(DOCUMENT sv, TextIter ti, string text, SourceBuffer buffer)
    {
        int xpos, ypos;
        if (sv.IsPasting) return;
        if (text != ".") return;
        
        //pull out candidate
        TextIter WordStart = new TextIter;
        WordStart = GetCandidate(ti);
        string Candidate2 = WordStart.getText(ti);
        writeln(Candidate2);


        string Candidate = to!(string)(GetLongCandidate(ti));
        writeln(Candidate.length, Candidate);

        if(Candidate.length < 1) return;
        DSYMBOL[] possibles = Symbols.Match(Candidate);


        IterGetPostion(sv, ti, xpos, ypos);
        dui.GetAutoPopUps.CompletionPush(possibles, xpos, ypos, STATUS_SCOPE);
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
        int OrigXlen, OrigYlen;
        Doc.getWindow(GtkTextWindowType.TEXT).getSize(OrigXlen, OrigYlen);
        if((ypos + dui.GetAutoPopUps.Height) > (OrigY + OrigYlen))
        {
            ypos = ypos - gdkRect.height - dui.GetAutoPopUps.Height;
        }
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

    dstring GetLongCandidate(TextIter ti)
    {

            
        dchar[127] Buffer;
        int index = 126;
        //auto CurChar = ti.getChar();
        auto frontTI = ti.copy();
        frontTI.backwardChar(); //ti is already advanced past the '.'
        dchar CurChar = frontTI.getChar();
        //while pos is a idchar pos--
        //if pos == ) skip to matching (
        //if pos == whitespace skip to nextchar if nextchar != ) or . done
        //if pos == nonid done


            void SkipParens()
            {
                int Pdepth = 1;
                frontTI.backwardChar();//skip the first ).
                while( Pdepth > 0)
                {
                    
                    dchar tchar = frontTI.getChar();
                    if (tchar == ')') Pdepth ++;
                    if (tchar == '(') Pdepth --;
                    if (!frontTI.backwardChar()) break;
                }
                CurChar = frontTI.getChar();                
            }
            void SkipSpaces()
            {
            }

        while(isLegalIdChar(CurChar))
        {
            index--;
            if(CurChar == ')') SkipParens();
            if( (CurChar == ' ') || (CurChar == '\t')) SkipSpaces();
            
            Buffer[index] = CurChar;
            if(!frontTI.backwardChar()) break;

            if(index < 1) break;
            CurChar = frontTI.getChar();
        }
        return Buffer[index .. $-1].idup;
    }

    bool isLegalIdChar(dchar character)
    {
        if (isAlphaNum(character)) return true;
        if (character == ')') return true;
        if (character == '.') return true;

        return false;
    }    

            
            
        

    public:
    

    this()
    {
        mName = "SCOPE_LIST";
        mInfo = "present all members of a scope for easy pickins";
        mState = false;
    }

        
    @property string Name() { return mName;}
    @property string Information(){ return mInfo;}
    @property bool   State(){return mState;}
    @property void   State(bool nuState)
    {
        mState = nuState;
        
        if(mState)  Engage();
        else        Disengage();
    }

        

    void Engage()
    {
        
        dui.GetDocMan.Event.connect(&WatchForNewDocument);

        Log.Entry("Engaged SCOPE_LIST element");
    }

    void Disengage()
    {
        Log.Entry("Disengaging SCOPE_LIST element");
    }


    PREFERENCE_PAGE GetPreferenceObject()
    {
        return null;
    }
}
