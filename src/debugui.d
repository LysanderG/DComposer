// debugui.d
// 
// Copyright 2011 Anthony Goins <anthony@LinuxGen11>
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


module debugui;

import std.algorithm;
import std.array;
import std.conv;
import std.stdio;
import std.string;


import dcore;
import ui;

import elements;

import gtk.Builder;
import gtk.ScrolledWindow;
import gtk.ToolButton;
import gtk.TextView;
import gtk.Entry;

class DEBUG_UI : ELEMENT
{
    private :

    string              mName;
    string              mInfo;
    bool                mState;

    bool                mExecLoaded;

    Builder             mBuilder;
    ScrolledWindow      mRoot;
    ToolButton          mRunBtn;
    ToolButton          mContinueBtn;
    ToolButton          mRestartBtn;
    ToolButton          mStopBtn;
    ToolButton          mStepOverBtn;
    ToolButton          mStepInBtn;
    ToolButton          mAddWatch;
    ToolButton          mQuitBtn;

    Entry               mWatchExpression;
    TextView            mTextConsole;
    TextView            mInfoConsole;

    //watch for project open signal and try to load the target app
    void Load(string ProjectFile)
    {
        Debugger.Load(Project.Name, Project.ProjectDir);
        mExecLoaded = true; //don't forget to FIX THIS!
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
        mName = "DEBUG_UI";
        mInfo = "experimental, simple, learning ... Debugging interface";
        mState = false;
    }


    void Engage()
    {

        Project.Opened.connect(&Load);
        
        mBuilder    = new Builder;
        mBuilder.addFromFile(Config.getString("DEBUG", "debug_ui", "/home/anthony/.neontotem/dcomposer/dbugx.glade"));

        mRoot       = cast(ScrolledWindow)mBuilder.getObject("scrolledwindow1");
        mRunBtn     = cast(ToolButton)mBuilder.getObject("runbtn");
        mContinueBtn= cast(ToolButton)mBuilder.getObject("continuebtn");
        mStepOverBtn= cast(ToolButton)mBuilder.getObject("stepoverbtn");
        mStepInBtn  = cast(ToolButton)mBuilder.getObject("stepinbtn");
        mAddWatch   = cast(ToolButton)mBuilder.getObject("watchbtn");
        mQuitBtn    = cast(ToolButton)mBuilder.getObject("quitbtn");

        mWatchExpression = cast(Entry)mBuilder.getObject("entry1");
        
        mTextConsole= cast(TextView)mBuilder.getObject("textview1");
        mInfoConsole= cast(TextView)mBuilder.getObject("textview2");

        mRunBtn.addOnClicked(delegate void(ToolButton x){if(!mExecLoaded)return; Debugger.Run();});
        mContinueBtn.addOnClicked(delegate void(ToolButton x){if(!mExecLoaded)return;  Debugger.Continue();});
        mStepOverBtn.addOnClicked(delegate void(ToolButton x){if(!mExecLoaded)return;  Debugger.StepOver();});
        mStepInBtn.addOnClicked(delegate void(ToolButton x){if(!mExecLoaded)return; Debugger.StepIn();});
        mAddWatch.addOnClicked(delegate void(ToolButton x){if(!mExecLoaded)return; Debugger.AddWatchSymbol(mWatchExpression.getText);});
        mQuitBtn.addOnClicked(delegate void(ToolButton x ){if(!mExecLoaded)return; Debugger.Abort();});
        

        Debugger.GdbOutput.connect(&GdbCatcher);
        

        mRoot.showAll();

        dui.GetExtraPane.appendPage(mRoot, "Debugger");

        Log.Entry("Engaged DEBUG_UI element");
                
    }

    void Disengage()
    {
        Log.Entry("Disengaged DEBUG_UI element");
    }

    void GdbCatcher(string GdbText)
    {
        if(GdbText is null) return;
        if(GdbText[0] == '=') return;

        

        JumpToPosition(GdbText);
        ShowDisplayExpressions(GdbText);
        
        mTextConsole.appendText(GdbText  ~'\n', true);
    }

    void JumpToPosition(string Record)
    {
        

        auto fname  = Record.findSplit(`fullname="`);
        if (fname[2].empty) return;
        auto idx = fname[2].countUntil(`"`);
        fname[2] = fname[2][0..idx];

        auto lineno  = Record.findSplit(`line="`);
        if (lineno[2].empty) return;
        idx = lineno[2].countUntil(`"`);
        lineno[2] = lineno[2][0..idx];

        dui.GetDocMan.OpenDoc(fname[2], to!int(lineno[2])-1);
        
    }

    void ShowDisplayExpressions(string DisplayText)
    {
        auto colonindex = std.string.indexOf(DisplayText,":");
        if (colonindex == -1) return;

        auto equalindex = std.string.indexOf(DisplayText, "=");
        if (equalindex == -1) return;
        
        mInfoConsole.appendText(DisplayText[colonindex+1..equalindex] ~"\t\t| " ~ DisplayText[equalindex+1..$] ~ '\n', true);        
    }
 
}
