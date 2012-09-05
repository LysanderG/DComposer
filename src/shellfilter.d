// shellfilter.d
// 
// Copyright 2012 Anthony Goins <neontotem@gmail.com>
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

module shellfilter;

import dcore;
import ui;
import elements;

import std.process;
import std.array;
import std.stdio;
import std.file;

import gtk.VBox;
import gtk.ComboBox;
import gtk.Entry;
import gtk.Label;
import gtk.Builder;
import gtk.Action;

class SHELLFILTER : ELEMENT
{
	string		mName;
	string		mInfo;
	bool		mState;

	Builder		mBuilder;
	VBox		mRoot;
	ComboBox	mInBox;
	ComboBox	mOutBox;
	Entry		mCommand;
	Label		mErrLabel;
	Action		mAction;		//not implementing this , yet



	void RunCommand(Entry E)
	{

		if (E.getText().length < 1) return;

		string ErrorFile = tempDir()~"/dcomposer.temp";
		if(exists(ErrorFile))remove(ErrorFile);
		
		string Input;
		string Output;
		string[] CmdText = split(E.getText(), "|");

		switch (mInBox.getActiveText())
		{
			case "None": 		Input = "";break;
			case "Selection": 	Input = dui.GetDocMan.GetSelection(); break;
			case "File": 		Input = dui.GetDocMan.GetText();break;
			default : return;
		}

		Input = escapeShellCommand("echo", Input);
		foreach (cmd; CmdText) Input ~= " | " ~ cmd;
		Input ~= " 2>"~ ErrorFile;
		writeln(Input , "\n==========================");
		Output = shell(Input);
		auto errortext = ErrorFile.readText();
		if(errortext.length > 0)
		{
			writeln("error");
			mErrLabel.setText("Error processing "~errortext);
			return;
		}
		else
		{
			mErrLabel.setText("");
		}
		writeln("=========================\n",Output);


		//ok we got the results in output
		auto doc = dui.GetDocMan.GetDocument();
		switch(mOutBox.getActiveText())
		{
			case "Insert at cursor" : doc.insertText(Output); break;
			case "Replace selection or document" :
			{
				if(doc.getBuffer.getHasSelection())
				{
					doc.getBuffer().deleteSelection(0,0);
					doc.insertText(Output);
				}
				else
				{
					doc.getBuffer().setText(Output);
				}
				break;
			}
					
			case "New Document" :
			{
				auto NewAct = dui.Actions.getAction("CreateAct");
				NewAct.activate();
				dui.GetDocMan.GetDocument.getBuffer.setText(Output);
			}
			break;
			default : break;
		}			

	}
				


		

	public:

    this()
    {
        mName = "SHELLFILTER";
        mInfo = "Process text through shell commands";
        mState = false;

        PREFERENCE_PAGE mPrefPage = null;
        dui.AddIcon("dcomposer-shellfilter", Config.getString("ICONS", "shell_filter", "$(HOME_DIR)/glade/funnel.png"));
    }

    @property string Name() {return mName;}
    @property string Information(){return mInfo;}
    @property bool   State() {return mState;}
    @property void   State(bool nuState)
    {
        if(mState == nuState) return;
        mState = nuState;
        if(mState) Engage();
        else Disengage();

    }
    PREFERENCE_PAGE GetPreferenceObject()
	{
		return null;
	}

    

    void Engage()
    {
		mBuilder = new Builder;

		mBuilder.addFromFile(Config.getString("SHELLFILTER", "glade_file","$(HOME_DIR)/glade/shellfilter.glade"));

		mRoot 	= cast(VBox)mBuilder.getObject("root");
		mInBox 	= cast(ComboBox)mBuilder.getObject("combobox1");
		mOutBox = cast(ComboBox)mBuilder.getObject("combobox2");
		mCommand= cast(Entry)mBuilder.getObject("entry1");
		mErrLabel=cast(Label)mBuilder.getObject("errorlabel");

		mErrLabel.setText("");
		mRoot.showAll();
		dui.GetExtraPane.appendPage(mRoot, "Shell Filter");
		dui.GetExtraPane.setTabReorderable ( mRoot, true);

		//mAction = new Action("ShellFilterAct", "Shell Filter", "Shell text processing", "dcomposer-shellfilter");
		mCommand.addOnActivate(&RunCommand);
		
		
		Log.Entry("Engaged "~Name()~"\t\t\telement.");
		
	}

	void Disengage()
	{
		mState = false;
		Log.Entry("Disengaged "~Name()~"\t\telement.");
	}
}
