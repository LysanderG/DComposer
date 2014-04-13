module config;

import dcore;

import json;

import std.array;
import std.file;
import std.getopt;
import std.path;
import std.process: executeShell;
import std.stdio;
import std.signals;

import std.c.stdlib;
import core.runtime;




/*string DCOMPOSER_VERSION;
string DCOMPOSER_BUILD_DATE;
string DCOMPOSER_COPYRIGHT;

string userDirectory;  //defaults to ~/.config/dcomposer  users config log history whatever changes run to run
string sysDirectory;   //defaults to ~/.local/share/dcomposer  keeps copies of install directory user can change these (plugins syntax highlighting)
string installDirectories; //defaults to /usr/local/share/dcomposer basically defaults for all users on system
*/

bool isDcomposerInstalled;
bool isFirstRun;

string DCOMPOSER_VERSION;
string DCOMPOSER_BUILD_DATE;
string DCOMPOSER_COPYRIGHT;

string userDirectory;
string sysDirectory;
string installDirectories;

string BUILD_USER;
string BUILD_MACHINE;
long BUILD_NUMBER ;

static this()
{
	mixin(import(".build.data"));
}


class CONFIG
{
private:

	string mCfgFile;
	JSON mJson;

	void FirstUserRun()
	{
		//copy system directory folders to local directory
		string src = buildPath(sysDirectory, "*");
		string cpCommand = "cp -r " ~ src ~ " " ~ userDirectory;
		executeShell("mkdir " ~ userDirectory);
		writeln(executeShell(cpCommand));
		FirstRun.emit();
		Log.Entry("Users first run.");
	}


public:
    alias mJson this;
	this()
	{
		//check if installed (as in sudo make install)
		//don't know how well this will work but
		//check xdg data dirs for a dcomposer subdirectory
		//if no xdg_data_dirs checks /usr/local/share /usr/share and /opt for a dcomposer directory
		isDcomposerInstalled = false;
		isFirstRun = false;

		if(sysDirectory != getcwd()) isDcomposerInstalled = true;

		//if installed (system wide) but not run yet by user then setup for user stuff
		//ie a user accessible config file/directory log, styles, what nots
		if(isDcomposerInstalled)
		{
			if(!userDirectory.exists()) isFirstRun = true; //can't call FirstRun yet mJson, log, etc not instantiated

		}
		else
		{
			userDirectory = sysDirectory;
		}

		mCfgFile = buildPath(userDirectory, "dcomposer.cfg");
	}

	void Engage(string[] CmdArgs)
	{
		scope(failure) Log.Entry("Failed", "Error");

		string TmpForLog;   //to use a seperate one off log file
        string project;     //start up with this project
        long Verbosity;     //how much stuff to log
        bool Quiet;         //show log stuff to std out
		bool Help;		    //show a help screen

		CmdArgs.getopt(std.getopt.config.noPassThrough, "c|config", &mCfgFile, "l|log", &TmpForLog, "v|verbosity", &Verbosity, "q|quiet", &Quiet, "p|project", &project, "h|help", &Help);

        if(Help) ShowHelp();

        if(!mCfgFile.exists)
        {
            {
                scope(failure)
                {

                    Log.Entry("Failed: Unable to create configuration file: " ~ mCfgFile, "Error");
                }
                File tmp;
                tmp.open(mCfgFile, "w");
                tmp.write(`{"config": { "this_file": "` ~ mCfgFile ~`"}}`);
            }
        }
        mJson = parseJSON(readText(mCfgFile));

        if(TmpForLog.length)SetValue("log", "interim_log_file", TmpForLog);

        if(project.length)SetValue("project", "cmd_line_project", project);

        string[] Cmdfiles;
        foreach(cmd_line_file; CmdArgs[1 .. $])
        {
	        if(cmd_line_file[0] != '-')
	        {
		        Cmdfiles ~= buildNormalizedPath(absolutePath(cmd_line_file));
	        }
        }
        SetValue("docman", "cmd_line_files", Cmdfiles);
        Config.Save();

        Log.Entry("Engaged");
    }

    void PostEngage()
    {
		CurrentPath(getcwd());
	    if(isFirstRun) FirstUserRun();
	    Log.Entry("PostEngaged");
    }


    void Disengage()
    {
	    Save();
	    Log.Entry("Disengaged");
    }

    void Save()
    {
	    scope(failure)
	    {
		    Log.Entry("Unable to save configuration file " ~ mCfgFile, "Error");
            return;
        }

        mJson.writeJSON!(3)(File(mCfgFile,"w"));
        Saved.emit();
    }

    void SetValue(T)(string Section, string Name, T value)
	{
		if(Section !in mJson.object)mJson[Section] = jsonObject();
		mJson[Section][Name] = convertJSON(value);

		Changed.emit(Section,Name);
	}

	alias SetValue SetArray;


    void SetValue(T...)(string Section, string Name, T args)
	{
		if(Section !in mJson.object)mJson[Section] = jsonObject();
		mJson[Section][Name] = jsonArray();
		foreach (arg; args) mJson[Section][Name] ~= convertJSON(arg);
		Changed.emit(Section,Name);
    }

    void AppendValue(T...)(string Section, string Name, T args)
    {
	    if(Section !in mJson.object)mJson[Section] = jsonObject();
	    if(Name !in mJson[Section].object) mJson[Section][Name] = jsonArray();
	    foreach(arg; args) mJson[Section][Name] ~= convertJSON(arg);
		Changed.emit(Section,Name);
    }


