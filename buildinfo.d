#!/usr/bin/rdmd
module buildinfo;

import std.file;
import std.string;
import std.process;

int main(string[] args)
{
	scope(failure)return -1;
	string ver = environment["VERSION_FROM_GIT"];
	string pre = environment["PREFIX"];
	string output = format(`
string DCOMPOSER_VERSION = "%s";
string DCOMPOSER_PREFIX = "%s";
`, ver, pre);
	std.file.write(".build.info", output);
	return 0;
}

