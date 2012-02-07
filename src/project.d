// project.d
// 
// Copyright 2012 Anthony Goins <anthony@LinuxGen11>
// 
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
// MA 02110-1301, USA.

module project;

import std.stdio;
import std.json;
import std.signals;
import std.file;
import std.path;
import std.process;
import std.string;
import std.conv;

import dcore;

immutable long PROJECT_VERSION = 1;



class FLAG
{
    /**
        This class defines single instance parameters for the dmd commandline
        they may be simple on off switches (-O or -g or -gc ... -fPIC -map etc)
        or switches with single arguments (-Offilename -Dddocdir -Xffilename -debuglib=name)
        flags with multiple arguments will be defined elsewhere keep this simple for now (-Ipath -version=ident -debug=ident)
    */

    private:

    bool	    m_On;                       //use or not to use
    bool		m_HasArgument;				//if m_Argument is relevant
    string      m_Brief;                    //'brief' description output for user
    string      m_String;                   //actual string to add to dmd
    string      m_Argument;                 //the ONE argument (if any) for the flag
    
    public:

	this()
	{
	}
    this(string String, string Brief,  bool HasArg, string Argument = " ")
    {
        m_On =  false;
		m_HasArgument = HasArg;
        m_Brief = Brief;
        m_String = String;
        m_Argument = Argument;     
    }
    
    @property
    {
		void State(bool NuState) { m_On = NuState;}
		bool State() {return m_On;}
		
		bool HasAnArg() {return m_HasArgument;}
		void InitHasArg(bool DoesIt) { m_HasArgument = DoesIt;}
		
		string Brief() { return m_Brief;}
		void Brief(string s) {m_Brief = s;}
        
		string CmdString() {return m_String;}
		void CmdString(string s) {m_String = s;}
		
		void   Argument(string Arg) {if (m_HasArgument) m_Argument = Arg;}
		string Argument() { return m_Argument;}
	}
    //are these properties really necessary?? why not just use a simple public struct
}

alias string[] LIST;

struct LISTS
{
    LIST[string] mLists;

    LIST GetKeys()
    {
        return mLists.keys;
    }

    void AddKey(string Key)
    {
        if(Key in mLists) return;
        mLists[Key].length = 0;
    }

    void SetKey(string Key, LIST Data)
    {
        mLists[Key] = Data;
    }

    void RemoveKey(string Key)
    {
        if(Key !in mLists)return;
        mLists.remove(Key);
    }

    LIST GetData(string Key)
    {
        if(Key !in mLists) return null;
        return mLists[Key];
    }

    void SetData(string Key, LIST Data)
    {
        SetKey(Key, Data);
    }
    LIST ConcatData(string Key, LIST Data)
    {
        return mLists[Key] ~= Data;
    }

    void ConcatData(string Key, string Data)
    {
        mLists[Key] ~= Data;
    }

    void RemoveData(string Key, string Item)
    {
        if(Key !in mLists) return;		
		LIST tmp;
		foreach( i; mLists[Key]) if ( i != Item) tmp ~= i;
		mLists[Key] = tmp.dup;		
	}

    void Zero()
    {
        foreach(key, ref LIST L; mLists) L = null;
    }

}


enum TARGET:int { NULL = 0, UNDEFINED, APP, SHARED, STATIC, OBJECT, OTHER }
enum :string { SRCFILES = "srcfiles", RELFILES = "relfiles", LIBFILES = "libfiles" , IMPPATHS = "imppaths" , LIBPATHS = "libpaths" , JPATHS = "jpaths" , VERSIONS = "versions" , DEBUGS = "debugs", MISC = "misc"} 



class PROJECT
{
    private :
    string          mName;                                  //name of project sans path or extension
    string          mWorkingPath;                           //working path and where .dpro file should be saved

    TARGET          mTarget;                                //what kind of proj this object is (null == no proj loaded)

    string          mCompiler;                              //dmd gdmd ldc 

    ulong           mVersion;                               //match file version (can we open or convert .dpro)
    

