module debugger;

import std.array;
import std.conv;
import std.file;
import std.process;
import std.signals;
import std.stdio;
import std.string;


import glib.IOChannel;

class NTDB
{
	private:
	
	ProcessPipes		mGdbProcess;
	IOChannel			mGdbChannelOut;
	int					mTargetId;
	string[]			mVariableNames;
	VARIABLE[string]	mVariables;
	immutable int		mDefaultDepth = 10;
	
	void SetupGdbWatcher()
	{
		mGdbChannelOut = new IOChannel(mGdbProcess.stdout.fileno);
		IOChannel.ioAddWatch(mGdbChannelOut, GIOCondition.IN|GIOCondition.PRI|GIOCondition.ERR, cast(GIOFunc)&GdbWatcher, cast(void*)this);		
	}
		
	static extern(C) bool GdbWatcher(GIOChannel * source, GIOCondition condition, void * data)
	{
		auto self = cast(NTDB)data;
		string response;
		size_t position;
        
		auto channel = new IOChannel(source);
		channel.readLine(response, position);
		response = response.strip();
		if(response.length < 1) return true;
		auto x = RECORD(response);
        
		//get inferior/target/child ... whatever pid
		if(x._class == "=thread-group-started")
		{
			self.mTargetId = to!int(x.Get("pid"));
		}
		//variables stuff
		if(x._class == "^done")
		{
			if(x.GetResult("stack-args")) self.CollectArguments(x);
			if(x.GetResult("locals")) self.CollectLocals(x);
			if(x.GetResult("name")) self.CollectVariables(x);
			if(x.GetResult("children")) self.CollectChildren(x);
			if(x.GetResult("changelist")) self.ChangeVariables(x);
		}
        //target exited
		if(x._class == "*stopped")
		{
			if(x.Get("reason").startsWith("exited")) self.Reset();
			self.UpdateVariables();
			
		}
        //gdb exited
		if(x._class == "^exit")
		{
            self.emit(x);
			return false;
		}
		
		self.emit(x);
		return true;
	}



	
	public:
	
	bool StartGdb(string TargetName)
	{
		if(TargetName.exists())
		{
			try
			{
				mGdbProcess = pipeShell("gdb --interpreter=mi " ~ TargetName ~ "\n");
				SetupGdbWatcher();
				mGdbProcess.stdin.writeln("-enable-pretty-printing\n");
				return true;
			}
			catch(Exception x)
			{
				dwrite(x);
			}
		}
		return false;
	}
	
	void StopGdb()
	{
        if(mGdbProcess.pid.processID< 0) return; //not running
		mGdbProcess.stdin.writeln("-gdb-exit\n");
		mGdbProcess.stdin.flush();
		mTargetId = 0;
		kill(mGdbProcess.pid, 9);
		wait(mGdbProcess.pid);
	}
	
	void StartTarget()
	{
		try {
		mGdbProcess.stdin.writeln("-exec-run --start\n");
		mGdbProcess.stdin.flush();
		}
		catch(Exception x)
		{
			dwrite(x);
		}
	}
	void ContinueTarget()
	{
		mGdbProcess.stdin.writeln("-exec-continue --all\n");
		mGdbProcess.stdin.flush();
	}	
	void StepOver()
	{
		mGdbProcess.stdin.writeln("-exec-next\n");
		mGdbProcess.stdin.flush();
	}
	void StepIn()
	{
		mGdbProcess.stdin.writeln("-exec-step\n");
		mGdbProcess.stdin.flush();
	}
	void StepOut()
	{
		mGdbProcess.stdin.writeln("-exec-finish\n");
		mGdbProcess.stdin.flush();
	}
	void ToCursor(string location)
	{
		mGdbProcess.stdin.writeln("-break-insert -t " ~ location);
		mGdbProcess.stdin.flush();
		mGdbProcess.stdin.writeln("-exec-continue --all\n");
		mGdbProcess.stdin.flush();		
        GetBreakPoints();
	}
	void Interrupt()
	{
		import core.sys.posix.signal;
		kill(mTargetId, 2);
	}
	
	void GetStackList()
	{
		mGdbProcess.stdin.writeln("-stack-list-frames\n");
		mGdbProcess.stdin.flush();
	}
	
	void GetBreakPoints()
	{
		mGdbProcess.stdin.writeln("-break-list\n");
		mGdbProcess.stdin.flush();
	}
	
