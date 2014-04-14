#!/usr/local/bin/rdmd -I../deps/dson/

module createflagfile;

import std.stdio;
import std.process;
import std.string;
import std.uni;
import std.algorithm;
import std.xml;

import json;


bool CheckFlagState(string switchFlag, ref string switchString, out bool hasarg)
{
	if(switchString.startsWith("-version=ident"))return false;
	if(switchString.startsWith("-debug=ident"))return false;
	if(switchString.startsWith("-I"))return false;
	if(switchString.startsWith("-L"))return false;
	if(switchString.startsWith("-J"))return false;

	if(switchString.length <= 2) //"-x" "-xx"
	{
		hasarg = false;
		return true;
	}

	if(switchString.canFind("="))
	{
		auto idx = switchString.indexOf("=");
		switchString = switchString[0..idx];
		hasarg = true;
		return true;
	}

	auto placeholder = switchString.endsWith("filename", "directory", "objdir", "docdir");
	if(placeholder > 0)
	{
		if(placeholder == 1)switchString = switchString.chomp("filename");
		if(placeholder == 2)switchString = switchString.chomp("directory");
		if(placeholder == 3)switchString = switchString.chomp("objdir");
		if(placeholder == 4)switchString = switchString.chomp("docdir");
		hasarg = true;
		return true;
	}

	//everything else
	hasarg = false;
	return true;
}





int main(string[] args)
{
	string jfilename = "fileofflags.json";
	if(args.length > 1) jfilename = args[1];

	auto jflags = jsonObject();

	auto dmdOutput = executeShell("dmd --help");

	if(dmdOutput.status == 0)
	{
		auto flagarray = jsonArray();
		foreach(index, line; dmdOutput.output.splitLines())
		{
			writeln(line);

			if(index == 0) jflags["dmdversion"] = line;
			else
			{
				line = line.stripLeft();
				if(line.length < 1)continue;
				if(line[0] != '-')continue;
				auto spacedIndex = line.indexOf(" ");
				//auto equalIndex = line.indexOf("=");
				//if(equalIndex == -1) equalIndex = spacedIndex;
				auto switchString = line[0..spacedIndex];
				auto briefString = line[spacedIndex..$];
				bool hasArg;
				if(CheckFlagState(switchString, switchString, hasArg))
				{
					auto jsonFlagObject = jsonObject();
					jsonFlagObject["cmdstring"] = switchString;
					jsonFlagObject["brief"] = briefString.strip().encode();
					jsonFlagObject["hasargument"] = hasArg;

					flagarray ~= jsonFlagObject;
					writeln("    ",switchString, " : ", briefString.strip(), "(", hasArg, ")");
				}
			}
		}
		jflags["flags"] = flagarray;
		writeJSON!4(jflags, File(jfilename,"w"));
	}
	else
	{
		writeln("error executing dmd");
		return 64;
	}

	return 0;
}