    /+void AppendObject(DocPos)(string Section, string Name, DocPos Value )
    {
	    if( Section !in mJson.object) mJson[Section] = jsonObject();
	    if( Name !in mJson[Section].object) mJson[Section][Name] = jsonArray();
	    if( !mJson[Section][Name].isArray())return;
	    //foreach(V; Value)
	    //{
		    //writeln(V.expand);
		    auto tmpjson = jsonObject();
		    tmpjson["document"] = convertJSON(Value[0]);
		    tmpjson["line"] = convertJSON(Value[1]);
		    mJson[Section][Name] ~= tmpjson;
	   // }
		Changed.emit(Section,Name);

    }+/

    void AppendObject(string Section, string Name, JSON jobject)
    {
	    if( Section !in mJson.object) mJson[Section] = jsonObject();
	    if( Name !in mJson[Section].object) mJson[Section][Name] = jsonArray();
	    if( !mJson[Section][Name].isArray())return;


		mJson[Section][Name] ~= jobject;
		Changed.emit(Section,Name);
	}


    T GetValue(T)(string Section, string Name, T Default = T.init)
    {
        if(Section !in mJson.object)
        {
	        mJson[Section] = jsonObject();

        }
        if(Name !in mJson.object[Section].object)
        {
			mJson[Section].object[Name] = convertJSON(Default);
		}
        return cast(T)(mJson[Section][Name]);
    }
    T[] GetArray(T)(string Section, string Name, T[] Default = T[].init)
    {
	    if(Section !in mJson.object)
	    {
		    mJson[Section] = jsonObject();
		    mJson[Section][Name] = jsonArray();
		    mJson[Section][Name] = convertJSON(Default);
	    }
	    if(Name !in mJson[Section].object)
	    {
			mJson[Section][Name] = jsonArray();
			mJson[Section][Name] = convertJSON(Default);
		}
	    T[] rv;
	    foreach(elem; mJson[Section][Name].array)rv ~= cast(T)elem;
	    return rv;
    }

    void Remove(string Section, string key = "")
    {
		if((Section in mJson.object) is null) return;
	    if(key.length)
	    {
			if((key in mJson[Section]) is null) return;
		    mJson[Section].object.remove(key);
	    }
	    else
	    {
		    mJson.object.remove(Section);
	    }
		Changed.emit(Section, key);

    }

    string[] GetKeys(string Section = "")
    {
		if(Section == "")return mJson.object.keys;
		if(Section !in mJson.object) return [];
		return mJson[Section].object.keys;
	}

	bool HasSection(string Section)
	{
		return cast(bool)(Section in mJson.object);
	}

	bool HasKey(string Section, string Key)
	{
		if(Section !in mJson.object) return false;
		if(Key !in mJson[Section].object) return false;
		return true;
	}


    mixin Signal!() FirstRun;                   //sets up users environment
    mixin Signal!(string, string) Changed;      //some option has been changed
    mixin Signal!() Saved;                      //cfg has been saved
    mixin Signal!() Preconfigure;               //about to present option guis to user ... make sure values in guis are accurate/up to date
    mixin Signal!() Reconfigure;                //set variables to cfg values... ie apply all changes


}

void ShowHelp()
{
	writeln("DComposer a Naive IDE for the D programming Language");
	writeln("Version :",DCOMPOSER_VERSION);
	writeln(DCOMPOSER_COPYRIGHT);
	writeln();
	writeln("Usage:");
	writeln("  dcomposer [OPTION...] [FILES...]");
	writeln();
	writeln("OPTIONS");
	writeln("  -c, --config=CFG_FILE      specify session configuration file");
	writeln("                             (~/.neontotem/dcomposer/dcomposer.cfg is default)");
	writeln("  -l, --log=LOG_FILE         specify session log file");
	writeln("                             (~/.neontotem/dcomposer/dcomposer.log is default)");
	writeln("  -p, --project=PROJECT_FILE specify project to open");
	writeln("  -v, --verbosity=LEVEL      amount of logging information shown(LEVEL has not been defined yet)");
	writeln("  -q, --quiet                do not echo log messages to std out");
	writeln("  -h, --help                 show this help message");

	writeln("\nFILES");
	writeln("Any text files to open for editing.  Must be valid utf8 encoded files for this version");
	writeln("DComposer has been brought to you by the letter 'D'");
	//writeln("Also at this time project files are only opened as text files");
	exit(0);
}


private string mCurPath;

public string CurrentPath()
{
	return mCurPath;
}
public bool CurrentPath(string nuPath)
{
	scope(failure) return false;
	if(nuPath.isDir)
	{
		mCurPath = nuPath;
		chdir(nuPath);
		ui.AddStatus("mCurPath", mCurPath);
		return true;
	}
	return false;
}



public string ConfigPath(string subFolder)
{
	scope(failure) Log.Entry("Failed to build configuration path", "Error");
	return buildPath(userDirectory, subFolder);
}

public string SystemPath(string subFolder)
{
	scope(failure) Log.Entry("Failed to build system path", "Error");
	return buildPath(sysDirectory, subFolder);
}


/*
 * Ok, some notes about paths after hitting a few stone walls.
 * dir 1  defaults to ~/.config/dcomposer (or should it be ~/.local/share/dcomposer)
 * 	userDirectory
 * 		anything the user can add and/or change
 * 			. user configuration
 * 			. log file
 * 			. styles
 * 			. help files
 * 			. user added stuff (mods, plugins, blah blah)
 *
 * dir list XDG_DATA_DIR (/usr/local/share/dcomposer /usr/share/dcomposer /opt/dcomposer most likely)
 * 	installDirectories
 * 		where to search for the installed dcomposer directory (this seems like a silly way to find ones self)
 * dir 2 search installDirectories if dcomposer is
 * 	sysDirectory
 * 		permanent stuff
 * 			.glade files
 * 			.icons
 * 			.read only stuff
 * 			.everything in userDirectory for global usage (environment copied for new users)
 * */
