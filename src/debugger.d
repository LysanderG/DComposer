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

enum DBGR_STATE
{
	OFF_OFF,            //NOTHING RUNNING NOT DEBUGGING
	
	ON_OFF,             //GDB IS READY BUT TARGET IS NOT RUNNING (ALMOST LIKE ON_PAUSED BUT TARGET IS NOT RUNNING ERRORS WILL SHOW UP)
	ON_PAUSED,          //GDB IS WAITING FOR INPUT TARGET IS HAS BEEN RUN BUT IS INTERRUPTED
	BUSY_OFF,	        //GDB IS PROCESSING COMMAND (insert break, get some info) TARGET IS NOT RUNNING
	BUSY_PAUSED,        //GDB HAS RECEIVED A COMMAND AND IS PROCESSING IT(step, disassemble, stack info) TARGET IS INTERRUPTED
	BUSY_RUNNING,       //GDB IS NOT ACCESSABLE TARGET IS RUNNING (INTERRUPT IS THE ONLY COMMAND THAT SHOULD WORK
	BUSY_STOPPED,       //ONLY WHEN RECEIVES A ASYNC *STOPPED AND THEN CHANGED IMMEDIATELY
	
	ON_QUITTING,        //GDB IS RECEIVING AN ASYNC OUTPUT *STOPPED WITH 'EXIT' REASON --> GOING TO ON_OFF STATE
	QUITTING_ANY,       //GDB HAS RECEIVED ^EXIT ... SO WHO CARES ABOUT TARGET
}

alias DBGR_STATE.QUITTING_ANY KILL;

class DEBUGGER
{

private:
	
    ProcessPipes    mGdbProcess;
    int             mTargetId;

    DBGR_STATE      mState;
    
    COMMAND[]       mCommandStack;
    
    //location stuff
    string          mSrcFile;
    int             mSrcLine;
    string          mAddress;
    
    string          mTarget;
    string          mGdbString;
    
    
    struct COMMAND
    {
	    bool Show;
	    string Command;
	    alias Command this;
    }
    
    
    void Execute()
    {

	    if(mCommandStack.length < 1) return;
	    
	    COMMAND cmd = mCommandStack[0];
	    mCommandStack = mCommandStack[1..$];
	    if(cmd.Show)
	    {
		    StreamOutput.emit("::> " ~ cmd.Command);
	    }

	    mGdbProcess.stdin.writeln(cmd.Command);
	    mGdbProcess.stdin.flush();
	    State = DBGR_STATE.BUSY_PAUSED;
    }
    
    void Spawn()
    {
	    if(mTarget.length == 0) mTarget  = Project.Name;
	    mCommandStack.length = 0;
		mTargetId = -1;
	    string[] cmdline = ["gdb", "--interpreter=mi", mTarget];
	    mGdbProcess = pipeProcess(cmdline, Redirect.all);
		fcntl(mGdbProcess.stdout.fileno, F_SETFL, O_NONBLOCK);
	    mGdbProcess.stdin.flush();
	    State = DBGR_STATE.ON_OFF;

    }
    
    void Abort()
    {
	    //how to invalidate mGdbProcess??
	    mTargetId = -1;
	    mTarget.length = 0;
	    State = DBGR_STATE.OFF_OFF;
	    mCommandStack.length = 0;
	    mSrcFile.length = 0;
	    mSrcLine = 0;
	    mAddress.length = 0;
	    
	    kill(mGdbProcess.pid);
	    wait(mGdbProcess.pid);
    }
    
    void ReadGdbOutput()
    {
	    if(mState == DBGR_STATE.OFF_OFF) return;
	    bool DoNotBreakout = true ;
		while( DoNotBreakout)
		{            		
			char[] buffer;
			buffer.length = 4;

            mGdbProcess.stdout.flush();
			auto read_response = read(mGdbProcess.stdout.fileno, buffer.ptr, buffer.length);
			if(read_response < 1)return;
			if(read_response < buffer.length) {DoNotBreakout = false;} //should check for errno
			
			mGdbString ~= cast(string)buffer[0..read_response];

			auto returnPos = mGdbString.indexOf('\n');
			if(returnPos > 0)
			{
				ProcessGdbOutput(mGdbString[0..returnPos]);
				mGdbString = mGdbString[returnPos+1 .. $];
			}
		}
	}
	
