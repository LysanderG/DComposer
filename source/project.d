module project;

import std.algorithm;
import std.conv;
import std.file;
import std.getopt;
import std.path;
import std.signals;
import std.string;
import std.process: pConfig=Config, spawnProcess;
import std.stdio;



import qore;
import json;


string defaultProjectRoot;
enum PROJECT_MODULE_VERSION = "B";

private PROJECT mProject;

string 	startUpProject;



PROJECT Project(){return mProject;}

void Engage(ref string[] cmdLineArgs)
{
    
    defaultProjectRoot = Config.GetValue("project", "project_root", "~/projects/dprojects".expandTilde());
	string	cmdLineBuild;
	
	auto optResults = getopt(cmdLineArgs,std.getopt.config.passThrough, "project|p", &startUpProject, "build|b", &cmdLineBuild);
	
	if(cmdLineBuild.length)
	{
		mProject = new PROJECT(cmdLineBuild);
		mProject.Build();
		
		import core.runtime;
		import core.stdc.stdlib;
        Runtime.terminate();
        exit(0);
    }
	
	mProject = new PROJECT;
   
	
	Log.Entry("Engaged");
}
void Mesh()
{
    if(startUpProject.length < 1)startUpProject = Config.GetValue!string("project", "last_session_project");
    if(startUpProject.length) mProject.Load(startUpProject);
	Log.Entry("Meshed");
}
void Disengage()
{
    Project().Save();
    if(Project.Type() != TARGET_TYPE.UNDEFINED)
        Config.SetValue("project", "last_session_project", Project.FullPath);
    else
        Config.SetValue("project", "last_session_project", "");
	Log.Entry("Disengaged");
}

string GetCmdLineOptions()
{
	string rv;
	rv  = "\t-p\t--project=PROJECT\tLoad PROJECT on startup\n";
	rv ~= "\t-b\t--build=PROJECT\t\tBuild PROJECT (\"name::target\") and exit without starting ui.\n";
	return rv;	
}



public:


class PROJECT
{
    private:
    string 		mName;				//just a name helloWorld  probably the file basename
    string      mFileName;			//probably same as mName but could be helloWorld_debug or helloWorld_release
    string      mLocation;			//location relative to "global project" folder 

    COMPILER	mCompiler;
    TARGET_TYPE mType;

    
    LISTS		mTags; 				//any additional info you want. see TAGS enum + anything else
    LISTS		mLists;				//source files,  libraries, paths, pre and post build scripts
    FLAG[string]mFlags;				//compiler flags --> this time just the enabled ones
    string      mDmdVersion;
    
    bool        mUseCustomBuild;
    string      mCustomBuildCommand;
    string      mBuildCommand;
    
    string      mErrorMessage;
    
    BUILD_STATE mLastBuildState;
    
    void LoadFlags()
    {
        string flagtext = readText(Config.GetResource("project","flags","utils","flags.json"));
        auto jFlags = parseJSON(flagtext);
        foreach (flag; jFlags.object)
        {
            if("Version" in flag)
            {
                mDmdVersion = cast(string)flag["Version"];   
                continue;
            }
            FLAG nuFlag;
            nuFlag.mState = false;
            nuFlag.mBrief = (cast(string)flag["brief"]).tr("&", "+");
            nuFlag.mId = cast(string)flag["id"];
            nuFlag.mSwitch = cast(string)flag["flag"];
            nuFlag.mType = cast(FLAG_TYPE)flag["arg_type"].toString;
            mFlags[nuFlag.mId] = nuFlag;            
        }
    }
    void ResetFlags()
    {
        foreach(ref flag; mFlags)
        {
            flag.mState = false;
            flag.mArgument.length = 0;
        }
        
        Transmit.ProjectEvent.emit(this, PROJECT_EVENT.FLAG, "ResetFlags");
    }
    void LoadDefaultTags()
    {
        import std.traits;
        static foreach(string mem; EnumMembers!TAGS)
        {
            mTags[mem] = [""];         
        } 
    }
    void ResetTags()
    {
        mTags.clear();
        LoadDefaultTags();
    }
    
