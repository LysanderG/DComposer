module debugger;

import core.sys.posix.poll;
import core.sys.posix.fcntl;
import core.sys.posix.unistd;
import core.stdc.errno;

import std.algorithm : findSplitAfter;
import std.signals;
import std.process;
import std.string;
import std.stdio;
import std.traits;
import std.conv;
import std.file;

import dcore;


enum STATE
{
    OFF,             //GDB NOT RUNNING
    SPAWNING,         //FORKED AND LOADED
    PROMPTING,          //REALLY WAITING FOR INPUT
    BUSY,            //PROCESSING INPUT
    TARGET_RUNNING,  //TARGET IS RUNNING GDB IS INACTIVE
    QUITTING         //RECEIVED THE SIGNAL TO QUIT GDB
}


class DEBUGGER
{

private:

	STATE mState;                                               //self explained
	ProcessPipes mGdbProcess;                                   //see phobos std.process this is our gdb child process

	pollfd mPollFd;                                             //not using this anymore get rid of it (just use O_NONBLOCK and stdc read
	string mGdbString;                                          //basically a buffer for what gdb returns
	int mTargetId;                                              //this is what gdb is debugging
	bool mTargetHasJustStopped;									//flag to indicate target just stopped running before a new prompt

	string mCurrSrcfile;                                        //location in target ... probably will remove this and let other modules
	int mCurrLine;                                              //just grab and parse gdbstring
	string mCurrAddress;




	void FormGdbOutput(string msg)
	{
		if(msg.length < 1)return;
        switch (msg[0])
        {
	        case '~' :
	        case '@' :
	        case '&' : FormStreamOutput(msg); break;

	        case '*' :
	        case '+' :
	        case '=' : FormAsyncOutput(msg); break;

			case '0' : .. case '9' :
	        case '^' : FormResultOutput(msg); break;

	        case '(' : StreamOutput.emit(msg);break;

	        default : Output.emit(msg);
        }

        if( (msg.startsWith("(gdb)")) && (mState != STATE.TARGET_RUNNING))
        {
	        State = STATE.PROMPTING;
        }
    }

    void FormStreamOutput(string msg)
    {
	    if (msg[0] == '~')
	    {
		    StreamOutput.emit(msg);
	    }
	    return;
    }

    void FormAsyncOutput(string msg)
    {
		//finds target pid from gdb output right after -exec-run
		if(mTargetId == -1)
		{
			auto splitResult = msg.findSplitAfter(`pid="`);
			if(splitResult[0].length > 0)
			{
				string rstring = splitResult[1][0..splitResult[1].indexOf('"')];
				mTargetId = to!int(rstring);
			}
		}
	    if(msg.startsWith("*running"))
	    {
		    State = STATE.TARGET_RUNNING;
	    }

	    if(msg.startsWith("*stopped"))
        {
	        State = STATE.BUSY;
	        mTargetHasJustStopped = true;
	        //set new location here ... easier than making others find it
	        writeln(msg["*stopped,".length..$]);
	        auto result = RECORD(msg["*stopped,".length..$]);
	        writeln("here");
	        mCurrSrcfile = result.Get("frame", "fullname");
	        writeln("here2");
			auto tmpstr = result.Get("frame", "line");
			writeln("here3");
	        if(tmpstr.length > 0)mCurrLine = to!int(tmpstr);
	        writeln("here4");
	        mCurrAddress = result.Get("frame", "addr");
	        writeln("mCurrAddress ", mCurrAddress);
        }
        AsyncOutput.emit(msg);
    }
    void FormResultOutput(string msg)
    {
	    if(msg.startsWith("^exit"))
	    {
		    State = STATE.QUITTING;
	    }
	    ResultOutput.emit(msg);
    }

public:
    this()
    {
	    mState = STATE.OFF;
	    mTargetId = -1;
    }

    void Engage()
    {
	    Log.Entry("Engaged DEBUGGER");
    }
    void Disengage()
    {
	    Log.Entry("Disengaged DEBUGGER");
    }

