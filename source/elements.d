module elements;

import std.algorithm;
import std.conv;
import std.file;
import std.getopt;
import std.path;
import std.range;
import core.runtime;
import core.sys.posix.dlfcn;

import qore;
import ui;

interface ELEMENT
{
    void Engage();
    void Mesh();
    void Disengage();

    void Configure();

    string Name();
    string Info();
    string Version();
    string License();
    string CopyRight();
    string Authors();

    Dialog SettingsDialog();
}

void Engage(ref string[] args)
{
    //cmdline stuff
    getopt(args, std.getopt.config.passThrough, "disableElements|X", &mElementsDisabled,"suppress|x", &mSuppressedElements);	
    dwrite(mSuppressedElements);
    if(mElementsDisabled) 
    {
        Log.Entry("Elements disabled for current session (not engaged)");
        return;
    }
    
    foreach (string regLibID; Config.GetKeys("registered_libraries"))
    {
        REGISTERED_LIBRARY tmpLib;
        
        auto values  = Config.GetArray!string("registered_libraries", regLibID);
        tmpLib.mFile = values[0];
        tmpLib.mID = values[1];
        tmpLib.mVersion = values[2];
        tmpLib.mInfo = values[3];
        tmpLib.mEnabled = values[4].to!bool;
        tmpLib.mBroken = values[5].to!bool;
        tmpLib.mAuthors = values[6];
        
        mRegisteredElements[regLibID] =  tmpLib;
    }
    foreach(suppressed; mSuppressedElements)
    {
        if(suppressed in mRegisteredElements) mRegisteredElements[suppressed].mSuppressed = true;
        else Log.Entry(suppressed ~ "is not a registered element");
                
    }
    AcquireNewElements();
    
    LoadElements();

    foreach (successfulElement; mElements)
    {
        successfulElement.Engage();
        successfulElement.Mesh();
     }
    
    Log.Entry("Engaged");
}

void Mesh()
{
    //foreach (elem; mElements)elem.Mesh();
    //not a good place to call element.mesh only happens once at startup ...
    //ignores that elements might be loaded dynamically anytime and need to call mesh.
    //was causing a frustrating double mesh error (2 connections for signals)
    Log.Entry("Meshed");
}

void Disengage()
{    
    foreach(reglib; mRegisteredElements)
    {
        string strEnabled = reglib.mEnabled.to!string;
        string strBroken = reglib.mBroken.to!string;
        Config.SetArray("registered_libraries", reglib.mID, 
        [ 
            reglib.mFile, reglib.mID, reglib.mVersion,
            reglib.mInfo, strEnabled, strBroken,
            reglib.mAuthors,
        ]);
    
    }
    foreach(lib; mRegisteredElements)
    {
        
        UnloadElement(lib.mID);   
    }
    //Config.Save();
    Log.Entry("Disengaged");
}

string GetCmdLineOptions()
{
	string rv;
	rv  ="\t-X	--disableElements\tDisable loading all elements for session.\n";
	rv ~="\t-x	--suppress=ELEMENT\tDisable specific ELEMENT for session.\n";
	return rv;
}

void DisableElement(string key)
{
    mRegisteredElements[key].mEnabled = false;
    UnloadElement(key);
}
void EnableElement(string key)
{
    mRegisteredElements[key].mEnabled = true;
    if(LoadElement(mRegisteredElements[key]))
    {
        mElements[key].Engage();
        mElements[key].Mesh();
        mRegisteredElements[key].mEnabled = true;
        return;
    }
    mRegisteredElements[key].mEnabled = false;
}

void BreakElement(string key)
{
    mRegisteredElements[key].mBroken = true;
    mRegisteredElements[key].mEnabled = false;
}
void UnbreakElement(string key)
{
    mRegisteredElements[key].mBroken = false;
}

auto GetRegisterdElements()
{
    return mRegisteredElements;
}

void ShowSettingDialog(string key)
{
    
    if(key !in mElements) return;
    Dialog dx = mElements[key].SettingsDialog();
    dx.run();
    dx.hide();

}

private:

ELEMENT[string]             mElements;

REGISTERED_LIBRARY[string]  mRegisteredElements;    //All the elements seen loaded or not (in config)
string[]                    mUnknownElements;       //Elements never seen before this session
string[]                    mBrokenElements;        //Elements marked to never load (must be broken right?)
string[]                    mSuppressedElements;    //Elements suppressed for currents session by user
bool                        mElementsDisabled;      //user disabled elements for current session



