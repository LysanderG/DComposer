// debugger.d
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


module debugger;

import std.conv;
import std.signals;
import std.stdio;
import std.utf;
import std.string;



import dcore;

import glib.Spawn;
import glib.IOChannel;
import glib.Source;



enum GDB_PROMPT = "(gdb)";

class DEBUGGER
{
    private :

    Spawn       mGdbProcess;
    IOChannel   mGdbOutput;
    IOChannel   mGdbInput;

    int         mSourceId;

    int[string]  mBreakPoints;
    int           mBreakCounter;

    void ReadGdbToPrompt()
    {
        Source.remove(mSourceId);
        string readbuffer;
        ulong TermPos;
        IOStatus RetStatus;
        while(!readbuffer.startsWith(GDB_PROMPT))
        {
            RetStatus = mGdbOutput.readLine(readbuffer, TermPos);

            if(RetStatus == IOStatus.NORMAL)
            {
                Output.emit(readbuffer);
            }
        }
    }

    void Load()
    {
        
        mGdbProcess = new Spawn(["gdb","--interpreter=mi", Project.WorkingPath ~"/"~Project.Name]);

        
        mGdbProcess.execAsyncWithPipes();
        //setpgid?
        //gdbprocess exit callback?
        
        mGdbOutput = IOChannel.unixNew(mGdbProcess.stdOut);
        mGdbInput  = IOChannel.unixNew(mGdbProcess.stdIn);

        ReadGdbToPrompt();
        
    }

    void SendSyncCommand(string Command)
    {
        ulong UnusedWriteSize;
        ulong TermPos;
        
        mGdbInput.writeChars(Command ~ "\n", -1, UnusedWriteSize);
        
        mGdbInput.flush();

        ReadGdbToPrompt();
    }

    void SendCommand(string Command)
    {

        ulong UnusedWriteSize;
        
        mGdbInput.writeChars(Command ~ "\n", -1, UnusedWriteSize);
       
        mGdbInput.flush();

        ReadGdbToPrompt();
                
        mSourceId = mGdbOutput.gIoAddWatch(IOCondition.IN, &GdbOutputWatcher, null);
        
    }
    

    public :

    this()
    {
    }

    void Engage()
    {
        Log.Entry("Engaged DEBBUGER");
    }

    void Disengage()
    {
        Log.Entry("Disengaged DEBUGGER");
    }


    void Cmd_Run()
    {
        Load();

        SendSyncCommand("-gdb-set target-async 1");

        SendSyncCommand("-break-insert _Dmain");

        SendCommand("-exec-run");
       
    }

    void Cmd_Continue()
    {
        SendCommand("-exec-continue");
    }

    void Cmd_StepOver()
    {
        SendCommand("-exec-next");
    }
    void Cmd_StepIn()
    {
		SendCommand("-exec-step");
	}
    void CatchBreakPoint(string Action, string SourceFile, int Line)
    {
        if ( mGdbProcess is null) return;
        string BreakKey =  SourceFile ~ ":" ~ to!string(Line);
        switch (Action)
        {
            case "add" :
            {                
                if(BreakKey in mBreakPoints)
                {
                    SendSyncCommand("-break-enable " ~ to!string(mBreakPoints[BreakKey]));
                    break;
                }
                    
                mBreakPoints[BreakKey] = ++mBreakCounter;
                SendSyncCommand("-break-insert " ~ BreakKey);
                break;
            }
            case "remove" :
            {
                if(BreakKey in mBreakPoints)
                {
                    SendSyncCommand("-break-disable " ~ to!string(mBreakPoints[BreakKey]));
                }
                    
                break;
            }
            default : return;
        }   
    }

    mixin Signal!(string) Output;
}


extern (C) int GdbOutputWatcher (GIOChannel* Channel, GIOCondition Condition, void* nothing)
{

    string readbuffer;
    ulong TermPos;
    IOStatus iostatus;
 
    iostatus = Debugger.mGdbOutput.readLine(readbuffer, TermPos);
    if(iostatus != IOStatus.NORMAL) return 1;

    if(iostatus == IOStatus.NORMAL)
    {
        Debugger.Output.emit(readbuffer);
    }

    if(readbuffer.startsWith("*stopped"))
    {
        Source.remove(Debugger.mSourceId);
        //Debugger.ReadGdbToPrompt();
        return 0;
        
    }
    return 1;
}
    
