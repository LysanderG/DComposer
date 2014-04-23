#!/usr/bin/rdmd

module builddata;

import std.process;
import std.file;
import std.string;
import std.path;
import std.array;
import std.conv;
import std.stdio;

int main(string[] args)
{
	scope(failure) return -1;

    auto ver = executeShell(`git describe --long --always`);
    auto date = executeShell(`date "+%x @ %R"`);
    auto copy = "Copyright 2011 - " ~ executeShell(`date "+%Y"`).output.chomp() ~ " Anthony Goins";
    auto user = environment.get("XDG_CONFIG_HOME", "~/.config".expandTilde());
    auto sys = getcwd();
    auto install = environment.get("XDG_DATA_DIRS", "/usr/local/share/:/usr/share/:/opt/");


    foreach(folder; install.split(":"))
    {
		auto check = buildPath(folder, "dcomposer");
		if(check.exists())
		{
			sys = check;
		}
	}


    ver.output  = ver.output.chomp();
    date.output = date.output.chomp();
    user = buildPath(user,"dcomposer");
    //sys  = buildPath(sys, "dcomposer");

    auto build_user = executeShell(`getent passwd $USER | cut -d ':' -f 5`);
    auto build_machine = executeShell(`hostname`);
    ulong build_number = 0;
    if(".build.data".exists())
    {
		auto bdfile = File(".build.data");
		string numberline;
		do {numberline = bdfile.readln();} while (!numberline.startsWith("//")) ;
		numberline = numberline[2 .. $].chomp();
		build_number = to!ulong(numberline);
		bdfile.close();
	}
	build_number++;

    string output = format(`

//%s
DCOMPOSER_VERSION = "%s";
DCOMPOSER_BUILD_DATE = "%s";
DCOMPOSER_COPYRIGHT = "%s";

userDirectory = "%s";
sysDirectory = "%s";
installDirectories = "%s";

BUILD_USER = "%s";
BUILD_MACHINE = "%s";
BUILD_NUMBER = %s;
	`,build_number, ver.output, date.output, copy, user, sys, install, build_user.output.chomp(",,,\n"), build_machine.output.chomp(), build_number);

    std.file.write(".build.data", output);
    return 0;
}





