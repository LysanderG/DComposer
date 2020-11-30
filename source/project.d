module project;

import std.getopt;
import std.signals;


import qore;

private:

string defaultProjectRoot;
enum PROJECT_MODULE_VERSION = "B";

PROJECT mProject;

string 	startUpProject;

public:
void Engage(ref string[] cmdLineArgs)
{

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
	
	string 		    mName;				//basename with extension
	string		    mLocation;			//related to general projects directory option
	TARGET          mGlobalTarget;     
	TARGET[]        mTargets;
	ulong		    mSelectedTarget;
	
	string[string] 	mTags;
	
	LISTS           mList;			    //almost everything
	FLAG[]          mFlags;
	
	
public:

    this()
    {
        mLocation = "/dev/null";
    }
    
    void Load(string projectFile)
    {
    }
    
    void Close()
    {
    }
    void Save()
    {
    }
    void Build(ulong TargetIndex = ulong.max)
    {
    }
    void Run(string[] arguments)
    {
    }
    void SelectTarget(ulong selectionIndex)
    {
    }	
}

class TARGET
{
    private:
    PROJECT     mOwner;
    
    TARGET_TYPE mType;
    FLAG[]      mFlags;
    LISTS       mTargetLists;
    
    bool        mUseCustomBuild;
    string      mCustomBuildCommand;
    COMPILER    mCompiler;
    
    string[] GetBuildCommand(in TARGET parent)
    {
        string[] rv;
        if(mUseCustomBuild)return [mCustomBuildCommand];
        
        rv ~= mCompiler;
        
        
        return rv;
    }
    string GetRunCommand()
    {
        string rv;
        return rv;
    }
    
    
}
enum TARGET_TYPE
{
	UNDEFINED,
	BIN,
	APP,
	SHARED_LIB,
	STATIC_LIB,
	OBJECT,
	DOCUMENTATION,
	HEADERS,
	OTHER,
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
    bool        mState;         //used or not
    ARG_TYPE    mArgType;       //bool(true used false not used),number, string, str_array, choice_index
    string      mArgValue;      //string representation of value "123", "blah, blah", "filex" 
    string[]    mChoices;
    

    this(string Switch, string Brief, bool HasArg, string Arg = "\0")
    {
        mState = false;
        mSwitch = Switch;
        mBrief = Brief;
        mArgument = HasArg;
        mValue = Arg;
    }

    void Reset()
    {
        mState = false;
        mValue = "";
    }
    void Set(string nuValue = "")
    {
        mState = true;
        if(HasArg && (nuValue.length) mValue = value;
    }
    bool opCast(bool T)(){return mState;}

}


enum TAGS
{
	AUTHOR 			= "Authors",
	COPYRIGHT		= "Copy right",
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