    void UpdateBuildCommand()
    {
        if(mType == TARGET_TYPE.UNDEFINED)
        {
            mBuildCommand = "";
            Transmit.ProjectEvent.emit(this, PROJECT_EVENT.EDIT, mBuildCommand);
            return;
        }
        
        mBuildCommand =  mCompiler ~ ' ';      
    
        //flags
        foreach(flag; mFlags)
        {
            string arg = " ";
            if(!flag.mState)continue;
            if(flag.mType != FLAG_TYPE.SIMPLE) arg = "=" ~ flag.mArgument ~ " ";
            mBuildCommand ~= flag.mSwitch ~ arg;
        }
                
        if(mFlags["of=<filename>"].mState == false)mBuildCommand ~= "-of" ~ mName ~ " ";
        
        foreach(verxian; List(LIST_KEYS.VERSION))
        {
            mBuildCommand ~= "-version=" ~ verxian ~ " ";
        }
        foreach(deebug; List(LIST_KEYS.DEBUG))
        {
            mBuildCommand ~= "-debug=" ~ deebug ~ " ";
        }
        
        foreach(impPath; List(LIST_KEYS.IMPORT_PATHS))
        {
            mBuildCommand ~= "-I" ~ impPath ~ " ";
        }
        foreach(strPath; List(LIST_KEYS.STRING_PATHS))
        {
            mBuildCommand ~= "-J" ~ strPath ~ " ";
        }
        foreach(libPath; List(LIST_KEYS.LIBRARY_PATHS))
        {
            mBuildCommand ~= "-L-L" ~ libPath ~ " ";
        }
        foreach(lib;List(LIST_KEYS.LIBRARIES))
        {
            mBuildCommand ~= "-L-l"~ lib ~ " ";
        }
        
        //sourcefiles
        foreach(srcFile; List(LIST_KEYS.SOURCE))
        {
            mBuildCommand ~= srcFile ~ " ";
        }
        
        foreach(sundry; List(LIST_KEYS.SUNDRY))
        {
            mBuildCommand ~= sundry ~ " ";
        }
        Transmit.ProjectEvent.emit(this, PROJECT_EVENT.EDIT, mBuildCommand);
    }
    
    void tmpMsgReceiver(string format, string msg)
    {
        if(format != "dmd")return;
        if(msg == "begin")
        {
            return;
        }
        if(msg == "end")
        {
            return;
        }
    }

public:
    this()
    {
        mDmdVersion = "unknown (ldmd or gdmd?)";
        mName = "";
        mLocation = "";
        LoadFlags();
        LoadDefaultTags();
        mFlags["vcolumns"].mState = true;
        Transmit.ProjectEvent.emit(this, PROJECT_EVENT.CREATED, "constructor");
        //temp for testing
        Transmit.Message.connect(&tmpMsgReceiver);
    }
    
    this(string cmdLineProject)
    {
        this();
        Load(cmdLineProject);
    }
    
