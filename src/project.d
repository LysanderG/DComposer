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
import std.process : shell;
import std.string;
import std.conv;
import std.xml;
import std.parallelism;
import std.concurrency;
import std.c.stdlib;

import dcore;


immutable long PROJECT_VERSION = 1;



class FLAG
{
    /**
        This class defines single instance parameters for the dmd commandline
        they may be simple on off switches (-O or -g or -gc ... -fPIC -map etc)
        or switches with single arguments (-Offilename -Dddocdir -Xffilename -debuglib=name)
        flags with multiple arguments will be defined elsewhere keep this simple for now (-Ipath -version=ident -debug=ident)
        *
        * notice phobos has a utility for flags
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

    void Reset()
    {
		m_On = false;
		m_Argument = " ";
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

    ref LIST GetData(string Key)
    {
        //static string[] almostnull = [""]; //lmao, what was I thinking?
        //if(Key !in mLists) return  almostnull; //used to return null but gui widget complained invalid text
        static LIST nothing = null; //what the hell is this?? why a reference return?
        if(Key !in mLists) return  nothing;
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
        //foreach(key,  L; mLists) mLists[key].length = 0;
        foreach(key,  L; mLists) mLists[key] = [""];
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
    string			mDmdId;									//version string (as spit out by dmd) compatible with flags


    FLAG[string]	mFlags;                                 //all cmd line params w/ 1 or less arguments
    LISTS           mList;                                  //lists of proj related stuff --srcfiles libfiles paths versions other cmd line args ...

    bool            mUseCustomBuild;                        //if build command should use custom  or bultin command
    string          mCustomBuildCommand;                    //users command to build project -- make  or scons or cmake or gdc x.d -r -L-liofjkjf whatever

	string 			mChildRunner;


    void ReadFlags(string FlagFile)
	{
        scope(failure)
        {
			Log.Entry("PROJECT.ReadFlags : Unable to open Flags File", "Error");
			exit(127);
		}
        scope(success)Log.Entry("PROJECTS.ReadFlags : Flags file opened successfully");

		auto jstring = readText(FlagFile);
		auto jval = parseJSON(jstring);
		//json file should be an array of obj -> each is {"brief":string, "cmdstring":string, "HasArg": true|false}

		string indx;
		foreach ( j; (jval.array))
		{
			if("version" in j.object)
			{
				mDmdId = j.object["version"].str;
				continue;
			}
			indx = j.object["cmdstring"].str;
			mFlags[indx] = new FLAG;
			mFlags[indx].State = false;
			mFlags[indx].Brief = std.xml.encode(j.object["brief"].str);
			mFlags[indx].CmdString = j.object["cmdstring"].str;
			mFlags[indx].Argument = " ";
			mFlags[indx].InitHasArg = (j.object["hasargument"].type == JSON_TYPE.TRUE) ? true : false;
		}
		Log.Entry("dcomposer projects prefer " ~ mDmdId , "Info");
	}

	void ResetFlags()
	{
		foreach (f;mFlags) f.Reset();
	}


	string PrettySave()
	{
		string output;
		output = "{\n";
		//version
		output ~= format("\"version\":%s,\n", mVersion);
		output ~= format("\"name\": \"%s\",\n", Name);
		output ~= format("\"basedir\": \"%s\",\n", WorkingPath);
		output ~= format("\"target\":%s,\n", cast(int)mTarget);


		foreach(key, strs; mList.mLists)
		{
			output ~= format("\"%s\":\n[\n", key);
			foreach(Ndx, s;strs)
			{
				output ~= format("\t\"%s\",\n",s);
			}
			if(strs.length > 0)output = output[0..$-2];
			output ~= "\n],\n";
		}

		output ~= "\"flags\":\n[\n";
		foreach(key, f; mFlags)
		{
			output ~= "\t{\n";
			output ~= format("\t\t\"%s\":\n\t\t{\n",key);
			output ~= format("\t\t\"state\":%s,\"cmdstring\":\"%s\",\"hasargument\":%s,\n",f.State, f.CmdString, f.HasAnArg);
			output ~= format("\t\t\"argument\":\"%s\",\n\t\t\"brief\":\"%s\"\n\t\t}\n",f.Argument, f.Brief);
			output ~= "\t},\n";
		}
		output = output[0..$-2];
		output ~= "\n]\n}";

		return output;
	}


    public :



    this()                                                  //ctor
    {
		mName = "";
		mCustomBuildCommand = "";
        mTarget = TARGET.NULL;
        mVersion = PROJECT_VERSION;

    }


    void Engage()                                           //dcore engage
    {
		mName = "";
		mCustomBuildCommand = "";
        mTarget = TARGET.NULL;
        mVersion = PROJECT_VERSION;
		WorkingPath = "";//Config.ExpandPath(Config.getString("PROJECT", "default_project_path", "~/projects"));
        mCompiler = Config.getString("PROJECT", "default_compiler", "dmd");
        mList.Zero;
        mUseCustomBuild = false;

        string FlagsFile = Config.getString("PROJECT","flags_file", "$(HOME_DIR)/flags/flagsfile.json" );
		ReadFlags(FlagsFile);

		mChildRunner = "sh " ~ Config.ExpandPath("$(HOME_DIR)/childrunner.sh") ~ " ";
        Log.Entry("Engaged PROJECT");
    }

    void Disengage()                                        //dcore disengage
    {

        if( (mTarget != TARGET.NULL) && (Name.length > 0)) Config.setString("PROJECT", "last_project", WorkingPath ~ "/" ~ Name ~ ".dpro");
        else Config.setString("PROJECT", "last_project", "no_project");
        Close();
        Log.Entry("Disengaged PROJECT");
    }

    void New()                                              //start a new project with default settings (or just open a default file?)
    {
		Event.emit(ProEvent.Creating);
        Clear();
        mTarget = TARGET.UNDEFINED;
        Event.emit(ProEvent.Created);
    }

    void Open(string pfile)                                             //open a .dpro file and we're off
    {
        Event.emit(ProEvent.Opening);
        Clear();

        scope(failure)
        {
            Clear();
            Log.Entry("PROJECT.Open : Failed to OPEN Project : " ~ pfile, "Error");
            return;

        }
		//scope(exit) Event.emit(ProEvent.Opened);

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
					break;
				}

				case JSON_TYPE.STRING :
				{
					//name basedir otherargs
					if(key == "name") 		Name      	= j.str;
					if(key == "basedir") 	WorkingPath = j.str;

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
		if(mTarget == TARGET.NULL) throw new Exception("Invalid Target Type");
		Log.Entry("Project opened: " ~ Name);
		Event.emit(ProEvent.Opened);
		CreateTags();

	}
	void Clear()
	{
		mName               = "";
        mWorkingPath      	= "";//Config.ExpandPath(Config.getString("PROJECT", "default_project_path", "~/projects"));
        mTarget             = TARGET.NULL;
        mCompiler           = Config.getString("PROJECT", "default_compiler", "dmd");
        mVersion            = PROJECT_VERSION;

		ResetFlags();

        mList.Zero();
        mUseCustomBuild = false;
        mCustomBuildCommand.length = 0;
	}

    void Close()                                            //return target type to null , and nothing doing
    {
		Event.emit(ProEvent.Closing);
        Save();
        Clear();
        Event.emit(ProEvent.Closed);

    }

    void Save()
	{
		if (mTarget == TARGET.NULL) return;
		Event.emit(ProEvent.Saving);

        scope(failure)
        {
            Log.Entry("PROJECT.Save :  Failed to save project: " ~ Name, "Error");
            return;
        }
        scope(success)Log.Entry("Project saved: " ~ Name);

		string Pfile = buildPath(WorkingPath, Name);
		Pfile = Pfile.setExtension("dpro");
		string jstring;
		JSONValue jval;

		/*jval.type = JSON_TYPE.OBJECT;

		jval.object["version"]		= JSONValue();
		jval.object["version"].type	= JSON_TYPE.INTEGER;
		jval.object["version"].integer = mVersion;

		jval.object["name"] 		= JSONValue();
		jval.object["name"].type 	= JSON_TYPE.STRING;
		jval.object["name"].str 	= Name;

		jval.object["basedir"] 		= JSONValue();
		jval.object["basedir"].type	= JSON_TYPE.STRING;
		jval.object["basedir"].str	= WorkingPath;

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
		jstring = toJSON(&jval);*/

