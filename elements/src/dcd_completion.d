module dcd_completion;

import ui;
import dcore;
import elements;
import document;
import ui_preferences;

import std.signals;
import std.string;
import std.uni;
import std.algorithm;
import std.stdio;


import gdk.Event;
import gdk.Keysyms;
import gtk.Widget;
import gtk.TextIter;
import gtk.TextBuffer;


extern (C) string GetClassName()
{
	return "dcd_completion.DCD_COMPLETION";
}

class DCD_COMPLETION : ELEMENT
{
	private:

	Pid mServerPid;
	string mClientCommand;
	string mServerCommand;

	void WatchForText(TextIter ti, string Text, gint TextLen, TextBuffer Buffer)
	{

		uiCompletion.PopComplete();
		if(Text.length > 1) return;

		auto whereRect = DocMan.Current.GetCursorRectangle();

		string[] Candidates;

		switch (Text[0])
		{
			case 'a' : .. case 'z' :
			case 'A' : .. case 'Z' :
			case '0' : .. case '9' :
			case '_' :
			case '.' :
			{
				Candidates = GetDCDCandidates(ti);
				if(Candidates.length > 0)uiCompletion.PushComplete(Candidates, whereRect);
				break;
			}

			case '(' :
			{
				Candidates = GetDCDCandidates(ti);
				if(Candidates.length > 0)uiCompletion.PushTip(Candidates, whereRect);
				break;
			}
			case ')' :
			{
				//try this see how it works
				uiCompletion.PopTip();
				break;
			}
			default : break;
		}
	}


	string[] GetDCDCandidates(TextIter ti)
	{
		//find offset
		auto tiOffset = ti.copy();
		int offsetnotbytes = tiOffset.getLineIndex();
		while(tiOffset.backwardLine())offsetnotbytes += tiOffset.getBytesInLine();

		//start dcd with -c offset
		string CmdOption = format("-c%s", offsetnotbytes);

		std.process.ProcessPipes presult;
		try
		{
			presult = std.process.pipeProcess([mClientCommand, CmdOption]);
		}
		catch(Exception x)
		{
			Log.Entry(x.toString(), "Error");
		}

		//write text to dcd stdin (why did i do it by line? dunno)
		foreach(oline; DocMan.Current.GetText().splitLines())
		{
			presult.stdin.writeln(oline);
		}
		presult.stdin.flush();
		presult.stdin.close();





		//now read the results from dcd
		string[] CompletionLines;
		foreach (line; presult.stdout.byLine())
		{
			auto idx = countUntil(line, '\t'); //get rid of the type thingy on the end don't think i need it
			if (idx < 0) idx = line.length;
			CompletionLines ~= line[0..idx].idup;
		}

		wait(presult.pid);

		//get rid of the first line ... it should be "identifiers" or "calltips" don't need it
		if(CompletionLines.length < 2) return [];
		return CompletionLines[1..$];
	}




	void WatchForNewDocuments(string EventName, DOC_IF nuDoc)
	{
		auto xDoc = cast(DOCUMENT)nuDoc;

		xDoc.getBuffer().addOnInsertText(&WatchForText);

	}


	public:
	string Name(){return "DCD completion";}
	string Info(){return "Symbol completion, calltips, and more using HackerPilot's excellent DCD utility.";}
	string Version() {return "00.01";}
	string CopyRight() {return "Anthony Goins © 2014";}
	string License() {return "New BSD license";}
	string[] Authors() {return ["Anthony Goins <neontotem@gmail.com>"];}

	void Engage()
	{
		Configure();

		string[] DcdServerCommandLine;
		foreach(imp; Config.GetArray("dcd_element","import_paths",["/opt/dmd/include/d2", "/usr/local/include/d/gtkd-2"]))
		{
			DcdServerCommandLine ~= "-I" ~ imp;
		}

		scope(failure)
		{
			Log.Entry("Failed to start dcd-server", "Error");
			assert(0);
		}
		mServerPid = spawnProcess(mServerCommand ~ DcdServerCommandLine, std.stdio.stdin, std.stdio.File("/dev/null","w"));
		dwrite(mServerPid.processID);
		DocMan.Event.connect(&WatchForNewDocuments);

		Log.Entry("Engaged");
	}


	void Disengage()
	{
		scope(failure)Log.Entry("Failed to Disengage DCD_COMPLETION", "Error");

		//execute([mClientCommand, "--shutdown"]);
		kill(mServerPid);
		wait(mServerPid);


		DocMan.Event.disconnect(&WatchForNewDocuments);

		Log.Entry("Disengaged");
	}


	void Configure()
	{
		mServerCommand = SystemPath(Config.GetValue("dcd_element", "server_command", "deps/DCD/dcd-server"));
		mClientCommand = SystemPath(Config.GetValue("dcd_element", "client_command", "deps/DCD/dcd-client"));
	}

	PREFERENCE_PAGE PreferencePage()
	{
		return null;
	}
}