    FLAG[string]	mFlags;                                 //all cmd line params w/ 1 or less arguments
    LISTS           mList;                                  //lists of proj related stuff --srcfiles libfiles paths versions other cmd line args ...

    bool            mUseCustomBuild;                        //if build command should use custom  or bultin command
    string          mCustomBuildCommand;                    //users command to build project -- make  or scons or cmake or gdc x.d -r -L-liofjkjf whatever


    void ReadFlags(string FlagFile)
	{
        scope(failure)Log.Entry("Unable to open Flags File", "Error");
        
		auto jstring = readText(FlagFile);
		auto jval = parseJSON(jstring);
		//json file should be an array of obj -> each is {"brief":string, "cmdstring":string, "HasArg": true|false}

		string indx;
		foreach ( j; jval.array)
		{
			indx = j.object["cmdstring"].str;
			mFlags[indx] = new FLAG;
			mFlags[indx].State = false;
			mFlags[indx].Brief = j.object["brief"].str;
			mFlags[indx].CmdString = j.object["cmdstring"].str;
			mFlags[indx].Argument = " ";
			mFlags[indx].InitHasArg = (j.object["hasargument"].type == JSON_TYPE.TRUE) ? true : false;
		}
	}


    public :

    

    this()                                                  //ctor
    {
        mTarget = TARGET.NULL;
        mVersion = PROJECT_VERSION;
    }


    void Engage()                                           //dcore engage
    {
        mCompiler = Config.getString("PROJECT", "default_compiler", "dmd");
        
        string FlagsFile = expandTilde(Config.getString("PROJECT","flags_file", "~/.neontotem/dcomposer/flagsfile.json" ));
		ReadFlags(FlagsFile);
        Log.Entry("Engaged PROJECT");
    }
    
    void Disengage()                                        //dcore disengage
    {
        Close();
        Log.Entry("Disengaged PROJECT");
    }

    void New()                                              //start a new project with default settings (or just open a default file?)
    {
        Close();       
        mTarget = TARGET.UNDEFINED;
        Event.emit("New");        
    }        
        
    void Open(string pfile)                                             //open a .dpro file and we're off
    {
        Close();
        scope(failure)
        {
            Log.Entry("Failed to open Project : " ~ pfile, "Error");
            mTarget = TARGET.NULL;
            Close();
            return;
        }
        scope(success)Log.Entry("Project opened: " ~ mName);
        
		auto jstring = readText(pfile);        
		
		auto jval = parseJSON(jstring);
		
		foreach( key, j; jval.object)
		{
			switch (j.type)
			{
				case JSON_TYPE.ARRAY :
				{
					if(key == "flags")
					{
						//I inadvertantly added an extra level to flags json object ... makes it harder to parse!
						//each object (flag) is preceeded by the cmd switch, no good reason for this.(I really should fix this)
						foreach ( f; j.array)
						{	
							auto SwitchKeys = f.object.keys; // this should be length = 1 ... really not needed
							if (SwitchKeys.length < 1) break;
							SetFlag(f.object[SwitchKeys[0]].object["cmdstring"].str, (f.object[SwitchKeys[0]].object["state"].type == JSON_TYPE.TRUE), f.object[SwitchKeys[0]].object["argument"].str);
						}
						break;
					}
					//else its an mList thing
					
					string[] tmp;
					foreach (l; j.array) tmp ~= l.str;
					SetList(key, tmp);
                    //this[key] = tmp;
					break;
				}
				
				case JSON_TYPE.STRING :
				{
					//name basedir otherargs
					if(key == "name") 		Name      	= j.str;
					if(key == "basedir") 	WorkingPath= j.str;
					//if(key == "other")		this[MISC] 	= [j.str];
					break;
				}
				case JSON_TYPE.INTEGER :
				{
					if(key == "version")	mVersion 	= j.integer;
					if(key == "target")		Target		= cast (TARGET) j.integer;
					break;
				}
				
				default : break;
			}
		}

        
        if(mVersion > PROJECT_VERSION)throw new Exception("bad version");
        
        CreateTags();

        Event.emit("Open");

	}    
    void Close()                                            //return target type to null , and nothing doing
    {
        Log.Entry("Closing Project", "Debug");
        if(mTarget != TARGET.NULL)   Save();
        mTarget = TARGET.NULL;
        
        mName = "";
        mWorkingPath = "";

        scope(failure)Log.Entry("Unable to open Flags File", "Error");
        string FlagsFile = expandTilde(Config.getString("PROJECT","flags_file", "~/neontotem/dcomposer/flagsfile.json" ));
		ReadFlags(FlagsFile);
        mList.Zero();
        mUseCustomBuild = false;
        mCustomBuildCommand = "";

        Event.emit("Close");  
    }

