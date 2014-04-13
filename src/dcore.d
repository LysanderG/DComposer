module dcore;


public import config;
public import log;
public import docman;
public import project;
public import symbols;
public import search;
public import shellfilter;
//import debugger;

CONFIG		Config;
LOG			Log;
DOCMAN		DocMan;
PROJECT 	Project;
SYMBOLS 	Symbols;
//DEBUGGER 	Debugger;
//history
//bookmarks
//terminal --maybe
//shellif (for the shell filter thingy)


void Engage(string[] CmdLineArgs)
{
	Log = new LOG;
	Config = new CONFIG;
	DocMan = new DOCMAN;
	Project = new PROJECT;
	Symbols = new SYMBOLS;

	Config.		Engage(CmdLineArgs);
	Log.		Engage();
	DocMan.		Engage();
	Project.	Engage();
	Symbols.	Engage();
	search.		Engage();
	//debugger.	Engage();

	Log.Entry("Engaged");
}

void PostEngage()
{
	Config.		PostEngage();
	Log.		PostEngage();
	DocMan.     PostEngage();
	Project.	PostEngage();
	Symbols.	PostEngage();
	search.		PostEngage();
	//Debugger.	PostEngage();

	Log.Entry("PostEngaged");
}

void Disengage()
{
	//Debugger.	Disengage();
	search.		Disengage();
	Symbols.	Disengage();
	Project.	Disengage();
	DocMan. 	Disengage();
	Config.		Disengage();
	Log.		Entry("Disengaged");
	Log.		Disengage();
}