	void InsertBreak(string location)
	{
		mGdbProcess.stdin.writeln("-break-insert " ~ location ~ "\n");
		mGdbProcess.stdin.flush();
		GetBreakPoints();
	}
	void RemoveBreak(string Id)
	{
		mGdbProcess.stdin.writeln("-break-delete ",Id);
		mGdbProcess.stdin.flush();
		GetBreakPoints();
	}
	void EnableBreak(string Id)
	{
		mGdbProcess.stdin.writeln("-break-enable " ~ Id);
		mGdbProcess.stdin.flush();
		GetBreakPoints();
	}
	void DisableBreak(string Id)
	{
		mGdbProcess.stdin.writeln("-break-disable " ~ Id);
		mGdbProcess.stdin.flush();
		GetBreakPoints();
	}
	void InsertWatch(string newWatch)
	{
		mGdbProcess.stdin.writeln("-break-watch " ~ newWatch ~ "\n");
		mGdbProcess.stdin.flush();
		GetBreakPoints();
	}
	
	
	void CreateVariables(string frameId)
	{
		mVariableNames.length = 0;
		mGdbProcess.stdin.writeln("-stack-select-frame " ~ frameId ~ "\n");
		mGdbProcess.stdin.flush();
		mGdbProcess.stdin.writeln("-stack-list-arguments 0\n");
		mGdbProcess.stdin.flush();
		
	}
	
	void CollectArguments(RECORD args)
	{
		foreach(name; args.GetValue("stack-args", 0, "args"))
		{
			if(name.Get() == "") continue;
			mVariableNames ~= name.Get();
		}
		mGdbProcess.stdin.writeln("-stack-list-locals 0\n");
		mGdbProcess.stdin.flush();
	}
	
	void CollectLocals(RECORD locals)
	{
		foreach(val; locals.GetValue("locals"))
		{
			if(val.Get() == "") continue;
			mVariableNames ~= val.Get();
		}
		//send variablenames through var-create
		foreach(var_name; mVariableNames)
		{
			if(var_name.startsWith("__"))continue;
			mGdbProcess.stdin.writeln("-var-create ", var_name, " @ ", var_name, "\n");
			mGdbProcess.stdin.flush();			
		}
	}
	
	void CollectVariables(RECORD var_created)
	{
		auto v_name = var_created.Get("name");
		auto v_exp = var_created.Get("exp");
		auto v_value = var_created.Get("value");
		auto v_type = var_created.Get("type");
		
        if(v_name !in mVariables)
            mVariables[v_name] = new VARIABLE(v_name,v_exp,v_value,v_type);
		
		mGdbProcess.stdin.writeln("-var-list-children 2 ", v_name, "\n");
		mGdbProcess.stdin.flush();
		
		
		string tmpStr = `$updatevariables`;
		emit(RECORD(tmpStr));
	}
	
	void CollectChildren(RECORD kids,int maxDepth = mDefaultDepth)
	{	

		VARIABLE parentVar;
		
		//get parent
		auto ancestors = kids.Get("children",0,"name").split(".");
		if(ancestors.length >= maxDepth)
		{
			return;
		}
		ancestors.length = ancestors.length - 1;
		parentVar = mVariables[ancestors[0]];
		foreach (anc; ancestors[1..$])
		{
			parentVar = parentVar._children[anc];
		}
		
		foreach(kid; kids.GetValue("children"))
		{
			auto path = kid.GetString("name").split(".");
			parentVar._children[path[$-1]] = new VARIABLE(
				kid.GetString("name"),
				kid.GetString("exp"),
				kid.GetString("value"),
				kid.GetString("type")
			);			
			if(kid.GetString("numchild") == "0")continue;
			mGdbProcess.stdin.writeln("-var-list-children 2 ", kid.GetString("name"), "\n");
			mGdbProcess.stdin.flush();
		}
	}
	
	void UpdateVariables()
	{
		mGdbProcess.stdin.writeln("-var-update --all-values *\n");
		mGdbProcess.stdin.flush();
	}
	
