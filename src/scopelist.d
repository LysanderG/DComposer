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
import elements;

import docman;
import document;


import std.stdio;



import gsv.SourceView;
import gsv.SourceBuffer;

import gtk.TextIter;
import gtk.Widget;



class SCOPE_LIST : ELEMENT
{
    private:

    string      mName;
    string      mInfo;
    bool        mState;


    void WatchForNewDocument(DOCUMENT_IF DocIF)
    {
        DOCUMENT DocX = cast (DOCUMENT) DocIF;

        DocX.addOnFocusOut (delegate bool (GdkEventFocus* ev, Widget w){dui.GetDocPop.Hide();return false;}); 

        DocX.TextInserted.connect(&WatchDoc);
    }

    void WatchDoc(DOCUMENT sv, TextIter ti, string text, SourceBuffer buffer)
    {
        if (text != ".")
        {
            if(mState)
            {
                mState = false;
                dui.GetDocPop.Close(TYPE_SCOPELIST);
            }
            return;            
        }
        
        //pull out candidate
        ti.backwardChar();
        ti.backwardWordStart();
        TextIter tiEnd = ti.copy();
        tiEnd.forwardWordEnd();

        //int CouldMoveback = ti.backwardChar();
        
       // while('.' == ti.getChar())
        //{
         //   ti.backwardWordStart();
         //   CouldMoveback = ti.backwardChar();
        //}
        //if(CouldMoveback)ti.forwardChar();

        string Candidate = ti.getText(tiEnd);

        string[] possibles = GetSymbols.GetMembers(Candidate);

        if(possibles.length < 1) return;
        
        mState = true;


        dui.GetDocPop.Push(sv, ti, possibles, TYPE_SCOPELIST);
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
        
        dui.GetDocMan.Appended.connect(&WatchForNewDocument);

        GetLog.Entry("Engaged SCOPE_LIST element");
    }

    void Disengage()
    {
        GetLog.Entry("Disengaging SCOPE_LIST element");
    }

}