void AcquireNewElements()
{
    string[] allLibsFound;
    foreach (rd; resourceDirectories)
    {
        scope(failure) continue;
        foreach(string de; dirEntries(buildPath(rd,"elements"), "*.so", SpanMode.shallow))
        {
            de = baseName(de);
            allLibsFound ~= de;
            if(de !in mRegisteredElements)mUnknownElements ~= de;
        }
    }    
    if(mUnknownElements.length)
    {
        string msg = "The following elements have been discovered\n";
        foreach (string unknown; mUnknownElements) msg ~= "\t" ~ unknown ~"\n";
        msg ~= "These elements can be enabled in prefrences";
        ShowMessage("NEW ELEMENTS DISCOVERED", msg, "Continue");
        foreach(unRegLibrary; mUnknownElements) RegisterLibrary(unRegLibrary);
    }
}
void LoadElements()
{
    foreach(ref reglibrary; mRegisteredElements)
    {
        if((!reglibrary.mEnabled) || reglibrary.mBroken || reglibrary.mSuppressed)
        {
            Log.Entry(reglibrary.mID ~ " not loaded (disabled, broken or suppressed");
            continue;
        }
        LoadElement(reglibrary);
    }
}
bool LoadElement(ref REGISTERED_LIBRARY ElementLibrary)
{
   
   if(ElementLibrary.mPtr !is null)
   {
       Log.Entry(ElementLibrary.mID ~ ": Element appears to be loaded already");
       return false;
   }
   
   if(ElementLibrary.mEnabled == false)
   {
       Log.Entry(ElementLibrary.mID ~ ": Element has been disabled by user");
       return false;
   }
   if(ElementLibrary.mBroken)
   {
       Log.Entry(ElementLibrary.mID ~ ": Element has been marked as broken");
       return false;
   }
   
   scope(failure)
   {
       ElementLibrary.mBroken =true;
       return false;
   }
   ElementLibrary.mPtr = Runtime.loadLibrary(findResource(buildPath("elements", ElementLibrary.mID)));
   
   if(ElementLibrary.mPtr is null) 
   {
       ElementLibrary.mBroken = true;
       Log.Entry("Failed to load Element :" ~ ElementLibrary.mID);
       ShowMessage("Error Loading Element", "Faile to load " ~ ElementLibrary.mID ~ "\nElement marked as broken");
       return false;
   } 
   
   auto tmpVar = dlsym(ElementLibrary.mPtr, "GetElementName");
   if(tmpVar is null)
   {
       ElementLibrary.mBroken = true;
       ElementLibrary.mEnabled = false;
       rt_unloadLibrary(ElementLibrary.mPtr);
       Log.Entry(ElementLibrary.mID ~ " does not appear to be an element(Marked as broken)");
       ShowMessage("Broken element library", ElementLibrary.mID ~ "is not a valid element(marked as broken)");
       return false;
   }
   
   string function() GetElementName = cast(string function())tmpVar;
   
   ELEMENT theElement = cast(ELEMENT)Object.factory(GetElementName());
   if(theElement is null)
   {
       ElementLibrary.mBroken = true;
       ElementLibrary.mEnabled = false;
       rt_unloadLibrary(ElementLibrary.mPtr);
       Log.Entry("Failed to instantiate "~GetElementName());
       ShowMessage("Element Error", "Failed to instantiate " ~ GetElementName());
       return false;
   }
   ElementLibrary.mAuthors = theElement.Authors.idup;
   ElementLibrary.mInfo   = theElement.Info.idup;

    string strEnabled = ElementLibrary.mEnabled.to!string;
    string strBroken = ElementLibrary.mBroken.to!string;
   Config.SetArray("registered_libraries", ElementLibrary.mID, 
   [ 
        ElementLibrary.mFile, ElementLibrary.mID, ElementLibrary.mVersion,
        ElementLibrary.mInfo, strEnabled,strBroken,
        ElementLibrary.mAuthors,
   ]);
   
   
   mElements[ElementLibrary.mID] = theElement;
   return true;
          
}

void UnloadElement(string elementKey)
{
    if(elementKey !in mElements) return;
    ELEMENT victim = mElements[elementKey];
    mElements[elementKey].Disengage();
    mElements.remove(elementKey);
    destroy(victim);
    
    //auto rez = rt_unloadLibrary(mRegisteredElements[elementKey].mPtr);
    auto rez = Runtime.unloadLibrary(mRegisteredElements[elementKey].mPtr);
    mRegisteredElements[elementKey].mPtr = null;
    mRegisteredElements[elementKey].mEnabled = false;
}

void RegisterLibrary(string libraryID)
{
    REGISTERED_LIBRARY tmpReg;
    
    tmpReg.mFile = findResource(buildPath("elements", libraryID));
    tmpReg.mID = libraryID;
    tmpReg.mVersion = "Unknown";
    tmpReg.mInfo = "Unknown";
    tmpReg.mAuthors = "Unknown";
    tmpReg.mEnabled = false;
    tmpReg.mBroken = false;
    
    Config.SetArray!(string[])("registered_libraries", libraryID,
    [libraryID, libraryID, "Unknown", "Unknown", "false", "false", tmpReg.mAuthors]);
}


struct REGISTERED_LIBRARY
{
    string      mFile; //fullpathname
    string      mID;
    string      mVersion;
    string      mInfo;
    string      mAuthors;
    bool        mEnabled;
    bool        mBroken;
    bool        mSuppressed;    
    void       *mPtr;
}
