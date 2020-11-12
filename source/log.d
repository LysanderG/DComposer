module log;

import std.datetime;
import std.file;
import std.path;
import std.process;
import std.signals;
import std.stdio;
import std.string;
import std.getopt;

import qore;

string mDefaultLogFile = "~/.config/dcomposer/loggity.log";
int MAX_ENTRIES_MEM = 1024;

void Engage(ref string[] cmdArgs)
{
	string logFileName;
	bool   quietStdOut;
	
	auto goResults = getopt(cmdArgs, std.getopt.config.passThrough, "log|l", &logFileName, "quiet|q", &quietStdOut);
	if(logFileName.length <1)logFileName = mDefaultLogFile.expandTilde();	
	Log = new LOG;	
	Log.Engage("xcomposer", !quietStdOut, logFileName);
}

void Mesh()
{
	if(Log.GetEchoStdOut()) //not set by command line so check config
	{
		Log.SetEchoStdOut(qore.config.Config.GetValue("log", "echo", true));
	}	 
	Log.Mesh();
}

void Disengage()
{
	Log.Disengage();
}


enum LogCmdOptions =
`	-l	--log=FILE		Specify a session log file.
	-q	--quiet			Do not echo log entries to stdout.
`;
string GetCmdLineOptions(){return LogCmdOptions;}



//system log... elements can create their own logs or use this one.
public LOG Log;

class LOG
{
    private :
    File 			mLogFile;
    string[]        mEntries;               //buffer of log entries not yet saved to file
    string          mLogFileName;           //which of the two above is actually being used this session
    bool            mEchoToStdOut;          //whether to write entries to stdout
    bool 			mSaveEntries;			//do not discard Entries from memory (access entries made before all signal connections are made) 
	int				mPID;					//used to distinguish among concurrently running processes with the same logfile... (happens)
	int				mMaxEntriesMem;
	int 			mMaxFileSize;
	
    public:
    
    void ChangeLogFileName(string NuName)
    {
        mLogFileName = NuName;
        mLogFile = File(mLogFileName, "a");
        Flush();
    }
    string GetLogFileName(){return mLogFileName;}
    
    void SetEchoStdOut(bool echo){mEchoToStdOut = echo;}
    bool GetEchoStdOut(){return mEchoToStdOut;}

    void Engage(string application, bool echoStdOut, string logFileName)
    {    	
    	if(!logFileName.dirName.exists) mkdirRecurse(logFileName.dirName);
    	mLogFileName = logFileName;
    	mLogFile = File(mLogFileName, "a");
        
        mEchoToStdOut = echoStdOut;
		mPID = thisProcessID;
		mMaxEntriesMem = MAX_ENTRIES_MEM;
				
        auto rightnow = Clock.currTime();
        auto logtime = rightnow.toISOExtString();

        Entry("<<<+++ LOG BEGINS +++>>>", "Begin");
        Entry(application);
        Entry(logtime, "Start");
        Entry("Log file set to : " ~ mLogFileName);        
        Entry("Engaged");
        
        
    }
    
    void Mesh()
    {
        Entry("Meshed");
    }

    void Disengage()
    {
        auto rightnow = Clock.currTime();
        auto logtime = rightnow.toISOExtString();
        Entry("Disengaged");

        //avoids sending a signal?
        mEntries.length += 2;
        mEntries[$-2] = logtime;
        mEntries[$-1] = "<<-- LOG ENDS -->>\n";
        mLogFile.writeln(mEntries[$-2]);
        mLogFile.writeln(mEntries[$-1]);
        mLogFile.close();
    }


    void Entry(string Message, string Level = "Info", string Module = __MODULE__ )
    {
        //Level can be any string, it is ignored by this class. should be less than 8 characters
        emit(Message, Level, Module);
        string x = format ("%4s %8s [%20s] : %s",mPID, Level, Module,  Message);
        mEntries ~= x;
        if(mEchoToStdOut) writeln(x);
        if(mLogFile.isOpen())
        {
            if(mEntries.length > mMaxEntriesMem)Flush();
	        mLogFile.writeln(x);
        }
    }

    void Flush()
    {
        mLogFile.flush();
        mEntries.length = 0;
    }

    mixin Signal!(string, string, string);

  	//returns entries made since last flush ... zero after PostEngage is called  
    string[] GetEntries(){return mEntries.dup;}

}


//used for tracing program ... easy to find and delete with a unique name.
alias dwrite = std.stdio.writeln;

