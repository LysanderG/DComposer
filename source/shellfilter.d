module shellfilter;

import std.mmfile;
import std.path;
import std.process;
import std.string;

import config;


string Filter(string InputText, string FilterCommand)
{
    string mmFileName = buildPath(userDirectory, ".shell_filter");
	string FullCommand;  
      
	if(InputText.length < 1)
    {
        FullCommand = "echo | " ~ FilterCommand;
    }
    else
    {        
        auto txtbytes = InputText.representation();
        auto IFile = new MmFile(mmFileName,  MmFile.Mode.readWriteNew, txtbytes.length, cast(void*)null);

        foreach(i, ch; txtbytes)IFile[i] = ch;
        FullCommand = escapeShellCommand("cat", mmFileName) ~ " |";

        FullCommand ~= " " ~ FilterCommand;
    }

	auto rv = executeShell(FullCommand);

	if(rv.status)
	{
		return "!SHELLFILTER_ERROR!\n"~rv.output;
	}
	return rv.output;
}



