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
import autopopups;
import docman;
import document;
import symbols;

import std.stdio;
import std.algorithm;
import std.ascii;



import gtk.TextIter;
import gtk.CheckButton;
import gtk.SpinButton;

import gdk.Rectangle;
import gsv.SourceBuffer;

class SYMBOL_COMPLETION : ELEMENT
{
    private:

    string      mName;
    string      mInfo;
    bool        mState;

    SYMBOL_COMPLETION_PAGE mPrefPage;

    int         mMinCompletionLength;

    DOCUMENT[]  mConnections;


    void WatchForNewDocument(string EventId, DOCUMENT_IF NuDoc)
    {
        DOCUMENT Doc = cast(DOCUMENT) NuDoc;
        if (Doc.GetType != DOC_TYPE.D_SOURCE) return;
        mConnections ~= Doc;
        Doc.TextInserted.connect(&WatchDoc);
    }

    void WatchDoc(DOCUMENT doc, TextIter ti, string text, SourceBuffer buffer)
    {
        if(doc.IsPasting) return;
        if (text == ".") return;
		
		if((text == "(") || (text == ")"))
        {
            dui.GetAutoPopUps.CompletionPop();
            return;
        }
		
        if(text.length > 1) return; 
        
        TextIter WordStart = new TextIter;
        WordStart = GetCandidate(ti);
        string Candidate = WordStart.getText(ti);


        DSYMBOL[] Possibles;
        
        if(Candidate.length < mMinCompletionLength)
        {
            Possibles.length = 0;
        }
        else
        {
            Possibles = Symbols.Match(Candidate);
        }
        
        int xpos, ypos;
        IterGetPostion(doc, WordStart, xpos, ypos);

        dui.GetAutoPopUps.CompletionPush(Possibles, xpos, ypos);
        
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
        
            
    void Configure()
    {
		mMinCompletionLength = Config.getInteger("SYMBOLS", "minimum_completion_length", 4);
	}
    
    public:

    this()
    {
        mName = "SYMBOL_COMPLETION";
        mInfo = "Retrieve any symbol for auto/code/symbol/tag completion (except for pesky local stuff)";
        mState = false;
        
        mPrefPage = new SYMBOL_COMPLETION_PAGE;
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
        Config.Reconfig.connect(&Configure);

        Log.Entry("Engaged SYMBOL_COMPLETION element");
    }
        

    void Disengage()
    {
        mState = false;
        foreach (cnx; mConnections) cnx.TextInserted.disconnect(&WatchDoc);
        dui.GetDocMan.Event.disconnect(&WatchForNewDocument);
    }

    PREFERENCE_PAGE GetPreferenceObject()
    {
        return mPrefPage;
    } 
   
}

class SYMBOL_COMPLETION_PAGE : PREFERENCE_PAGE
{
	CheckButton		mEnable;
	SpinButton		mMinLength;

	this()
	{
		super("Elements", Config.getString("PREFERENCES", "glade_file_symbol_completion", "~/.neontotem/dcomposer/symcompref.glade"));

		mEnable = cast (CheckButton)mBuilder.getObject("checkbutton1");
		mMinLength = cast (SpinButton)mBuilder.getObject("spinbutton1");

		mMinLength.setRange(1, 1024);
		mMinLength.setIncrements(1, -1);
		mMinLength.setValue(Config.getInteger("SYMBOLS", "minimum_completion_length", 4));
		
		mFrame.showAll();
	}

	override void Apply()
	{
		Config.setInteger("SYMBOLS", "minimum_completion_length", mMinLength.getValueAsInt());
	}

	override void PrepGui()
	{
		mEnable.setActive(true);
		mMinLength.setValue(Config.getInteger("SYMBOLS", "minimum_completion_length", 4));
	}
	
	
}