    void Load(string projectFile)
    {
        string jsonProjString;

        try
        {
            jsonProjString = readText(projectFile);
        }
        catch(FileException fe)
        {
            Log.Entry(fe.msg, "Error");
            Transmit.ProjectEvent.emit(this, PROJECT_EVENT.ERROR, fe.msg);
            return;
        }
		
		auto projson = parseJSON(jsonProjString);
		
		mName 		= cast(string)projson["name"];
		mFileName 	= cast(string)projson["file_name"];
		Location 	= cast(string)projson["location"];
		mCompiler 	= cast(COMPILER)projson["compiler"].toString;
		mType 		= cast(TARGET_TYPE)projson["type"];		
		ResetTags();
		string[] tmpV;
		foreach(string tagKey, tagValue; projson["tags"])
		{
    		tmpV.length = 0;
			foreach(value; tagValue)
			{
    		    tmpV ~= value.toString();
			}
			mTags[tagKey] = tmpV;
        }
        
        mLists.Zero();
        foreach(string listKey, listValue; projson["lists"])
        {
	        foreach(value;listValue)mLists[listKey] ~= value.toString;
        }
        
        ResetFlags();
        foreach(flagValue; projson["flags"])
        {
            auto fID = flagValue["id"].toString;
            mFlags[fID].mState = true;
            mFlags[fID].mArgument = flagValue["argument"].toString;
        }
        
        mUseCustomBuild = cast(bool)projson["use_custom_build_command"];
        mCustomBuildCommand = cast(string)projson["custom_build_command"];   
        
        mLastBuildState = BUILD_STATE.UNKNOWN;   
		
		chdir(FullPath.dirName);
        Transmit.ProjectEvent.emit(this, PROJECT_EVENT.OPENED,FullPath);
        Log.Entry("Loaded " ~ projectFile);
    }
    
    void Save()
    {
        scope(failure)
        {
            mErrorMessage = "Failed to Save project file : " ~ FullPath;
            Log.Entry(mErrorMessage, "Error");
            Transmit.ProjectEvent.emit(this, PROJECT_EVENT.ERROR, mErrorMessage);
            return;
        }
        if(mType == TARGET_TYPE.UNDEFINED)return;
	    auto projson = jsonObject();
	    
	    projson["name"] = mName;
	    projson["file_name"] = mFileName;
	    projson["location"] = mLocation;
	    projson["compiler"] = mCompiler;
	    projson["type"] = mType;
	    
	    projson["tags"] = jsonObject;
	    foreach(string tagkey, tagValue; mTags)
	    {
		    projson["tags"][tagkey] = jsonArray;
		    foreach(item; tagValue)
		    {
		        if(item.length == 0)continue;
		        projson["tags"][tagkey] ~= item;
            }
		}
		projson["lists"] = jsonObject;
		foreach(string listKey, listValue; mLists)
		{
			projson["lists"][listKey] = jsonArray;
			foreach(item; listValue)projson["lists"][listKey] ~= item;
		}
		
		projson["flags"] = jsonArray;
		foreach(flag; mFlags)
		{
    		if(!flag.mState)continue;
    		auto thisFlag = jsonObject;
    		thisFlag["id"] = flag.mId;
    		thisFlag["state"] = true;
    		thisFlag["argument"] = flag.mArgument;
    		projson["flags"] ~= thisFlag;
        }	
        
        projson["use_custom_build_command"] = mUseCustomBuild;
        projson["custom_build_command"] = mCustomBuildCommand;
	    
	    
	    std.file.write(FullPath, projson.toJSON!5);
        Transmit.ProjectEvent.emit(this, PROJECT_EVENT.SAVED, FullPath);
        Log.Entry("Saved " ~ mLocation);
    }
    
