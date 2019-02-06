module dcore;


public import config;
public import log;
public import docman;
public import project;
public import symbols;
public import search;
public import shellfilter;
public import ddocconvert;
public import debugger;

CONFIG      Config;
LOG         Log;
DOCMAN      DocMan;
PROJECT     Project;
SYMBOLS     Symbols;

void Engage(string[] CmdLineArgs)
{
    Log = new LOG;
    Config = new CONFIG;
    DocMan = new DOCMAN;
    Project = new PROJECT;
    Symbols = new SYMBOLS;

    Config.     Engage(CmdLineArgs);
    Log.        Engage();
    DocMan.     Engage();
    Project.    Engage();
    Symbols.    Engage();
    search.     Engage();

    Log.Entry("Engaged");
}

void PostEngage()
{
    Config.     PostEngage();
    Log.        PostEngage();
    DocMan.     PostEngage();
    Project.    PostEngage();
    Symbols.    PostEngage();
    search.     PostEngage();

    Log.Entry("PostEngaged");
}

void Disengage()
{
    search.     Disengage();
    Symbols.    Disengage();
    Project.    Disengage();
    DocMan.     Disengage();
    Config.     Disengage();
    Log.        Entry("Disengaged");
    Log.        Disengage();
}

