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
import std.path;

import gsv.SourceView;
import gsv.SourceBuffer;

import gtk.TextIter;
import gtk.Widget;
import gtk.CheckButton;
import gtk.Label;

import gdk.Rectangle;






class CALL_TIPS : ELEMENT
{
    private:

    string      mName;
    string      mInfo;
    bool        mState;

    DOCUMENT[] ConnectedDocs;

    CALL_TIPS_PREF	mPrefPage;
    bool 			mEnabled;

    void Configure()
    {
		mEnabled = Config.getBoolean("CALL_TIPS", "enabled", true);
	}

    public:

    this()
    {
        mName = "CALL_TIPS";
        mInfo = "Displays function signatures, assisting user in choosing and applying the proper function";

        mPrefPage = new CALL_TIPS_PREF;
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

        Config.Reconfig.connect(&Configure);
        Configure();
        Log.Entry("Engaged "~Name()~"\t\telement.");
    }

    void Disengage()
    {
        mState = false;
        dui.GetDocMan.Event.disconnect(&WatchForNewDocument);
        foreach(Doc; ConnectedDocs) Doc.TextInserted.disconnect(&WatchDoc);
        ConnectedDocs.length = 0;
        Log.Entry("Disengaged "~mName~"\t\telement.");

    }

    void WatchForNewDocument(string EventId, DOCUMENT Doc)
    {
        if (Doc is null ) return;
        if ((extension(Doc.Name) == ".d") || (extension(Doc.Name) == ".di"))
        {
			Doc.TextInserted.connect(&WatchDoc);
			ConnectedDocs ~= Doc;
		}
    }

    void WatchDoc(DOCUMENT sv , TextIter ti, string Text, SourceBuffer Buffer)
    {
        if(sv.Pasting) return;
        if(!mEnabled) return;

        switch(Text)
        {
            case "(" :
            {

				TextIter TStart = new TextIter;
				ti.backwardChar();//to go back before the '('
				string Candidate = sv.Symbol(ti, TStart);

				auto Possibles = Symbols.MatchCallTips(Candidate);
				DSYMBOL[] FuncPossibles;

				foreach (dsym; Possibles)
                {
                    if(dsym.Kind != "function") continue;
                    if( !endsWith(Candidate, dsym.Scope[$-1])) continue;
                    FuncPossibles ~= dsym;
                }

                int xpos, ypos, xlen, ylen;
                sv.GetIterPosition(ti, xpos, ypos, xlen, ylen);

                dui.GetAutoPopUps.TipPush(FuncPossibles, xpos, ypos, ylen);
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

    PREFERENCE_PAGE GetPreferenceObject()
    {
        return mPrefPage;
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


class CALL_TIPS_PREF :PREFERENCE_PAGE
{
	CheckButton mEnabled;

	this()
	{
		super("Elements", Config.getString("PREFERENCES", "glade_file_call_tip", "$(HOME_DIR)/glade/proviewpref.glade")); //yes proviewpref.glade is a generic ui
		mEnabled = cast (CheckButton)mBuilder.getObject("checkbutton1");
		Label  x = cast (Label)      mBuilder.getObject("label1");
		x.setMarkup("<b>Function Call Tips :</b>");

		mFrame.showAll();
	}

	override void Apply()
	{
		Config.setBoolean("CALL_TIPS", "enabled", mEnabled.getActive());
	}

	override void PrepGui()
	{
		mEnabled.setActive(Config.getBoolean("CALL_TIPS", "enabled", true));
	}
}