    void Spawn(string Target)
    {
		mTargetId = -1;
	    string[] cmdline = ["gdb", "--interpreter=mi", Target];
	    mGdbProcess = pipeProcess(cmdline, Redirect.all);
	    mPollFd.fd = mGdbProcess.stdout.fileno;
	    mPollFd.events = POLLIN | POLLPRI;
		fcntl(mPollFd.fd, F_SETFL, O_NONBLOCK);
	    mGdbProcess.stdin.flush();
	    State = STATE.SPAWNING;
    }

    void Unload()
    {
		mTargetId = -1;
	    State = STATE.OFF;
	    kill(mGdbProcess.pid);
	    wait(mGdbProcess.pid);

    }

    void Process()
    {

        mPollFd.fd = mGdbProcess.stdout.fileno;
        mPollFd.events = POLLIN |  POLLPRI;

        void GetGdbOutput()
		{
			while(true)
			{
				char[] buffer;
				buffer.length = 5;

				auto read_response = read(mGdbProcess.stdout.fileno, buffer.ptr, buffer.length);
				if(read_response < 1) {errno = 0;return;} //should check for errno
				mGdbString ~= cast(string)buffer[0..read_response];

				auto returnPos = mGdbString.indexOf('\n');
				if(returnPos > 0)
				{
					FormGdbOutput(mGdbString[0..returnPos]);
					mGdbString = mGdbString[returnPos+1 .. $];
				}

				if(mState == STATE.TARGET_RUNNING) return;
				if(mState == STATE.PROMPTING)return;
				if(mState == STATE.QUITTING)return;

			}
		}



		final switch (mState) with (STATE)
		{
			case OFF            :
			case QUITTING       : return;
			case SPAWNING       :
			case BUSY           :
			case TARGET_RUNNING : GetGdbOutput(); break;
			case PROMPTING      : break; //not looking for input waiting for orders
		}
	}



	void Command(string cmd)
	{
		StreamOutput.emit(":> " ~ cmd);
		mGdbProcess.stdin.writeln(cmd);
		mGdbProcess.stdin.flush();
		State = STATE.BUSY;
	}


	Pid ProcessID()
	{
	    return mGdbProcess.pid;
    }

    bool IsPrompting()
    {
	    return(mState == STATE.PROMPTING);
    }

    bool IsRunning()
    {
	    return mState == STATE.TARGET_RUNNING;
	    //return (mState != STATE.QUITTING) || (mState == STATE.OFF);
    }

    int TargetID()
    {
		return mTargetId;
	}

	@property void State(STATE nuState)
	{
		mState = nuState;
		if(mState == STATE.PROMPTING)
		{
			if(mTargetHasJustStopped)
			{
				mTargetHasJustStopped = false;
				Stopped.emit();
			}
			Prompt.emit();
		}

		if(mState == STATE.OFF) GdbExited.emit();
	}

	void GetLocation(out string SrcFile, out int SrcLine, out string Address)
	{
		SrcFile = mCurrSrcfile;
		SrcLine = mCurrLine;
		Address = mCurrAddress;
	}


    mixin Signal!string Output;
    mixin Signal!string StreamOutput;
    mixin Signal!string AsyncOutput;
    mixin Signal!string ResultOutput;
    mixin Signal Stopped;
    mixin Signal Prompt;
    mixin Signal GdbExited;
}






enum VALUE_TYPE :int {EMPTY = -1, CONST, TUPLE, LIST}

//if -break-insert overloadedfunc
//gdb will set a breakpoint for each function named overloadedfunc
//BUT (UNDOCUMENTED BUT) it puts a LIST smack dab in the the middle of a TUPLE
//so to get around this will allow skipping key reading for tuples named "bkpt"
//who the hell would name all the variables in a tuple the same name anyway
//{varID="firstvalue",varID="highvalue",varID="lowvalue"}wtf! but thats not bad enough
//{varID="firstvalue","anothervalue","thisvalue",varID="thatvalue",varID="lastvalue"}
//no... no I don't see a reason to document that !!!  Its easy to see what the value of varID is... right?

