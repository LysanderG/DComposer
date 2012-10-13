#!/usr/bin/rdmd
module buildinfo;

import std.file;
import std.string;
import std.process;

int main(string[] args)
{
	scope(failure)return -1;
	string ver = environment.get("VERSION_FROM_GIT", shell("git describe --long --always"));


	string pre = environment.get("PREFIX", "/usr/local");

	string output = format(`
static string DCOMPOSER_VERSION = "%s";
static string DCOMPOSER_PREFIX = "%s";
`, chomp(ver), pre);
	std.file.write(".build.info", output);
	return 0;
}

