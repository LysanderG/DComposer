// debugger2.d
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


module debugger2;

import dcore;

import std.algorithm;
import std.array;
import std.signals;
import std.stdio;
import std.conv;
import std.demangle;
import std.string;

import glib.Spawn;
import glib.Source;
import glib.IOChannel;


string GDB_PROMPT = "(gdb)";

class BREAK_POINT
{
	string 					mLocation;	  	//generic location passed to create breakpoint
	string			 		mSourceFile;  	//I'm not figuring these out but gathered from gdb responses
	string					mFunction;
	string					mLabel;
	ulong					mLine;
	
	string 					mType; 			//breakpoint, watchpoint, catchpoint
	string					mDisposition;	//marked disabled after next hit or kept
	string					mAddress;		//ulong?? location or pending
	string					mWhat;			//silly name basically a string where (i think)
	string					mCondition;		//what (besides reaching) causes a break
	
	
	bool					mEnabled;

	@property void Enable(bool x){mEnabled = x;}
	@property bool Enable(){return mEnabled;}
	
	this(string Location)
	{
		mLocation = Location; //in its many forms
	}
}

struct WATCH_POINT
{
	string					mName;
	string					mEnabled;
}

/*
 * Hate working in the dark
 * Can't find accurate information
 * about gdb actual frame record fields
 * different gdb commands will return different things
 * and many are undocumented.
 * Probably should work with assoc arrays or tuples
 * */
struct FRAMEINFO
{
	string Level;
	string Function;
	string Address;
	string SourceFile;
	string Line;
	string From;
}
	
	


class DEBUGGER2
{
	enum STATUS { Null, Engaged, Spawned, Running}
	
	private:
	
	BREAK_POINT[string]	mBreaks;
	WATCH_POINT[string]	mWatches;
	//CALL_STACK[]			mStack;

	string[]				mCommandHistory;

	string[string]			mMangledSymbols;

	STATUS					mStatus;
	int						mSourceEventID;
	
	Spawn					mGdbProcess;
	IOChannel				mGdbOut;
	IOChannel				mGdbIn;

	enum DIRECTGDB {TO_SIGNAL, TO_LOAD_MANGLED_SYMBOLS}
	DIRECTGDB 				mDirectOutPut;

	void LoadMangledSymbols()
	{
		
		writeln("LoadMangledSymbols()");
		mDirectOutPut = DIRECTGDB.TO_LOAD_MANGLED_SYMBOLS;
		AsyncCommand("info variables ^_D");		
	}

	
	
	public :

	
	
	this()
	{
		mStatus = STATUS.Null;
	}

	void Engage()
	{
		mStatus = STATUS.Engaged;
		Log.Entry("Engaged DEBUGGER (2)");
	}

	void Disengage()
	{
		mStatus = STATUS.Null;
		Log.Entry("Disengaged DEBUGGER (2)");
	}


	//		BREAK POINTS ////////////////////////////////////////////
	void  HandleDocBreak(string GiveOrTake, string file, int lineno)
	{
		if (mGdbProcess is null)
		{
			Output.emit("~\"^error Gdb process has not been started.\nPlease 'Load' project to begin debug session\n\"");
			return;
		}
		if (GiveOrTake == "add") AddBreak( file ~ ":" ~ to!string(lineno));
		if (GiveOrTake == "remove") RemoveBreak(file ~ ":" ~ to!string(lineno));

		
	}

	void AddBreak(string BreakID)
	{
		//keep track of breaks later -> dis/enabled, conditions, lots of flash!
		AsyncCommand("-break-insert " ~ BreakID);
	}

	void RemoveBreak(string BreakID)
	{
		AsyncCommand("-break-delete " ~ BreakID);
	}
		

	// 		WATCHES //////////////////////////////////////////////

	void SetWatchPoint(string WatchSymbol)
	{
	}

	void ClearWatchPoints()
	{
	}

	void EnableWatchPoint(string WatchSymbol)
	{
	}

	void DisableWatchPoint(string WatchSymbol)
	{
	}
	
	// Gdb commands ////////////////////////////////////////////////

	void SyncCommand(string Command)
	{
	}

	void AsyncCommand(string Command)
	{
		if (mGdbProcess is null)
		{
			Output.emit("~\"^error Gdb process has not been started.\nPlease 'Load' project to begin debug session\n\"");
			return;
		}
		if(Command is null) return;
		ulong UnusedWriteSize;
        mGdbIn.writeChars(Command ~ '\n', -1, UnusedWriteSize);
       
        mGdbIn.flush();

        
	}


