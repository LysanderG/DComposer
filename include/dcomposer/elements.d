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

    auto NewLibraries = AcquireLibraries();

    if(NewLibraries.length > 0)
    {
        string newElementsString;
        foreach(elemlib; NewLibraries) newElementsString ~= "\t"~ elemlib.baseName() ~"\n";

        auto response =ShowMessage("DComposer detected new elements", newElementsString ~ "To enable these elements please run element manager", "Ignore", "Manage Elements");

        if(response == 1) ui_elementmanager.Execute();
    }

    if(ElementsDisabled)
    {
        Log.Entry("Enaged : Elements disabled by user");
        return;
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
    //foreach(elem; Elements)elem.Disengage();
    foreach(key; Libraries.keys)
    {
        if(Libraries[key].mEnabled) Log.Entry("Unloading Element " ~ key);

        UnloadElement(key);
    }
    Log.Entry("Disengaged");
}

string[] AcquireLibraries()
{
    string[] newLibs;
    //first lets see what we have in the search paths ---> add a user option for more search paths silly
    auto available  = filter!`endsWith(a.name, ".so")`(dirEntries(ElementPaths[0],SpanMode.shallow));
    auto available1 = filter!`endsWith(a.name, ".so")`(dirEntries(ElementPaths[1],SpanMode.shallow));

    //now lets see whats "on record"
    auto LibsRegistered = Config.GetKeys("element_libraries");

    //check for new elements (libsavailable - libsregistered)
    foreach (string elemlib; chain(available, available1) )
    {
        auto elemkey = elemlib.baseName();
        Libraries[elemkey] = LIBRARY(elemlib);
        if(LibsRegistered.canFind(elemkey))
        {
            string[] libStuff = Config.GetArray!string("element_libraries", elemkey);
            Libraries[elemkey].mFile = libStuff[0];
            Libraries[elemkey].mClassName = libStuff[1];
            Libraries[elemkey].mName = libStuff[2];
            Libraries[elemkey].mInfo = libStuff[3];
            Libraries[elemkey].mEnabled = (libStuff[4] == "Enabled");
            Libraries[elemkey].mRegistered = true;
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
        Config.SetArray("element_libraries", lib.mFile.baseName(), regval);
    }
    Config.Save();
}


//for dynamically loading ....only load enabled elements which are not loaded ...?
void LoadElements()
{
    foreach(keyfile, ref lib; Libraries)
    {
        if(lib.mEnabled)
        {
            if(lib.Ptr is null)
            {
                lib.Ptr = Runtime.loadLibrary(lib.mFile.SystemPath());
                if(lib.Ptr is null)
                {
                    lib.mEnabled = false;
                    ShowMessage("Error loading dynamic library", "Failed to load " ~ lib.mFile, "Continue");
                    Log.Entry("Failed to load library: " ~ lib.mFile, "Error");
                    continue;
                }
                Log.Entry("Loaded library: " ~ lib.mFile);
                auto tmpvar = dlsym(lib.Ptr, "GetClassName");
                if(tmpvar is null)
                {
                    lib.mEnabled = false;
                    Log.Entry(lib.mFile ~ " is not a valid dcomposer element.", "Error");
                    ShowMessage("Error loading element", lib.mFile ~ " is not a valid dcomposer element", "Continue");
                    Runtime.unloadLibrary(lib.Ptr);
                    lib.Ptr = null;
                    continue;
                } 
                string function() GetClassName = cast(string function())tmpvar; //wouldn't work without tmpvar??
                if(GetClassName is null)
                {
                    lib.mEnabled = false;
                    Log.Entry(lib.mFile ~ " does not contain an ELEMENT interface.", "Error");
                    ShowMessage("Error loading element", lib.mFile ~ " does not contain an ELEMENT interface", "Continue");
                    Runtime.unloadLibrary(lib.Ptr);
                    lib.Ptr = null;
                    continue;
                }
                lib.mClassName = GetClassName().idup;
                auto  tmp = cast(ELEMENT)Object.factory(lib.mClassName);
                if(tmp is null)
                {
                    lib.mEnabled = false;
                    Log.Entry(lib.mClassName ~ " does not exist in element", "Error");
                    Runtime.unloadLibrary(lib.Ptr);
                    lib.Ptr = null;
                    continue;
                }
                lib.mName = tmp.Name.idup;
                lib.mInfo = tmp.Info.idup;
                lib.mRegistered = true;
                Elements[lib.mClassName] = tmp;
                Elements[lib.mClassName].Engage();
            }
        }
    }
}

bool UnloadElement(string Name)
{

    if(Libraries[Name].mClassName !in Elements) return false;
    bool rv;

    scope(failure)Log.Entry("Failed to unload " ~ Name, "Error");
    scope(success)Log.Entry("Unloaded library: " ~ Libraries[Name].mClassName);

    Elements[Libraries[Name].mClassName].Disengage();
    Config.Save();

    destroy(Elements[Libraries[Name].mClassName]);
    Elements.remove(Libraries[Name].mClassName);

    rv = Runtime.unloadLibrary(Libraries[Name].Ptr);
    Libraries[Name].Ptr = null;
    Libraries[Name].mEnabled = false;

    Config.Reload();

    return rv;
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


    @property void Ptr(void * x){mVptr = x;}
    @property void * Ptr(){return mVptr;}
    this(void * x){Ptr = x;}

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
