//      dpro.d
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

module dproject;

import std.parallelism;

import dcore;


import std.json;
import std.stdio;
import std.file;
import std.path;
import std.process;
import std.string;
import std.signals;

import glib.SimpleXML;

immutable long PROJECT_VERSION = 100;

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
}


alias string[] LIST;
enum TARGET { NULL, APP, SHARED, STATIC, OBJECT, OTHER }
enum :string { SRCFILES = "srcfiles", RELFILES = "relfiles", LIBFILES = "libfiles" , INCPATHS = "incpaths" , LIBPATHS = "libpaths" , JPATHS = "jpaths" , VERSIONS = "versions" , DEBUGS = "debugs"} 

class PROJECTD
{
	private :

	long 			mVersion;
	string			mName;
	string			mBaseDir;
	TARGET			mType;
	
	LIST[string]	mLists;
	
	FLAG[string]	mFlags;
	
	string 		    mOtherArgs;

    bool        	mUseManualCmdLine;              //if the user wants to supply a custom commandline (which negates reason for this class!)
    string 	 	    mManualCmdLine;                 //users command line;
	
	void ReadFlags(string FlagFile)
	{
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
	
	public:
    this()
	{
		mVersion = PROJECT_VERSION;
		mName = "";
		mType = TARGET.NULL;
		mBaseDir =absolutePath( getcwd());
		
		mUseManualCmdLine = false;
        mManualCmdLine = " ";
        mOtherArgs = " ";
		
		//DEFAULT KEYS
		AddList(SRCFILES);
		AddList(RELFILES);
		AddList(LIBFILES);
		AddList(INCPATHS);
		AddList(LIBPATHS);
		AddList(JPATHS);
		AddList(VERSIONS);
		AddList(DEBUGS);
		
		//couldnt figure out how to add the default keys without adding a "" string 
		//so here I'm deleting that "" string and keeping the default key mlists
		//i know i know such a hack.
		foreach (key,l; mLists) Remove(key, "");
	}

    void Engage()
    {
        auto FlagFile = Config().getString("DPROJECT","flags_file");
		ReadFlags(FlagFile);
        Log().Entry("Engaged D_PROJECT");
    }

    void Disengage()
    {
        Save();
        Log().Entry("Disengaged D_PROJECT");
    }


    FLAG[string] GetFlags() {return mFlags.dup;}
	void SetFlag(string key, bool NuState, string NuArgument = "")
	{
		if ( (key in mFlags) == null) return;
		
		mFlags[key].State = NuState;
		mFlags[key].Argument = NuArgument;
    }


	@property
    {
        void    OtherArgs(string Options)
        {
            mOtherArgs = Options;
            OtherArgsChanged.emit(mOtherArgs);
        }
        string  OtherArgs() {return mOtherArgs;}
	
        void Name(string nuname)
        {
            //perhaps some code to ensure nuname is a valid name? (no wierd characters or whatever)
            //or if its a path change base dir and extract name to name
            mName = baseName(nuname);

            //BaseDir = buildPath(BaseDir,Name);
writeln("**"~mName);
            NameChanged.emit(mName);
        }
        string Name() {return mName.idup;}
	
        void   BaseDir(string nudir)
        {
            auto ProDir = buildPath(nudir, Name);
            
            mBaseDir = nudir;
            if(!exists(ProDir))mkdir(ProDir);
            chdir(ProDir);
            BaseDirChanged.emit(BaseDir);
        }
        string BaseDir() {return mBaseDir.idup;}

        bool UseManualBuild(){return mUseManualCmdLine;}
        void UseManualBuild(bool NuVal){mUseManualCmdLine = NuVal;}
        
        string CmdLine(){return mUseManualCmdLine? mManualCmdLine: BuildCommand();}
        void CmdLine(string NuVal){mManualCmdLine = NuVal;}

        TARGET Type(){return mType;}
        void Type(TARGET X){mType = X;TypeChanged.emit(mType);}
    }
	

    void Close()
    {
        Save();

        mVersion = PROJECT_VERSION;
        mBaseDir = Config.getString("DPROJECT", "default_project_folder", "/home/anthony/projects");
        ReadFlags(Config().getString("DPROJECT","flags_file"));
        foreach ( key, L; mLists) mLists[key].clear;
        mManualCmdLine.length = 0;
        mName = " ";
        mOtherArgs = " ";
        mType = TARGET.APP;
        mUseManualCmdLine = false;    
    }
        
	
	void Save()
	{
        auto ProDir = buildPath(BaseDir, Name);
		string Pfile = buildPath(ProDir, Name);
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
		jval.object["basedir"].str	= mBaseDir;
		
		jval.object["type"] 		= JSONValue();
		jval.object["type"].type	= JSON_TYPE.INTEGER;
		jval.object["type"].integer = mType;
		
		jval.object["other"]		= JSONValue();
		jval.object["other"].type	= JSON_TYPE.STRING;
		jval.object["other"].str	= mOtherArgs;
		
		//mLists
		foreach (key, strs; mLists)
		{
			jval.object[key]		= JSONValue();
			jval.object[key].type 	= JSON_TYPE.ARRAY;
			jval.object[key].array.length = mLists[key].length;
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

		Saved.emit(Pfile);		
		
	}
	
	void Open(string pfile)
	{
        scope(failure)
        {
            Log.Entry("Failed to open Project : " ~ pfile, "Error");
            Close();
            return;
        }
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
					foreach (l; j.array)
					{
						tmp ~= l.str;
					}
					Set(key, tmp);
					break;
				}
				
				case JSON_TYPE.STRING :
				{
					//name basedir otherargs
					if(key == "name") 		mName      	= j.str;
					if(key == "basedir") 	mBaseDir   	= j.str;
					if(key == "other")		mOtherArgs 	= j.str;
					break;
				}
				case JSON_TYPE.INTEGER :
				{
					if(key == "version")	mVersion 	= j.integer;
					if(key == "type")		mType 		= cast (TARGET) j.integer;
					break;
				}
				
				default : break;
			}
		}

