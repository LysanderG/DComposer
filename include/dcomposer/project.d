/** more testting stuff */
module project;


import std.file;
import std.path;
import std.process : Pid, spawnProcess, executeShell, execute, wait, kill;
import std.signals;
import std.string;
import std.path;
import std.algorithm;
import std.traits;
import std.stdio;
import std.conv;

import json;

import dcore;
import ui;

enum PROJECT_MODULE_VERSION = "A";  //see notes a bottom of this module

/** Testing comment <added> documentation */
class PROJECT
{
    private :

    string      mDcomposerProjectVersion;
    string      mName;
    string      mFolder;
    COMPILER    mCompiler;
    TARGET      mTargetType = TARGET.EMPTY;

    bool        mUseCustomBuild;
    string      mCustomBuildCommand;

    FLAG[]      mFlags;
    string      mFlagsVersion;
    LISTS       mData;

    string      mStartUpProject;

    string      mDefaultProjectRootPath;

    Pid[]       mRunPids;

    void Clear()
    {
        mDcomposerProjectVersion = PROJECT_MODULE_VERSION;
        SetNameAndFolder("", mDefaultProjectRootPath);
        Compiler = COMPILER.DMD;
        TargetType = TARGET.EMPTY;
        UseCustomBuild = false;
        CustomBuildCommand = "";
        foreach(ref flag; mFlags) flag.Reset();
        mData.Zero();
        Event.emit(PROJECT_EVENT.LISTS);
        Log.Entry("Reset");
    }

    void LoadFlags()
    {
        string ffile = FlagsPath( Config.GetValue("project", "flag_file", "flags.json"));
        string ftext = readText(ffile);
        auto jflags = parseJSON(ftext);
        mFlagsVersion = cast(string)jflags["dmdversion"];
        mFlags.length = 0;
        foreach(obj; jflags["flags"])
        {
            FLAG tmp;
            tmp.mState = false;
            tmp.mArgument = cast(bool)obj["hasargument"];
            tmp.mBrief = cast(string)obj["brief"];
            tmp.mSwitch = cast(string)obj["cmdstring"];
            tmp.mValue = "\0";
            mFlags ~= tmp;
        }

    }

    public :

    string[] BuildCommand()
    {

        if(mUseCustomBuild) return [mCustomBuildCommand];

        with (LIST_NAMES)
        {
            string[] buildCMD;

            buildCMD ~= strip(cast(string)Compiler);

            foreach(flag; mFlags)
            {
                if(flag.mState)
                {
                    //buildCMD ~= flag.mSwitch;
                    if(flag.mArgument) buildCMD ~= (flag.mSwitch~flag.mValue);
                    else buildCMD ~= flag.mSwitch;
                }
            }
            if(!GetFlag("-of", "name output file to filename")) buildCMD ~= ("-of" ~ mName);
            foreach(item; mData[VERSIONS])
            {
                buildCMD ~= ["-version=" ~ item];
            }
            foreach(item; mData[DEBUGS])
            {
                buildCMD ~= ("-debug=" ~ item);
            }
            foreach(item; mData[IMPORT])
            {
                buildCMD ~= ("-I" ~ item);
            }
            foreach(item; mData[STRING])
            {
                buildCMD ~= ("-J" ~ item);
            }
            foreach(item; mData[LIBRARY_PATHS])
            {
                buildCMD ~= ("-L-L" ~ item);
            }
            foreach(item; mData[LIBRARIES])
            {
                if(item == "\0")continue;
                if(item.length < 1)continue;
                buildCMD ~= ("-L-l" ~ LibName(item));
            }
            foreach(item; mData[OTHER])
            {
               buildCMD ~= item;
            }
            foreach(item; mData[SRC_FILES])
            {
                buildCMD ~= item;
            }
            return buildCMD;
        }
    }


    mixin Signal!(PROJECT_EVENT)Event;
    mixin Signal!(string)       RunOutput;
    mixin Signal!(string)       BuildOutput;