	void ChangeVariables(RECORD deltas)
	{
        string tmp = "$updatevariables";
        scope(exit)emit(RECORD(tmp));
		
		foreach(xvar; mVariables)
		{
			void WalkKids(VARIABLE parent)
			{
				foreach(kid; parent._children)
				{
					kid._color = "black";
					WalkKids(kid);
				}
			}
			xvar._color = "black";
			WalkKids(xvar);
		}
		
		
		VARIABLE WalkTree(string[] names)
		{
            mVariables[names[0]]._color = "red";
			if(names.length == 1)return mVariables[names[0]];
			
			if(names.length == 2)return mVariables[names[0]]._children[names[1]];
				
			VARIABLE tmpVar;
			
			tmpVar = mVariables[names[0]];
			foreach(name; names[1..$])
			{
                if(tmpVar._children is null)break;
				tmpVar = tmpVar._children[name];
                tmpVar._color = "red";
			}
			return tmpVar;
		}
		foreach(delta; deltas.GetValue("changelist"))
		{
			if(!delta)return; 
			auto Current = WalkTree(delta.GetString("name").split("."));
            Current._color = "red";
			Current._value = delta.GetString("value");
			Current._in_scope = delta.GetString("in_scope");
			if(delta.GetString("type_changed") == "true") 
            {
                Current._type = delta.GetString("new_type");
                Current._children.Clear();
            }			
			if(delta.GetString("new_num_children").length)
			{
				mGdbProcess.stdin.writeln("-var-list-children 2 ",delta.GetString("name"), "\n");
				mGdbProcess.stdin.flush();				
			}
		}
	}	
	
	VARIABLE[string] GetVariables()
	{
		return mVariables;
	}
	
	
	
	
	
	void Reset()
	{
		mTargetId = 0;
		mVariableNames.length = 0;
		foreach(key; mVariables.byKey)
		{
			mGdbProcess.stdin.writeln("-var-delete ",key,"\n");
			mGdbProcess.stdin.flush();
			mVariables.remove(key);
		}
		auto tmpstr = `^done,create_variable="nothing"`;
		emit(RECORD(tmpstr));
	}
	mixin Signal!RECORD;
	
}


enum VAL_TYPE
{
	NIL,
	CONST,
	TUPLE,
	LIST
}

private int findClosingQuote(string text)
{
    int rv = -1;
    bool skipnext = false;
    if(text[0] == '"') text = text[1..$];
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
            rv = i+1;
            break;
        }
    }
    return rv;
}
 

struct VALUE
{
	VAL_TYPE			_type;
	string				_const;
	VALUE[string]	   _tuple;
	LIST				_list;
	
	this(ref string inpStr)
	{
		switch(inpStr[0])
		{
			case '"' : //simple const
				_type = VAL_TYPE.CONST;
				auto quoteIndex = findClosingQuote(inpStr);
				_const = inpStr[1..quoteIndex];
				inpStr = inpStr[quoteIndex + 1.. $];
				return;
			case '[' : //its a list
				_type = VAL_TYPE.LIST;
				_list =  LIST(inpStr);
				return;
			default : //it is a tuple ... right?
				_type = VAL_TYPE.TUPLE;
				if(inpStr[0] == '{') inpStr = inpStr[1..$];
				string key;
				VALUE value;
				while( ReadResult(inpStr, key, value))
				{
					_tuple[key] = value;
					if(inpStr.length < 1) return;
					if(inpStr[0] == '}') break;
				}
				//skip closing }
				inpStr = inpStr[1..$];
				return;
		}
	}
	
	string toString()
	{
		string rv;
		static string tabs; 
		final switch(_type) with(VAL_TYPE)
		{
			case NIL	:
				rv = "NULL";
				break;
			case CONST  :
				rv = _const;
				break;
			case TUPLE  :
				rv = "\n" ~ tabs ~ "{\n";
				tabs ~= '\t';
				foreach(key, val; _tuple)
				{
					rv ~= tabs ~ key ~ ":" ~ val.toString() ~ ",\n";
				}
				if(_tuple.length > 0) rv = rv[0 .. $-2];
				tabs = tabs[0..$-1];
				rv ~= "\n" ~ tabs ~ "}";
				break;					
			case LIST   :
				rv = "\n" ~ tabs ~ "[\n";
				tabs ~= '\t';
				foreach(val; _list._values)
				{
					rv ~= tabs ~ val.toString() ~ ",\n";
				}
				if(_list._values.length > 0) rv = rv[0..$-2];
				tabs.length = tabs.length - 1;
				rv ~= "\n" ~ tabs ~ "]";
				break;			
		}
		return rv;
	}
	
	VALUE Get(string key)
	{
		VALUE rvCrap;
		if(key in _tuple) return _tuple[key];
		return rvCrap;
	}
	VALUE Get(size_t index)
	{
		VALUE rvCrap;
		if(_type != VAL_TYPE.LIST)return rvCrap;
		if(index >= _list._values.length) return rvCrap;
		return _list._values[index];
	}
	string GetString(string key)
	{
		if(key in _tuple) return _tuple[key].toString;
		return "";
	}
	string GetString(size_t index)
	{
		if(index >= _list._values.length) return "";
		return _list._values[index].toString;
	}
	string Get()
	{
		return _const;
	}
	
	T opCast(T:bool)(){return (_type != VAL_TYPE.NIL);}
	
