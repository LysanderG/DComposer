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
import std.path;




import gsv.SourceView;
import gsv.SourceBuffer;

import gtk.TextIter;
import gtk.Widget;

import gdk.Rectangle;
import gtk.CheckButton;



class SCOPE_LIST : ELEMENT
{
    private:

    string      mName;
    string      mInfo;
    bool        mState;

    SCOPE_LIST_PAGE mPrefPage;
    bool		mEnabled;   //This is what mState should be for but mState (d)evolved  into an Engage/Disengage (read permanent) solution.
							//A superfluous solution at that.


	void Configure()
	{
		mEnabled = Config.getBoolean("SCOPE_LIST", "enabled", true);
	}

    void WatchForNewDocument(string EventId, DOCUMENT Doc)
    {
        if (Doc is null ) return;
        if ((extension(Doc.Name) == ".d") || (extension(Doc.Name) == ".di"))
        {
			Doc.TextInserted.connect(&WatchDoc);
		}
    }

    void WatchDoc(DOCUMENT sv, TextIter ti, string text, SourceBuffer buffer)
    {
        int xpos, ypos, xlen, ylen;

		if (text.length > 1) return;
        if (text != ".") return;
        if (!mEnabled) return;
        if (sv.Pasting) return;

        ti.backwardChar();
        TextIter TStart = new TextIter;

		string Candidate = sv.Symbol(ti, TStart);

        if(Candidate.length < 1) return;
        DSYMBOL[] possibles = Symbols.Match(Candidate);

        sv.GetIterPosition(ti, xpos, ypos, xlen, ylen);
        dui.GetAutoPopUps.CompletionPush(possibles, xpos, ypos, ylen, STATUS_SCOPE);
    }


    public:

    this()
    {
        mName = "SCOPE_LIST";
        mInfo = "present all members of a scope for easy pickins";
        mState = false;

        mPrefPage = new SCOPE_LIST_PAGE;
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
        Config.Reconfig.connect(&Configure);
        Configure();

        Log.Entry("Engaged "~Name()~"\t\telement.");
	}

    void Disengage()
    {
		dui.GetDocMan.Event.disconnect(&WatchForNewDocument);
		Config.Reconfig.disconnect(&Configure);
        Log.Entry("Disengaged "~mName~"\t\telement.");
    }


    PREFERENCE_PAGE GetPreferenceObject()
    {
        return mPrefPage;
    }
}

class SCOPE_LIST_PAGE : PREFERENCE_PAGE
{
	CheckButton 	mEnabled;


	this()
	{
		super("Elements", Config.getString("PREFERENCES", "glade_file_scope_list", "$(HOME_DIR)/glade/scopelistpref.glade"));
		mEnabled = cast(CheckButton)mBuilder.getObject("checkbutton1");
		mFrame.showAll();
	}

	override void Apply()
	{
		Config.setBoolean("SCOPE_LIST", "enabled", mEnabled.getActive());
	}

	override void PrepGui()
	{
		mEnabled.setActive(Config.getBoolean("SCOPE_LIST","enabled"));
	}
}
