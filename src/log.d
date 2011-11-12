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


import dcore;

class LOG
{
	private :
	string[]        mEntries;
	string          mLogFileName;
    ulong           mMaxLines;
    ulong           mMaxFileSize;
    bool            mFinalFlush;


	public:

    this(){}
	this(string FileName, ulong MaxLineBuffer = 128, ulong MaxAppendFileSize = 524288)
	{
		mLogFileName = absolutePath(FileName);
		mMaxLines = MaxLineBuffer;
		
		string mode = "w";
		if(exists(FileName))
		{
			if ( getSize(FileName) < MaxAppendFileSize) mode = "a";
		}

		auto rightnow = Clock.currTime();
		auto logtime = rightnow.toISOExtString();
		
		auto f = File(mLogFileName, mode);

		f.writeln("<<++	LOG BEGINS ++>>");
		f.writeln(logtime);
	}
    ~this()
    {
        if(!mFinalFlush)Disengage();
    }

    void Engage()
    {
        mLogFileName = Config().getString("LOG", "log_file");
        mMaxLines = Config().getInteger("LOG", "max_lines_buffer");
        mMaxFileSize = Config().getUint64("LOG", "max_file_size");

        string mode = "w";
        if(exists(mLogFileName))
        {
            if(getSize(mLogFileName) < mMaxFileSize) mode = "a";
        }

        auto rightnow = Clock.currTime();
        auto logtime = rightnow.toISOExtString();
        
        auto f = File(mLogFileName, mode);

        f.writeln("<<++	LOG BEGINS ++>>");
		f.writeln(logtime);
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
        mFinalFlush = true;
	}     

	
	void Entry(string Message, string Level = "Info", string Module = null, )
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
	void		Flush()
	{
		auto f = File(mLogFileName, "a");
		foreach (l; mEntries) f.writeln(l);
		mEntries.length = 0;
	}	
	mixin Signal!(string, string, string);


    string[] GetEntries(){return mEntries.dup;}
}

	



	
