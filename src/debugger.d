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

	        case '^' : FormResultOutput(msg); break;

	        case '(' : StreamOutput.emit(msg);break;

	        default : break;
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
			//Output.emit(msg[1..$]);
		    State = STATE.TARGET_RUNNING;
	    }

	    if(msg.startsWith("*stopped"))
        {
			//Output.emit(msg[1..$]);
			string two = msg[9..$];
			auto rezult = TUPLE(two);
	        State = STATE.BUSY;
	        mTargetHasJustStopped = true;

	        //might not have a file/line if from some shared object or something
            //going to forego doing this in debugger module let callers (connectors) find the location
			//scope(failure)return;
			//mCurrSrcfile = rezult._resultItems["frame"]._value._tuple._resultItems["file"]._value._const[1..$-1];
			//mCurrLine = to!int(rezult._resultItems["frame"]._value._tuple._resultItems["line"]._value._const[1..$-1]) -1;
			try
			{
				if("frame" in rezult._resultItems)
				{
					mCurrSrcfile = rezult["frame"]._value._tuple["file"]._value._const[1..$-1];
					mCurrLine = to!int(rezult["frame"]._value._tuple["line"]._value._const[1..$-1]) -1;
				}
		    }
		    catch(Exception X)
		    {
			    mCurrLine = 0;
			    mCurrSrcfile = "";
		    }

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

	void GetLocation(out string SrcFile, out int SrcLine)
	{
		SrcFile = mCurrSrcfile;
		SrcLine = mCurrLine;
	}


    mixin Signal!string Output;
    mixin Signal!string StreamOutput;
    mixin Signal!string AsyncOutput;
    mixin Signal!string ResultOutput;
    mixin Signal Stopped;
    mixin Signal Prompt;
    mixin Signal GdbExited;
}






enum VALUE_TYPE :int {CONST, TUPLE, LIST}

struct RESULT
{
	string _name;
	VALUE _value;

	this(ref string InString)
	{

		auto EqualPos = InString.indexOf("=");
		if(EqualPos < 1)throw new Exception("Error Reading gdb Result");
		_name = InString[0..EqualPos];
		InString = InString[EqualPos+1..$];
		_value = VALUE(InString);

	}

	string toString()
	{
		string rv = _name ~ " : " ~ _value.toString() ~ '\n';
		return rv;
	}

}


struct VALUE
{
	VALUE_TYPE _type;
	string _const;
	TUPLE _tuple;
	LIST _list;

	this(ref string InString)
	{
		switch (InString[0])
		{
			case '"' :
			{
				_type = VALUE_TYPE.CONST;
				auto endQuote = InString[1..$].indexOf('"');
				_const = InString[0..endQuote+2];
				InString = InString[endQuote+2..$];
				break;
			}
			case '{' :
			{

			    _type = VALUE_TYPE.TUPLE;
			    _tuple = TUPLE(InString);
			    break;
			}
			case '[' :
			{
				_type = VALUE_TYPE.LIST;
				_list = LIST(InString);
				break;
			}
			case 'a' : ..case 'z':
			case 'A' : ..case 'Z':return;
			default : return;//throw new Exception("Error Reading gdb Value" ~ InString[0]);
		}
	}
    string toString()
    {
	    switch (_type) with(VALUE_TYPE)
	    {
		    case CONST : return _const[1..$-1];
		    case TUPLE : return _tuple.toString();
		    case LIST  : return _list.toString();
		    default : return "ERROR";
	    }
    }

}

struct TUPLE
{
	RESULT[string] _resultItems;
	alias _resultItems this;

	this(ref string InString)
	{
		do
		{
		    //skip the { or ,
		    InString = InString[1..$];
		    auto newResult = RESULT(InString);
			_resultItems[newResult._name] = newResult;
			if(InString.length < 1) return;
		}while(InString[0] == ',');
		//should be }
		InString = InString[1..$];
	}

	string toString()
	{
		string rv;
		foreach(ri; _resultItems)
		{
			rv ~=  ri.toString();
		}
		return rv;
	}
}

struct LIST
{
	int _ltype; //0 result, 1 tuple, 2 value, -1 empty list
	RESULT[] _resultItems;
	TUPLE[] _tupleItems;
	VALUE[] _valueItems;
	this(ref string InString)
	{
		if(InString[0..2] == "[]")
		{
			InString = InString[2..$];
			return;
		}
		if(InString[1] == '"') //its a value
	    {
		    _ltype = 2;
		    do
		    {
			    //skip [ or ,
			    InString = InString[1..$];
			    _valueItems ~= VALUE(InString);
			    if(InString.length < 1) return;
		    }while(InString[0] == ',');
		    //skip final ]
		    InString = InString[1..$];
		    return;
	    }
	    if(InString[1] == '{') //its an array of tuples old school crap
	    {
		    _ltype = 1;
		    //skip [
		    InString = InString[1..$];
		    do
		    {
			    if(InString[0] == ',')InString = InString[1..$];
			    _tupleItems ~= TUPLE(InString);
			    if(InString.length < 1) return;
		    }while (InString[0] == ',');
		    //skip }] both
		    InString = InString[1..$];
		    return;
	    }
	    //guess its a result ... stupid gdb documentation is so wrong!
	    //no offense :) mine is worse ... well if I had any, it'd be worse.
	    _ltype = 0;

	    do
	    {
		    if(InString[0] == ',')InString = InString[1..$];
		    _resultItems ~= RESULT(InString);
		    if(InString.length < 1) return;
	    }while(InString[0] == ',');
	    //skip ]
	    InString = InString[1..$];
	}

	string toString()
	{
		string rv;
		foreach(vi; _valueItems)
		{
			rv ~= vi.toString();
		}
		return rv;
	}
}

xpoint breakpoint;

struct xpoint
{
	string[string] _items;

	this(VALUE vtuple)
	{

		if (vtuple._type != VALUE_TYPE.TUPLE) throw new Exception("Bad breakpoint value");


		foreach(key, gdbitem; vtuple._tuple._resultItems)
		{
	        //_items[key] = gdbitem._value._const;
	        _items[key] = gdbitem._value.toString();
        }
    }
}
unittest
{
	string gdb_string = `bkpt={number="1",type="breakpoint",disp="keep",enabled="y",addr="0x08048564",func="main",file="myprog.c",fullname="/home/nickrob/myprog.c",line="68",thread-groups=["i1","i2"],times="0"}`;
	auto rout = RESULT(gdb_string);

    string xdb = `bkpt={number="1",type="breakpoint",disp="keep",enabled="y",addr="0x000100d0",func="main",file="hello.c",fullname="/home/foo/hello.c",line="5",thread-groups=["i1","02"],times="0",ignore="3"}`;

    auto xout = RESULT(xdb);

}