	int opApply(int delegate(VALUE) dg)
	{
		int rv;
		
		if(_type == VAL_TYPE.LIST)
		{
			foreach(val; _list._values)
			{
				rv = dg(val);
				if(rv)break;
			}
		}
		if(_type == VAL_TYPE.TUPLE)
		{
			foreach(val; _tuple)
			{
				rv = dg(val);
				if(rv)break;
			}
		}
		return rv;
	}

}

struct  LIST
{
	 VALUE[] _values;
	
	this(ref string inpStr)
	{
		assert (inpStr[0] == '[');
		inpStr = inpStr[1..$];
		do
		{
			switch(inpStr[0])
			{
				case '[': assert(false);
				case '"':
				case '{':
					_values ~=  VALUE(inpStr);
					if(inpStr.length < 1) return;
					if(inpStr[0] == ',')inpStr = inpStr[1..$];
					break;
				default :
					string key;
					 VALUE value;
					 ReadResult(inpStr, key, value);
					_values ~= value;
					if(inpStr.length < 1) return;
					if(inpStr[0] == ',') inpStr = inpStr[1..$];
			}
		}while(inpStr[0] != ']');
		inpStr = inpStr[1..$];			
			
	}
}

bool  ReadResult(ref string inStr, out string key, out  VALUE value)
{
	auto equalPos = inStr.indexOf('=');
	if(equalPos < 0) return false;
	key = inStr[0..equalPos];
	inStr = inStr[equalPos + 1 .. $];
	value =  VALUE(inStr);
	
	if(inStr.length < 1) return true;
	if(inStr[0] == ',') inStr = inStr[1..$];
	return true;
}

struct  RECORD
{
	VALUE[string]	_values;
	string			_class;
	string			_rawString;
	
	this(ref string inStr)
	{
		inStr = inStr.stripRight();
		_rawString = inStr;
		switch(inStr[0])
		{
			case '^':
			case '*':
			case '=':
			case '+':
            case '$': //my own communication stuff
				auto classIndex = inStr.indexOf(',');
				if(classIndex < 0)
				{
					_class = inStr;
					return;
				}
				_class = inStr[0..classIndex];
				inStr = inStr[classIndex + 1 .. $];
				string key;
				VALUE value;
				while( ReadResult(inStr, key, value))
				{
					_values[key] = value;
				}
				return;
			default :
				_class = "stream";
		}
			
	}
	 VALUE GetValue_old(string key, string[] keys...)
	{
		if(key !in _values) return  VALUE.init;
		 VALUE _tmpV = _values[key];
		
		foreach(indx; keys)
		{
			if(_tmpV._type == VAL_TYPE.TUPLE) _tmpV = _tmpV._tuple[indx];
		}
		return _tmpV;
	}
	
	string Get(CHARS, I...)(CHARS rec_result, I indexes)
	{
		scope(failure) return VALUE.init._const;
		VALUE tmp;
		
		tmp = _values[rec_result];
		foreach(index; indexes)
		{
			tmp = tmp.Get(index);
		}
		return tmp.Get();
	}
	VALUE GetValue(CHARS, i...)(CHARS rec_result, i indexes)
	{
		scope(failure) return VALUE.init;
		VALUE tmp = _values[rec_result];
		foreach(index; indexes)
		{ 
			tmp = tmp.Get(index);
		}
		return tmp;
	}
	VALUE GetResult(string result_key)
	{
		scope(failure) return VALUE.init;
		if(result_key in _values) return _values[result_key];
		return VALUE.init;
	}
}


class VARIABLE
{
	string _name;
	string _exp;
	string _value;
	string _type;
	string _in_scope;
	string _color;
	
	VARIABLE[string] _children;
	this(string name, string exp, string value, string type)
	{
		_name = name;
		_exp = exp;
		_value = value;
		_type = type;
		_color = "red";
	}
	
	alias toString = toxString;
	string toxString(string tab = "")
	{
		string rv = tab ~ "{\n";
		tab ~= "\t";
		rv ~= tab ~ _name ~ "\n";
		rv ~= tab ~ _exp  ~ "\n";
		rv ~= tab ~ _value~ "\n";
		rv ~= tab ~ _type ~ "\n";
		rv ~= tab ~ "[\n";
		foreach(kid; _children)
			rv ~= kid.toString(tab ~ "\t");
		rv ~= tab ~ "]\n";
		tab.length = tab.length -1;
		rv ~= tab ~ "}\n";
		return rv;
	}
		
	
}

void Clear(T)(ref T aa)
{
    foreach(key; aa.keys)aa.remove(key);
}
