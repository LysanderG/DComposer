module config;


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

import json;
import log;

string DCOMPOSER_VERSION;
string DCOMPOSER_BUILD_ID;
string DCOMPOSER_COPYRIGHT;

string userDirectory;
string sysDirectory;
string defaultConfigFile;
bool isInstalled;

static this()
{
	userDirectory = "~/.config/dcomposer".expandTilde();
	//sysDirectory = "/opt/dcomposer";
	sysDirectory = "/home/anthony/projects/dcomposerx";
	defaultConfigFile = buildPath(userDirectory, "dcomposer_nuveau.cfg");
}



//main config file others maybe created for "elements" or whatever
CONFIG Config;

void Engage(ref string[] cmdLineArgs)
{	
	Config = new CONFIG;
	
	string configFile;
	getopt(cmdLineArgs, std.getopt.config.passThrough, "config|c", &configFile);
	
	if(configFile.length < 1)configFile = defaultConfigFile;
	
	Config.SetCfgFile(configFile);
	Config.SetResourcePath("resource", "/home/anthony/projects/dcomposerx/resources");
	Config.Load();

	Log.Entry("Engaged");
	
	
}

void Mesh()
{
	Log.Entry("Meshed");

}

void Disengage()
{
	Config.Save();
	Log.Entry("Disengaged");
}

string GetCmdLineOptions()
{
	string rv;
	rv ~= "\t-c	--config=FILE\t\tset config file for session\n";
	return rv;
}

string findResource(string relativePath)
{
	auto optOne = buildPath(sysDirectory, relativePath);
	if(exists(optOne)) return optOne;
	auto optTwo = buildPath(userDirectory, relativePath);
	if(exists(optTwo))return optTwo;
	Log.Entry("Unable to locate resource " ~ relativePath, "Error");
	throw new Exception("Failed to locate resoure!");
}

class CONFIG
{
private:

    string mCfgFile;
    JSON mJson;
    //like mResourcePath["icons"] = "/opt/dcomposer/resources/icons/";
    //cfg.SetResource("glade", "/opt/dcomposer/glade");
    //cfg.GetResource("section", "key", "icons", "ying-yang.png"); <- /opt/dcomposer/resources/icons/ying-yang.png
    //cfg.GetResource("section", "key", "glade", "ui_preferences.glade"); <- /opt/dcomposer/glade/ui_preferences.glade 
    string[string] mResourcePath;

public:
    alias mJson this;

    void Load()
    {
        string CfgText = readText(mCfgFile);
        dstring FinalText;
        char[] copy = CfgText.dup;
        size_t i;
        while(i < CfgText.length)FinalText ~= copy.decode!(Flag!"useReplacementDchar".no, char[])(i);
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
    
    void SetResourcePath(string ResourceType, string ResourcePath)
    {
        //to do to do 
        mResourcePath[ResourceType] = ResourcePath;
    }
    
    string GetResource(string Section, string Key, string ResourceType, string Default = string.init)
    {
        return buildPath(mResourcePath[ResourceType], GetValue(Section, Key, Default));
           
    }

    mixin Signal!(string, string) Changed;      //some option has been changed
    mixin Signal!() Saved;                      //cfg has been saved
    mixin Signal!() Preconfigure;               //about to present option guis to user ... make sure values in guis are accurate/up to date
    mixin Signal!() Reconfigure;                //set variables to cfg values... ie apply all changes
    mixin Signal!(string) WorkingDirectory;     //emitted from CurrentPath
}
