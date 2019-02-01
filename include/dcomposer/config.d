module config;

import dcore;
import ui;

import json;

import std.array;
import std.file;
import std.getopt;
import std.path;
import std.stdio;
import std.signals;
import std.string;
import std.utf;
import std.uni;
import std.encoding;
import std.typecons;

import core.stdc.stdlib;
import core.runtime;

bool isDcomposerInstalled;

string DCOMPOSER_VERSION;
string DCOMPOSER_BUILD_DATE;
string DCOMPOSER_COPYRIGHT;

string userDirectory;
string sysDirectory;

string BUILD_USER;
string BUILD_MACHINE;
long BUILD_NUMBER ;

static this()
{
    //mixin(import(".build.data"));
    DCOMPOSER_VERSION = "v0.1test";
    DCOMPOSER_BUILD_DATE = "January 24, 2019";
    DCOMPOSER_COPYRIGHT = "Copyright 2011 - 2019 Anthony Goins";
    BUILD_USER = "anthony@archdad";
    BUILD_MACHINE = "archdad";
    BUILD_NUMBER = 1000;
    userDirectory = "~/.config/dcomposer/".expandTilde();
    //s
}


class CONFIG
{
private:

    bool mIsFirstRun;
    string mCfgFile;
    JSON mJson;

    void FirstUserRun()
    {
        string WelcomeText = format(
    "Welcome to DComposer (ver %s, %s).\n"~
    "The naive IDE for the D programming language.\n"~
    "%s\n" ~
    "I really hope it proves useful for you.\n"~
    "Thanks for trying it out!",
    DCOMPOSER_VERSION, DCOMPOSER_BUILD_DATE, DCOMPOSER_COPYRIGHT);

        mCfgFile = buildPath(userDirectory,"dcomposer.cfg");
        Save();

        FirstRun.emit();
        ShowMessage("First Run", WelcomeText, "OK");
        Log.Entry("\tUsers first run.");
    }


public:
    alias mJson this;


    void Reload()
    {

        string CfgText = readText(mCfgFile);
        dstring FinalText;
        char[] copy = CfgText.dup;
        size_t i;
        while(i < CfgText.length)FinalText ~= copy.decode!(Flag!"useReplacementDchar".no, char[])(i);
        //while(i < CfgText.length)FinalText ~= std.utf.decode!(Flag!"useReplacementDchar".no,char[])(copy, i);

        mJson = parseJSON(FinalText);
    }
    void SetCfgFile(string cmdLineCfgName)
    {
        if(cmdLineCfgName.length)
        {
            if(cmdLineCfgName.exists) 
            {
                mCfgFile = cmdLineCfgName;
                return;
            }
            scope(failure)Log.Entry("Failed: Unable to create configuration file: " ~ cmdLineCfgName, "Error");
            std.file.write(cmdLineCfgName,`{"config": { "this_file": "` ~ cmdLineCfgName ~ `"}}`);
            mCfgFile = cmdLineCfgName;
            return;
        }
        //no cfg file given on command line so it is ~/.config/dcomposer/dcomposer.cfg
        else
        {
            mCfgFile = buildPath(userDirectory, "dcomposer.cfg");
            if(!mCfgFile.exists)std.file.write(mCfgFile, `{"config": { "this_file": "` ~ mCfgFile ~ `"}}`);
        }
    }


    /*@disable bool FindRootResourceDirectory(string ExecPath)
    {
        mDefaultRootResourceDirectory = "~/.config/dcomposer".expandTilde();
        mRootResourceDirectory.length = 0;
        //are we already set up in home directory?
        if(mDefaultRootResourceDirectory.exists)
        {
            mIsFirstRun = false;
            mRootResourceDirectory = mDefaultRootResourceDirectory;
        }
        else // we have to find where our resources are
        {
            mIsFirstRun = true;
            //use which to see if we are installed globally somewhere
            auto shellResponse = executeShell("which dcomposer");
            if(shellResponse.status == 0)
            {
                auto tmpDir = shellResponse.output.dirName();
                switch (tmpDir)
                {
                    case "/opt" :
                        mRootResourceDirectory = "/opt/dcomposer";
                        return true;
                    case "/usr/bin" :
                        mRootResourceDirectory = "/usr/share/dcomposer";
                        break;
                    case "/usr/local/bin" :
                        mRootResourceDirectory = "/usr/local/share/dcomposer";
                        break;
                    default :
                        break;
                }
            }
            else //it probably isnt installed globally
            {
                //look in path with the executable
                auto tmpDir = ExecPath.dirName();
                //tmpdir should contain elements, resources, glade, styles, flags, etc...
                //for now just check for resources
                if(buildPath(tmpDir, "resources").exists())
                {
                    mRootResourceDirectory = tmpDir;
                }
                else
                {
                    //ok last check, are resources in current directory
                    auto curDir = getcwd();
                    if(buildPath(curDir, "resources").exists())
                    {
                        mRootResourceDirectory = curDir;
                    }
                }
            }
        }
        if(mRootResourceDirectory.length == 0) return false;
        Log.Entry("\tResource files found @ " ~ mRootResourceDirectory);
        sysDirectory = mRootResourceDirectory;
        return true;
    }*/