    void Save()
	{
        scope(failure)
        {
            Log.Entry("Failed to save project: " ~ mName, "Error");
            return;
        }
        scope(success)Log.Entry("Project saved: " ~ mName);
        
		string Pfile = buildPath(mWorkingPath, mName);
		Pfile = Pfile.setExtension("dpro");
		string jstring;
		JSONValue jval;
		
		jval.type = JSON_TYPE.OBJECT;

		jval.object["version"]		= JSONValue();
		jval.object["version"].type	= JSON_TYPE.INTEGER;
		jval.object["version"].integer = mVersion;
		
		jval.object["name"] 		= JSONValue();
		jval.object["name"].type 	= JSON_TYPE.STRING;
		jval.object["name"].str 	= mName;
		
		jval.object["basedir"] 		= JSONValue();
		jval.object["basedir"].type	= JSON_TYPE.STRING;
		jval.object["basedir"].str	= mWorkingPath;
		
		jval.object["target"] 		= JSONValue();
		jval.object["target"].type	= JSON_TYPE.INTEGER;
		jval.object["target"].integer = mTarget;
		
		//mLists
		foreach (key, strs; mList.mLists)
		{
			jval.object[key]		= JSONValue();
			jval.object[key].type 	= JSON_TYPE.ARRAY;
			jval.object[key].array.length = this[key].length;
			foreach(i, s; strs)
			{
				jval.object[key].array[i].type 	= JSON_TYPE.STRING;
				jval.object[key].array[i].str	= s;
			}
		}
		
		//mFlags		
		jval.object["flags"] 		=JSONValue();
		jval.object["flags"].type	=JSON_TYPE.ARRAY;
		jval.object["flags"].array.length = mFlags.length;
		uint i = 0;
		foreach (key, f; mFlags)
		{
			if (f.State == false) continue;
			
			jval.object["flags"].array[i].type 										= JSON_TYPE.OBJECT;
			jval.object["flags"].array[i].object[key] 								= JSONValue();
			jval.object["flags"].array[i].object[key].type 							= JSON_TYPE.OBJECT;
			
			jval.object["flags"].array[i].object[key].object["state"] 				= JSONValue();
			jval.object["flags"].array[i].object[key].object["state"].type 			= (f.State) ? JSON_TYPE.TRUE : JSON_TYPE.FALSE;
			
			jval.object["flags"].array[i].object[key].object["brief"] 				= JSONValue();
			jval.object["flags"].array[i].object[key].object["brief"].type			= JSON_TYPE.STRING;
			jval.object["flags"].array[i].object[key].object["brief"].str 			= f.Brief;
			
			jval.object["flags"].array[i].object[key].object["cmdstring"] 			= JSONValue();
			jval.object["flags"].array[i].object[key].object["cmdstring"].type 		= JSON_TYPE.STRING;
			jval.object["flags"].array[i].object[key].object["cmdstring"].str 		= f.CmdString;
			
			jval.object["flags"].array[i].object[key].object["hasargument"]			= JSONValue();
			jval.object["flags"].array[i].object[key].object["hasargument"].type	= (f.HasAnArg) ? JSON_TYPE.TRUE : JSON_TYPE.FALSE;
			
			jval.object["flags"].array[i].object[key].object["argument"]			= JSONValue();
			jval.object["flags"].array[i].object[key].object["argument"].type		= JSON_TYPE.STRING;
			jval.object["flags"].array[i].object[key].object["argument"].str		= f.Argument;	
			i++;				
			
		}
		jstring = toJSON(&jval);
		
		std.file.write(Pfile, jstring);

		Event.emit("Save");
		
	}
	
        
    FLAG[string] GetFlags()                                 //returns all flags or a copy of em
    {
        return mFlags.dup;
    }
    bool SetFlag(string key, bool NuState, string NuArgument = "")
	{
		if ( (key in mFlags) == null) return false;
		
		mFlags[key].State = NuState;
		mFlags[key].Argument = NuArgument;
        Event.emit("SetFlag");
        return true;
    }
    bool CreateTags()                                       //command to build tags (ie dmd -X) json file
    {
        if((mTarget == TARGET.NULL) || mTarget == (TARGET.UNDEFINED)) return false;

        string tagfilename = mName ~ ".tags";
        string docfilename = buildPath(mWorkingPath, "tmptags.doc");

        string CreateTagsCommand = mCompiler ~ " -c -o- -X -Xf" ~ tagfilename ~ " -D -Df" ~ docfilename;

        foreach(pth; this[IMPPATHS]) CreateTagsCommand ~= " -I" ~ pth;
        foreach(src; this[SRCFILES]) CreateTagsCommand ~= " " ~ src;
        
        auto result = system(CreateTagsCommand);
        
        if(result == 0)
        {
            system("rm " ~ docfilename);
            Event.emit("CreateTags");
            Log.Entry("Project tags Created");
            return true;
        }

        Log.Entry("Failed to create project tags");
        return false;        
    }
    bool Build()                                            //build the project
    {
        if( (mTarget == TARGET.NULL) || (mTarget == TARGET.UNDEFINED) ) return false;

        BuildMsg.emit(`BEGIN`);
        BuildMsg.emit(BuildCommand());   

        std.stdio.File Process = File("tmp","w");

        Process.popen("sh /home/anthony/.neontotem/dcomposer/childrunner.sh " ~ BuildCommand() ~ " 2>&1 ", "r");

        foreach(string L; lines(Process) ) BuildMsg.emit(chomp(L));

        scope(exit) Process.close();
        Event.emit("Build");
        
        return true;
    }
    string BuildCommand()                                   //return the auto generated command to build the .dpro file
    {
        
        if(mUseCustomBuild) return mCustomBuildCommand;
        
        string cmdline = mCompiler;        
        
		foreach(src; this[SRCFILES])
		{
			auto srcopt = relativePath(src, mWorkingPath);
			srcopt = buildNormalizedPath(srcopt);
			cmdline ~= " " ~ srcopt ~ " ";
		}
        
		foreach(lib; this[LIBFILES])    cmdline ~= "-L-l" ~ LibName(lib) ~ " ";
		
		foreach (i; this[IMPPATHS])     cmdline ~= "-I" ~ i ~ " ";
		foreach (l; this[LIBPATHS])     cmdline ~= "-L-L" ~ l ~ " ";
		
		foreach (v; this[VERSIONS])     cmdline ~= "-version=" ~ v ~ " ";
		foreach (d; this[DEBUGS])       cmdline ~= "-debug=" ~ d ~ " ";
		foreach (j; this[JPATHS])       cmdline ~= "-J" ~ j ~ " ";
        foreach (m; this[MISC])         cmdline ~= m ~ " ";
		
		foreach (f; mFlags)
		{
			if (f.State == true)
			{
				cmdline ~= f.CmdString;
				if (f.HasAnArg) cmdline ~= f.Argument;
				cmdline ~= " ";
			}
		}
		
		if (mFlags["-of"].State == false) cmdline ~= "-of" ~ mName ~ " ";
		
		return cmdline;
    }
    bool Run(string args = null )                                              //if app then run the thing
    {
        if(mTarget != TARGET.APP) return false;
        
        scope(failure)
        {
            Log.Entry("Failed to run project");
            return false;
        }

        string ProcessCommand =  "./" ~ Project.Name;
        if(args !is null) ProcessCommand ~= " " ~ args;
        
        std.stdio.File Process;
        Process.popen(ProcessCommand, "r");

        Log.Entry("Running ... " ~ ProcessCommand);
        foreach(string L; lines(Process) ) Log.Entry(chomp(L));//RunMsg.emit(chomp(L));
    
        Process.close();
        Event.emit("Run");            
        return true;
    }