/* hah all my fault ... failed to see that record is a list not a tuple!!tuple, oh wait never mind*/



struct RECORD
{

    VALUE[string] _values; //i think all results are a tuple of results at least one
    //alias _values this;

    this(string recordString)
    {
	    do
	    {
		    if(recordString[0] ==',')recordString = recordString[1..$];
	        string _tmpKey;

	        auto EqualPos = recordString.indexOf("=");
	        auto BracePos = recordString.indexOf("{");
	        if((EqualPos < 0) || ((EqualPos > BracePos) && (BracePos > -1)))
	        {
		        throw new Exception("Error Reading gdb ResultRecord");
	        }
	        _tmpKey = recordString[0..EqualPos];
	        recordString = recordString[EqualPos+1..$];

	        //trying again with bkpt multi problems
	        if(_tmpKey == "bkpt")
	        {
		        recordString = '[' ~ recordString ~ ']';
	        }
	        _values[_tmpKey] = VALUE(recordString);
	        if(recordString.length < 1) break;
        }while(recordString[0] == ',');
    }


    VALUE GetValue(INDEX1, INDEX...)(INDEX1 FirstIndex, INDEX Indices)
    {

	    VALUE _tmpV = _values[FirstIndex];


	    foreach(indx; Indices)
	    {
	        if(_tmpV._type == VALUE_TYPE.EMPTY) return _tmpV;
	        if(_tmpV._type == VALUE_TYPE.CONST) return _tmpV;
	        if(_tmpV._type == VALUE_TYPE.TUPLE)
	        {
		        _tmpV = _tmpV.Get(indx);
		        continue;
	        }
	        if(_tmpV._type == VALUE_TYPE.LIST)
	        {
		        _tmpV = _tmpV._list.Get(indx);
		        continue;
	        }
	    }
	    return _tmpV;

    }

    string Get(INDEX1, INDEX...)(INDEX1 FirstIndex, INDEX Indices)
    {
	    scope(failure)return "";

	    VALUE _tmpV = _values[FirstIndex];


	    foreach(indx; Indices)
	    {
	        if(_tmpV._type == VALUE_TYPE.EMPTY) return "[]";
	        if(_tmpV._type == VALUE_TYPE.CONST) return _tmpV._const;
	        if(_tmpV._type == VALUE_TYPE.TUPLE)
	        {
		        _tmpV = _tmpV.Get(indx);
		        continue;
	        }
	        if(_tmpV._type == VALUE_TYPE.LIST)
	        {
		        _tmpV = _tmpV._list.Get(indx);
		        continue;
	        }
	    }
	    return _tmpV._const;
    }
}


struct VALUE
{
    VALUE_TYPE _type;
	string _const;
	VALUE[string] _values;
	LIST _list;

	static string _UniqueKeyName;

	this(ref string recordString)
	{
		_type = VALUE_TYPE.EMPTY;

		switch(recordString[0])
		{
			case '"' : //a simple value aka _const
			{
				_type = VALUE_TYPE.CONST;
				auto closeQuotePos = recordString[1..$].indexOf('"');
				_const = recordString[1..closeQuotePos+1];
				recordString = recordString[closeQuotePos+2..$];
				break;
			}
			case '{' : //a tuple
			{
				//CHECK FOR EMPTY TUPLE (WHY WOULD THERE BE ONE THOUGH
				if(recordString[1] == '}')
				{
					recordString = recordString[2..$];
					return;
				}

				_type = VALUE_TYPE.TUPLE;
				//this is tuple aka VALUE[string]
				//skip {
				recordString = recordString[1..$];
				do
				{
					if(recordString[0] == ',') recordString = recordString[1..$];
					string _tmpKey;
					auto EqualPos = recordString.indexOf("=");
					auto BracePos = recordString.indexOf("{");
					if((EqualPos < 0) || ((EqualPos > BracePos) && BracePos > -1))
					{
						throw new Exception("Error reading gdb tuple");
					}
					_tmpKey = recordString[0..EqualPos];
	                recordString = recordString[EqualPos+1..$];
	                _values[_tmpKey] = VALUE(recordString);

    	            if(recordString.length < 1) break;
	            }while(recordString[0] == ',');
	            //skip }
	            recordString = recordString[1..$];
	            break;
			}
			case '[' : // a list
			{
				_type = VALUE_TYPE.LIST;
				_list = LIST(recordString);
				break;
			}
			default :
		}
	}

