// debuggerui.d
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


module debuggerui;

import std.string;
import std.stdio;
import std.array;

import elements;
import dcore;
import ui;


import gtk.Builder;
import gtk.VBox;
import gtk.ToolButton;
import gtk.TextView;
import gtk.TreeView;
import gtk.TreeStore;
import gtk.Entry;
import gtk.CellEditableIF;

import gdk.Color;


class DEBUGGER_UI : ELEMENT
{
	string 			mName;
	string 			mInfo;
	bool			mState;
	
	Builder			mBuilder;
	VBox			mRoot;
	TextView		mGdbView;
	TextView		mProgramView;

	Entry			mCmdEntry;
	
	ToolButton		mLoad;
	ToolButton		mRun;


	void GrabGdbOutput(string Text)
	{
		if(Text.length < 1)
		{
			mGdbView.appendText("OMG null text!!!\n");
			return;
		}
		if(Text.startsWith("(gdb)"))
		{
			mGdbView.appendText(Text ~ '\n');
			return;
		}
		
		string line;
		line = Text.replace(`\"`, `"`);
		line = Text.replace(`\n`, "\n");
		
		
		switch (Text[0])
		{
			case '~' :
			{
				scope(failure) {mGdbView.appendText(line);break;}
				line = line[2..$-2];
				mGdbView.appendText(line ~ '\n');
				break;
			}

			case '=' :
			{
				
				scope(failure) {mGdbView.appendText(line);break;}
				line = line[1..$];
				mGdbView.appendText('\t' ~ line ~ '\n');
				
				break;
			}

			default :
			{
				mProgramView.appendText(line ~ '\n');
			}
		}

		
	}
		
	
    
    public :
    
    @property string Name(){return mName;}
    @property string Information(){return mInfo;}
    @property bool   State(){return mState;}
    @property void   State(bool nuState)
    {
        if(mState == nuState) return;
        mState = nuState;
        (mState) ? Engage() : Disengage();
    }

    this()
    {
		mName = "DEBUGGERUI";
		mInfo = "2nd generation debugger interface";
		mState = false;
	}

	void Engage()
	{
		mState = true;
		mBuilder = new Builder;
		mBuilder.addFromFile(Config.getString("DEBUG", "debugger_ui", "/home/anthony/.neontotem/dcomposer/debuggerui.glade"));

		mRoot 		= cast (VBox) 		mBuilder.getObject("root");		
		mGdbView 	= cast (TextView)	mBuilder.getObject("gdbtext");
		mProgramView= cast (TextView)	mBuilder.getObject("programtext");
		mCmdEntry	= cast (Entry)		mBuilder.getObject("cmdentry");

		mLoad		= cast (ToolButton) mBuilder.getObject("loadbtn");
		mRun 		= cast (ToolButton) mBuilder.getObject("runbtn");
		
		dui.GetExtraPane.appendPage(mRoot, "Debugging2");
        dui.GetExtraPane.setTabReorderable ( mRoot, true);

        Debugger2.Output.connect(&GrabGdbOutput);

        mCmdEntry	.addOnActivate(delegate void(Entry x){Debugger2.AsyncCommand(mCmdEntry.getText());});
        mLoad		.addOnClicked(delegate void(ToolButton x) { Debugger2.LoadProject([Project.Name, "-ctmpcfg", "-ltmplog.log"] );});
		mRun		.addOnClicked(delegate void(ToolButton x) { Debugger2.AsyncCommand("-exec-run");});
			
        mGdbView.modifyText(StateType.NORMAL, new Color(200,200,0));
        mGdbView.modifyBase(StateType.NORMAL, new Color(5, 5, 5));
        
		mProgramView.modifyText(StateType.NORMAL, new Color(200, 0, 0));
        

        Log.Entry("Engaged DEBUGGERUI element");                
    }

    void Disengage()
    {
		mState = false;
		Log.Entry("Disengaged DEBUGGERUI element");
	}

	PREFERENCE_PAGE GetPreferenceObject()
	{
		return null;
	}

}
