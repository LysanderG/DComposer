module project;

import std.getopt;
import std.signals;


import qore;

private:

string defaultProjectRoot;
enum PROJECT_MODULE_VERSION = "B";

PROJECT mProject;


public:
void Engage(ref string[] cmdLineArgs)
{
	string 	cmdLineProject;
	string	cmdLineBuild;
	
	auto optResults = getopt(cmdLineArgs,std.getopt.config.passThrough, "project|p", &cmdLineProject, "build|b", &cmdLineBuild);
	
	if(cmdLineBuild.length)
	{
		dwrite(">>> ",cmdLineBuild);
		//mProject = new PROJECT(cmdLineBuild);
		//mProject.Build();
		CoreSkipUI();
		dwrite("how do you exit a d program??");
    }
	
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
	TARGET[]        mTargets;
	ulong		    mSelectedTarget;
	
	string[string] 	mTags;
	
	LISTS           mList;			    //almost everything
	FLAG[]          mFlags;
	
	bool            mUseCustomBuild;
	string          mCustomBuildCommand;
	
public:
	
	
	
	
}


struct TARGET
{
	string 		mId;
	string		mNotes;}

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
    bool mState;
    bool mArgument;
    string mBrief;
    string mSwitch;
    string mValue;

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