	void ProcessGdbOutput(string msg)
	{

		string reason;
		
		if(msg.length < 1) return;
		switch(msg[0])
		{
			case '~' :
			case '@' :
			case '&' : StreamOutput.emit(msg); break;
			
			case '*' :
			case '+' :
			case '=' : AsyncOutput.emit(msg);
			           if(msg.startsWith("=thread-group-started,"))
			           {
				           mTargetId = to!int(RECORD(msg["=thread-group-started,".length..$]).Get("pid"));
			           }
			           if(msg.startsWith("*stopped,"))
			           {
				           auto Record = RECORD(msg["*stopped,".length..$]);
				           reason = RECORD(msg["*stopped,".length..$]).Get("reason");
				           if(reason.startsWith("exited"))State = DBGR_STATE.ON_QUITTING;
				           else 
				           {
					           //this assumes any reasons for stopping other than exited* will have a frame in the results
					           mSrcFile = Record.Get("frame","fullname");
					           mSrcLine = to!int(Record.Get("frame","line")) - 1; //-1  cuz zero based vs one based line numbering
					           mAddress = Record.Get("frame", "addr");
					           State = DBGR_STATE.BUSY_STOPPED;
				           }
				           
		               }
		               if(msg.startsWith("*running,")) State = DBGR_STATE.BUSY_RUNNING;
		               break;
			
			case '^' : ResultOutput.emit(msg);
			           if(msg.startsWith("^exit"))State = DBGR_STATE.QUITTING_ANY;
			           break;
			           
		    case '0' : .. case '9' :
		              State = DBGR_STATE.BUSY_PAUSED;
		              ResultOutput.emit(msg);
		              break;
            default  : Output.emit(msg);
                       AsyncOutput.emit(msg);
        }		
        
        if(msg.startsWith("(gdb)"))State = DBGR_STATE.ON_PAUSED;
        if(reason.startsWith("exited"))State = DBGR_STATE.ON_QUITTING;
    }
    
    
    
	    
    
public:
    
    this()
    {
	    mState = DBGR_STATE.OFF_OFF;
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
    
    
    void Process()
    {

	    //ReadGdbOutput();
	    final switch(mState) with(DBGR_STATE)
	    {
		    case    OFF_OFF     : Spawn();break;
		    case    ON_OFF      : Execute();break; 
		    case    ON_PAUSED   : Execute();break;
		    case    BUSY_OFF    : break;
		    case    BUSY_PAUSED : break;
		    case    BUSY_RUNNING: break;
		    case    BUSY_STOPPED: break; //never should show up here
		    case    ON_QUITTING : State = ON_OFF;break;
		    case    QUITTING_ANY: Abort();break;
	    }
	    ReadGdbOutput();
    }
    
    void Command(string cmd, bool show = true)
    {
	    COMMAND x;
	    x.Show = show;
	    x.Command = cmd;
	    
	    mCommandStack ~= x;

    }
    
    void Interrupt()
    {
	    import core.sys.posix.signal;	    

	    if(mState == DBGR_STATE.BUSY_RUNNING)kill(mTargetId, 2);
    }
    
    void GetLocation(out string file, out int line, out string address)
    {
	    file = mSrcFile;
	    line = mSrcLine;
	    address = mAddress;
    }
    
    @property void State(DBGR_STATE NuState)
    {       
	    final switch(NuState) with (DBGR_STATE)
	    {
		    case    OFF_OFF     : mState = NuState;break; //already unloaded think thats good enough
		    case    ON_OFF      : mState = NuState;break;
		    case    ON_PAUSED   : if(mState == BUSY_RUNNING)break; //only go to on_pause from busy_stopped when target running 
		                          if(mState == ON_QUITTING)break;
		                          if(mState == ON_OFF)break; 
		                          if(mState == BUSY_OFF)mState = ON_OFF; //keep track if target has started running yet
		                          else mState = NuState;
		                          break;
		    case    BUSY_OFF    : mState = NuState;break;
		    case    BUSY_PAUSED : if(mState == ON_OFF)mState = DBGR_STATE.BUSY_OFF;
	                              else mState = BUSY_PAUSED;
	                              break;
		    case    BUSY_RUNNING: mState = NuState;break;
		    case    BUSY_STOPPED: mState = DBGR_STATE.ON_PAUSED;
		                          TargetStopped.emit();
		                          break;
            case    ON_QUITTING : mState = NuState;break;
            case    QUITTING_ANY: mState = NuState;GdbExited.emit();
        }
        NewState.emit(mState);
    }
    @property DBGR_STATE State(){return mState;}
        	                          
	        
    
    mixin Signal!(string) StreamOutput;
    mixin Signal!(string) AsyncOutput;
    mixin Signal!(string) ResultOutput;
    mixin Signal!(string) Output;
    mixin Signal!(DBGR_STATE) NewState;
    mixin Signal GdbExited;
    mixin Signal TargetStopped;

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
				//auto closeQuotePos = recordString[1..$].indexOf('"');
				auto closeQuotePos = recordString[1..$].findQuote();
				
				
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

private int findQuote(string text)
{
	int rv = -1;
	bool skipnext = false;
	foreach(int i, x;text)
	{
		if(skipnext)
		{
			skipnext = false;
			continue;
		}
		if(x == '\\')skipnext = true;
		if(x == '"')
		{
	        rv = i;
	        break;
        }
    }
    return rv;
}
		