	VALUE Get(string index)
	{
		return _values[index];
	}
	VALUE Get(int index)
	{
		return _list._values[index];
	}

	string toString(string nameValueSep = "=", string itemSep = ",")
	{

		string rv;
		bool notFirstItem;

		switch(_type) with(VALUE_TYPE)
		{
			case EMPTY : return "[]";
			case CONST : return _const;
			case TUPLE :
			{

				foreach(key, t; _values)
				{
					if(t._type == CONST)
					{
						if(notFirstItem) rv ~= itemSep;
					    rv ~= key ~ nameValueSep ~ t._const;
					    notFirstItem = true;
				    }
				}
				return rv;
			}
			case LIST :
			{
				rv ~= "[";
				foreach(i; _list._values)
				{
					if(notFirstItem) rv ~= itemSep;
					if(i._type == CONST) rv ~= i._const;
					if(i._type == LIST) foreach( ti; i._list._values) rv ~= ti.toString();
					notFirstItem = true;
				}
				rv = rv ~ "]";
				return rv;
			}
			default :return "{}";
		}
	}
}

struct LIST
{
				//this sucks... given an array of tuples they MIGHT all have the same name!name
				//so can I treat them like arrays of tuples and just drop all names?
	VALUE_TYPE _type;
	VALUE[] _values;
	//alias _values this;
	//VALUE[string] _tuples; //forget this for now

	this(ref string recordString)
	{
		_type = VALUE_TYPE.EMPTY; //initial value should change;
		//skip [
		recordString = recordString[1..$];
		if(recordString[0] == ']')//empty array
		{
			recordString = recordString[1..$];
			return;
		}

		if(recordString[0] == '"')//we are an array of simple strings
		{
			_type = VALUE_TYPE.CONST;
			do
			{
				if(recordString[0] == ',') recordString = recordString[1..$];
				_values ~= VALUE(recordString);
				if(recordString.length < 1) return;
			}while(recordString[0] == ',');
			//skip ]
			recordString = recordString[1..$];
			return;
		}
		if(recordString[0] == '{') // an array of tuples
		{
			_type = VALUE_TYPE.TUPLE;
			do
			{
				if(recordString[0] == ',') recordString = recordString[1..$];
				_values ~= VALUE(recordString);

				if(recordString.length < 1)return;
			}while(recordString[0] == ',');
			//skip ] again
			recordString = recordString[1..$];
			return;
		}
		//now it should be an array of results ie
		//[bkpt={blah="blah",ant="insect"},bkpt={blah="humph",ant="bee"}]
		_type = VALUE_TYPE.TUPLE;
		do
		{
			if(recordString[0] == ',') recordString = recordString[1..$];
			auto equalPos = recordString.indexOf('=');
			auto bracePos = recordString.indexOf('{');
			//if(equalPos < 0)throw new Exception("Error reading an array of tuples from gdb");
			if( (equalPos < 0) || (equalPos >= bracePos)) equalPos = -1;
			recordString = recordString[equalPos+1..$];
			_values ~= VALUE(recordString);
			if(recordString.length < 1)return;
		}while(recordString[0] == ',');
		//skip ]
		recordString = recordString[1..$];
	}

	VALUE Get(int index)
	{
    	return _values[index];
	}
	VALUE Get(string index)
	{
        throw new Exception("Tried to access LIST value with a string index");
	}
}