        if(mVersion > PROJECT_VERSION)Version.emit();

        chdir(buildPath(BaseDir, Name));
		Opened.emit(pfile);

        CreateTags();

	}

    void New(string nuName, TARGET nuType = TARGET.APP, string nuDirectory ="./")
    {

        if(Type != TARGET.NULL)
        {
            Close();
            return;
        }
        //this = new PROJECTD;
        Name = nuName;
        Type = nuType;
        BaseDir = Config.getString("DPROJECT","default_project_folder","/home/anthony/projects");
        auto ProDir = buildPath(BaseDir,Name);
        if(!exists(ProDir))mkdir(ProDir);
        chdir(ProDir);
    }
    	
	string BuildCommand()
	{

        if(mUseManualCmdLine) return mManualCmdLine;
        
        string cmdline = "dmd ";

        auto ProDir = buildPath(mBaseDir, mName);
        
		foreach(s; mLists[SRCFILES])
		{
			auto tstr = relativePath(s, ProDir);
			tstr = buildNormalizedPath(tstr);
			cmdline ~= tstr ~ " ";
			//cmdline ~= s ~ " ";
		}
		foreach(l; mLists[LIBFILES])
		{

			cmdline ~= "-L-l" ~ LibName(l)~ " ";
		}
		
		foreach (i; mLists[INCPATHS]) cmdline ~= "-I" ~ i ~ " ";
		foreach (l; mLists[LIBPATHS]) cmdline ~= "-L-L" ~ l ~ " ";
		
		foreach (v; mLists[VERSIONS]) cmdline ~= "-version=" ~ v ~ " ";
		foreach (d; mLists[DEBUGS]) cmdline ~= "-debug=" ~ d ~ " ";
		foreach (j; mLists[JPATHS]) cmdline ~= "-J" ~ j ~ " ";
		
		foreach (f; mFlags)
		{
			if (f.State == true)
			{
				cmdline ~= f.CmdString;
				if (f.HasAnArg) cmdline ~= f.Argument;
				cmdline ~= " ";
			}
		}
		
		if (mFlags["-of"].State == false) cmdline ~= "-of" ~ Name ~ " ";

		cmdline ~= " " ~ mOtherArgs;
		
		return cmdline;
	}


    int CreateTagsx()
    {
        //scope(exit)system("rm tmp.doc");
        scope(failure)return -1;
        scope(success)TagsUpdated.emit(Name);
        
        
        
        string tagcmd = "dmd -c -o- -X -Xf"~ Name ~".tags -D -Dftmp.doc ";
        foreach(projectsrc; Get(SRCFILES)) {tagcmd ~= projectsrc ~ " ";}
        foreach(importpath; Get(INCPATHS)) {tagcmd ~= "-I"~importpath ~ " ";}

        auto tagtask = task!system(tagcmd);
        
        
        tagtask.executeInNewThread(); 
        return 0;
        
    }

    int CreateTags()
    {
        //scope(exit)system("rm tmp.doc");
        scope(failure)return -1;
        scope(success)TagsUpdated.emit(Name);
        
        
        
        string tagcmd = "dmd -c -o- -X -Xf"~ Name ~".tags -D -Dftmp.doc ";
        foreach(projectsrc; Get(SRCFILES)) {tagcmd ~= projectsrc ~ " ";}
        foreach(importpath; Get(INCPATHS)) {tagcmd ~= "-I"~importpath ~ " ";}
writeln(tagcmd);        

        return system(tagcmd);


        
    }

    void Build()
    {
        BuildMsg.emit(`BEGIN`);
        BuildMsg.emit(BuildCommand());   
        std.stdio.File Process = File("tmp","w");

        //scope(failure)foreach(string L; lines(Process) )Log().Entry(SimpleXML.escapeText( chomp(L), -1),"Error");
        Process.popen("sh /home/anthony/.neontotem/dcomposer/childrunner.sh " ~ BuildCommand() ~ " 2>&1 ", "r");

        string[] output;

        foreach(string L; lines(Process) )
        {
           BuildMsg.emit(chomp(L));
        }
        scope(exit) Process.close();
    }

    
    
    