    void Build()
    {
	    
        bool buildStatus;
        scope(exit)Transmit.ProjectEvent.emit(this, PROJECT_EVENT.BUILD, "");
        import std.process;
        
        if(mType == TARGET_TYPE.UNDEFINED) return;
                
        docman.SaveAll();
        Save();
      
        //prescripts
        foreach(pscript; List(LIST_KEYS.PRE_SCRIPTS))
        {
            scope(failure)
            {
                Log.Entry(pscript ~ " caused failed on exception", "Error");
                continue;
            }
            auto rslt = execute(pscript, null, Config.detached);
            Log.Entry(pscript ~ "exited with return value" ~ rslt.output);
        }
        
        if(mUseCustomBuild)
        {
            auto result = execute(mCustomBuildCommand);
            result.output.splitLines.each!((n){Transmit.Message.emit("custom", n);});
            if(result.status == 0) mLastBuildState = BUILD_STATE.SUCCEEDED;
            else mLastBuildState = BUILD_STATE.FAILED;
        }
        else
        {
            UpdateBuildCommand();
            auto result = executeShell(mBuildCommand);
            
            Transmit.Message.emit(mCompiler, "begin");
            foreach(line; result.output.lineSplitter())
            {
                Transmit.Message.emit(mCompiler, line);
            }
            Transmit.Message.emit(mCompiler, "end "~result.status.to!string);
            if(result.status == 0) mLastBuildState = BUILD_STATE.SUCCEEDED;
            else mLastBuildState = BUILD_STATE.FAILED;
        }
              
        
        //postscripts
        foreach(pscript; List(LIST_KEYS.POST_SCRIPTS))
        {
            scope(failure)
            {
                Log.Entry(pscript ~ " caused failed on exception", "Error");
                continue;
            }
            auto rslt = execute(pscript, null, Config.detached);
            Log.Entry(pscript ~ "exited with return value" ~ rslt.output);
        }
    }
    
    void Run()
    {
        if(mType != TARGET_TYPE.APP) return;
        string exeName = "./" ~mName;
        if(mFlags["of=<filename>"].mState)exeName = "./" ~ mFlags["of=<filename>"].mArgument; 
        
        
        auto TerminalCommand = Config.GetArray!string("project","terminal command", ["xterm", "-T","dcomposer running project","-e"]);
    
        auto tFile = File(ProjRunScript, "w");

        tFile.writeln("#!/bin/bash");
        tFile.write(exeName); 
        tFile.writeln();
        tFile.writeln(`echo -e "\n\nProgram Terminated with exit code $?.\nPress a key to close terminal..."`);
        tFile.writeln(`read -sn1`);
        tFile.flush();
        tFile.close();
        setAttributes(ProjRunScript, 509);

        string[] CmdStrings;
        CmdStrings = TerminalCommand;
        CmdStrings ~= ["./"~ProjRunScript];

        try
        {
            auto x = spawnProcess(CmdStrings,stdin, stdout, stderr,null, pConfig.detached, null);
            Log.Entry(`"` ~ Name ~ `"` ~ " spawned ... " );
        }
        catch(Exception E)
        {
            Log.Entry(E.msg);
            return;
        }
    
    }
    
    void Close()
    {  
        mName =  "";
        mFileName = "";
        mLocation = ".";
        mCompiler = COMPILER.DMD;
        mType = TARGET_TYPE.UNDEFINED;
        ResetTags();
        mLists.Zero();        
        ResetFlags();
        mUseCustomBuild = false;
        mCustomBuildCommand = "";
        chdir(Config.GetValue!string("config","initialDir",getcwd()));
        Transmit.ProjectEvent.emit(this, PROJECT_EVENT.CLOSED, "");
        
    }
    
    void Name(string nuName)
    {
        if(!nuName.isValidFilename()) return;
        mName = nuName;
        Transmit.ProjectEvent.emit(this, PROJECT_EVENT.NAME, mName);
        if((mLocation == "./") || (mLocation == ".") || (mLocation == "") || (mLocation == mName))
            Location = "./" ~ nuName;
        FileName = mName.setExtension(".dpro");
    }
    string Name()
    {
        return mName;
    }    
    void FileName(string nuFileName)
    {
        if(!nuFileName.isValidFilename())return;
        mFileName = nuFileName.idup;
        Transmit.ProjectEvent.emit(this, PROJECT_EVENT.FILE_NAME, mFileName);
    }
    string FileName()
    {
        return mFileName;
    }
    void Location(string nuLocation)
    {
        if(!nuLocation.isValidPath())return;
        mLocation = nuLocation;
        mkdirRecurse(buildNormalizedPath(defaultProjectRoot, Location));
        chdir(buildPath(defaultProjectRoot, mLocation));
        Transmit.ProjectEvent.emit(this, PROJECT_EVENT.LOCATION, mLocation);        
    }
    string Location()
    {
	    return mLocation;
	}
	
