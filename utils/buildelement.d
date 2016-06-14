#!/usr/bin/rdmd

module buildelement;

import std.process;
import std.stdio;
import std.file;
import std.path;

int main(string[] args)
{
    if (args.length != 2) return 1;
    chdir("./elements");

    string[] options = ["dmd",
                        "-g",
                        "-debug",
                        "-I../src/",
                        "-I../deps/dson",
                        "-shared",
                        "-fPIC",
                        "-defaultlib=libphobos2.so",
                        "-odelements",
                        "-of" ~ args[1].setExtension("so"),
                        "src/" ~ args[1]
                        ];
    auto rv = execute(options);
    writeln(rv.output);
    return rv.status;
}
