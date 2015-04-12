module elements;

import dcore;
import ui;
public import ui_preferences;

import std.algorithm;
import std.range;
import std.path;
import std.file;
import std.string;
import std.conv;
import std.typecons;

import core.runtime;
import core.sys.posix.dlfcn;



LIBRARY[string] Libraries;
string[]    LibsNewlyAdded;     //diff of the above two


ELEMENT[string] Elements;


void Engage()
{

    auto ElementsDisabled = Config.GetValue("elements", "disabled", false);
    if(ElementsDisabled)
    {
        Log.Entry("Enaged : Elements disabled by user");
        return;
    }


    auto NewLibraries = AcquireLibraries();

    if(NewLibraries.length > 0)
    {
        string newElementsString;
        foreach(elemlib; NewLibraries) newElementsString ~= "\t"~ elemlib.baseName() ~"\n";

        auto response =ShowMessage("DComposer detected new elements", newElementsString ~ "To enable these elements please run element manager", "Ignore", "Manage Elements");

        if(response == 1) ui_elementmanager.Execute();
    }
    //ok now lets load the libraries and  engage elements
    LoadElements();


    Log.Entry("Engaged");
}


void PostEngage()
{

    Log.Entry("PostEngaged");
}

void Disengage()
{
    RegisterLibraries();
    foreach(elem; Elements) elem.Disengage();
    Log.Entry("Disengaged");
}

string[] AcquireLibraries()
{
    string[] newLibs;
    //first lets see what we have in the search paths ---> add a user option for more search paths silly
    auto available  = filter!`endsWith(a.name, ".so")`(dirEntries( SystemPath( Config.GetValue("elements", "element_path", "elements")),SpanMode.shallow));

    //now lets see whats "on record"
    auto LibsRegistered = Config.GetKeys("element_libraries");

    //check for new elements (libsavailable - libsregistered)
    foreach (string elemlib; available)
    {
        Libraries[elemlib] = LIBRARY(elemlib);
        if(LibsRegistered.canFind(elemlib))
        {
            string[] libStuff = Config.GetArray!string("element_libraries", elemlib);
            Libraries[elemlib].mFile = libStuff[0];
            Libraries[elemlib].mClassName = libStuff[1];
            Libraries[elemlib].mName = libStuff[2];
            Libraries[elemlib].mInfo = libStuff[3];
            Libraries[elemlib].mEnabled = (libStuff[4] == "Enabled");
            Libraries[elemlib].mRegistered = true;
            continue;
        }
        newLibs ~= elemlib;
    }
    return newLibs;
}

void RegisterLibraries()
{
    foreach(lib;Libraries)
    {
        //if(lib.mRegistered == false) continue;
        string[5] regval;
        regval[0] = lib.mFile;
        regval[1] = lib.mClassName;
        regval[2] = lib.mName;
        regval[3] = lib.mInfo;
        if(lib.mEnabled)regval[4] = "Enabled"; else regval[4] = "Disabled";
        Config.SetArray("element_libraries", lib.mFile, regval);
    }
}


//for dynamically loading ....only load enabled elements which are not loaded ...?
void LoadElements()
{
    foreach(keyfile, ref lib; Libraries)
    {
        if(lib.mEnabled)
        {
            if(lib.ptr is null)
            {
                lib.ptr = Runtime.loadLibrary(lib.mFile);
                if(lib.ptr is null)
                {
                    lib.mEnabled = false;
                    ShowMessage("Error loading dynamic library", "Failed to load " ~ lib.mFile, "Continue");
                    Log.Entry("     Failed to load library: " ~ lib.mFile, "Error");
                    continue;
                }
                Log.Entry("     Loaded library: " ~ lib.mFile);
                auto tmpvar = dlsym(lib.ptr, "GetClassName");
                string function() GetClassName = cast(string function())tmpvar; //wouldn't work without tmpvar??
                lib.mClassName = GetClassName();
                auto  tmp = cast(ELEMENT)Object.factory(lib.mClassName);
                lib.mName = tmp.Name;
                lib.mInfo = tmp.Info;
                lib.mRegistered = true;
                Elements[lib.mClassName] = tmp;
                Elements[lib.mClassName].Engage();
            }
        }
    }
}


/* *** NOTICE ***
 * ALL ELEMENT MODULES MUST HAVE A
 * extern (C) string GetClassName()
 * {
 *      return fullyQualifiedName!Element;
 * }
 * */

interface ELEMENT
{
    void Engage();
    void Disengage();

    void Configure();

    string Name();
    string Info();
    string Version();
    string License();
    string CopyRight();
    string[] Authors();

    PREFERENCE_PAGE PreferencePage();
}


struct LIBRARY
{
    void * mVptr;
    string mFile;
    string mClassName;
    string mName;
    string mInfo;
    bool mEnabled;
    bool mRegistered;


    @property void ptr(void * x){mVptr = x;}
    @property void * ptr(){return mVptr;}
    this(void * x){ptr = x;}

    this(string xFile)
    {
        mVptr = null;
        mFile = xFile;
        mClassName = null;
        mName = "unknown";
        mInfo = "unknown";
        mEnabled = false;
        mRegistered = false;
    }
}

/*
 * todo's
 *
 * add version numbers and possibly check em?
 * element manager! enable and or disable whenever not just at start up
 * preferences!! oh ... thats what i'm trying to do now
 *
 */
