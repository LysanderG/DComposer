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
import std.path;



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
    bool		mEnabled;

    DOCUMENT[]  mConnections;


    void WatchForNewDocument(string EventId, DOCUMENT Doc)
    {
        if (Doc is null ) return;
        if ((extension(Doc.Name) == ".d") || (extension(Doc.Name) == ".di"))
        {
			Doc.TextInserted.connect(&WatchDoc);
			mConnections ~= Doc;
		}
    }

    void WatchDoc(DOCUMENT doc, TextIter ti, string text, SourceBuffer buffer)
    {
		if(mEnabled == false) return;
        if(doc.Pasting) return;
        if (text == ".") return;

		if((text == "(") || (text == ")"))
        {
            dui.GetAutoPopUps.CompletionPop();
            return;
        }

        if(text.length > 1) return;

        TextIter WordStart = new TextIter;
        string Candidate = doc.Symbol(ti.copy(), WordStart);

        DSYMBOL[] Possibles;

        if(Candidate.length < mMinCompletionLength)
        {
            Possibles.length = 0;
        }
        else
        {
            Possibles = Symbols.Match(Candidate);
        }

        int xpos, ypos, xlen, ylen;
        doc.GetIterPosition(ti.copy(), xpos, ypos, xlen, ylen);

        dui.GetAutoPopUps.CompletionPush(Possibles, xpos, ypos, ylen);

    }

    void Configure()
    {
		mMinCompletionLength = Config.getInteger("SYMBOLS", "minimum_completion_length", 4);
		mEnabled = Config.getBoolean("SYMBOLS", "completion_enabled", true);
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
        Configure();

        Log.Entry("Engaged "~Name()~"\telement.");
    }


    void Disengage()
    {
        mState = false;
        foreach (cnx; mConnections) cnx.TextInserted.disconnect(&WatchDoc);
        dui.GetDocMan.Event.disconnect(&WatchForNewDocument);
        Config.Reconfig.disconnect(&Configure);
        Log.Entry("Disengaged "~Name()~"\telement.");
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
		super("Elements", Config.getString("PREFERENCES", "glade_file_symbol_completion", "$(HOME_DIR)/glade/symcompref.glade"));

		mEnable = cast (CheckButton)mBuilder.getObject("checkbutton1");
		mMinLength = cast (SpinButton)mBuilder.getObject("spinbutton1");

		mMinLength.setRange(1, 1024);
		mMinLength.setIncrements(1, -1);
		mMinLength.setValue(Config.getInteger("SYMBOLS", "minimum_completion_length", 4));

		mFrame.showAll();
	}

	override void Apply()
	{
		Config.setBoolean("SYMBOLS", "completion_enabled", mEnable.getActive());
		Config.setInteger("SYMBOLS", "minimum_completion_length", mMinLength.getValueAsInt());
	}

	override void PrepGui()
	{
		mEnable.setActive(Config.getBoolean("SYMBOLS", "completion_enabled", true));
		mMinLength.setValue(Config.getInteger("SYMBOLS", "minimum_completion_length", 4));
	}


}
