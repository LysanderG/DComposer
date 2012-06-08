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

import std.algorithm;
import std.string;
import std.stdio;
import std.array;
import std.conv;

import core.sys.posix.unistd;

import elements;
import dcore;
import ui;
import document;


import gtk.Builder;
import gtk.VBox;
import gtk.ToolButton;
import gtk.TextView;
import gtk.TreeView;
import gtk.TreeStore;
import gtk.Entry;
import gtk.CellEditableIF;
import gtk.Action;
import gtk.Widget;
import gtk.Notebook;
import gtk.Label;
import gtk.ScrolledWindow;

import gdk.Color;


extern(C) void 	* 	vte_terminal_new();
extern(C) int 		vte_terminal_get_pty(void *vteterminal);
extern(C) char 	* 	vte_terminal_get_allow_bold (void * vteterminal);
extern(C) int   	vte_terminal_fork_command (void *terminal, const char *command, char **argv, char **envv, const char *working_directory, gboolean lastlog, gboolean utmp, gboolean wtmp);
extern(C) void 	* 	vte_terminal_pty_new (void *terminal, int flags, void * errorthingy);
extern(C) void      vte_terminal_set_pty(void *terminal, int pty_master);

extern(C) int 		openpty(int *amaster, int *aslave, char *name, void *termp, void *winp);
extern(C) int 		grantpt(int fd);
extern(C) int 		unlockpt(int fd);



                                                         

class DEBUGGER_UI : ELEMENT
{
	string 			mName;
	string 			mInfo;
	bool			mState;
	
	Builder			mBuilder;
	VBox			mRoot;
	TextView		mGdbView;
	ScrolledWindow  mProgScroll;
	Widget			mProgramVte;
	void *			cProgramVte;

	Entry			mCmdEntry;
	
	ToolButton		mLoad;
	ToolButton		mRun;
	ToolButton		mContinue;
	ToolButton		mFinish;
	ToolButton		mRunToCursor;
	ToolButton		mStepIn;
	ToolButton		mStepOver;
	ToolButton		mAbort;

	int				pty_master;
	int				pty_slave;
	char *			pty_name;



	void Load()
	{
		Debugger2.LoadProject([Project.Name, "&"] );

		char * TtyCharName = ttyname(pty_slave);
		string TtyName = to!string(TtyCharName);


		Debugger2.AsyncCommand("set inferior-tty " ~ TtyName ~ "\n");
	}

	void GrabGdbOutput(string Text)
	{
		if(Text.length < 1)
		{
			mGdbView.appendText("OMG null text!!!\n");
			return;
		}

		mGdbView.appendText(Text ~ '\n');

		if(Text.startsWith("*stopped"))
		{
				scope(failure){mGdbView.appendText("exited"); return;}
				auto tmp = debugger2.GetGdbFrameInfo(Text);
				dui.GetDocMan.OpenDoc(tmp.SourceFile, to!int(tmp.Line) -1);		
			
		}		

	}

	void AddWatch(Action x = null)
	{
		auto tmpdoc = cast(DOCUMENT)dui.GetDocMan().GetDocX();
		auto CurrentWord = tmpdoc.GetCurrentWord();

		//for now just put up the basic struct
		//later will match the current word to the mangled symbol that gdb sees
		//gdb sucks with d symbols (or I am stupidier than I thought)
		Debugger2.AsyncCommand("display " ~ CurrentWord);
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
		mProgScroll = cast (ScrolledWindow) mBuilder.getObject("scrolledwindow5");
		mCmdEntry	= cast (Entry)		mBuilder.getObject("cmdentry");

		mLoad		= cast (ToolButton) mBuilder.getObject("loadbtn");
		mRun 		= cast (ToolButton) mBuilder.getObject("runbtn");
		mContinue  	= cast (ToolButton) mBuilder.getObject("continuebtn");
		mFinish		= cast (ToolButton) mBuilder.getObject("finishbtn");
		mRunToCursor= cast (ToolButton) mBuilder.getObject("runtocursorbtn");
		mStepIn		= cast (ToolButton) mBuilder.getObject("stepinbtn");
		mStepOver	= cast (ToolButton) mBuilder.getObject("stepoverbtn");
		mAbort		= cast (ToolButton) mBuilder.getObject("abortbtn");
		
		
		dui.GetExtraPane.appendPage(mRoot, "Debugging2");
        dui.GetExtraPane.setTabReorderable ( mRoot, true);

        Debugger2.Output.connect(&GrabGdbOutput);

        cProgramVte = vte_terminal_new();
        Widget mProgramVte = new Widget(cast (GtkWidget*)cProgramVte);

		openpty(&pty_master, &pty_slave, pty_name, null, null);
		grantpt(pty_master);
		unlockpt(pty_master);
		vte_terminal_set_pty(cProgramVte, pty_master);
        
        mProgramVte.showAll();

        
        mCmdEntry	.addOnActivate(delegate void(Entry x){Debugger2.AsyncCommand(mCmdEntry.getText());});
        mLoad		.addOnClicked(delegate void(ToolButton x) { Load();});
		mRun		.addOnClicked(delegate void(ToolButton x) { Debugger2.AsyncCommand("-exec-run &" );});
		mContinue	.addOnClicked(delegate void(ToolButton x) { Debugger2.AsyncCommand("-exec-continue" );});
		mFinish		.addOnClicked(delegate void(ToolButton x) { Debugger2.AsyncCommand("-exec-finish" );});
		mRunToCursor.addOnClicked(delegate void(ToolButton x) { Debugger2.AsyncCommand("advance " ~ dui.GetDocMan.GetCurrentLocation());});
		mStepIn		.addOnClicked(delegate void(ToolButton x) { Debugger2.AsyncCommand("-exec-step" );});
		mStepOver  	.addOnClicked(delegate void(ToolButton x) { Debugger2.AsyncCommand("-exec-next" );});
		mAbort		.addOnClicked(delegate void(ToolButton x) { Debugger2.AsyncCommand("kill" );});
			
        mGdbView.modifyText(StateType.NORMAL, new Color(200,200,0));
        mGdbView.modifyBase(StateType.NORMAL, new Color(5, 5, 5));


		Action  WatchAct = new Action("WatchAct", "Add _Watch", "Follow symbol in debugger", null);
        WatchAct.addOnActivate(&AddWatch);
        WatchAct.setAccelGroup(dui.GetAccel());
        dui.Actions().addActionWithAccel(WatchAct, null);
        dui.GetDocMan.AddContextAction(WatchAct);


        //auto NoteBook2 = cast(Notebook)mBuilder.getObject("rightnotebook");
        //NoteBook2.appendPage(mProgramVte, new Label("Program"));
		mProgScroll.add(mProgramVte);

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
