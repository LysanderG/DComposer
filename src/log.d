//      log.d
//      
//      Copyright 2011 Anthony Goins <anthony@LinuxGen11>
//      
//      This program is free software; you can redistribute it and/or modify
//      it under the terms of the GNU General Public License as published by
//      the Free Software Foundation; either version 2 of the License, or
//      (at your option) any later version.
//      
//      This program is distributed in the hope that it will be useful,
//      but WITHOUT ANY WARRANTY; without even the implied warranty of
//      MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//      GNU General Public License for more details.
//      
//      You should have received a copy of the GNU General Public License
//      along with this program; if not, write to the Free Software
//      Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
//      MA 02110-1301, USA.


module log;

import std.stdio;
import std.signals;
import std.path;
import std.datetime;
import std.file;

import core.stdc.signal;


import dcore;

class LOG
{
	private :
	string[]        mEntries;                       //buffer of log entries not yet saved to file
    
	string          mSystemDefaultLogName;          //system log file can be overridden be interimfilename but reverts
                                                    //if no -l option on command line
    string          mInterimFileName;               //override regular log file name from cmdline for one session
    string          mLogFile;                       //which of the two above is actually being used this session
    
    ulong           mMaxLines;                      //flush entries buffer
    ulong           mMaxFileSize;                   //if log is this size then don't append overwrite
   

	public:

    this()
    {

        mSystemDefaultLogName =  Config.ExpandPath("$(HOME_DIR)/dcomposer.log");
        mInterimFileName = "unspecifiedlogfile.cfg";
        
        mMaxFileSize = 65_535;
        mMaxLines = 124;
        
        signal(SIGSEGV, &SegFlush);
        signal(SIGABRT, &SegFlush);
        signal(SIGINT, &SegFlush);
        
    }
    ~this()
    {
		Flush();
	}

    void Engage()
    {
        mSystemDefaultLogName = Config.getString("LOG", "default_log_file", mSystemDefaultLogName);
        if(Config.hasKey("LOG", "interim_log_file"))
        {
            mLogFile = Config.getString("LOG", "interim_log_file","$(HOME_DIR)/error.log");
            Config.removeKey("LOG", "interim_log_file");
        }
        else mLogFile = mSystemDefaultLogName;
        
        mMaxLines = Config.getUint64("LOG", "max_lines_buffer", mMaxLines);
        mMaxFileSize = Config.getUint64("LOG", "max_file_size", mMaxFileSize);

        string mode = "w";
        if(exists(mLogFile))
        {
            if(getSize(mLogFile) < mMaxFileSize) mode = "a";
        }

        auto rightnow = Clock.currTime();
        auto logtime = rightnow.toISOExtString();
        
        auto f = File(mLogFile, mode);

        f.writeln("<<++	LOG BEGINS ++>>");
		f.writeln(logtime);

        Entry("Engaged LOG");
    }

    void Disengage()
	{

		auto rightnow = Clock.currTime();
		auto logtime = rightnow.toISOExtString();

                Entry("Disengaged LOG");

		mEntries.length += 2;
		mEntries[$-2] = logtime;
		mEntries[$-1] = "<<-- LOG ENDS -->>\n";
		Flush();
	}     

	
	void Entry(string Message, string Level = "Info", string Module = null )
	{
		//Level can be any string
		//but for now "Debug", "Info", and "Error" will be expected (but not required)
        writeln(Message);
		emit(Message, Level, Module);
		mEntries.length = mEntries.length + 1;
		mEntries[$-1] = Level ~ ": " ~ Message;
		if(Module !is null) mEntries[$-1] ~= " in " ~ Module;
		if(mEntries.length >= mMaxLines) Flush();
	}
    
	void Flush()
	{
		auto f = File(mLogFile, "a");
		foreach (l; mEntries) f.writeln(l);
        f.flush();
        f.close();
		mEntries.length = 0;
	}
    
    mixin Signal!(string, string, string);

    //this only returns the current buffer of entries!
    //the only point of this is to catch entries made before LOG_UI is engaged
    //(you can't show log entries in a gui before the gui is instantiated)
    //.. ok but what if the buffer is like 1 and 100 entries have been made when LOG_UI is engaged?
    //well the file is still there, maybe LOG_UI should just process the file
    //.. then mLogFile will have to be exposed
    //-- why have a max lines anyway?? It's silly just extra crap, maybe have a flush every BackUpAtLineCount
    string[] GetEntries(){return mEntries.dup;}
}

	

import std.c.stdlib;
extern (C) void SegFlush(int SysSig)nothrow @system
{
	try
	{
		writeln("Caught Signal = ", SysSig);
	    Log.Flush();
	    exit(127);
    }
    catch(Exception X)
    {
	    return;
    }
}
	
