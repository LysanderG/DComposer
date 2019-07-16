#!/usr/bin/rdmd

module buildelement;

import std.process;
import std.stdio;
import std.file;
import std.path;

int main(string[] args)
{
    if(args.length == 2)
    {
        args.length = 4;
        args[1] = "/usr/";
        args[2] = "/usr/";
    }
    string DCOMPOSER_PREFIX = args[1];
    string GTKD_IMPORT = args[2];
    if (args.length != 4 )
    {
        writeln("USAGE: buildelement DCOMPOSER_PREFIX GTKD_IMPORTS ELEMENT_MODULE");
        writeln("\t DCOMPOSER_PREFIX is the path to where we are building dcomposer not where it is installed");
        writeln("\t GTKD_IMPORTS is where we can find the gtkd source files");
        writeln("\t ELEMENT_MODULE is the name of the element source file");
        writeln("Good luck :)");
        return 200;
    }
    chdir(buildPath(DCOMPOSER_PREFIX, "lib/dcomposer/elements/src"));

    string[] options = ["dmd",
                        "-g",
                        "-debug",
                        "-I" ~ buildPath(DCOMPOSER_PREFIX, "include/dcomposer"),
                        "-I" ~ GTKD_IMPORT,
                        "-I" ~ GTKD_IMPORT ~ "gtkd",
                        "-I" ~ GTKD_IMPORT ~ "sourceview",
                        "-I" ~ GTKD_IMPORT ~ "vte",
                        "-shared",
                        "-fPIC",
                        "-defaultlib=libphobos2.so",
                        "-odelements",
                        "-of" ~ buildPath(DCOMPOSER_PREFIX, "lib/dcomposer/elements", args[3].setExtension("so")),
                        buildPath(DCOMPOSER_PREFIX, "lib/dcomposer/elements/src", args[3]),
                        ];
    auto rv = execute(options);
    std.stdio.write("*\n",rv.output);
    return rv.status;
}
