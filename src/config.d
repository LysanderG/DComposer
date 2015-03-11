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

bool isDcomposerInstalled;

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

    string mDefaultRootResourceDirectory;
    string mRootResourceDirectory;
    bool mIsFirstRun;
    string mCfgFile;
    JSON mJson;

    void FirstUserRun()
    {
        //copy resources from global (immutable) to user (mutable) space

        string src;
        string dest;
        string cpCommand;

        //copy any cfg files
        src = mRootResourceDirectory;
        dest = userDirectory;
        mkdir(dest);
        cpCommand = "cp " ~ src ~ "/*.cfg " ~ dest;
        executeShell(cpCommand);

        //elements
        dest = buildPath(userDirectory, "elements");
        mkdir(dest);
        cpCommand = "cp " ~ src ~ "/elements/*.so " ~ dest;
        dwrite(executeShell(cpCommand));

        //flags
        dest = buildPath(userDirectory, "flags");
        mkdir(dest);
        cpCommand = "cp " ~ src ~ "/flags/* " ~ dest;
        executeShell(cpCommand);

        //glade
        dest = buildPath(userDirectory, "glade");
        mkdir(dest);
        cpCommand = "cp " ~ src ~ "/glade/*.glade " ~ dest;
        executeShell(cpCommand);

        //resources
        dest = buildPath(userDirectory, "resources");
        mkdir(dest);
        cpCommand = "cp " ~ src ~ "/resources/* " ~ dest;
        executeShell(cpCommand);

        //styles
        dest = buildPath(userDirectory, "styles");
        mkdir(dest);
        cpCommand = "cp " ~ src ~ "/styles/*.xml " ~ dest;
        executeShell(cpCommand);

        //tags
        dest = buildPath(userDirectory, "tags");
        mkdir(dest);
        cpCommand = "cp " ~ src ~ "/tags/*.json " ~ dest;
        executeShell(cpCommand);

        FirstRun.emit();
        Log.Entry("\tUsers first run.");
    }


public:
    alias mJson this;

    void SetCfgFile(string cmdLineCfgName)
    {
        //1. use command line given cfg file
        //2. look at current directory
        //3. look at mRootResourceDirectory
        //4. create one in mRootResource directory
        //5. create one in  current

        scope(success)Log.Entry("\tConfiguration file set to: " ~ mCfgFile);
        //1
        if(cmdLineCfgName.length > 0)
        {
            if(!cmdLineCfgName.exists())
            {
                scope(failure)Log.Entry("Failed: Unable to create configuration file: " ~ cmdLineCfgName, "Error");
                File tmp;
                tmp.open(cmdLineCfgName, "w");
                tmp.write(`{"config": { "this_file": "` ~ cmdLineCfgName ~ `"}}`);
                mCfgFile = cmdLineCfgName;
                return;
            }
            else
            {
                mCfgFile = cmdLineCfgName;
                return;
            }
        }
        //2
        auto tmpdir1 = buildPath(getcwd(), "dcomposer.cfg");
        if(tmpdir1.exists)
        {
            mCfgFile = tmpdir1;
            return;
        }

        //3
        auto tmpdir2 = buildPath(mRootResourceDirectory, "dcomposer.cfg");
        if(tmpdir2.exists)
        {
            mCfgFile = tmpdir2;
            return;
        }
        //4
        {
            scope(failure)
            {
                scope(failure)Log.Entry("Failed: Unable to create configuration file.", "Error");
                File tmpF2;
                tmpF2.open(tmpdir1, "w");
                tmpF2.write(`{"config": { "this_file": "` ~ tmpdir1 ~ `"}}`);
                return;
            }
            File tmpF;
            tmpF.open(tmpdir2, "w");
            tmpF.write(`{"config": { "this_file": "` ~ tmpdir2 ~ `"}}`);
            mCfgFile = tmpdir2;
        }
    }


    bool FindRootResourceDirectory(string ExecPath)
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
                        break;
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
    }

    void Engage(string[] CmdArgs)
    {
        scope(failure) Log.Entry("Failed", "Error");

        string TmpForCfg;   //user specified cfg file
        string TmpForLog;   //to use a seperate one off log file
        string project;     //start up with this project
        long Verbosity;     //how much stuff to log
        bool Quiet;         //show log stuff to std out
        bool Help;          //show a help screen

        if(!FindRootResourceDirectory(CmdArgs[0]))
        {
            Log.Entry("Failed to find DComposer resource files!!", "Error");
        }

        CmdArgs.getopt(std.getopt.config.noPassThrough, "c|config", &TmpForCfg, "l|log", &TmpForLog, "v|verbosity", &Verbosity, "q|quiet", &Quiet, "p|project", &project, "h|help", &Help);

        if(Help) ShowHelp();

        SetCfgFile(TmpForCfg);

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
    scope(exit)dwrite(userDirectory, "**",subFolder);
    scope(failure) Log.Entry("Failed to build configuration path", "Error");
    return buildPath(userDirectory, subFolder);
}

public string SystemPath(string subFolder)
{
    scope(failure) Log.Entry("Failed to build system path", "Error");
    dwrite(buildPath(sysDirectory, subFolder));
    return buildPath(sysDirectory, subFolder);
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
