module shellfilter;

//import dcore;

import std.process;
import std.mmfile;
import std.stdio;
import std.string;
import std.algorithm;
import std.conv;


enum mmFileName = "dcomposer_filter";

string Filter(string InputText, string CmdLine)
{
	//adding an end o line to prevent freezing on commands that wait for stdin
	//now removing it because cat nulltextfile | echo //;date   causes error
	if(InputText.length < 1) InputText = "\0";
	auto txtbytes = InputText.representation();
	auto IFile = new MmFile(mmFileName,  MmFile.Mode.readWriteNew, txtbytes.length, cast(void*)null);

	foreach(i, ch; txtbytes)IFile[i] = ch;

	string FullCommand;
	if(InputText.length > 0)FullCommand = escapeShellCommand("cat", mmFileName) ~ " | ";// ~ escapeShellCommand(CmdLine) ~ " 2> " ~ mmErrorFile;

	FullCommand ~= " " ~ CmdLine;

	auto rv = executeShell(FullCommand);

	if(rv.status)
	{
		return "!DCOMPOSER_SHELLFILTER_ERROR!\n"~rv.output;
	}
	return rv.output;
}