    /**
    More Tests
    hurray
    */
    void Engage()
    {
        Clear();
        mStartUpProject = "";
        mDefaultProjectRootPath = Config.GetValue("project","project_root_path", "~/projects/dprojects/").expandTilde();
        string tmp1 = Config.GetValue!string("project", "last_session_project");
        string tmp2 = Config.GetValue!string("project", "cmd_line_project");
        if(tmp1.length > 0) mStartUpProject = tmp1;
        if(tmp2.length > 0) mStartUpProject = tmp2;
        LoadFlags();
        foreach(member; __traits(allMembers, LIST_NAMES)) mData[mixin("LIST_NAMES."~member)] = ["\0"];
        Log.Entry("Engaged");
    }
    void PostEngage()
    {
        if(mStartUpProject.length > 0) Open(mStartUpProject);
        Log.Entry("PostEngaged");
    }
    void Disengage()
    {
        Save();
        Config.Remove("project", "cmd_line_project");
        Config.Remove("project", "last_session_project");
        if(mName.length > 0) Config.SetValue("project", "last_session_project", buildNormalizedPath(mFolder,mName.setExtension(".dpro")));
        foreach(pid; mRunPids)kill(pid);
        foreach(pid; mRunPids)wait(pid);
        Log.Entry("Disengaged");
    }

    void Create()
    {
        Save();
        Clear();
        Name = "new_project";
        Folder = DefaultProjectRootPath;
        TargetType = TARGET.UNDEFINED;
        Event.emit(PROJECT_EVENT.CREATED);
        Log.Entry("Created");
    }
    void Close()
    {
        Save();
        Clear();
        Event.emit(PROJECT_EVENT.NAME);
        Event.emit(PROJECT_EVENT.FOLDER);
        Log.Entry("Closed");
    }

    void Open(string projfile = null)
    {
        Save();
        Clear();
        scope(failure)
        {
            ui.ShowMessage("Project Error", "Failed to open " ~ projfile);
            return;
        }
        auto jsontext = readText(projfile);

        auto jdata = parseJSON(jsontext);

        if("DcomposerProjectVersion" !in jdata)
        {
            ui.ShowMessage("Project Error", "Not a DComposer project file!", "Sorry");
            return;
        }
        mDcomposerProjectVersion = cast(string)jdata["DcomposerProjectVersion"];
        if(!PROJECT_MODULE_VERSION.startsWith(mDcomposerProjectVersion))
        {
            ui.ShowMessage("Project Error", "Wrong Project Version!", "Sorry");
            return;
        }
        Name = cast(string)jdata["Name"];
        Folder = cast(string)jdata["Folder"];
        CurrentPath(Folder);
        Compiler = cast(COMPILER)cast(string)jdata["Compiler"];
        TargetType = cast(TARGET)cast(int)jdata["TargetType"];
        UseCustomBuild = cast(bool)jdata["UseCustomBuild"];
        CustomBuildCommand = cast(string)jdata["CustomBuildCommand"];
        mFlagsVersion = cast(string)jdata["FlagsVersion"];
        foreach(obj; jdata["Flags"])
        {
            string Switch = cast(string)obj["Switch"];
            string Brief = cast(string)obj["Brief"];
            SetFlag(Switch, Brief, cast(bool)obj["State"]);
            if(obj["Argument"])SetFlagArgument(Switch, Brief, cast(string)obj["Value"]);
        }
        foreach(string key, obj; jdata["lists"])
        {
            string[] rv;

            foreach(item; obj) rv ~= cast(string)item;
            SetListData(key, rv);
        }

        Event.emit(PROJECT_EVENT.OPENED);
        Log.Entry("Opened " ~ Name);
    }