    void Engage(string[] CmdArgs)
    {
        scope(failure) Log.Entry("Failed", "Error");

        bool ElementsDisabled; //dont allow elements to be loaded
        string TmpForCfg;   //user specified cfg file
        string TmpForLog;   //to use a seperate one off log file
        string project;     //start up with this project
        long Verbosity;     //how much stuff to log
        bool Quiet;         //show log stuff to std out
        bool Help;          //show a help screen
        
        bool dtagBuild;
        string dtagPackagePath;
        string dtagPackageName;
        string[] dtagImports;
        string[] dtagJpaths;
        
        sysDirectory = CmdArgs[0].dirName().buildPath("../").absolutePath().buildNormalizedPath();
        dwrite(sysDirectory);
        try
        {
            auto cmdResults = CmdArgs.getopt
            (
                std.getopt.config.noPassThrough, std.getopt.config.caseSensitive,
                "x|disableElements",
                "Do not allow plugins for the session.",
                &ElementsDisabled,
                "c|configFile",
                "Specify a configuration file.",
                &TmpForCfg,
                "l|logFile",
                "Specify a log file.",
                &TmpForLog,
                "v|verbose",
                "Not implemented.",
                &Verbosity,
                "q|quiet",
                "Do not send log messages to stdout.",
                &Quiet,
                "p|project",
                "Specify a project to load.",
                &project,
                "t|dtag",
                "Create a dtag file from a package.",
                &dtagBuild,
                "P|dtagPackage",
                "Full path to package for building dtag file.",
                &dtagPackagePath,
                "N|dtagName",
                "Name of dtag package.",
                &dtagPackageName,
                "I|dtagImports",
                "Additional import paths for building dtag file.",
                &dtagImports,
                "J|dtagStringImport",
                "Additional string import paths for building dtag file.",
                &dtagJpaths
            );
            
            if(cmdResults.helpWanted)
            {
                defaultGetoptPrinter(
                    "DComposer a Naive IDE for the D programming Language\n" ~
                    "Version :" ~ DCOMPOSER_VERSION ~ "\n" ~
                    DCOMPOSER_COPYRIGHT ~ "\n\n" ~
                    "Usage:\n" ~
                    "  dcomposer [OPTION...] [FILES...]\n" ~
                    
                    "OPTIONS",
    
                    cmdResults.options);
                writeln("\nFILES");
                writeln("Any text files to open for editing.  Must be valid utf8 encoded files for this version");
                writeln("DComposer has been brought to you by the letter 'D'");
                    exit(0);
            }
        }
        catch(GetOptException ohmy)
        {
            writeln("dcomposer: ",ohmy.msg, "\nTry 'dcomposer --help' for more information.");
            exit(0);
        }
        if(Help) ShowHelp();
        
        if(Quiet)Log.QuietStandardOut();
        
        if(!userDirectory.exists)
        {
            mkdir(userDirectory);
            mkdir(buildPath(userDirectory, "resources"));
            mkdir(buildPath(userDirectory, "elements"));
            mIsFirstRun = true;
                    
        }
        SetCfgFile(TmpForCfg);
        
        
        try
        {
            string CfgText = readText(mCfgFile);
            dstring FinalText;
            char[] copy = CfgText.dup;
            size_t i;
            while(i < CfgText.length)FinalText ~= copy.decode!(Flag!"useReplacementDchar".no, char[])(i);
            mJson = parseJSON(FinalText);
        }
        catch (Exception xsepchun)
        {
            Log.Entry(xsepchun.msg, "Error");
            mJson = parseJSON("{}");
        }
        
        if(dtagBuild)
        {
            BuildTagFile(dtagPackagePath, dtagPackageName, dtagImports, dtagJpaths);
            exit(0);
        }
        if(TmpForLog.length)SetValue("log", "interim_log_file", TmpForLog);
        SetValue("log", "echo_to_std_out", !Quiet);



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

        if(ElementsDisabled)SetValue("elements", "disabled", ElementsDisabled);

        Config.Save();



        Log.Entry("Engaged");
    }

