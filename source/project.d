module project;

import std.getopt;
import std.signals;
import std.file;
import std.path;


import qore;
import json;


string defaultProjectRoot;
enum PROJECT_MODULE_VERSION = "B";

PROJECT mProject;

string 	startUpProject;



PROJECT Project(){return mProject;}

void Engage(ref string[] cmdLineArgs)
{
    
    defaultProjectRoot = Config.GetValue("project", "project_root", "~/projects/dprojects".expandTilde());
	string	cmdLineBuild;
	
	auto optResults = getopt(cmdLineArgs,std.getopt.config.passThrough, "project|p", &startUpProject, "build|b", &cmdLineBuild);
	
	if(cmdLineBuild.length)
	{
		dwrite(">>> ",cmdLineBuild);
		//mProject = new PROJECT(cmdLineBuild);
		//mProject.Build();
		dwrite("how do you exit a d program??");
		
		import core.runtime;
		import core.stdc.stdlib;
        Runtime.terminate();
        exit(0);
    }
    
    if(startUpProject.length < 1)startUpProject = Config.GetValue!string("project", "last_session_project");
	
	mProject = new PROJECT;
    if(startUpProject.length) mProject.Load(startUpProject);
	
	Log.Entry("Engaged");
}
void Mesh()
{
	Log.Entry("Meshed");
}
void Disengage()
{
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
    string 		mFullPath;			//global folder + location + filename
    
    COMPILER	mCompiler;
    TARGET_TYPE mType;
    
    
    
    LISTS		mTags; 				//any additional info you want. see TAGS enum + anything else
    LISTS		mLists;				//source files,  libraries, paths, pre and post build scripts
    FLAG[string]mFlags;				//compiler flags --> this time just the enabled ones
    
    bool        mUseCustomBuild;
    string      mCustomBuildCommand;
    string      mBuildCommand;
    
    void LoadFlags()
    {
        string flagtext = readText(Config.GetResource("project","flags","utils","flags.json"));
        auto jFlags = parseJSON(flagtext);
        foreach (flag; jFlags.object)
        {
            
            FLAG nuFlag;
            nuFlag.mBrief = cast(string)flag["brief"];
            nuFlag.mId = cast(string)flag["id"];
            nuFlag.mSwitch = cast(string)flag["id"];
            nuFlag.mType = cast(FLAG_TYPE)flag["arg_type"].toString;
            mFlags[nuFlag.mId] = nuFlag;            
        }
    }
    void LoadDefaultTags()
    {
        import std.traits;
        static foreach(string mem; EnumMembers!TAGS)
        {
            mTags[mem] = [""];
        } 
        dwrite(mTags);
    }

public:
    this()
    {
        LoadFlags();
        LoadDefaultTags();
        Transmit.ProjectEvent.emit(this, PROJECT_EVENT.CREATED);
        dwrite(mCompiler);
        dwrite(mType);
    }
    
    void Load(string projectFile)
    {
        string jsonProjString = readText(projectFile);
        Log.Entry(jsonProjString);
        Transmit.ProjectEvent.emit(this, PROJECT_EVENT.OPENED);
        Log.Entry("Loaded " ~ projectFile);
    }
    
    void Save()
    {
        Transmit.ProjectEvent.emit(this, PROJECT_EVENT.SAVED);
        Log.Entry("Saved " ~ mLocation);
    }
    
    void Build()
    {
    }
    
    void Run()
    {
    }
    
    void Close()
    {     
    }
    
    void Name(string nuName)
    {
    }
    string Name()
    {
        return mName;
    }    
    void FileName(string nuFileName)
    {
    }
    string FileName()
    {
        return mFileName;
    }
    void Location(string nuLocation)
    {
    }
    string Location()
    {
	    return mLocation;
	}
	void Compiler(COMPILER nuCompiler)
	{
		mCompiler = nuCompiler;
    }
    COMPILER Compiler()
    {
	    return mCompiler;
    }  
    void SetCustomBuildCommand(string theCustomCommand)
    {
        mCustomBuildCommand = theCustomCommand;
    }
    string GetCustomCommand()
    {
        return mCustomBuildCommand;
    }
    void UseCustomCommand(bool yayNay)
    {
        mUseCustomBuild = yayNay;
    }
    bool UseCustomCommand()
    {
        return mUseCustomBuild;
    }
    void Type(TARGET_TYPE nuType)
    {
	    mType = nuType;
    }
    TARGET_TYPE Type()
    {
	    return mType;
    }
    void SetFlag(string id, bool state , string arg = "")
    {
        mFlags[id].mState= state;
        mFlags[id].mArgument = arg;
    }
    bool GetFlag(string id, out string arg)
    {
        arg = mFlags[id].mArgument;
        return mFlags[id].mState;
    }
    void SetTag(string key, string value)
    {
        mTags[key] = value;        
    }
    string[] GetTag(string key)
    {
        return mTags[key];
    }
    void AppendTag(string key, string value)
    {
        mTags[key] ~= value;
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
enum TAGS
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
    FOLDER,
    COMPILER,
    TARGET_TYPE,
    USE_CUSTOM_BUILD,
    CUSTOM_BUILD_COMMAND,
    FLAG,
    LISTS,
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
	BIN,
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
	SIMPLE = "SIMPE",
	NUMBER = "NUMBER",
	STRING = "STRING",
	CHOICE = "CHOICE",
	NOTHING = "NOTHING",
}


