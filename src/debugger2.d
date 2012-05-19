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
import std.signals;
import std.stdio;

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
	void SetBreakPoint( string BreakID, BREAK_POINT bp = null)
	{
	}
	void ClearBreakPoints()
	{
		//foreach(bkpt; mBreaks) 
		mBreaks = null;
	}
	void ActivateBreakPoints()
	{
	}

	void EnableBreakPoint( string BreakID)
	{
		if (BreakID in mBreaks)
		{
			mBreaks[BreakID].Enable();
		}
	}

	void DisableBreakPoint( string BreakID)
	{
	}

	void ToggleBreakPoint( string BreakID, string humm, int hoo)
	{
	}

	void ChangeBreakPoint( string BreakID, BREAK_POINT bp)
	{
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

		mSourceEventID = mGdbOut.gIoAddWatch(IOCondition.IN, &GdbOutWatcher, null);
		
		//mGdbOut.gIoAddWatch(IOCondition.ERR , &GdbOutWatcher2, null);
		
		
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

	//void ReadGdbToPrompt()
    //{
    //    //Source.remove(mSourceEventID);
    //    string readbuffer;
    //    ulong TermPos;
    //    IOStatus RetStatus;
    //    while(!readbuffer.startsWith(GDB_PROMPT))
    //    {
    //        RetStatus = mGdbOut.readLine(readbuffer, TermPos);
//
    //        if(RetStatus == IOStatus.NORMAL)
    //        {
    //            Output.emit(readbuffer);
    //        }
    //    }
    //}


    mixin Signal!(string) Output;
}

extern (C) int GdbOutWatcher (GIOChannel* Channel, GIOCondition Condition, void* nothing)
{

    string readbuffer;
    ulong TermPos;
    IOStatus iostatus;

	//if ((Condition & GIOCondition.HUP))
	//{
	//	writeln(Condition);
	//	Log.Entry("see i told you so!!");
	//	//return 0;
	//}
		
    iostatus = Debugger2.mGdbOut.readLine(readbuffer, TermPos);
    if(iostatus != IOStatus.NORMAL) return 1;

    if(iostatus == IOStatus.NORMAL)
    {
        Debugger2.Output.emit(readbuffer);
    }
    return 1;
}

extern (C) int GdbOutWatcher2 (GIOChannel* Channel, GIOCondition Condition, void* nothing)
{

    Log.Entry("hup!!");
    return 0;
}