	string FullPath()
	{
    	return buildNormalizedPath(defaultProjectRoot, mLocation, mFileName);
    }
	void Compiler(COMPILER nuCompiler)
	{
		mCompiler = nuCompiler;
        Transmit.ProjectEvent.emit(this,PROJECT_EVENT.COMPILER, mCompiler);
    }
    COMPILER Compiler()
    {
	    return mCompiler;
    }  
    void SetCustomBuildCommand(string theCustomCommand)
    {
        mCustomBuildCommand = theCustomCommand;
        Transmit.ProjectEvent.emit(this, PROJECT_EVENT.CUSTOM_BUILD_COMMAND, mCustomBuildCommand);
    }
    string GetCustomCommand()
    {
        return mCustomBuildCommand;
    }
    void UseCustomCommand(bool yayNay)
    {
        mUseCustomBuild = yayNay;
        Transmit.ProjectEvent.emit(this, PROJECT_EVENT.USE_CUSTOM_BUILD, mUseCustomBuild.to!string);
    }
    bool UseCustomCommand()
    {
        return mUseCustomBuild;
    }
    
    string GetBuildCommand()
    {
        UpdateBuildCommand();
        return tr(mBuildCommand, " ", "\n");
    }
    void Type(TARGET_TYPE nuType)
    {
	    mType = nuType;
	    switch(mType)with(TARGET_TYPE)
	    {
    	    case SHARED_LIB:
    	        mFlags["shared"].mState = true;
    	        break;
    	    case STATIC_LIB:
    	        mFlags["lib"].mState = true;
    	        break;
    	    case OBJECT:
    	        mFlags["c"].mState = true;
    	        break;
    	    case DOCUMENTATION:
    	        mFlags["D"].mState = true;
    	        mFlags["o-"].mState = true;
    	        break;
    	    case HEADERS:
    	        mFlags["o-"].mState = true;
    	        mFlags["H"].mState = true;
    	        break;
    	    default:
    	    
    	    
    	}
	    Transmit.ProjectEvent.emit(this, PROJECT_EVENT.TARGET_TYPE, mType.to!string);
    }
    TARGET_TYPE Type()
    {
	    return mType;
    }
    void SetFlag(string id, bool state , string arg = "")
    {
        mFlags[id].mState= state;
        mFlags[id].mArgument = arg;
        Transmit.ProjectEvent.emit(this, PROJECT_EVENT.FLAG, id);
        
    }
    auto GetFlags()
    {
        return mFlags.byValue;
    }
    bool GetFlag(string id, out string arg)
    {

        arg = mFlags[id].mArgument;
        return mFlags[id].mState;
    }
    auto GetFlagIds()
    {
        return mFlags.byKey();
    }
    
    string GetDmdFlagsVersion()
    {
        return mDmdVersion;
    }
    void SetTag(string key, string[] value)
    {
        
        mTags.mLists.remove(key);
        mTags.mLists[key] = value;        
        Transmit.ProjectEvent.emit(this, PROJECT_EVENT.TAGS, key);
    }
    string[] GetTag(string key)
    {
        return mTags[key];
    }
    void TagAppend(string key, string value)
    {
        mTags[key] ~= value;
        Transmit.ProjectEvent.emit(this, PROJECT_EVENT.TAGS, key);
    }
    void TagAppend(string key, string[] value)
    {
        mTags[key] ~= value;
        Transmit.ProjectEvent.emit(this, PROJECT_EVENT.TAGS, key);
    }
    string[] TagKeys() 
    {
        return mTags.keys;
    }
    void TagRemove(string key)
    {
        mTags.Remove(key);
        Transmit.ProjectEvent.emit(this, PROJECT_EVENT.TAGS, key);
    }
    
