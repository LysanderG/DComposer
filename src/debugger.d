module debugger;

import std.process;


enum { DBG_NO_APP, DBG_NOT_LOADED, DBG_LOADED, DBG_RUNNING, DBG_PAUSED}

class DEBUGGER
{

private:

	int     mState;
	ProcessPipes mGdbPipes;



public:

    this()
    {
    }

    void Engage()
    {
    }

    void Disengage()
    {
    }

    /**
    Loads the current project into gdb
    If no project or project is not an application ...
    well it doesn't work.
    -file-exec-and-symbols
    throws: GdbException.
    */
    void LoadExec()
    {
    }

    /**
    Completely stop gdb.
    prep for change of executable.
    After a build or project is closed
    */
    void Unload()
    {
    }

    /**
    Start running (probably going to break at main)
    */
    void Run()
    {
    }


    /**
    Continue running an interrupted program
    */
    void Continue()
    {
    }

    /**
    Continue running to a particular location, then stop
    */
    void ContinueTo(string SrcFile, int line)
    {
    }

    void Interrupt()
    {
    }

    /**
    Inserts a break point
    --break-insert
    throws: GdbException
    */
    void InsertBreak(string SrcFile, int line)
    {
    }

    /**
    Toggles a break point at the given location.

    Throws: GdbException.
    */
    void ToggleBreakPoint(string SrcFile, int Line)
    {
    }


    void SetWatch(string Expression)
    {
    }

    void StepOver()
    {
    }

    void StepIn()
    {
    }

    void StepOut()
    {
	}
}
