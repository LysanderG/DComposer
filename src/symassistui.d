// untitled.d
// 
// Copyright 2012 Anthony Goins <anthony@LinuxGen11>
// 
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
// MA 02110-1301, USA.


module symassistui;

import std.ascii;

import elements;
import dcore;


import ui;
import docman;
import document;

import gtk.Builder;
import gtk.Viewport;
import gtk.Label;
import gtk.TextView;
import gtk.TextIter;
import gtk.Widget;
import gdk.Event;



class SYMBOL_ASSIST : ELEMENT
{
    private:

    string      mName;
    string      mInfo;
    bool        mState;

    Builder     mBuilder;
    Viewport    mRootWidget;
    Label       mLabel;
    TextView    mText;


    void GetDocWord(Widget W)
    {
        DOCUMENT DocW = cast(DOCUMENT) W;

        TextIter cursor = new TextIter;
        DocW.getBuffer.getIterAtMark(cursor,DocW.getBuffer.getInsert());
        auto start = cursor.copy();
        auto end = cursor.copy();
        start.backwardWordStart();
        end.forwardWordEnd();

        CatchSymbol(start.getText(end), null);
    }

    void GetAssistance(Widget W)
    {
        DOCUMENT DocW = cast(DOCUMENT) W;
        TextIter cursor = new TextIter;
        DocW.getBuffer.getIterAtMark(cursor,DocW.getBuffer.getInsert());

        if(!cursor.insideWord()) return;
        
        auto start = cursor.copy();
        auto end = cursor.copy();

        bool GoForward = true;
        bool GoBack = true;        
        
        
        do //back
        {
            if(!start.backwardChar())
            {
                GoForward = false;
                break;
            }
        }
        while( (isAlphaNum(start.getChar()) || (start.getChar() == '_') || (start.getChar() == '.')));
        if(GoForward)start.forwardChar();

        do //forward
        {
            if(!end.forwardChar())
            {
                GoBack = false;
                break;
            }
        }
        while( (isAlphaNum(end.getChar())) || (end.getChar() == '_') || (end.getChar() == '.'));
        if(GoBack)end.backwardChar();


        auto Possibles = Symbols.Match(start.getText(end));

        if(Possibles.length < 1) return;

        CatchSymbol(Possibles[0].Path, Possibles[0].Comment);
    }

        
        
        
        


    void CatchSymbol(string Name, string Comments)
    {
        mLabel.setMarkup(" ");
        mText.getBuffer.setText(" ");
        if(Comments is null) Comments = "no documentation";
        mLabel.setMarkup(Name);
        mText.getBuffer.setText(Comments);
    }


    void WatchForNewDoc(string EventType, DOCUMENT_IF NuDoc)
    {
        if(EventType != "AppendDocument")return;
        auto doc = cast(DOCUMENT)NuDoc;
        doc.addOnEventAfter(delegate void (Event what, Widget W){GetAssistance(W);});
        
    }
    
    public:

    this()
    {
        mName = "SYMBOL_ASSIST_UI";
        mInfo = "Show Documentation comments for symbols";
        mState = false;

    }

    @property string Name() {return mName;}
    @property string Information() {return mInfo;}
    @property bool   State() {return mState;}
    @property void   State(bool NuState)
    {
        if (NuState == mState) return;
        NuState ? Engage() : Disengage();

    }

    void Engage()
    {
        mBuilder = new Builder;

        mBuilder.addFromFile(Config.getString("SYMBOL_ASSIST", "glade_file", "~/.neontotem/dcomposer/assist.glade"));
        mRootWidget = cast(Viewport) mBuilder.getObject("viewport1");
        mLabel = cast (Label) mBuilder.getObject("label1");
        mText = cast(TextView) mBuilder.getObject("textview1");

        dui.GetExtraPane.appendPage(mRootWidget, "Assistance");
        dui.GetExtraPane.setTabReorderable ( mRootWidget, true); 
        
        mRootWidget.showAll();

        dui.GetAutoPopUps.connect(&CatchSymbol);
        dui.GetDocMan.Event.connect(&WatchForNewDoc);
        
        Log.Entry("Engaged SYMBOL ASSIST element");
    }
    void Disengage()
    {
        dui.GetAutoPopUps.disconnect(&CatchSymbol);
        Log.Entry("Disengaged SYMBOL_ASSIST element");
    }
}
        
