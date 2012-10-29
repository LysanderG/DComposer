// gotodef.d
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


module gotodef;

import elements;
import dcore;
import ui;

import std.stdio;
import std.string;

import gtk.Action;


class GOTODEF : ELEMENT
{
	private :

	string 		mName;
	string 		mInfo;
	bool		mState;


	void Go(Action Act)
	{
		string CurrentWord = dui.GetDocMan.Current.WordAtPopUpMenu;
		writeln(CurrentWord);
		auto Results = Symbols.GetMatches(CurrentWord);

		if(Results.length < 1)
		{
			auto DotIndex = lastIndexOf(CurrentWord, ".");
			if(DotIndex != -1)  Results = Symbols.GetMatches(CurrentWord[DotIndex .. $]);
		}
		writeln(Results.length);

		if(Results.length < 1) return;
		if(Results.length != 1) Log.Entry("Multiple definitions possible for " ~ CurrentWord);

		dui.GetDocMan.Open(Results[0].File, Results[0].Line-1);



	}


	public:
	this()
    {
        mName = "GOTO_DEF";
        mInfo = "Simply provides a context menu in document to jump to the current words definition.";

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
		dui.AddIcon("dcomposer-goto", Config.getString("GOTODEF", "goto", "$(HOME_DIR)/glade/arrow-transition.png"));

		Action  GotoDefAction = new Action("GotoDefAct", "_Goto definition", "Move to current words definition", "dcomposer-goto");

		GotoDefAction.addOnActivate(&Go);

		dui.GetDocMan.AddContextMenuAction(GotoDefAction);
		Log.Entry("Engaged "~Name()~"\t\telement.");

	}

    void Disengage()
    {
		Log.Entry("Disengaged "~Name()~"\t\telement.");
	}

    PREFERENCE_PAGE GetPreferenceObject()
    {
		return null;
	}
}