    mixin Signal!(string) Event;                                  //any change to object emits this event string may tell what event is
    mixin Signal!(string) RunMsg;                                 //stdout from running project
    mixin Signal!(string) BuildMsg;                               //stdout from building with compiler

    //====================
    //====================
    //List stuff -- lvalue ?? lvalue?? wtf  this didnt work so well

    //if target is null should return null!

    void opOpAssign(string s = "+=")(string Key)                    {   mList.AddKey(Key);          Event.emit("ListChange");}
    void opOpAssign(string s = "-=")(string Key)                    {   mList.RemoveKey(Key);       Event.emit("ListChange");} 
    void opIndexAssign(LIST Data, string Key)                       {   mList.SetKey(Key, Data);    Event.emit("ListChange");}
    void opOpIndexAssign(string s = "~=")(LIST Data, string Key)    {   mList.ConcatData(Key, Data);Event.emit("ListChange");}
    void opOpIndexAssign(string s = "~=")(string Data, string Key)  {   mList.ConcatData(Key, Data);Event.emit("ListChange");}
    string[] opIndex(string Key)                                    {   return mList.GetData(Key);  }//Event.emit("ListChange");}

    void SetList(string Key, LIST Data)                             {   mList.SetKey(Key, Data);Event.emit("ListChange");}
    void SetList(string Key, string Data)                           {   mList.SetKey(Key, [Data]);Event.emit("ListChange");}
    void RemoveItem(string Key, string Item)                        {   mList.RemoveData(Key, Item);Event.emit("ListChange");}
    void AddItem(string Key, string Item)                           {   mList.ConcatData(Key, Item);Event.emit("ListChange");}
    string[] GetList(string Key)                                    {   return mList.GetData(Key);}
    string GetCatList(string Key)
    {
        string rv;
        foreach(s; mList.GetData(Key)) rv ~= s;
        return rv;
    }
        