    void Save()
    {
        if(mName.length < 1)
        {
            Log.Entry ("Failed to save unnamed project.");
            return;
        }

        string projfile = buildPath(mFolder, mName.setExtension(".dpro"));
        scope(failure)
        {
            ui.ShowMessage("Failed Project Save", "Unable to save project to " ~ projfile);
            Log.Entry("Failed to save " ~ projfile);
            return;
        }

        if(!mFolder.isValidPath())
        {
            ui.ShowMessage("Bad Path", mFolder ~ "is not a valid path");
            return;
        }
        if(!mFolder.exists())mkdirRecurse(mFolder);
        CurrentPath(Folder);

        auto data = jsonObject();

        data["DcomposerProjectVersion"] = mDcomposerProjectVersion;
        data["Name"] = mName;
        data["Folder"] = mFolder;
        data["Compiler"] = mCompiler;
        data["TargetType"] = mTargetType;
        data["UseCustomBuild"] = mUseCustomBuild;
        data["CustomBuildCommand"] = mCustomBuildCommand;

        data["FlagsVersion"] = mFlagsVersion;
        data["Flags"] = jsonArray();
        foreach(flag; mFlags)
        {
            auto jflag = jsonObject();
            jflag["State"] = flag.mState;
            jflag["Switch"] = flag.mSwitch;
            jflag["Brief"] = flag.mBrief;
            jflag["Argument"] = flag.mArgument;
            jflag["Value"] = flag.mValue;
            data["Flags"] ~= jflag;
        }

        data["lists"] = jsonObject();

        foreach(key, list; mData)
        {
            data["lists"][key] = jsonArray();
            foreach(item; list)
            {
                data["lists"][key] ~= item;
            }
        }
        std.file.write(projfile,data.toJSON!(5));
        Event.emit(PROJECT_EVENT.SAVED);
        Log.Entry("Saved " ~ Name);
    }

    void Edit()
    {
        Event.emit(PROJECT_EVENT.EDIT);
    }

    void Build()
    {

        if(TargetType == TARGET.EMPTY) 
        {
            ui.ShowMessage("Project Build", "No project to build", "OK");
            return;
        }
        DocMan.SaveAll();
        Save();

        foreach(script; mData[LIST_NAMES.PREBUILD])
        {
            scope(failure)
            {
                Log.Entry("Error "~script);
                continue;
            }
            Log.Entry("Running pre-build script " ~ script);
            auto prerv = executeShell(script);
            Log.Entry("\t" ~ script ~ " exited with a return value of :" ~ to!string(prerv.status));
        }


        BuildOutput.emit("BEGIN");
        
        scope(failure)
        {
            BuildOutput.emit("END");
            Log.Entry("DComposer error, Build failed", "Error");
            return;
        }

        //auto rv = executeShell(BuildCommand());
        auto rv = execute(BuildCommand());
        foreach(line; rv.output.splitLines)BuildOutput.emit(line);
        if(rv.status == 0) BuildOutput.emit("Success");
        if(rv.status)Log.Entry(format("Build failed with status %s", rv.status));

        BuildOutput.emit("END");

        //remove later
        
        Log.Entry("Build finished");

        foreach(script; mData[LIST_NAMES.POSTBUILD])
        {
            scope(failure)
            {
                Log.Entry("Error "~script);
                continue;
            }
            Log.Entry("Running post-build script " ~ script);
            auto postrv = executeShell(script);
            Log.Entry("\t" ~ script ~ " exited with a return value of :" ~ to!string(postrv.status));
        }
    }

    //try run with a script
    void Run(string[] args = null)
    {
        import std.stdio;
        enum tmpfilename = "tmp_run_script";
        scope(failure)
        {

            if( tmpfilename.exists())std.file.remove(tmpfilename);
            ShowMessage("Error", "Failed to run " ~ mName);
            Log.Entry("Failed to run " ~ mName);
        }
        if(TargetType == TARGET.EMPTY) ui.ShowMessage("Project Run", "No project to run.\nTo run single source file try Document->Run", "OK");
        if(TargetType != TARGET.APPLICATION) 
        {
            Log.Entry("Failed to run " ~ mName ~ ", project is not an application");
            return;
        }

        CurrentPath(Folder);

        string ExecName = (GetFlag("-of", "name output file to filename")) ? GetFlagArgument("-of", "name output file to filename") : mName;

        auto TerminalCommand = Config.GetArray!string("terminal_cmd","run", ["xterm", "-T","dcomposer running project","-e"]);

        auto tFile = File(tmpfilename, "w");

        tFile.writeln("#!/bin/bash");
        tFile.write("./", ExecName,);
        foreach(arg; args)tFile.write(" ",arg);
        tFile.writeln();
        tFile.writeln(`echo -e "\n\nProgram Terminated.\nPress a key to close terminal..."`);
        tFile.writeln(`read -sn1`);
        tFile.flush();
        tFile.close();
        setAttributes(tmpfilename, 509);


        string[] CmdStrings;

        CmdStrings = TerminalCommand;
        CmdStrings ~= ["./"~tmpfilename];

        try
        {
            mRunPids ~= spawnProcess(CmdStrings);
            Log.Entry(`"` ~ mName ~ `"` ~ " spawned ... " );
        }
        catch(Exception E)
        {
            Log.Entry(E.msg);
            return;
        }



    }


