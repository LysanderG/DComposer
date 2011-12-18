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


import dcore;

import glib.Spawn;
import glib.IOChannel;



class DEBUGGER
{
    private :

    bool        mRunning;

    ulong       mCmdId;
    

    Spawn       mGdbProcess;
    IOChannel   mReadFromGdb;
    IOChannel   mWriteToGdb;

    ulong[string] mBreakpoints;
    ulong         mBreakCounter;

    ulong[string] mDisplayExpressions;
   

    bool ReadGdbOutput(string Data)
    {
        scope(failure)return true;

        validate(Data);
        return false;
    }

    bool ReadGdbError(string Data)
    {
        writeln("ERROR ",Data);
        return true;
    }

    int  WatchKidOutput(GIOCondition Condition)
    {
        string RetrievedText;
        size_t TerminatorPos;

        if (Condition == GIOCondition.HUP)
        {
            //channel.unref();
            mReadFromGdb.unref();
            return 0;
        }
        //channel.readLine(OutText, TerminatorPos);
        mReadFromGdb.readLine(RetrievedText, TerminatorPos);

        GdbOutput.emit(RetrievedText);
                
        return 1;
    }

    version (none)
    {
        static extern (C) int  WatchKidOutput(GIOChannel* channel, GIOCondition Condition, void* Data)
        {
            string RetrievedText;
            size_t TerminatorPos;

            DEBUGGER self = cast(DEBUGGER)Data;
            if (Condition == GIOCondition.HUP)
            {
                //channel.unref();
                self.mReadFromGdb.unref();
                return 0;
            }
            //channel.readLine(OutText, TerminatorPos);
            self.mReadFromGdb.readLine(RetrievedText, TerminatorPos);

            self.GdbOutput.emit(RetrievedText);
                    
            return 1;
        }
    }

    public :

    mixin Signal!(string) GdbOutput;

    void Engage()
    {
        mGdbProcess = null;
        mRunning = false;
                
        Log.Entry("Engaged DEBUGGER");
    }

    void Disengage()
    {
        Unload();
        Log.Entry("Disengaged DEBUGGER");
    }


    void Load(string AppName, string SourceDirectories)
    {
        size_t BytesWritten;
        
        mRunning = true;

        mGdbProcess = new Spawn(["gdb","--interpreter=mi", AppName]);

        //mGdbProcess.execAsyncWithPipes(null, &ReadGdbOutput, &ReadGdbError);
        mGdbProcess.execAsyncWithPipes();

        mReadFromGdb = IOChannel.unixNew(mGdbProcess.stdOut);
        mReadFromGdb.gIoAddWatch(GIOCondition.IN | GIOCondition.HUP, &C_WatchKidOutput, cast(void*) this);
        mWriteToGdb = IOChannel.unixNew(mGdbProcess.stdIn);
        mWriteToGdb.writeChars("-break-insert _Dmain\n", -1, BytesWritten);

    }
        
    
    void Unload()
    {
        if(mRunning)
        {
            size_t BytesWritten;
            mWriteToGdb.writeChars("-exec-abort\n", -1, BytesWritten);
            mWriteToGdb.flush();
            mWriteToGdb.writeChars("-gdb-exit\n", -1, BytesWritten);
            mWriteToGdb.flush();
            
            
            mWriteToGdb.shutdown(true);
            mGdbProcess.close();        
            mRunning = false;
        }
    }
    ulong Run()
    {
        size_t BytesWritten;
        mCmdId++;
        string Id = to!string(mCmdId);
        mWriteToGdb.writeChars(Id~"-exec-run\n", -1, BytesWritten);
        mWriteToGdb.flush();
        return mCmdId;
    }

    ulong Continue()
    {
        size_t BytesWritten;
        mCmdId++;
        string Id = to!string(mCmdId);
        mWriteToGdb.writeChars(Id~"-exec-continue\n", -1, BytesWritten);
        mWriteToGdb.flush();
        return mCmdId;
    }
    ulong Abort()
    {
        size_t BytesWritten;
        mCmdId++;
        string Id = to!string(mCmdId);
        //mWriteToGdb.writeChars(Id~"-exec-abort\n", -1, BytesWritten);
        mWriteToGdb.writeChars(Id~"kill\n", -1, BytesWritten);

        mWriteToGdb.flush();

        //foreach(key, value ; mDisplayExpressions) mDisplayExpressions.remove(key);
        
        return mCmdId;
    }
        
    ulong StepIn()
    {
        size_t BytesWritten;
        mCmdId++;
        string Id = to!string(mCmdId);
        mWriteToGdb.writeChars(Id~"-exec-step\n", -1, BytesWritten);
        mWriteToGdb.flush();
        return mCmdId;
    }
    ulong StepOver()
    {
        size_t BytesWritten;
        mCmdId++;
        string Id = to!string(mCmdId);
        mWriteToGdb.writeChars(Id~"-exec-next\n", -1, BytesWritten);
        mWriteToGdb.flush();
        return mCmdId;
    }

    void CatchBreakPoint(string Action, string FileName, int LineNo)
    {
        size_t BytesWritten;
        string BreakKey = FileName ~ ':' ~ to!string(LineNo);

        if(Action == "add")
        {
            if(BreakKey in mBreakpoints) return;
            mBreakpoints[BreakKey] = ++mBreakCounter;
            mCmdId++;
            string Id = to!string(mCmdId);
            writeln("-break-insert " ~ BreakKey);
            writeln(mWriteToGdb);
            mWriteToGdb.writeChars(Id~"-break-insert " ~ BreakKey ~ "\n", -1, BytesWritten);
            mWriteToGdb.flush();
            return;
        }
        if(Action == "remove")
        {
            if (BreakKey !in mBreakpoints) return;
            
            mCmdId++;
            string Id = to!string(mCmdId);
            mWriteToGdb.writeChars(Id~"-break-delete " ~to!string(mBreakpoints[BreakKey])~ "\n", -1, BytesWritten);
            mWriteToGdb.flush();
            mBreakpoints.remove(BreakKey);

            return;
        }
    }

    ulong AddWatchSymbol(string WatchSymbol)
    {
        if(WatchSymbol in mDisplayExpressions) return 0;
        mDisplayExpressions[WatchSymbol] = mDisplayExpressions.length+1;
        size_t BytesWritten;
        mCmdId++;
        string Id = to!string(mCmdId);
        mWriteToGdb.writeChars("display "~ WatchSymbol ~"\n", -1, BytesWritten);
        mWriteToGdb.flush();
        return mCmdId;
    }

    ulong RemoveWatchSymbol(string WatchSymbol)
    {
        if(WatchSymbol in mDisplayExpressions)
        {
            size_t BytesWritten;
            mCmdId++;
            string Id = to!string(mCmdId);
            mWriteToGdb.writeChars(Id ~ "-display-delete " ~ to!string(WatchSymbol) ~ "\n", -1, BytesWritten);
            mWriteToGdb.flush();
            return mCmdId;
        }
        return 0;
    }
            
    
        
        
            
}

static extern (C) int C_WatchKidOutput(GIOChannel* channel, GIOCondition Condition, void* Data)
{
    return Debugger.WatchKidOutput(Condition);    
}
