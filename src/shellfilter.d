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
import document;

import std.process : escapeShellFileName;
import std.array;
import std.stdio;
import std.file;
import std.algorithm;

import gtk.VBox;
import gtk.ComboBox;
import gtk.Entry;
import gtk.Label;
import gtk.Builder;
import gtk.Action;
import gtk.TextIter;
import gtk.Button;

class SHELLFILTER : ELEMENT
{
	string		mName;
	string		mInfo;
	bool		mState;

	Builder		mBuilder;
	VBox		mRoot;
	ComboBox	mInBox;
	ComboBox	mOutBox;
	ComboBox	mCommandCombox;
	Entry		mCommand;
	Label		mErrLabel;
	Action		mAction;		//not implementing this , yet

	string[]	mCmdHistory;



	void RunCommand(Entry E)
	{
		scope(failure)
		{
			mErrLabel.setText("Error");
			return;
		}

		if (E.getText().length < 1) return;

		string ErrorFile = tempDir()~"/dcomposer.temp";
		if(exists(ErrorFile))remove(ErrorFile);

		string Input;
		string Output;
		string CmdText = E.getText();



		string TextToProcess = tempDir()~"/dcompprocess.text";
		File TextToProcessFile = File(TextToProcess, "w");

		switch (mInBox.getActiveText())
		{
			case "None": 		Input = "";break;  //tried Input = "" but some commands wait for std input forever causing a freeze
			case "Word":		Input = dui.GetDocMan.GetWord();		if(Input.length < 1) return; break;
			case "Line":		Input = dui.GetDocMan.GetLineText();	if(Input.length < 1) return; break;
			case "Selection": 	Input = dui.GetDocMan.GetSelection(); 	if(Input.length < 1) return; break;
			case "Document":	Input = dui.GetDocMan.GetText(); 		if(Input.length < 1) return; break;
			default : return;
		}

		TextToProcessFile.write(Input);
		TextToProcessFile.close();

		string xInput = "";

		if(Input.length >0) xInput = `cat  ` ~ TextToProcess ~ ` | `;
		xInput ~= CmdText ~ " 2> " ~ escapeShellFileName(ErrorFile);
		Output = shell(xInput);

		auto errortext = ErrorFile.readText();
		if(errortext.length > 0)
		{
			mErrLabel.setText("Error processing "~errortext);
			return;
		}
		else
		{
			mErrLabel.setText("");
		}



		//ok we got the results in output
		DOCUMENT doc;
		scope(exit)if(doc !is null)doc.getBuffer.endUserAction();

		switch(mOutBox.getActiveText())
		{
			case "Insert at cursor" :
			{
				doc = dui.GetDocMan.GetDocument();
				doc.getBuffer.beginUserAction();
				doc.insertText(Output);
				break;
			}

			case "Replace input" :
			{
				doc = dui.GetDocMan.GetDocument();
				doc.getBuffer.beginUserAction();
				TextIter InputStart = new TextIter;
				TextIter InputEnd = new TextIter;

				switch(mInBox.getActiveText())
				{
					case "None" :
					{

						doc.getBuffer.getIterAtMark(InputStart,doc.getBuffer.getInsert);
						InputEnd = InputStart.copy;
						break;
					}
					case "Word" :
					{
						doc.getBuffer.getIterAtMark(InputStart,doc.getBuffer.getInsert);
						InputEnd = InputStart.copy;
						InputStart.backwardWordStart();
						InputEnd.forwardWordEnd();
						break;
					}
					case "Line" :
					{
						doc.getBuffer.getIterAtMark(InputStart,doc.getBuffer.getInsert);
						InputEnd = InputStart.copy;
						InputStart.setLineOffset(0);
						InputEnd.forwardToLineEnd();
						break;
					}
					case "Selection" :
					{
						 doc.getBuffer.getSelectionBounds (InputStart, InputEnd);
						 break;
					}
					case "Document" :
					{
						doc.getBuffer.getStartIter(InputStart);
						doc.getBuffer.getEndIter(InputEnd);
						break;
					}

					default :
				}

				doc.getBuffer.delet(InputStart, InputEnd);
				doc.getBuffer.insert(InputStart, Output);
				break;
			}

			case "New document" :
			{
				auto NewAct = dui.Actions.getAction("CreateAct");
				NewAct.activate();
				doc = dui.GetDocMan.GetDocument();
				doc.getBuffer.beginUserAction();
				doc.getBuffer.setText(Output);
				break;
			}
			default : break;
		}

		if(!mCmdHistory.canFind(CmdText))mCommandCombox.prependOrReplaceText(CmdText);
		mCmdHistory ~= CmdText;
	}

	void Configure()
	{
		mCmdHistory = Config.getStringList("SHELLFILTER", "history", ["sort", "date"]);


		foreach(cmd; mCmdHistory) mCommandCombox.appendText(cmd);

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

		auto tmpButton = cast(Button)mBuilder.getObject("button1");
		tmpButton.addOnClicked(delegate void (Button x){RunCommand(mCommand);});
		mRoot 	= cast(VBox)mBuilder.getObject("root");
		mInBox 	= cast(ComboBox)mBuilder.getObject("combobox1");
		mOutBox = cast(ComboBox)mBuilder.getObject("combobox2");
		//mCommand= cast(Entry)mBuilder.getObject("entry1");
		mCommandCombox = cast(ComboBox)mBuilder.getObject("commandbox");
		mErrLabel=cast(Label)mBuilder.getObject("errorlabel");

		mCommandCombox.add(new Entry);
		mCommand = cast(Entry)(mCommandCombox.getChild());

		mErrLabel.setText("");
		mRoot.showAll();
		//dui.GetExtraPane.appendPage(mRoot, "Shell Filter");
        dui.GetExtraPane.insertPage(mRoot, new Label("Shell Filter"), Config.getInteger("SHELLFILTER", "page_position"));

		dui.GetExtraPane.setTabReorderable ( mRoot, true);

		Configure();

		mCommand.addOnActivate(&RunCommand);

		Log.Entry("Engaged "~Name()~"\t\t\telement.");

	}

	void Disengage()
	{
		Config.setInteger("SHELLFILTER", "page_position", dui.GetExtraPane.pageNum(mRoot));

		string[] saveHistory;
		foreach(history; uniq(mCmdHistory.sort)) saveHistory ~= history;
		Config.setStringList("SHELLFILTER", "history", saveHistory);
		mState = false;
		Log.Entry("Disengaged "~Name()~"\t\telement.");
	}
}