	/////////////////////////////////////////////////////////////////

	void LoadProject(string[] Target)
	{
		mGdbProcess = new Spawn(["gdb","--interpreter=mi", "--args"] ~ Target);        
        mGdbProcess.execAsyncWithPipes();
        mGdbOut = IOChannel.unixNew(mGdbProcess.stdOut);        
        mGdbIn  = IOChannel.unixNew(mGdbProcess.stdIn);

		AsyncCommand("-gdb-set target-async 1");
		AsyncCommand("break _Dmain");

		mSourceEventID = mGdbOut.gIoAddWatch(IOCondition.IN, &GdbOutWatcher, null);
		
		//mGdbOut.gIoAddWatch(IOCondition.ERR , &GdbOutWatcher2, null);

		//grab all d symbols and demangle them into a symbolname[demagled] = mangled
		LoadMangledSymbols();
		
		
	}
	void UnLoadProject()
	{
		//Source.remove(mSourceEventID);
		mGdbOut.shutdown(1);
		mGdbIn.shutdown(1);
		mGdbProcess.close();		
	}

	void CatchGdbOutputs(string gdbResponse)
	{
	}

	@property DIRECTGDB gdbDirection(){return mDirectOutPut;}
	
	void AddMangledSymbol(string gdbVariableInfo)
	{
		static DoneCtr = 3;
		if(gdbVariableInfo.canFind("^done"))
		{
			DoneCtr--;
			if(DoneCtr < 1)
			{
				DoneCtr = 2;
				mDirectOutPut = DIRECTGDB.TO_SIGNAL;
				return;
			}
		}
		auto Split = gdbVariableInfo.findSplitBefore("_D");
		string key = demangle(Split[1].chomp(`;\n"`));
		mMangledSymbols[key] = Split[1].chomp(`;\n"`);
		writeln(key, " = ", Split[1]);
		
	}
	
		

    mixin Signal!(string) Output;
}

extern (C) int GdbOutWatcher (GIOChannel* Channel, GIOCondition Condition, void* nothing)
{

    string readbuffer;
    ulong TermPos;
    IOStatus iostatus;


		
    iostatus = Debugger2.mGdbOut.readLine(readbuffer, TermPos);
    if(iostatus != IOStatus.NORMAL) return 1;

    if(iostatus == IOStatus.NORMAL)
    {
		writeln(Debugger2.gdbDirection, " --> ", readbuffer);
		switch(Debugger2.gdbDirection)
		{
			case DEBUGGER2.DIRECTGDB.TO_LOAD_MANGLED_SYMBOLS : Debugger2.AddMangledSymbol(readbuffer);break;
			case DEBUGGER2.DIRECTGDB.TO_SIGNAL: Debugger2.Output.emit(readbuffer);break;
			default : Debugger2.Output.emit(readbuffer);break;
		}
    }
    return 1;
}



FRAMEINFO GetGdbFrameInfo( string SomeGdbString)
{
	FRAMEINFO Frame;

	auto SplitStr = findSplit(SomeGdbString, "frame={");

	if(SplitStr[2].empty) return Frame;

	int openbraces = 1;

	ulong ctr = 0;
	while (openbraces)
	{
		if(SplitStr[2][ctr] == '{') openbraces++;
		if(SplitStr[2][ctr] == '}') openbraces--;
		ctr++;
		scope(failure)return Frame;
	}

	auto framestring = SplitStr[2][0..ctr];

	//address
	auto tmpstr = findSplitAfter(framestring, `addr="`);
	if(!tmpstr[1].empty)
	{
		foreach (chr; tmpstr[1].until(`"`)) Frame.Address ~= chr;
	}
	//sourcefile
	tmpstr = findSplitAfter(framestring, `fullname="`);
	if(!tmpstr[1].empty)
	{
		foreach (chr; tmpstr[1].until(`"`)) Frame.SourceFile ~= chr;
	}
	//lineno
	tmpstr = findSplitAfter(framestring, `line="`);
	if(!tmpstr[1].empty)
	{
		foreach (chr; tmpstr[1].until(`"`)) Frame.Line ~= chr;
	}
		
		

	return Frame;
}