//==========LIST STUFF =========================

    string[] AddList(string key, string content = "")
	{
		//this is allow additional functionality to this project class
		//for instance may add todo key with each thing to be done 
		//or a log key with a new item with every version
		//if key exists then add content ... no dont do that /// replace it
		
		if (key !in mLists) 
		{
			mLists[key] ~= content;
			return mLists[key];
		}
		ListChanged.emit(key, mLists[key]);
		return Add(key, content);
	}

	string[] Set(string key, string[] NuList)
	{	
		mLists[key] = NuList.dup;
		ListChanged.emit(key, mLists[key]);
		return mLists[key].dup;		
	}
	string[] Set(string key, string item)
	{
		
		mLists[key].length = 1;
		mLists[key][0] = item.idup;
		ListChanged.emit(key, mLists[key]);

		return mLists[key].dup;
	}

	//not remove or delete just clear the list
    void Clear(string key)
    {
        if(key !in mLists) return;

        mLists[key].length = 0;
        ListChanged.emit(key, mLists[key]);
    }
	
	string[] Add(string key, string item)
	{
		if(key !in mLists) return null;
		
		mLists[key] ~= item.idup;

		ListChanged.emit(key, mLists[key]);
		return mLists[key].dup;
	}
	
	string[] Get(string key)
	{
		if(key !in mLists)return null;
		return mLists[key].dup;
	}

	string GetFirst(string key)
	{
		if(!(key in mLists))return "-";
        if(mLists[key].length < 1) return "-";
		return mLists[key][0];
	}

	string[] GetListsKeys()
	{
		return mLists.keys;
	}
	
	string[] Remove(string key, string item)
	{
		if(key !in mLists) return null;
		
		LIST tmp;
		
		foreach( i; mLists[key]) if ( i != item) tmp ~= i;
		mLists[key] = tmp.dup;
		ListChanged.emit(key, mLists[key]);
		return mLists[key].dup;
	}

	mixin Signal!(string , string[] ) ListChanged;
	mixin Signal!(string ) BaseDirChanged;
	mixin Signal!(string ) NameChanged;
	mixin Signal!(string ) OtherArgsChanged;
	mixin Signal!(string ) Opened;
	mixin Signal!(string ) Saved;
    mixin Signal!(TARGET ) TypeChanged;
    mixin Signal!()        Version;
    mixin Signal!(string ) BuildMsg;
    mixin Signal!(string)        TagsUpdated;
	
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


