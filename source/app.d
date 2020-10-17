module app;

import std.file;
import std.stdio;


import qore;
import ui;
import elements;


int main(string[] args)
{
    
	HandleCommandLineHelp(args);

    qore.Engage(args);
    ui.Engage(args);
    elements.Engage(args);
    
    qore.Mesh();
    ui.Mesh();
    elements.Mesh();
    
    ui.run(args);
     
    elements.Disengage();
    ui.Disengage();
    qore.Disengage();
    
    return 0;
}


void HandleCommandLineHelp(ref string[] cmdLine)
{
	import std.getopt;
	import log;
	import config;
	import core.runtime;
	
	bool helpMe;
	
	auto optRes = getopt(cmdLine, std.getopt.config.passThrough);

	string helpString;
	if(optRes.helpWanted)
	{
		import core.stdc.stdlib;
		helpString  = "DComposer a naive IDE for the D programming language.\n";
		helpString ~= "Version: 0.6.\n";
		helpString ~= "USAGE: dcomposer [OPTIONS] <PROJECT> <DOCUMENTS...>\n";
		helpString ~= "OPTIONS\n";
		helpString ~= log.GetCmdLineOptions();
		helpString ~= config.GetCmdLineOptions();
		helpString ~= elements.GetCmdLineOptions();
		
		helpString ~= "PROJECT:\n\tProject to open (must be a .dpro file) subsequent project files will be opened in editor\n";
		helpString ~= "DOCUMENTS:\n\tValid utf8 text files opened in editor\n";
		helpString ~= "Thank you for your interest and time for this IDE.\n";
		helpString ~= "dcomposer has been bought to you by the letter D.\n";
		writeln(helpString);
    	Runtime.terminate();
    	exit(-1);
    }
}