    void PostEngage()
    {
        CurrentPath(Config.GetValue("config","starting_folder", getcwd()));
        if(mIsFirstRun) FirstUserRun();
        Log.Entry("PostEngaged");
    }


    void Disengage()
    {
        Save();
        Log.Entry("Disengaged");
    }

    void Save()
    {
        try
        {
            string jstring = toJSON!3(mJson);
            std.file.write(mCfgFile, jstring.sanitize());
        }
        catch(Exception x)
        {
            Log.Entry("Unable to save configuration file " ~ mCfgFile, "Error");
            Log.Entry(x.msg, "Error");
            return;
        }
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
    mixin Signal!(string) WorkingDirectory;     //emitted from CurrentPath



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
    writeln("                             (~/.config/dcomposer/dcomposer.cfg is default)");
    writeln("      --elements-disabled    disallow loading of elements(plugins) during session");
    writeln("  -l, --log=LOG_FILE         specify session log file");
    writeln("                             (~/.config/dcomposer/dcomposer.log is default)");
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
    if(mCurPath.length < 1) return getcwd();
    return mCurPath;
}
public bool CurrentPath(string nuPath)
{
    scope(failure) return false;
    if(nuPath == mCurPath) return true;
    if(nuPath.isDir)
    {
        mCurPath = nuPath;
        chdir(nuPath);
        Config.WorkingDirectory.emit(mCurPath);
        ui.AddStatus("mCurPath", mCurPath);
        return true;
    }
    return false;
}



deprecated public string ConfigPath(string subFolder)
{
    scope(exit)Log.Entry("ConfigPath has been deprecated");
    scope(failure) Log.Entry("Failed to build configuration path", "Error");
    return buildPath(userDirectory, subFolder);
}

public string SystemPath(string subFolder)
{
    scope(failure) Log.Entry("Failed to build system path", "Error");
    return buildPath(sysDirectory, subFolder);
}

public string RelativeSystemPath(string Folder)
{
    scope(failure)
    {
        Log.Entry("Error determining relative path", "Error");
        return Folder;
    }
    return relativePath(Folder, sysDirectory);
}
public string[] ElementPaths()
{
    string[] rv;
    rv.length = 2;
    rv[0] = buildPath(sysDirectory,"lib/dcomposer/elements");
    rv[1] = buildPath(userDirectory, "elements");
    return rv;
}
public string ElementPath(string file)
{
    string rv = buildPath(userDirectory, "elements/", file);
    if (rv.exists) return rv;
    rv = buildPath(sysDirectory, "lib/dcomposer/elements/", file);
    if (rv.exists) return rv;
    throw new Exception("Failed to find " ~ file ~ " in Element path.");

}
public string ResourcePath(string file){return buildPath(sysDirectory, "share/dcomposer/resources/",file);}
public string GladePath(string file)   {return buildPath(sysDirectory, "share/dcomposer/glade/",file);}
public string FlagsPath(string file)   {return buildPath(sysDirectory, "share/dcomposer/flags/",file);}
public string[] StylesPath()  
{
    string[] rv;
    rv.length = 2;
    rv[0] = buildPath(sysDirectory,"share/dcomposer/styles");
    rv[1] = buildPath(userDirectory, "styles");
    return rv;
}

/*
 * Ok, some notes about paths after hitting a few stone walls.
 * dir 1  defaults to ~/.config/dcomposer (or should it be ~/.local/share/dcomposer)
 *  userDirectory
 *      anything the user can add and/or change
 *          . user configuration
 *          . log file
 *          . styles
 *          . help files
 *          . user added stuff (mods, plugins, blah blah)
 *
 * dir list XDG_DATA_DIR (/usr/local/share/dcomposer /usr/share/dcomposer /opt/dcomposer most likely)
 *  installDirectories
 *      where to search for the installed dcomposer directory (this seems like a silly way to find ones self)
 * dir 2 search installDirectories if dcomposer is
 *  sysDirectory
 *      permanent stuff
 *          .glade files
 *          .icons
 *          .read only stuff
 *          .everything in userDirectory for global usage (environment copied for new users)
 * */