    string[] List(string key)
    {
        return mLists[key];
    }
    
    void ListSet(string key, string[] nuList)
    {
        mLists[key] = nuList;
    }
    void ListAppend(string key, string value)
    {
        mLists[key] ~= value;
        Transmit.ProjectEvent.emit(this, PROJECT_EVENT.LISTS, key);
    }
    void ListAppend(string key, string[] value)
    {
        mLists[key] ~= value;
        Transmit.ProjectEvent.emit(this, PROJECT_EVENT.LISTS, key);
    }
    
    BUILD_STATE GetLastBuildState()
    {
        return mLastBuildState;
    }
    
    
}

alias string[] LIST;
struct LISTS
{
    LIST[string] mLists;
    alias mLists this;

    void RemoveData(string Key, size_t index)
    {
        mLists[Key] = mLists[Key][0..index] ~ mLists[Key][index + 1 .. $];
    }
    void RemoveData(string Key, string data)
    {
        foreach(index, item; mLists[Key])
        {
            if(item == data)
            {
                 RemoveData(Key, index);
                 break;
            }
        }
    }

    void Remove(string Key)
    {
         mLists.remove(Key);
    }

    void Zero()
    {
        foreach(ref item; mLists)item.length = 0;
    }

    ref string[] opIndex(string key)
    {
        string[] rv;
        if (key !in mLists) mLists[key] = rv;
        return mLists[key];
    }
    ref string[] opIndexAssign(string[] Value, string key)
    {
        mLists[key] = Value;
        return mLists[key];
    }
    ref string[] opIndexAssign(string Value, string key)
    {
        mLists[key] = [Value];
        return mLists[key];
    }
    /*ref string[] opIndexOpAssign(string)(string[] Values, string key)
    {
        mList[key] ~= Values;
        return mList[key];
    }*/
}


struct FLAG
{
	string 		mId;		
	string 		mSwitch;
	string      mBrief;
	FLAG_TYPE	mType;
	string		mArgument;
	bool 		mState;
}
enum TAGS :string
{
	AUTHOR 			= "Author",
	COPYRIGHT		= "Copy Right",
	NOTES 			= "Notes",
	EMAIL			= "Email",
	WEBSITE			= "Website",
	LICENSE			= "License",
	CREDIT			= "Credit",
		
}

enum PROJECT_EVENT
{
	CREATED,
    OPENED,
    SAVED,
    EDIT,
    NAME,
    FILE_NAME,
    LOCATION,
    COMPILER,
    TARGET_TYPE,
    USE_CUSTOM_BUILD,
    CUSTOM_BUILD_COMMAND,
    FLAG,
    LISTS,
    ERROR,
    TAGS,
    CLOSED,
    BUILD,
}

enum COMPILER :string
{
    DMD = "dmd",
    LDC = "ldmd",
    GDC = "gdmd",
}

enum TARGET_TYPE
{
	UNDEFINED,          //no project.. dont build,run,save ...
	APP,
	SHARED_LIB,
	STATIC_LIB,
	OBJECT,
	DOCUMENTATION,
	HEADERS,
	OTHER,
}

enum FLAG_TYPE :string
{
	SIMPLE = "SIMPLE",
	NUMBER = "NUMBER",
	STRING = "STRING",
	CHOICE = "CHOICE",
}

enum LIST_KEYS : string
{
    SOURCE = "Source Files",
    RELATED = "Related Files",
    VERSION = "Versions",
    DEBUG = "Debugs",
    IMPORT_PATHS = "Import Paths",
    STRING_PATHS = "String Import Paths",
    LIBRARY_PATHS = "Library Paths",
    LIBRARIES = "Libraries",
    PRE_SCRIPTS = "Prescript Files",
    POST_SCRIPTS = "Postscript Files",
    SUNDRY = "Sundry",
}

enum BUILD_STATE
{
    UNKNOWN,
    FAILED,
    SUCCEEDED,
}

