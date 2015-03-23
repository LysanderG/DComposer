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

    int           mMaxLines;                      //flush entries buffer
    int           mMaxFileSize;                   //if log is this size then don't append overwrite

    bool            mLockEntries;                   //don't dispose of mEntries if this is true

    bool            mEchoToStdOut;                  //whether to write entries to stdout


    public:

    this()
    {


        mInterimFileName = "unspecifiedlogfile.cfg";

        mMaxFileSize = 65_535;
        mMaxLines = 255;

        mLockEntries = true;
        mEchoToStdOut = true;

        //signal(SIGSEGV, &SegFlush);
        //signal(SIGINT, &SegFlush);

    }


    void Engage()
    {
        mSystemDefaultLogName = SystemPath( Config.GetValue("log", "default_log_file",  "dcomposer.log"));
        if(Config.HasKey("log", "interim_log_file"))
        {
            mLogFile = Config.GetValue("log", "interim_log_file",buildPath(userDirectory, "error.log"));
            Config.Remove("log", "interim_log_file");
        }
        else mLogFile = mSystemDefaultLogName;

        mMaxLines     = Config.GetValue("log", "max_lines_buffer", mMaxLines);
        mMaxFileSize  = Config.GetValue("log", "max_file_size", mMaxFileSize);
        mEchoToStdOut = Config.GetValue("log", "echo_to_std_out", true);

        string mode = "w";
        if(exists(mLogFile))
        {
            if(getSize(mLogFile) < mMaxFileSize) mode = "a";
        }

        auto rightnow = Clock.currTime();
        auto logtime = rightnow.toISOExtString();

        auto f = File(mLogFile, mode);
        f.writeln("<<++ LOG BEGINS ++>>");
        f.writeln(logtime);
        f.writeln(DCOMPOSER_VERSION);
        f.writeln(DCOMPOSER_BUILD_DATE);
        f.writeln(DCOMPOSER_COPYRIGHT);
        f.writeln(userDirectory);
        f.writeln(sysDirectory);
        f.writeln(installDirectories);
        f.writeln(BUILD_USER);
        f.writeln(BUILD_MACHINE);
        f.writeln(BUILD_NUMBER) ;

        Entry("\tLog file set to : " ~ mLogFile);
        Entry("Engaged");
    }
    void PostEngage()
    {
        Log.Entry("PostEngaged");
    }

    void Disengage()
    {

        auto rightnow = Clock.currTime();
        auto logtime = rightnow.toISOExtString();

        mLockEntries = false;

        Entry("Disengaged");

        mEntries.length += 2;
        mEntries[$-2] = logtime;
        mEntries[$-1] = "<<-- LOG ENDS -->>\n";
        Flush();
    }


    void Entry(string Message, string Level = "Info", string Module = __MODULE__ )
    {
        //Level can be any string
        //but for now "Debug", "Info", and "Error" will be expected (but not required)

        emit(Message, Level, Module);

        string x = format ("%8s [%20s] : %s", Level, Module,  Message);
        //if(Module !is null) x = format("%s in %s", x, Module);
        mEntries ~= x;
        if(mEntries.length >= mMaxLines) Flush();
        if(mEchoToStdOut) writeln(x);
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



void dwrite(T...) (T args)
{
    writeln(args);
}


import std.c.stdlib;
extern (C) void SegFlush(int SysSig)nothrow @system
{
    try
    {
        string TheError = format("Caught Signal %s", SysSig);
        Log.Entry(TheError, "Error");
        Log.Flush();
        abort();
    }
    catch(Exception X)
    {
        return;
    }
}