    //==================================================================================================================
    //List
    void DeleteListItem(string Key, int Index)
    {
        mData.RemoveData(Key, Index);
        Event.emit(PROJECT_EVENT.LISTS);
    }
    void DeleteListItem(string Key, string Item)
    {
        mData.RemoveData(Key, Item);
        Event.emit(PROJECT_EVENT.LISTS);
    }
    void AddListItem(string Key, string Item)
    {
        //need serious checks here (should i allow new keys?)
        mData[Key] ~= Item;
        Event.emit(PROJECT_EVENT.LISTS);

    }


    //==================================================================================================================
    //PROPERTIES

    @property void Name(string nuName)
    {
        if(nuName == mName) return;
        mName = nuName;
        Event.emit(PROJECT_EVENT.NAME);
    }
    @property string Name()
    {
        return mName;
    }
    @property void Folder(string nuFolder)
    {
        if(nuFolder == mFolder)return;
        mFolder = nuFolder;
        Event.emit(PROJECT_EVENT.FOLDER);
    }
    //silly function to stop the endless crap
    void SetNameAndFolder(string nuName, string nuFolder )
    {
        mFolder = nuFolder;
        mName = nuName;
    }
    @property string Folder()
    {
        return mFolder;
    }
    @property string DefaultProjectRootPath()
    {
        return mDefaultProjectRootPath;
    }
    @property void Compiler(COMPILER x)
    {
        if(x == mCompiler)return;
        mCompiler = x;
        Event.emit(PROJECT_EVENT.COMPILER);
    }
    @property COMPILER Compiler()
    {
        return mCompiler;
    }
    @property void TargetType(TARGET nuType)
    {
        if(nuType == mTargetType) return;
        mTargetType = nuType;
	switch(nuType)
	{
		case TARGET.SHARED :
			SetFlagArgument("-of", "name output file to filename", "lib" ~ Name ~ ".so");
			SetFlag("-of", "name output file to filename",true);
			SetFlag("-shared", "generate shared library (DLL)", true);
			SetFlag("-lib", "generate library rather than object files", false);
			break;
		case TARGET.APPLICATION :
			SetFlagArgument("-of", "name output file to filename", Name);
			SetFlag("-of", "name output file to filename",true);
			SetFlag("-shared", "generate shared library (DLL)", false);
			SetFlag("-lib", "generate library rather than object files", false);
			break;
		case TARGET.STATIC:
			SetFlagArgument("-of", "name output file to filename", "lib" ~ Name ~ ".a");
			SetFlag("-of", "name output file to filename", true);
			SetFlag("-shared", "generate shared library (DLL)", false);
			SetFlag("-lib", "generate library rather than object files", true);
			break;
		default :break;
	}
			
        Event.emit(PROJECT_EVENT.TARGET_TYPE);
    }
    @property TARGET TargetType()
    {
        return mTargetType;
    }
    @property void UseCustomBuild(bool nuUse)
    {
        if(nuUse == mUseCustomBuild)return;
        mUseCustomBuild = nuUse;
        Event.emit(PROJECT_EVENT.USE_CUSTOM_BUILD);
    }
    @property bool UseCustomBuild()
    {
        return mUseCustomBuild;
    }
    @property void CustomBuildCommand(string nuCommand)
    {
        if(nuCommand == mCustomBuildCommand) return;
        mCustomBuildCommand = nuCommand;
        Event.emit(PROJECT_EVENT.CUSTOM_BUILD_COMMAND);
    }
    @property string CustomBuildCommand()
    {
        return mCustomBuildCommand;
    }

