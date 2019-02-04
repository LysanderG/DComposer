#!/usr/bin/rdmd

module builddata;

import std.process;
import std.file;
import std.string;
import std.path;
import std.array;
import std.conv;
import std.stdio;
import std.datetime;

int main(string[] args)
{
	string Version = "Unspecified";
	string date;
	string copyright;

	{ //version scope ?
		scope(failure)Version = "Unknown";
		auto result = executeShell("git describe");
		if(result.status == 0) Version = result.output.chomp;
	}
	//date
	auto now = Clock.currTime();
	date = now.toString();

	//copyright
	copyright = "Copyright © 2011 - " ~ now.year.to!string ~ " Anthony Goins";
	
	writeln(Version);
	writeln(date);
	writeln(copyright);

	string finalOutput= format(`
//.builddata file
DCOMPOSER_VERSION="%s";
DCOMPOSER_BUILD_DATE="%s";
DCOMPOSER_COPYRIGHT="%s";
//.builddata ends
//This has been so cut back it really isn't necessary anymore
`,Version, date, copyright);

	std.file.write(".build.data",finalOutput);
	return 0;
}