    //=====================
    //=====================
    //get/setters properties

    @property
    {
        string Name() {return mName;}
        void Name(string nuName)
        {
            mName = nuName;
            Event.emit("Name");
        }

        string WorkingPath() {return mWorkingPath;}
        void WorkingPath(string nuPath)
        {
            
            scope(failure)
            {
                mWorkingPath = "";
                Event.emit("WorkingPath");
                return;
            }
            if(!nuPath.exists) mkdir(nuPath);
            chdir(nuPath);
            mWorkingPath = nuPath;
            Event.emit("WorkingPath");
        }

        string Compiler(){return mCompiler;}
        void Compiler(string nuCompiler){mCompiler = nuCompiler;Event.emit("Compiler");}

        bool UseCustomBuild(){return mUseCustomBuild;}
        void UseCustomBuild(bool UseIt){mUseCustomBuild = UseIt;Event.emit("UseCustomBuild");}

        string CustomBuildCommand(){return mCustomBuildCommand;}
        void CustomBuildCommand(string nuCommand){mCustomBuildCommand = nuCommand;Event.emit("CustomBuildCommand");}

        int Target(){return cast(int)mTarget;}
        void Target(int nuTarget){mTarget = cast(TARGET)nuTarget;Event.emit("Target");}
    }

        

        
}
    
string LibName(string Lib)
{
    auto retstr = baseName(Lib);
    retstr = chompPrefix(retstr, "lib");
    auto pos = std.string.indexOf(retstr,".so");
    if(pos == -1)
    {
        pos = std.string.indexOf(retstr,".a");
        if (pos == -1) return Lib;
    }
    retstr = retstr[0..pos];
    return retstr;
}