    @property ref LISTS Lists()
    {
        return mData;
    }

    void SetListData(string key, string[] Data)
    {
        if(Data == mData[key])return;
        mData[key] = Data;
        Event.emit(PROJECT_EVENT.LISTS);
    }
    void SetListData(string key, string Data)
    {
        if(mData[key] == [Data])return;
        mData[key] = [Data];
        Event.emit(PROJECT_EVENT.LISTS);
    }


    bool GetFlag(string Switch, string Brief)
    {
        foreach(flag; mFlags)
        {
            if((flag.mSwitch == Switch) && (flag.mBrief == Brief)) return flag.mState;
        }
        return false;
    }
    void SetFlag(string Switch, string Brief, bool nuState)
    {
        foreach(ref flag; mFlags)
        {
            if((flag.mSwitch == Switch) && (flag.mBrief == Brief))
            {
                flag.mState = nuState;
                Event.emit(PROJECT_EVENT.FLAG);
                return;
            }
        }
    }
    string GetFlagArgument(string Switch, string Brief)
    {
        foreach(flag; mFlags)
        {
            if((flag.mSwitch == Switch) && (flag.mBrief == Brief) && (flag.mArgument))
            {
                return flag.mValue;
            }
        }
        return "\0";
    }
    void SetFlagArgument(string Switch, string Brief, string nuArg)
    {
        foreach(ref flag; mFlags)
        {
            if((flag.mSwitch == Switch) && (flag.mBrief == Brief))
            {
                flag.mValue = nuArg;
                Event.emit(PROJECT_EVENT.FLAG);
                return;
            }
        }
    }

    immutable(FLAG[]) Flags(){return mFlags.idup;};

    string getExecutable()
    {
	if(TargetType != TARGET.APPLICATION)return null;
	return GetFlagArgument("-of", "name output file to filename");
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


string LibName(string FullName)
{
    auto rv = FullName.baseName();
    rv = rv.chompPrefix("lib");
    bool extensionsStripped = false;
    do
    {
        auto tmp = rv.stripExtension();
        if(tmp == rv) extensionsStripped = true;
        rv = tmp;
    }while(!extensionsStripped);
    return rv;
}


enum TARGET : int
{
    EMPTY = -1,
    UNDEFINED,
    APPLICATION,
    STATIC,
    SHARED,
    OBJECT,
    DOC,
    SYMBOL,
    OTHER
}

enum COMPILER : string
{
    DMD = "dmd ",
    GDMD = "gdmd ",
    LDMD = "ldmd ",
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
    LISTS
}
enum LIST_NAMES : string
{
    SRC_FILES = "Source Files",
    REL_FILES = "Related Files",
    VERSIONS = "Versions",
    DEBUGS = "Debugs",
    IMPORT = "Import Paths",
    STRING = "String Imports",
    LIBRARIES = "Libraries",
    LIBRARY_PATHS = "Library Paths",
    PREBUILD = "Prebuild Scripts",
    POSTBUILD = "Postbuild Scripts",
    OTHER = "Sundry",
    NOTES = "Notes"
}




//PROJECT VERSIONING
/*
 * 1 VERSION STARTS                 -> "A"
 * 2 none breaking new feature(s)   -> "AA"
 * 3 feature set 2 implemented      -> "AAA"
 * 4 break feature set 2            -> "AAB"
 * 5 add new feature set            -> "AABA"
 * 6 rework whole project           -> "B"
 * 7 new features                   -> "BA"
 * 8 break those last features      -> "BB"
 *
 * version test is
 *
 * if ( DcomposerProjVersion.startsWith(FileProjVersion) ) good to go
 * else fail to load
 *
 * so a project saved as ver "A"    works with 1-5
 * project saved as ver "B"         works with 6-8
 * saved as ver "AAB"               works with 4-5
 *
 * I think this is silly
 *
 */
