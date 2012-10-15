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
import std.string;

import core.stdc.signal;


import dcore;

/**
 * Saves info and errors to file
 *
 * Probably better off using someone elses library
 * */
class LOG
{
	private :
	string[]        mEntries;                       //buffer of log entries not yet saved to file

	string          mSystemDefaultLogName;          //system log file can be overridden by interimfilename but reverts
                                                    //if no -l option on command line
    string          mInterimFileName;               //override regular log file name from cmdline for one session
    string          mLogFile;                       //which of the two above is actually being used this session

    ulong           mMaxLines;                      //flush entries buffer
    ulong           mMaxFileSize;                   //if log is this size then don't append overwrite

    bool			mLockEntries;					//don't dispose of mEntries if this is true

    bool			mEchoToStdOut;					//whether to write entries to stdout


	public:

    this()
    {

        mSystemDefaultLogName =  Config.ExpandPath("$(HOME_DIR)/dcomposer.log");
        mInterimFileName = "unspecifiedlogfile.cfg";

        mMaxFileSize = 65_535;
        mMaxLines = 255;

        mLockEntries = true;
        mEchoToStdOut = true;

        signal(SIGSEGV, &SegFlush);
        signal(SIGABRT, &SegFlush);
        signal(SIGINT, &SegFlush);

    }
    ~this()
    {
		mLockEntries = false;
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

        mMaxLines     = Config.getUint64("LOG", "max_lines_buffer", mMaxLines);
        mMaxFileSize  = Config.getUint64("LOG", "max_file_size", mMaxFileSize);
        mEchoToStdOut = Config.getBoolean("LOG", "echo_to_std_out", true);

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

		mLockEntries = false;

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
        if(mEchoToStdOut) writeln(Message);
		emit(Message, Level, Module);

		string x = format ("%s: %s", Level, Message);
		if(Module !is null) x = format("%s in %s", x, Module);
		mEntries ~= x;
		if(mEntries.length >= mMaxLines) Flush();
	}

	void Flush()
	{
		if(mLockEntries)return; //no saving entries while entries are locked
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

    void SetLockEntries(bool Lock){ mLockEntries = Lock;}
}



import std.c.stdlib;
extern (C) void SegFlush(int SysSig)nothrow @system
{
	try
	{
		string TheError = format("Caught Signal %s", SysSig);
		Log.Entry(TheError, "Error");
	    Log.Flush();
	    exit(127);
    }
    catch(Exception X)
    {
	    return;
    }
}