		std.file.write(Pfile, PrettySave());

		Event.emit(ProEvent.Saved);
	}

    void OpenLastSession()
    {
        auto lastProject = Config.getString("PROJECT", "last_project", "no_project");
        if (lastProject == "no_project")return;
        if (!exists(lastProject))
        {
			Log.Entry("Last project loaded, " ~ lastProject ~ ", can not be found.", "Error");
			return;
		}
        Open(lastProject);
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
        Event.emit(ProEvent.FlagChanged);
        return true;
    }
    bool CreateTags()                                       //command to build tags (ie dmd -X) json file
    {
		string docfilename;
		scope(success)
        {
            if (exists(docfilename)) shell("rm " ~ docfilename);
            Event.emit(ProEvent.CreatedTags);
            Log.Entry("Project tags Created");

        }
		scope(failure)
		{
			Log.Entry("Failed to create project tags");
			Event.emit(ProEvent.FailedTags);
			return false;
		}

        if((mTarget == TARGET.NULL) || mTarget == (TARGET.UNDEFINED)) return false;

        Event.emit(ProEvent.CreatingTags);

        string tagfilename = Name ~ ".json";
        docfilename = buildPath(WorkingPath, "tmptags.doc");

        string CreateTagsCommand = mCompiler ~ " -c -o- -wi -X -Xf" ~ tagfilename ~ " -D -Df" ~ docfilename;

        foreach(pth; this[IMPPATHS]) CreateTagsCommand ~= " -I" ~ pth;
        foreach(src; this[SRCFILES]) CreateTagsCommand ~= " "   ~ src;
        foreach(exp; this[JPATHS])	 CreateTagsCommand ~= " -J" ~ exp;

        auto result = shell(CreateTagsCommand);

		return true;
    }
    bool Build()                                            //build the project
    {
		scope(success) CreateTags();
		scope(failure)
		{
			Log.Entry("System failure: Unable to build project.", "Error");
			return false;
		}

        if( (mTarget == TARGET.NULL) || (mTarget == TARGET.UNDEFINED) ) return false;

        string TemporaryFileName = buildPath(tempDir(), "dcomposer_build.tmp");

        Event.emit(ProEvent.Building);

        BuildMsg.emit(BuildCommand());

        std.stdio.File Process = File(TemporaryFileName,"w");

        foreach (prescript; Project["PRE_BUILD_SCRIPTS"])writeln(prescript, " ",shell(prescript));

        Process.popen(mChildRunner ~ BuildCommand() ~ " 2>&1 ", "r");



        foreach(string L; lines(Process) ) BuildMsg.emit(chomp(L));


        scope(exit) Process.close();
        Event.emit(ProEvent.Built);

        foreach (postscript; Project["POST_BUILD_SCRIPTS"]) writeln(shell(postscript));
        return true;
    }
    string BuildCommand()                                   //return the auto generated command to build the .dpro file
    {

        if(mUseCustomBuild) return mCustomBuildCommand;

        string cmdline = mCompiler ~ " ";
		foreach (f; mFlags)
		{
			if (f.State == true)
			{
				cmdline ~= f.CmdString;
				if (f.HasAnArg) cmdline ~= f.Argument;
				cmdline ~= " ";
			}
		}
		foreach (v; this[VERSIONS])     cmdline ~= " -version=" ~ v ~ " ";
		foreach (d; this[DEBUGS])       cmdline ~= " -debug=" ~ d ~ " ";


		foreach(lib; this[LIBFILES])    cmdline ~= " -L-l" ~ LibName(lib) ~ " ";

		foreach (i; this[IMPPATHS])     cmdline ~= " -I" ~ i ~ " ";
		foreach (l; this[LIBPATHS])     cmdline ~= " -L-L" ~ l ~ " ";

		foreach (j; this[JPATHS])       cmdline ~= " -J" ~ j ~ " ";
        foreach (m; this[MISC])         cmdline ~= m ~ " ";



		if (mFlags["-of"].State == false) cmdline ~= " -of" ~ Name ~ " ";

		foreach(src; this[SRCFILES])
		{
			auto srcopt = relativePath(src, WorkingPath);
			srcopt = buildNormalizedPath(srcopt);
			cmdline ~= " " ~ srcopt ~ " ";
		}

		return cmdline;
    }
    bool Run(string args = null )                                              //if app then run the thing
    {
        if(mTarget != TARGET.APP) return false;

        Event.emit(ProEvent.Running);

        scope(failure)
        {
            Log.Entry("System Failed to run project", "Error");
            return false;
        }

        //string ProcessCommand =  "xterm -hold  -title -e ./" ~ Project.Name;
        string xTermTitle = "dcomposer running " ~ Project.Name;
        string ProcessCommand = format(`xterm -hold -T "%s" -e %s`, xTermTitle, "./"~Project.Name);
        if(args !is null) ProcessCommand ~= " " ~ args;

        std.stdio.File Process;
        Process.popen(ProcessCommand, "r");

        Log.Entry("Running ... " ~ ProcessCommand);
        foreach(string L; lines(Process) ) Log.Entry(chomp(L));

        Process.close();
        Event.emit(ProEvent.Ran);
        return true;
    }

    bool RunConcurrent(string args = null)
    {
        if(mTarget != TARGET.APP)
        {
			Log.Entry("Project is not a runnable application", "Error");
			return false;
		}
        if(!exists(Project.Name))
        {
			Log.Entry(Project.Name ~ " executable file not found. (Has project been built?)", "Error");
			return false;
		}
        //string ProcessCommand =  "xterm -hold  -title -e ./" ~ Project.Name;
        string xTermTitle = "dcomposer running " ~ Project.Name;
        string ProcessCommand = format(`xterm  -T "%s" -e "%s; bash " &`, xTermTitle, "./"~Project.Name);
        if(args !is null) ProcessCommand ~= " " ~ args;

        //auto RunTask = task!funRun(ProcessCommand, thisTid);

        //RunTask.executeInNewThread();
        spawn(&funRun, ProcessCommand);
        return true;

    }

    mixin Signal!(ProEvent) Event;                                  //any change to object emits this event string may tell what event is
    mixin Signal!(string) 	RunMsg;                                 //stdout from running project
    mixin Signal!(string)	BuildMsg;                               //stdout from building with compiler

    //====================
    //====================
    //List stuff -- lvalue ?? lvalue?? wtf  this didnt work so well

    //if target is null should return null!

    //later note... I think i need to do ref string[] opIndex(string Key){return  mList.GetData(Key);}

    void opOpAssign(string s = "+=")(string Key)                    {   mList.AddKey(Key);          Event.emit(ProEvent.ListChanged);}
    void opOpAssign(string s = "-=")(string Key)                    {   mList.RemoveKey(Key);       Event.emit(ProEvent.ListChanged);}
    void opIndexAssign(LIST Data, string Key)                       {   mList.SetKey(Key, Data);    Event.emit(ProEvent.ListChanged);}
    void opOpIndexAssign(string s = "~=")(LIST Data, string Key)    {   mList.ConcatData(Key, Data);Event.emit(ProEvent.ListChanged);}
    ref string opOpIndexAssign(string s = "~=")(string Data, string Key)
    {
        AddItem(Key, Data);
        return mList.GetData(Key);
    }
    ref string[] opIndex(string Key)                                {   return mList.GetData(Key);  }//Event.emit("ListChange");}

    void SetList(string Key, LIST Data)                             {   mList.SetKey(Key, Data);Event.emit(ProEvent.ListChanged);}
    void SetList(string Key, string Data)                           {   mList.SetKey(Key, [Data]);Event.emit(ProEvent.ListChanged);}
    void RemoveItem(string Key, string Item)                        {   mList.RemoveData(Key, Item);Event.emit(ProEvent.ListChanged);}
    void AddItem(string Key, string Item)                           {   mList.ConcatData(Key, Item);Event.emit(ProEvent.ListChanged);}
    void AddUniqueItem(string Key, string Item)
    {
		foreach(KeyItem; mList.GetData(Key))
		{
			if (KeyItem == Item) return;
		}
		mList.ConcatData(Key, Item);
		Event.emit(ProEvent.ListChanged);
	}
	string[] GetList(string Key)                                    {   return mList.GetData(Key);}
    string GetCatList(string Key)
    {
        string rv;
        foreach(s; mList.GetData(Key)) rv ~= s;
        if (rv is null) rv = "";
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
            Event.emit(ProEvent.NameChanged);
        }

        string WorkingPath() {return mWorkingPath;}
        void WorkingPath(string nuPath)
        {
            scope(failure)
            {
                mWorkingPath = "";
                Event.emit(ProEvent.PathChanged);
                return;
            }
            if(!nuPath.exists) mkdir(nuPath);
            chdir(nuPath);
            mWorkingPath = nuPath;
            Event.emit(ProEvent.PathChanged);
        }

        string Compiler(){return mCompiler;}
        void Compiler(string nuCompiler){mCompiler = nuCompiler;Event.emit(ProEvent.CompilerChanged);}

        bool UseCustomBuild(){return mUseCustomBuild;}
        void UseCustomBuild(bool UseIt){mUseCustomBuild = UseIt;Event.emit(ProEvent.UseCustomBuildChanged);}

        string CustomBuildCommand(){return mCustomBuildCommand;}
        void CustomBuildCommand(string nuCommand){mCustomBuildCommand = nuCommand;Event.emit(ProEvent.CustomBuildChanged);}

        int Target(){return cast(int)mTarget;}
        void Target(int nuTarget){mTarget = cast(TARGET)nuTarget;Event.emit(ProEvent.TargetChanged);}
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

void funRun(string command)
{
    string[] rv;
    std.stdio.File Process;
    Process.popen(command, "r");
    Process.close();
    //foreach(string L; lines(Process) )
    //{
    //    rv ~= L;
    //}
//
    //return rv;
}


enum ProEvent {
	Creating,
	Created,
	Closing,
	Closed,
	Saving,
	Saved,
	Opening,
	Opened,
	CreatingTags,
	CreatedTags,
	FailedTags,
	Building,
	Built,
	Running,
	Ran,
	ListChanged,
	NameChanged,
	FlagChanged,
	PathChanged,
	CompilerChanged,
	UseCustomBuildChanged,
	CustomBuildChanged,
	TargetChanged
}
